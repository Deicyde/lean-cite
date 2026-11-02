module

public meta import Cite.Basic

/-!
# `cite_source`, `cite_sources`, `@[cite]`, `cite … in` and `#cite_tags`

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
      if fs.any (·.1 == "doc") then throwErrorAt d "the field `doc` is given twice: a docstring is `doc`"
      -- the comment's own text, which a Verso docstring does not keep as a string
      let fm ← getFileMap
      if let (some a, some b) := (d.raw.getPos?, d.raw.getTailPos?) then
        let text := String.Pos.Raw.extract fm.source a b
        let text := ((text.drop 3).dropEnd 2).trimAscii.toString
        unless text.isEmpty do fs := fs.push ("doc", text)
    modifyEnv (sourceExt.addEntry · { name := n, title := title.getString, fields := fs,
                                      module := (← getEnv).mainModule })
  | _ => throwUnsupportedSyntax

/-- Declare the sources a JSON file describes: `cite_sources "sources.json"`, the path being
relative to this file's directory, as for `include_str`. The file is an object from the name of
each source to its fields:

```json
{"ladr4e": {"title": "Linear Algebra Done Right, 4th edition", "type": "pdf",
            "uri": "https://linear.axler.net/LADR4e.pdf",
            "entries": {"3.21": {"title": "Fundamental theorem of linear maps"}}}}
```

A source needs a `title`. Its other fields are those of `cite_source`, all strings, with two
exceptions. `uri` may be an object from prefixes of entries to templates, for a database whose
addresses differ by kind of entry; each becomes the field `uri.<prefix>`. `entries` lists the
entries that may be cited, each with its fields or just its title; citing another is an error,
like a LaTeX `\ref` to an undefined label. A source without `entries` takes any entry.

Hovering over a source or an entry in a citation shows its fields. Lean reads the file when it
compiles this command. Lake does not know that the module depends on the file, so after editing
the file, rebuild the module, for instance by touching it. -/
syntax (name := citeSources) "cite_sources " str : command

@[command_elab citeSources]
def elabCiteSources : CommandElab
  | `(command| cite_sources $path:str) => do
    let some dir := (System.FilePath.mk (← getFileName)).parent
      | throwErrorAt path "cannot find the directory of this file"
    let text ← try IO.FS.readFile (dir / path.getString)
      catch e => throwErrorAt path m!"cannot read {path.getString}: {e.toMessageData}"
    let json ← match Json.parse text with
      | .ok j => pure j
      | .error e => throwErrorAt path m!"{path.getString} is not JSON: {e}"
    let sources ← match sourcesOfJson json with
      | .ok ss => pure ss
      | .error e => throwErrorAt path m!"{path.getString}: {e}"
    for s in sources do
      if let some d := (sourceDecls (← getEnv) s.name)[0]? then
        throwErrorAt path "the source `{s.name}` is already declared, in module `{d.module}`"
    let mod := (← getEnv).mainModule
    for s in sources do
      modifyEnv (sourceExt.addEntry · { s with module := mod })
  | _ => throwUnsupportedSyntax

/-- An option of a citation: `(rel := hasPart)` gives the relation, one of the Literature Links
relations; `(role := helper)` how the target takes part; `(part := "a")` the part of the entry.
Before a command, `(step := 2)` and `(statement := 2)` mark a step instead; see `cite … in`. -/
syntax citeOpt := "(" ident " := " (ident <|> str <|> num) ")"

/-- The options, each once: (key, value, the option's syntax). -/
def citeOptions (opts : Array (TSyntax ``citeOpt)) : CoreM (Array (String × String × Syntax)) := do
  let mut out := #[]
  for o in opts do
    let (key, val) ← match o with
      | `(citeOpt| ($k:ident := $v:ident)) => pure (k, v.getId.eraseMacroScopes.toString)
      | `(citeOpt| ($k:ident := $v:str)) => pure (k, v.getString)
      | `(citeOpt| ($k:ident := $v:num)) => pure (k, toString v.getNat)
      | _ => throwUnsupportedSyntax
    let k := key.getId.eraseMacroScopes.toString
    if out.any (·.1 == k) then throwErrorAt key "the option `{k}` is given twice"
    out := out.push (k, val, o.raw)
  return out

/-- The source named by `src`, or an error at it. Hovering over `src` shows the source. -/
def checkSource (src : Ident) : CoreM Source := do
  match findSource (← getEnv) src.getId.eraseMacroScopes with
  | .error msg => throwErrorAt src msg
  | .ok s =>
    addHover src s.hover
    return s

/-- An error at `id` unless it is one of the entries of `s`, when `s` lists them. Hovering over
`id` shows the entry. -/
def checkEntry (s : Source) (id : StrLit) : CoreM Unit := do
  unless s.entries.isEmpty || (s.entry? id.getString).isSome do
    throwErrorAt id (s.unknownEntry id.getString)
  addHover id (s.entryHover id.getString)

/-- Check a relation's name. -/
def checkRel (rel : String) (ref : Syntax) : CoreM Unit :=
  unless rel.isEmpty || relations.contains rel do
    throwErrorAt ref "unknown relation `{rel}`; the relations are {", ".intercalate relations}"

/-- The citation that the arguments of `cite` describe, for `target`. -/
def mkCitation (src : Ident) (id : StrLit) (opts : Array (TSyntax ``citeOpt))
    (comment : Option StrLit) (target : Target) : CoreM Citation := do
  let s ← checkSource src
  if id.getString.all Char.isWhitespace then throwErrorAt id "the entry of a citation cannot be empty"
  checkEntry s id
  let mut c : Citation := { source := s.name, id := id.getString, target,
                            comment := (comment.map (·.getString)).getD "",
                            module := (← getEnv).mainModule }
  for (k, val, o) in ← citeOptions opts do
    match k with
    | "rel" => checkRel val o; c := { c with rel := val }
    | "role" => c := { c with role := val }
    | "part" => c := { c with part := val }
    | "step" | "statement" =>
      throwErrorAt o "a step needs the lines it marks; write `cite … ({k} := …) in` before the \
        command, or wrap tactics or a term in `cite … step … =>` or `cite … step … in`"
    | k => throwErrorAt o "unknown option `{k}` of `cite`; the options are `rel`, `role` and `part`"
  return c

/-- The step tag that `src`, `id`, step numbers and a relation describe, for lines `start`–`stop`
of the current module. -/
def mkStepTag (src : Ident) (id : StrLit) (steps : Array Nat) (rel : String) (relRef : Syntax)
    (start stop : Nat) (form : String) : CoreM StepTag := do
  let s ← checkSource src
  if id.getString.all Char.isWhitespace then throwErrorAt id "the entry of a step cannot be empty"
  checkEntry s id
  if steps.any (· == 0) then throwErrorAt id "steps are numbered from 1"
  checkRel rel relRef
  return { source := s.name, id := id.getString, steps, rel, module := (← getEnv).mainModule,
           start, stop, form }

/-- `@[cite src "id"]` records that the declaration formalizes the entry `id` of the source `src`,
declared with `cite_source` or `cite_sources`. Options follow the entry, then an optional comment:
`@[cite ladr4e "1.3" (rel := hasPart) (role := helper) "associativity"]`.

The source is read as a name even when it is a keyword, such as `stacks` where `Cite.CrossRef` is
imported. An `example` keeps nothing; before one, write `cite src "id" in` instead. -/
syntax (name := cite) &"cite" ppSpace Lean.Parser.rawIdent ppSpace str (ppSpace citeOpt)*
  (ppSpace str)? : attr

/-- Is `decl` the name Lean gives an `example` while elaborating it, or a name under it, as for a
`where` helper of an example? -/
def isExampleName (decl : Name) : Bool :=
  decl.components.contains `_example

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

With `(step := k)`, it instead records that the command, from its keyword, carries out step `k` of
the proof of `id`; with `(statement := k)`, that its statement does, from its keyword to the end of
its signature. A step takes `(rel := …)` and no other option.

A command cannot start with a non-reserved word. This form therefore makes `cite` a keyword in
every file that imports it, as the cross-reference attributes do `stacks` and `kerodon`; write
`«cite»` for an identifier.

A proof is elaborated asynchronously, so its errors come after this command has recorded the
citation; a citation is recorded even when its command fails, as with `@[cite]`. -/
syntax (name := citeIn) "cite " Lean.Parser.rawIdent ppSpace str (ppSpace citeOpt)* (ppSpace str)?
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

/-- The step that `(step := k)` or `(statement := k)` marks on the command `inner`, whose keyword is
`kw`. -/
def commandStep (src : Ident) (id : StrLit) (opts : Array (String × String × Syntax))
    (comment : Option StrLit) (inner kw : Syntax) : CoreM StepTag := do
  let mut step := none
  let mut rel := ("", Syntax.missing)
  for (k, val, o) in opts do
    match k with
    | "step" | "statement" =>
      if step.isSome then throwErrorAt o "a command takes one of `step` and `statement`"
      let some n := val.toNat? | throwErrorAt o "a step is a number"
      step := some (k, n, o)
    | "rel" => rel := (val, o)
    | k => throwErrorAt o "a step takes `rel` and no `{k}`"
  if let some c := comment then throwErrorAt c "a step takes no comment"
  let some (form, n, o) := step | throwError "no step"
  let fm ← getFileMap
  let some pos := kw.getPos? | throwErrorAt inner "the command has no position"
  if form == "statement" && inner.isOfKind ``Parser.Command.mutual then
    throwErrorAt o "a `mutual` block has several statements; mark each declaration's instead"
  -- the statement runs to the end of the signature, or of the name when the signature is empty;
  -- the command, to its end
  let last ← if form == "statement" then
      let sig := inner.find? fun s => s.isOfKind ``Parser.Command.declSig ||
          s.isOfKind ``Parser.Command.optDeclSig
      match sig.bind (·.getTailPos?) <|> (inner.find? (·.isOfKind ``Parser.Command.declId)).bind
          (·.getTailPos?) <|> kw.getTailPos? with
      | some p => pure (some p)
      | none => throwErrorAt inner "this command has no statement"
    else pure inner.getTailPos?
  let some stop := last | throwErrorAt inner "the command has no position"
  mkStepTag src id #[n] rel.1 rel.2 (fm.toPosition pos).line (fm.toPosition stop).line
    (if form == "statement" then "statement" else "command")

@[command_elab citeIn]
def elabCiteIn : CommandElab
  | `(command| cite $src:ident $id:str $opts* $[$comment:str]? in $cmd) => do
    let inner := unwrapCommand cmd
    let some kw := keywordOf? inner | throwErrorAt cmd "the command has no keyword"
    let keyword := kw.getAtomVal
    let parsed ← liftCoreM <| citeOptions opts
    if parsed.any fun (k, _) => k == "step" || k == "statement" then
      -- a bad step is reported, and the command it wraps is still elaborated
      let t? ← try some <$> liftCoreM (commandStep src id parsed comment inner kw)
        catch e => logException e; pure none
      elabCommand cmd
      if let some t := t? then addStepTag t
      return
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
    | .decl n => m!"{(privateToUserName? n).getD n}"
    | .lines mod line _ kw => m!"the {kw} at {mod}:{line}"
  let opts := [("rel", c.rel), ("role", c.role), ("part", c.part)].filter (!·.2.isEmpty)
    |>.map fun (k, v) => s!" ({k} := {v})"
  let comment := if c.comment.isEmpty then "" else s!" \"{c.comment}\""
  m!"{c.source} {c.id}{String.join opts}{comment}: {target}"

/-- `#cite_tags` lists every citation, those of imported modules included; `#cite_tags src` those
of the source `src`. -/
elab (name := citeTags) "#cite_tags" src:(ppSpace Lean.Parser.rawIdent)? : command => do
  let env ← getEnv
  let name? := src.map (·.raw.getId.eraseMacroScopes)
  if let (some s, some n) := (src, name?) then
    if let .error msg := findSource env n then throwErrorAt s msg
  let cs := citations env |>.filter fun c => name?.all (c.source == ·)
  if cs.isEmpty then logInfo "No citations." else
  logInfo <| MessageData.joinSep (cs.toList.map (·.describe)) "\n"

end Cite
