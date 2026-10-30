module

public meta import Cite.Steps
public meta import Lean.Elab.Eval
public meta import Lean.Meta.Instances

/-!
# `#cite_export`

`#cite_export "out.json" Root₁ Root₂` writes, as JSON:

* `sources`: every declared source;
* `citations`: every citation, with the module and line range of what it cites;
* `steps`: the steps marked in the imported modules named `Rootᵢ` or `Rootᵢ.…`, by
  `-- cite … step` markers in their source files (`form` `comment`) or by wrappers (`tactic`,
  `term`, `command` or `statement`), with the lines each marks and the declaration that holds them;
* `mathlib`: the cross-references of Mathlib's attributes (`@[stacks]`, `@[kerodon]`,
  `@[wikidata]` and the rest), when Mathlib's attribute is imported, each with the module of the
  declaration it tags, which may be the project's own.

This package depends on Lean alone, so it reads Mathlib's `tagExt` through Mathlib's own API: it
elaborates and evaluates a term that names it. There is a term for each layout Mathlib has had:

* to 2026-05-12, `Mathlib.StacksTag.tagExt` (Stacks and Kerodon);
* from 2026-05-13, `Mathlib.CrossRef.tagExt` with `databaseURL` and `databaseLabel`;
* from 2026-07-04, with `Database.url : Database → String` and `Database.shortName`;
* from 2026-09-01 (Mathlib v4.34.0), with `Database.url : Database → String → String`.

The first term that elaborates is used. When the extension is there but no term fits, the export
warns and leaves Mathlib's cross-references out.

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

/-- A module's name as Literature Links wants it: dotted, without `«»`, naming its file. -/
def modName (m : Name) : String := m.toString (escape := false)

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
    ((moduleOf? env n).map fun m => ("module", toJson (modName m))).toList ++
    (ranges.map fun r => ("lines", toJson [r.range.pos.line, r.range.endPos.line])).toList

/-- Pairs whose value is empty are left out. -/
def nonEmpty (fields : List (String × String)) : List (String × Json) :=
  fields.filter (!·.2.isEmpty) |>.map fun (k, v) => (k, toJson v)

def citationJson (c : Citation) : CoreM Json := do
  let target ← match c.target with
    | .decl n => declJson n
    | .lines mod line stop kw => pure (Json.mkObj
        [("module", toJson (modName mod)), ("lines", toJson [line, stop]), ("keyword", toJson kw)])
  return Json.mkObj <| [("source", toJson c.source.toString), ("id", toJson c.id)] ++
    nonEmpty [("rel", c.rel), ("role", c.role), ("part", c.part), ("comment", c.comment),
              ("citedIn", modName c.module)] ++
    [("target", target)]

def sourceJson (s : Source) : Json :=
  Json.mkObj [("name", toJson s.name.toString), ("title", toJson s.title),
    ("module", toJson (modName s.module)),
    ("fields", Json.mkObj (s.fields.toList.map fun (k, v) => (k, toJson v)))]

/-- The declarations of module `mod` that have declaration ranges, with those ranges. Recursors,
the other constructions Lean adds to an inductive type, and a structure's constructor share the
type's lines, so they are left out. -/
def moduleDecls (env : Environment) (mod : Name) : CoreM (Array (Name × Nat × Nat)) := do
  let some idx := env.getModuleIdx? mod | return #[]
  let some data := env.header.moduleData[idx.toNat]? | return #[]
  let mut out := #[]
  for n in data.constNames do
    if ((privateToUserName? n).getD n).isInternal || isAuxRecursor env n || isNoConfusion env n ||
        (env.find? n matches some (.recInfo _)) then
      continue
    -- a structure's constructor shares its lines; an inductive's are written out
    if let some (.ctorInfo c) := env.find? n then
      if isStructure env c.induct then continue
    if let some r ← findDeclarationRanges? n then
      out := out.push (n, r.range.pos.line, r.range.endPos.line)
  return out

/-- The steps marked in module `mod`: its `-- cite … step` markers, read from its source file, and
its wrappers, from `tags`. Each holds `form`, `comment` for a marker, and is resolved to the
innermost declaration whose lines hold its own. -/
def stepsOf (mod : Name) (cs : Array Citation) (tags : Array StepTag) : CommandElabM (Array Json) := do
  -- `lake env` sets LEAN_SRC_PATH; `lake build` does not, and then the file is looked for from
  -- the working directory, the package's root
  let relPath := modToFilePath "." mod "lean"
  let path? ← match ← (← getSrcSearchPath).findWithExt "lean" mod with
    | some path => pure (some path)
    | none => pure (if ← relPath.pathExists then some relPath else none)
  let mut found : Array (Name × String × Array Nat × String × Nat × Nat × String × Option Nat) := #[]
  if let some path := path? then
    let r := scan (splitLines (← IO.FS.readFile path))
    for (line, msg) in r.problems do
      logWarning m!"{path}:{line}: {msg}"
    for mk in r.marks do
      let m := mk.marker
      if let .error msg := findSource (← getEnv) m.source then
        if (sourceDecls (← getEnv) m.source).size > 1 then throwError m!"{path}:{m.line}: {msg}"
        logWarning m!"{path}:{m.line}: {msg}; the marker is left out"
        continue
      found := found.push (m.source, m.id, m.steps, m.rel, mk.start, mk.stop, "comment", some m.line)
  else
    logWarning m!"no source file for module `{mod}` in LEAN_SRC_PATH or at {relPath}; \
      its comment markers are left out"
  for t in tags do
    if t.module == mod then
      found := found.push (t.source, t.id, t.steps, t.rel, t.start, t.stop, t.form, none)
  let decls ← liftCoreM <| moduleDecls (← getEnv) mod
  -- the commands a `cite … in` wraps in this module, which have no declaration of their own
  let anonymous := cs.filterMap fun c => match c.target with
    | .lines m line stop kw => if m == mod then some (line, stop, kw) else none
    | _ => none
  let mut out := #[]
  for (source, id, steps, rel, start, stop, form, marker) in found do
    -- the innermost declaration whose lines hold the marked ones
    let holders := decls.filter fun (_, a, b) => a ≤ start && stop ≤ b
    let holder := holders.foldl (init := none) fun best d => match best with
      | some b => if d.2.2 - d.2.1 < b.2.2 - b.2.1 then some d else best
      | none => some d
    let wrapped := anonymous.find? fun (a, b, _) => a ≤ start && stop ≤ b
    out := out.push <| Json.mkObj <|
      [("source", toJson source.toString), ("id", toJson id), ("steps", toJson steps)] ++
      nonEmpty [("rel", rel)] ++
      [("module", toJson (modName mod)), ("form", toJson form)] ++
      (marker.map fun l => ("marker", toJson l)).toList ++
      [("lines", toJson [start, stop])] ++
      (holder.map fun (n, _, _) =>
        ("declaration", toJson ((privateToUserName? n).getD n).toString)).toList ++
      (wrapped.map fun (_, _, kw) => ("keyword", toJson kw)).toList
  return out

/-- Mathlib's cross-references as (declaration, database, address, identifier, comment), one term
for each layout of Mathlib's attribute, newest first; the first that elaborates is used. -/
def mathlibReaders : List (Name × String) := [
  (`Mathlib.CrossRef.tagExt, "fun (env : Lean.Environment) =>
    let s := Lean.PersistentEnvExtension.getState Mathlib.CrossRef.tagExt env
    (s.2.flatten.appendList s.1).map fun t =>
      (t.declName, t.database.shortName, t.database.url t.tag, t.tag, t.comment)"),
  -- 2026-07-04 to 2026-08-31: `url` is the address of the database's tag pages
  (`Mathlib.CrossRef.tagExt, "fun (env : Lean.Environment) =>
    let s := Lean.PersistentEnvExtension.getState Mathlib.CrossRef.tagExt env
    (s.2.flatten.appendList s.1).map fun t =>
      (t.declName, t.database.shortName, t.database.url ++ t.tag, t.tag, t.comment)"),
  -- 2026-05-13 to 2026-07-03: no short name, so it is the label's first word ("Stacks Tag")
  (`Mathlib.CrossRef.tagExt, "fun (env : Lean.Environment) =>
    let s := Lean.PersistentEnvExtension.getState Mathlib.CrossRef.tagExt env
    (s.2.flatten.appendList s.1).map fun t =>
      let label := Mathlib.CrossRef.databaseLabel t.database
      (t.declName, ((label.splitOn \" \").headD label).toLower,
        Mathlib.CrossRef.databaseURL t.database ++ t.tag, t.tag, t.comment)"),
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
  let type := Expr.forallE `env (mkConst ``Environment) (toTypeExpr (Array MathlibRow)) .default
  let mut tried : Array Name := #[]
  for (ext, src) in mathlibReaders do
    unless env.contains ext do continue
    tried := tried.push ext
    -- a reader for another layout fails to elaborate; its errors are not this command's
    let messages := (← get).messages
    try
      let .ok stx := Parser.runParserCategory env `term src | continue
      let f ← liftTermElabM <| Term.withoutErrToSorry <|
        Term.evalTerm (Environment → Array MathlibRow) type stx
      return some (ext, f env)
    catch _ =>
      modify fun s => { s with messages }
  unless tried.isEmpty do
    let ext : Name := tried[0]!
    logWarning m!"Mathlib's cross-references are left out: `{ext}` is imported, but none of the \
      {tried.size} readers for its layouts fits this Mathlib"
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
  let cs := citations env
  let citationsJ ← liftCoreM <| cs.mapM citationJson
  let rootNames := roots.map (·.getId)
  let mods := env.header.moduleNames.filter fun m => rootNames.any (·.isPrefixOf m)
  let mut steps := #[]
  let tags := stepTags env
  for mod in mods do
    steps := steps ++ (← stepsOf mod cs tags)
  -- a source that two modules declare is an error where it is used, and a warning otherwise
  let used := (cs.map (·.source)) ++ steps.filterMap fun j => (j.getObjValAs? String "source").toOption.map (·.toName)
  let names := (sources env).foldl (init := #[]) fun ns s => if ns.contains s.name then ns else ns.push s.name
  for name in names do
    if let .error msg := findSource env name then
      if used.contains name then throwError msg else logWarning m!"{msg}; no citation uses it"
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
    ("roots", toJson (rootNames.map modName)),
    ("modules", toJson (mods.map modName)),
    ("sources", toJson ((sources env).map sourceJson)),
    ("citations", toJson citationsJ),
    ("steps", toJson steps),
    ("mathlibExtension", toJson ((mathlib.map (·.1.toString)).getD "")),
    ("mathlib", toJson mathlibJ)]
  IO.FS.writeFile path.getString (out.pretty ++ "\n")
  logInfo m!"{cs.size} citations, {steps.size} steps in {mods.size} modules, \
    {mathlibJ.size} Mathlib cross-references → {path.getString}"

end Cite
