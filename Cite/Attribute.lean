module

public meta import Cite.Basic

/-!
# `cite_source`, `@[cite]`, `cite … in` and `#cite_tags`

```lean
/-- Sheldon Axler, *Linear Algebra Done Right*, 4th edition. -/
cite_source ladr4e "Linear Algebra Done Right, 4th edition"
  (type := "pdf") (uri := "https://linear.axler.net/LADR4e.pdf")

@[cite ladr4e "3.21"]
theorem finrank_ker_add_finrank_range … := …

@[cite ladr4e "1.3" (rel := hasPart) "associativity of addition"]
theorem exercise_1A_2 … := …

cite ladr4e "1.14" in
example : … := …

attribute [cite ladr4e "1.33"] Submodule
```

Lean elaborates an `example` and then discards it, together with what an attribute recorded about
it. `@[cite]` on an `example` is therefore an error that points to `cite … in`, which records the
lines of the command it wraps. That form also serves `recall` and other commands that declare
nothing by name. The command it wraps is not a top-level command, so linters that look at top-level
commands, such as `linter.missingDocs`, do not see it.

Lean writes a declaration's own docstring after compiling it, which replaces what an attribute
appended before elaboration. Mathlib's cross-reference attributes append their links then, and lose
them on documented declarations. `@[cite]` leaves docstrings alone; links come from the exporter.
-/

public meta section

open Lean Elab Command

namespace Cite

/-- A field of a source: `(uri := "https://…")`. -/
syntax citeField := "(" ident " := " str ")"

/-- Declare a source that declarations can cite:
`cite_source ladr4e "Linear Algebra Done Right, 4th edition" (uri := "https://…")`.

The fields are free-form and passed to exporters. `uri` is the source's address; a `uri`
containing `{id}` is a template for the address of each entry, as for a web database. `type` is
the Literature Links type of the source's ends, such as `pdf` or `html`. `registry` names the
source in Literature Links `identifiers`, such as `wikidata`. A docstring is kept as the field
`doc`. The name must be unique among the projects imported together. -/
syntax (name := citeSource) (docComment)? "cite_source " ident ppSpace str (ppSpace citeField)* :
  command

@[command_elab citeSource]
def elabCiteSource : CommandElab
  | `(command| $[$doc]? cite_source $name:ident $title:str $fields*) => do
    let n := name.getId.eraseMacroScopes
    if let some s := (sourceDecls (← getEnv) n)[0]? then
      throwErrorAt name "the source `{n}` is already declared, in module `{s.module}`"
    let mut fs := #[]
    for f in fields do
      let `(citeField| ($k:ident := $v:str)) := f | throwUnsupportedSyntax
      let key := k.getId.eraseMacroScopes.toString
      if fs.any (·.1 == key) then throwErrorAt k "the field `{key}` is given twice"
      fs := fs.push (key, v.getString)
    if let some d := doc then
      fs := fs.push ("doc", d.getDocString.trimAscii.toString)
    modifyEnv (sourceExt.addEntry · { name := n, title := title.getString, fields := fs,
                                      module := (← getEnv).mainModule })
  | _ => throwUnsupportedSyntax

/-- An option of a citation: `(rel := hasPart)` gives the relation, one of the Literature Links
relations; `(role := helper)` how the target takes part; `(part := "a")` the part of the entry. -/
syntax citeOpt := "(" ident " := " (ident <|> str) ")"

/-- The citation that the arguments of `cite` describe, for `target`. -/
def mkCitation (src : Ident) (id : StrLit) (opts : Array (TSyntax ``citeOpt))
    (comment : Option StrLit) (target : Target) : CoreM Citation := do
  let name := src.getId.eraseMacroScopes
  if let .error msg := findSource (← getEnv) name then throwErrorAt src msg
  if id.getString.all Char.isWhitespace then throwErrorAt id "the entry of a citation cannot be empty"
  let mut c : Citation := { source := name, id := id.getString, target,
                            comment := (comment.map (·.getString)).getD "",
                            module := (← getEnv).mainModule }
  let mut seen : Array String := #[]
  for o in opts do
    let (key, val) ← match o with
      | `(citeOpt| ($k:ident := $v:ident)) => pure (k, v.getId.eraseMacroScopes.toString)
      | `(citeOpt| ($k:ident := $v:str)) => pure (k, v.getString)
      | _ => throwUnsupportedSyntax
    let k := key.getId.eraseMacroScopes.toString
    if seen.contains k then throwErrorAt key "the option `{k}` is given twice"
    seen := seen.push k
    match k with
    | "rel" =>
      unless relations.contains val do
        throwErrorAt o "unknown relation `{val}`; the relations are {", ".intercalate relations}"
      c := { c with rel := val }
    | "role" => c := { c with role := val }
    | "part" => c := { c with part := val }
    | k => throwErrorAt key "unknown option `{k}` of `cite`; the options are `rel`, `role` and `part`"
  return c

/-- `@[cite src "id"]` records that the declaration formalizes the entry `id` of the source `src`,
declared with `cite_source`. Options follow the entry, then an optional comment:
`@[cite ladr4e "1.3" (rel := hasPart) (role := helper) "associativity"]`.

An `example` keeps nothing; before one, write `cite src "id" in` instead. -/
syntax (name := cite) &"cite" ppSpace ident ppSpace str (ppSpace citeOpt)* (ppSpace str)? : attr

/-- Is `decl` the name Lean gives an `example` while elaborating it? -/
def isExampleName : Name → Bool
  | .str _ "_example" => true
  | _ => false

initialize registerBuiltinAttribute {
  name := `cite
  descr := "Record that a declaration formalizes an entry of a source declared with `cite_source`."
  add decl stx kind := do
    unless kind == .global do throwError "`cite` is global; it cannot be local or scoped"
    if isExampleName decl then
      throwError "an `example` is discarded after elaboration, together with what `@[cite]` \
        records; write `cite … in` before the `example` instead"
    let `(attr| cite $src:ident $id:str $opts* $[$comment:str]?) := stx | throwUnsupportedSyntax
    let c ← mkCitation src id opts comment (.decl decl)
    unless ← addCitation c do throwError "this module already records this citation"
}

/-- `cite src "id" in cmd` records that the command `cmd` formalizes the entry `id` of the source
`src`, by the lines `cmd` spans. It is for commands that declare nothing by name, such as an
`example` or a `recall`; a named declaration takes `@[cite src "id"]`. The options and comment are
those of `@[cite]`, and several `cite … in` may wrap the same command.

A command cannot start with a non-reserved word. This form therefore makes `cite` a keyword in
every file that imports it, as Mathlib's attributes do `stacks` and `kerodon`; write `«cite»` for
an identifier. -/
syntax (name := citeIn) "cite " ident ppSpace str (ppSpace citeOpt)* (ppSpace str)?
  " in" ppLine command : command

/-- The command that `cite … in`, `open … in` and `set_option … in` wrap. -/
partial def unwrapCommand (cmd : Syntax) : Syntax :=
  if cmd.isOfKind ``citeIn then unwrapCommand cmd[6]
  else if cmd.isOfKind ``Parser.Command.in then unwrapCommand cmd[2]
  else cmd

/-- What comes before a command's keyword: its docstring, attributes and modifiers. -/
def beforeKeyword : List SyntaxNodeKind :=
  [``Parser.Command.docComment, ``Parser.Term.attributes, ``Parser.Term.attrKind,
   ``Parser.Command.declModifiers]

/-- The keyword of a command: its first atom after its docstring, attributes and modifiers. -/
partial def keywordOf? (stx : Syntax) : Option Syntax :=
  match stx with
  | .atom .. => some stx
  | .node _ k args => if beforeKeyword.contains k then none else args.findSome? keywordOf?
  | _ => none

@[command_elab citeIn]
def elabCiteIn : CommandElab
  | `(command| cite $src:ident $id:str $opts* $[$comment:str]? in $cmd) => do
    let inner := unwrapCommand cmd
    let some kw := keywordOf? inner | throwErrorAt cmd "the command has no keyword"
    let keyword := kw.getAtomVal
    if (inner.find? (·.isOfKind ``Parser.Command.declId)).isSome then
      logWarningAt src m!"`{keyword}` declares a name; `@[cite …]` on it records the name, \
        which outlives line numbers"
    let fm ← getFileMap
    let some pos := kw.getPos? | throwErrorAt cmd "the command has no position"
    let some stop := inner.getTailPos? | throwErrorAt cmd "the command has no position"
    let target := .lines (← getMainModule) (fm.toPosition pos).line (fm.toPosition stop).line keyword
    -- a bad citation is reported, and the command it wraps is still elaborated
    let c? ← try some <$> liftCoreM (mkCitation src id opts comment target)
      catch e => logException e; pure none
    elabCommand cmd
    if let some c := c? then
      unless ← addCitation c do logErrorAt src "this module already records this citation"
  | _ => throwUnsupportedSyntax

/-- A line describing a citation, for `#cite_tags`. -/
def Citation.describe (c : Citation) : MessageData :=
  let target := match c.target with
    | .decl n => m!"{.ofConstName n}"
    | .lines mod line _ kw => m!"the {kw} at {mod}:{line}"
  let opts := [("rel", c.rel), ("role", c.role), ("part", c.part)].filter (!·.2.isEmpty)
    |>.map fun (k, v) => s!" ({k} := {v})"
  let comment := if c.comment.isEmpty then "" else s!" \"{c.comment}\""
  m!"{c.source} {c.id}{String.join opts}{comment}: {target}"

/-- `#cite_tags` lists every citation, those of imported modules included; `#cite_tags src` those
of the source `src`. -/
elab (name := citeTags) "#cite_tags" src:(ppSpace ident)? : command => do
  let env ← getEnv
  let name? := src.map (·.getId.eraseMacroScopes)
  if let (some s, some n) := (src, name?) then
    if let .error msg := findSource env n then throwErrorAt s msg
  let cs := citations env |>.filter fun c => name?.all (c.source == ·)
  if cs.isEmpty then logInfo "No citations." else
  logInfo <| MessageData.joinSep (cs.toList.map (·.describe)) "\n"

end Cite
