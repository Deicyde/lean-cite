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

An `example` is elaborated and then discarded, along with anything an attribute recorded about it,
so `@[cite]` on an `example` is an error that points to `cite … in`. That form records the lines of
the command it wraps, and also serves `recall` and other commands that declare nothing by name.

Unlike Mathlib's `@[stacks]`, `@[cite]` leaves docstrings alone. Lean writes a declaration's own
docstring after compiling it, which replaces what an attribute appended before elaboration, so a
documented declaration would lose the link; links come from the exporter instead.
-/

public meta section

open Lean Elab Command

namespace Cite

/-- A field of a source: `(uri := "https://…")`. -/
syntax citeField := "(" ident " := " str ")"

/-- Declare a source that declarations can cite:
`cite_source ladr4e "Linear Algebra Done Right, 4th edition" (uri := "https://…")`.

The fields are free-form and passed to exporters. `uri` is the source's address; a `uri`
containing `{id}` is a template for the address of each entry, as for a web database.
`type` is the Literature Links type of the source's ends, such as `pdf` or `html`. -/
syntax (name := citeSource) (docComment)? "cite_source " ident ppSpace str (ppSpace citeField)* :
  command

@[command_elab citeSource]
def elabCiteSource : CommandElab
  | `(command| $[$_doc]? cite_source $name:ident $title:str $fields*) => do
    let n := name.getId
    if let some s := findSource? (← getEnv) n then
      throwErrorAt name "the source `{n}` is already declared, in module `{s.module}`"
    let mut fs := #[]
    for f in fields do
      let `(citeField| ($k:ident := $v:str)) := f | throwUnsupportedSyntax
      fs := fs.push (k.getId.toString, v.getString)
    modifyEnv (sourceExt.addEntry · { name := n, title := title.getString, fields := fs,
                                      module := (← getEnv).mainModule })
  | _ => throwUnsupportedSyntax

/-- An option of a citation: `(rel := hasPart)` gives the relation, one of the Literature Links
relations; `(role := helper)` how the target takes part; `(part := "a")` the part of the entry. -/
syntax citeOpt := "(" ident " := " (ident <|> str) ")"

/-- The citation that the arguments of `cite` describe, for `target`. -/
def mkCitation (src : Ident) (id : StrLit) (opts : Array (TSyntax ``citeOpt))
    (comment : Option StrLit) (target : Target) : CoreM Citation := do
  let some _ := findSource? (← getEnv) src.getId
    | throwErrorAt src "unknown source `{src.getId}`; declare it with `cite_source`"
  if id.getString.isEmpty then throwErrorAt id "the entry of a citation cannot be empty"
  let mut c : Citation := { source := src.getId, id := id.getString, target,
                            comment := (comment.map (·.getString)).getD "",
                            module := (← getEnv).mainModule }
  for o in opts do
    let (key, val) ← match o with
      | `(citeOpt| ($k:ident := $v:ident)) => pure (k, v.getId.toString)
      | `(citeOpt| ($k:ident := $v:str)) => pure (k, v.getString)
      | _ => throwUnsupportedSyntax
    match key.getId.toString with
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

On an `example`, which keeps nothing, write `cite src "id" in example …` instead. -/
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
    addCitation c
}

/-- `cite src "id" in cmd` records that the command `cmd` formalizes the entry `id` of the source
`src`, by the lines `cmd` spans. It is for commands that declare nothing by name, such as an
`example` or a `recall`; a named declaration takes `@[cite src "id"]`. The options and comment are
those of `@[cite]`, and several `cite … in` may wrap the same command.

A command cannot start with a non-reserved word, so this makes `cite` a keyword in every file that
imports it, as Mathlib's attributes do `stacks` and `kerodon`; write `«cite»` for an identifier. -/
syntax (name := citeIn) "cite " ident ppSpace str (ppSpace citeOpt)* (ppSpace str)?
  " in" ppLine command : command

/-- The command that a chain of `cite … in` wraps. -/
partial def unwrapCiteIn (cmd : Syntax) : Syntax :=
  if cmd.isOfKind ``citeIn then unwrapCiteIn cmd[6] else cmd

/-- The first atom of `stx`, such as the keyword of a command. -/
partial def firstAtom? (stx : Syntax) : Option String :=
  match stx with
  | .atom _ val => some val
  | .node _ _ args => args.findSome? firstAtom?
  | _ => none

/-- The keyword of a command and the syntax it starts: for a declaration, the keyword after its
docstring, attributes and modifiers. -/
def commandKeyword (cmd : Syntax) : String × Syntax :=
  if cmd.isOfKind ``Parser.Command.declaration then
    ((firstAtom? cmd[1]).getD "", cmd[1])
  else ((firstAtom? cmd).getD "", cmd)

@[command_elab citeIn]
def elabCiteIn : CommandElab
  | `(command| cite $src:ident $id:str $opts* $[$comment:str]? in $cmd) => do
    let inner := unwrapCiteIn cmd
    let (keyword, head) := commandKeyword inner
    if inner.isOfKind ``Parser.Command.declaration &&
        (inner[1].find? (·.isOfKind ``Parser.Command.declId)).isSome then
      logWarningAt src m!"`{keyword}` declares a name; `@[cite …]` on it records the name, \
        which outlives line numbers"
    let fm ← getFileMap
    let some pos := head.getPos? | throwErrorAt cmd "the command has no position"
    let some stop := inner.getTailPos? | throwErrorAt cmd "the command has no position"
    let target := .lines (← getMainModule) (fm.toPosition pos).line (fm.toPosition stop).line keyword
    let c ← liftCoreM <| mkCitation src id opts comment target
    elabCommand cmd
    addCitation c
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
  if let some s := src then
    if (findSource? env s.getId).isNone then throwErrorAt s "unknown source `{s.getId}`"
  let cs := citations env |>.filter fun c => src.all (c.source == ·.getId)
  if cs.isEmpty then logInfo "No citations." else
  logInfo <| MessageData.joinSep (cs.toList.map (·.describe)) "\n"

end Cite
