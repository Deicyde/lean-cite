module

public meta import Cite.Steps
public meta import Lean.Elab.Eval
public meta import Lean.Meta.Instances

/-!
# `#cite_export`

`#cite_export "out.json" Root₁ Root₂` writes, as JSON:

* `sources`: every declared source;
* `citations`: every citation, with the module and line range of what it cites;
* `steps`: the `-- cite … step` markers in the source files of the imported modules named
  `Rootᵢ` or `Rootᵢ.…`, with the lines each marks and the declaration that holds them;
* `mathlib`: the cross-references of Mathlib's attributes (`@[stacks]`, `@[kerodon]`,
  `@[wikidata]` and the rest), when Mathlib's attribute is imported, each with the module of the
  declaration it tags, which may be the project's own.

This package depends on Lean alone, so it reads Mathlib's `tagExt` through Mathlib's own API: it
elaborates and evaluates a term that names it. That term exists for the two layouts Mathlib has
had, `Mathlib.Tactic.StacksAttribute` (`Mathlib.StacksTag.tagExt`, Stacks and Kerodon) and, from
May 2026, `Mathlib.Tactic.CrossRefAttribute` (`Mathlib.CrossRef.tagExt`, every database).

A file of the module system sees another module's theorems as axioms and its private declarations
not at all. Run the export with `lake env lean export.lean` from a file that imports what it should
see and does not start with `module`.
-/

public meta section

open Lean Elab Command

namespace Cite

/-- The kind of a declaration, from its constant: `instance` for an instance, Prop-valued ones
included; `def` for a `partial def`; `abbrev` for any reducible definition. -/
def declKind (env : Environment) (n : Name) : String :=
  if Meta.isInstanceCore env n then "instance" else
  match env.find? n with
  | some (.thmInfo _) => "theorem"
  | some (.defnInfo _) =>
    if getReducibilityStatusCore env n == .reducible then "abbrev" else "def"
  | some (.opaqueInfo _) => if env.contains (n ++ `_unsafe_rec) then "def" else "opaque"
  | some (.inductInfo _) =>
    if isClass env n then "class" else if isStructure env n then "structure" else "inductive"
  | some (.axiomInfo _) => "axiom"
  | some (.ctorInfo _) => "constructor"
  | some (.recInfo _) => "recursor"
  | some (.quotInfo _) => "quot"
  | none => "unknown"

/-- The module that declares `n`. -/
def moduleOf? (env : Environment) (n : Name) : Option Name := do
  let idx ← env.getModuleIdxFor? n
  env.header.moduleNames[idx.toNat]?

/-- `{"declaration", "module", "kind", "lines"}` for a declaration, `lines` being the first and last
line of its whole syntax, docstring included. A private declaration is named as Lean prints it,
and marked `"private": true`. -/
def declJson (n : Name) : CoreM Json := do
  let env ← getEnv
  let ranges ← findDeclarationRanges? n
  let shown := (privateToUserName? n).getD n
  return Json.mkObj <|
    [("declaration", toJson shown.toString), ("kind", toJson (declKind env n))] ++
    (if isPrivateName n then [("private", toJson true)] else []) ++
    ((moduleOf? env n).map fun m => ("module", toJson m.toString)).toList ++
    (ranges.map fun r => ("lines", toJson [r.range.pos.line, r.range.endPos.line])).toList

/-- Pairs whose value is empty are left out. -/
def nonEmpty (fields : List (String × String)) : List (String × Json) :=
  fields.filter (!·.2.isEmpty) |>.map fun (k, v) => (k, toJson v)

def citationJson (c : Citation) : CoreM Json := do
  let target ← match c.target with
    | .decl n => declJson n
    | .lines mod line stop kw => pure (Json.mkObj
        [("module", toJson mod.toString), ("lines", toJson [line, stop]), ("keyword", toJson kw)])
  return Json.mkObj <| [("source", toJson c.source.toString), ("id", toJson c.id)] ++
    nonEmpty [("rel", c.rel), ("role", c.role), ("part", c.part), ("comment", c.comment),
              ("citedIn", c.module.toString)] ++
    [("target", target)]

def sourceJson (s : Source) : Json :=
  Json.mkObj [("name", toJson s.name.toString), ("title", toJson s.title),
    ("module", toJson s.module.toString),
    ("fields", Json.mkObj (s.fields.toList.map fun (k, v) => (k, toJson v)))]

/-- The declarations of module `mod` that have declaration ranges, with those ranges. Recursors and
the other constructions Lean adds to an inductive type share its range, so they are left out. -/
def moduleDecls (env : Environment) (mod : Name) : CoreM (Array (Name × Nat × Nat)) := do
  let some idx := env.getModuleIdx? mod | return #[]
  let some data := env.header.moduleData[idx.toNat]? | return #[]
  let mut out := #[]
  for n in data.constNames do
    if ((privateToUserName? n).getD n).isInternal || isAuxRecursor env n || isNoConfusion env n ||
        (env.find? n matches some (.recInfo _)) then
      continue
    if let some r ← findDeclarationRanges? n then
      out := out.push (n, r.range.pos.line, r.range.endPos.line)
  return out

/-- The `-- cite … step` markers of module `mod`, read from its source file. -/
def stepsOf (mod : Name) (cs : Array Citation) : CommandElabM (Array Json) := do
  -- `lake env` sets LEAN_SRC_PATH; `lake build` does not, and then the file is looked for from
  -- the working directory, the package's root
  let relPath := modToFilePath "." mod "lean"
  let path ← match ← (← getSrcSearchPath).findWithExt "lean" mod with
    | some path => pure path
    | none =>
      unless ← relPath.pathExists do
        logWarning m!"no source file for module `{mod}` in LEAN_SRC_PATH or at {relPath}"
        return #[]
      pure relPath
  let r := scan (splitLines (← IO.FS.readFile path))
  for (line, msg) in r.problems do
    logWarning m!"{path}:{line}: {msg}"
  let decls ← liftCoreM <| moduleDecls (← getEnv) mod
  -- the commands a `cite … in` wraps in this module, which have no declaration of their own
  let anonymous := cs.filterMap fun c => match c.target with
    | .lines m line stop kw => if m == mod then some (line, stop, kw) else none
    | _ => none
  let mut out := #[]
  for mk in r.marks do
    let m := mk.marker
    if let .error msg := findSource (← getEnv) m.source then
      logWarning m!"{path}:{m.line}: {msg}; the marker is left out"
      continue
    -- the innermost declaration whose lines hold the marked ones
    let holders := decls.filter fun (_, a, b) => a ≤ mk.start && mk.stop ≤ b
    let holder := holders.foldl (init := none) fun best d => match best with
      | some b => if d.2.2 - d.2.1 < b.2.2 - b.2.1 then some d else best
      | none => some d
    let wrapped := anonymous.find? fun (a, b, _) => a ≤ mk.start && mk.stop ≤ b
    out := out.push <| Json.mkObj <|
      [("source", toJson m.source.toString), ("id", toJson m.id),
       ("steps", toJson m.steps)] ++ nonEmpty [("rel", m.rel)] ++
      [("module", toJson mod.toString), ("marker", toJson m.line),
       ("lines", toJson [mk.start, mk.stop])] ++
      (holder.map fun (n, _, _) =>
        ("declaration", toJson ((privateToUserName? n).getD n).toString)).toList ++
      (wrapped.map fun (_, _, kw) => ("keyword", toJson kw)).toList
  return out

/-- Mathlib's cross-references as (declaration, database, address, identifier, comment), one term
for each layout of Mathlib's attribute; the first whose extension is in the environment is used. -/
def mathlibReaders : List (Name × String) := [
  (`Mathlib.CrossRef.tagExt, "fun (env : Lean.Environment) =>
    let s := Lean.PersistentEnvExtension.getState Mathlib.CrossRef.tagExt env
    (s.2.flatten.appendList s.1).map fun t =>
      (t.declName, t.database.shortName, t.database.url t.tag, t.tag, t.comment)"),
  (`Mathlib.StacksTag.tagExt, "fun (env : Lean.Environment) =>
    let s := Lean.PersistentEnvExtension.getState Mathlib.StacksTag.tagExt env
    (s.2.flatten.appendList s.1).map fun t =>
      let (db, url) := match t.database with
        | .stacks => (\"stacks\", \"https://stacks.math.columbia.edu/tag/\")
        | .kerodon => (\"kerodon\", \"https://kerodon.net/tag/\")
      (t.declName, db, url ++ t.tag, t.tag, t.comment)")]

/-- A row of Mathlib's cross-references. -/
abbrev MathlibRow := Name × String × String × String × String

unsafe def readMathlibUnsafe : CommandElabM (Option (Name × Array MathlibRow)) := do
  let env ← getEnv
  for (ext, src) in mathlibReaders do
    unless env.contains ext do continue
    let stx ← match Parser.runParserCategory env `term src with
      | .ok stx => pure stx
      | .error e => throwError "cannot parse the reader of `{ext}`: {e}"
    let type := Expr.forallE `env (mkConst ``Environment) (toTypeExpr (Array MathlibRow)) .default
    let f ← liftTermElabM <| Term.evalTerm (Environment → Array MathlibRow) type stx
    return some (ext, f env)
  return none

/-- Mathlib's cross-references, with the extension they were read from, when Mathlib's attribute
is imported. -/
@[implemented_by readMathlibUnsafe]
opaque readMathlib : CommandElabM (Option (Name × Array MathlibRow))

/-- Write the citations, step markers, sources and Mathlib's cross-references as JSON; see the
module docstring. -/
elab (name := citeExport) "#cite_export " path:str roots:(ppSpace ident)* : command => do
  let env ← getEnv
  -- a module sees only what its imports make public: theorems as axioms, private names not at all
  if env.header.isModule then
    throwError "`#cite_export` needs a file that does not start with `module`, which sees every \
      declaration whole"
  for s in sources env do
    if let .error msg := findSource env s.name then throwError msg
  let cs := citations env
  let citationsJ ← liftCoreM <| cs.mapM citationJson
  let rootNames := roots.map (·.getId)
  let mods := env.header.moduleNames.filter fun m => rootNames.any (·.isPrefixOf m)
  let mut steps := #[]
  for mod in mods do
    steps := steps ++ (← stepsOf mod cs)
  let mathlib ← readMathlib
  let mathlibJ ← liftCoreM <| (mathlib.map (·.2)).getD #[] |>.mapM
    fun (n, db, url, tag, comment) => do
      let d ← declJson n
      return d.mergeObj <| Json.mkObj <|
        [("database", toJson db), ("id", toJson tag), ("url", toJson url)] ++
        nonEmpty [("comment", comment)]
  let out := Json.mkObj [
    ("format", toJson "cite-export/1"),
    ("lean", toJson Lean.versionString),
    ("roots", toJson (rootNames.map (·.toString))),
    ("modules", toJson (mods.map (·.toString))),
    ("sources", toJson ((sources env).map sourceJson)),
    ("citations", toJson citationsJ),
    ("steps", toJson steps),
    ("mathlibExtension", toJson ((mathlib.map (·.1.toString)).getD "")),
    ("mathlib", toJson mathlibJ)]
  IO.FS.writeFile path.getString (out.pretty ++ "\n")
  logInfo m!"{cs.size} citations, {steps.size} step markers in {mods.size} modules, \
    {mathlibJ.size} Mathlib cross-references → {path.getString}"

end Cite
