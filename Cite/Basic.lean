module

public meta import Lean.Elab.Command
public meta import Lean.Data.Json

/-!
# Citations: sources and the records of what cites them

A *source* is a work that Lean declarations cite: a book, an article, or a web database such as the
Stacks Project. `cite_source` declares one, and `cite_sources` those a JSON file describes. The
registry is open: any project can declare its own sources beside those another project declared.

A *citation* records that a declaration, or a command with no name of its own such as an `example`,
formalizes an entry of a source, such as item 3.21 of a book. It is kept in `citeExt`, and
`Cite.citations` lists those of the current module and of every imported one.
-/

public meta section

open Lean

namespace Cite

/-- The [Literature Links](https://github.com/mathlib-initiative/literature-links) relations a
citation may state: how the source's entry relates to what cites it. -/
def relations : List String :=
  ["exactMatch", "closeMatch", "broadMatch", "narrowMatch", "relatedMatch", "hasPart", "noMatch"]

/-- A work that declarations cite. -/
structure Source where
  /-- The name citations use, such as `ladr4e`. -/
  name : Name
  /-- A readable title. -/
  title : String
  /-- Fields for exporters, as `cite_source` was given them, such as `("uri", "…")`. -/
  fields : Array (String × String) := #[]
  /-- The entries a JSON file lists for the source, each with its fields, such as
  `("3.21", #[("title", "Fundamental theorem of linear maps")])`. When there are any, a citation
  must name one of them; when there are none, any entry may be cited. -/
  entries : Array (String × Array (String × String)) := #[]
  /-- The module that declared the source. -/
  module : Name := .anonymous
  deriving Inhabited, Repr

/-- The value of a field of the source. -/
def Source.field? (s : Source) (key : String) : Option String :=
  s.fields.find? (·.1 == key) |>.map (·.2)

/-- The fields of the source's entry `id`, when the source lists `id` among its entries. -/
def Source.entry? (s : Source) (id : String) : Option (Array (String × String)) :=
  s.entries.find? (·.1 == id) |>.map (·.2)

/-- `template` with each `{id}` replaced by `id`, when it has an `{id}`. -/
def fillTemplate (template id : String) : Option String :=
  match template.splitOn "{id}" with
  | [_] => none
  | parts => some (id.intercalate parts)

/-- The address of the entry `id`: the entry's own field `uri`, or else the source's template for
it with `{id}` replaced by `id`. That template is the field `uri.p` for the longest prefix `p` of
`id` that has one, or else the field `uri`. A `uri` without `{id}` is the source's address, not an
entry's. -/
def Source.entryUri? (s : Source) (id : String) : Option String :=
  match (s.entry? id).bind (fun fs => fs.find? (·.1 == "uri")) with
  | some (_, u) => some u
  | none =>
    let byPrefix := s.fields.filterMap fun (k, v) =>
      if k.startsWith "uri." then
        let p := String.ofList (k.toList.drop 4)
        if id.startsWith p then some (p.length, v) else none
      else none
    let best := byPrefix.foldl (init := none) fun (b : Option (Nat × String)) c =>
      if b.all (·.1 < c.1) then some c else b
    match best with
    | some (_, t) => fillTemplate t id
    | none => (s.field? "uri").bind (fillTemplate · id)

/-- Markdown about the source, shown on hovering over its name in a citation: its title, its
docstring and its other fields. -/
def Source.hover (s : Source) : String :=
  let rest := s.fields.toList.filter (·.1 != "doc") |>.map fun (k, v) => s!"* `{k}`: {v}"
  let parts := [s!"**{s.title}**"] ++ (s.field? "doc").toList ++ ["\n".intercalate rest]
  "\n\n".intercalate (parts.filter (!·.isEmpty))

/-- Markdown about the entry `id` of the source, shown on hovering over the entry in a citation:
its title, its address, its other fields, and the source's docstring. -/
def Source.entryHover (s : Source) (id : String) : String :=
  let fields := (s.entry? id).getD #[]
  let title := match fields.find? (·.1 == "title") with
    | some (_, t) => s!": {t}"
    | none => ""
  let link := (s.entryUri? id).map fun u => s!"<{u}>"
  let rest := fields.toList.filter (fun (k, _) => k != "title" && k != "uri")
    |>.map fun (k, v) => s!"* `{k}`: {v}"
  let parts := [s!"**{s.title}**, {id}{title}"] ++ link.toList ++ ["\n".intercalate rest] ++
    (s.field? "doc").toList
  "\n\n".intercalate (parts.filter (!·.isEmpty))

/-- Why a citation of the source cannot name `id`: the source lists its entries, and `id` is not
one of them. -/
def Source.unknownEntry (s : Source) (id : String) : MessageData :=
  m!"the source `{s.name}` has no entry \"{id}\"; its entries are listed in the JSON file that \
    declares it, in module `{s.module}`"

/-- Is `w` a source name: parts of ASCII letters, digits and `_`, separated by `.`, none starting
with a digit? -/
def isSourceName (w : String) : Bool :=
  !w.isEmpty && (w.splitOn ".").all fun part =>
    match part.toList with
    | c :: cs => (c.isAlpha || c == '_') && cs.all (fun c => c.isAlphanum || c == '_')
    | [] => false

/-- The fields of `j`, an object whose values are strings, or why it is not one; `what` names `j`
in the message. -/
def stringFields (j : Json) (what : String) : Except String (Array (String × String)) := do
  let kvs ← j.getObj? |>.mapError fun _ => s!"{what} is not an object"
  kvs.toArray.mapM fun (k, v) => match v with
    | .str s => pure (k, s)
    | _ => throw s!"the field `{k}` of {what} is not a string"

/-- The sources a JSON file describes, or what is wrong with it: see `cite_sources`. -/
def sourcesOfJson (j : Json) : Except String (Array Source) := do
  let kvs ← j.getObj? |>.mapError fun _ =>
    "the file is not an object from the names of sources to their fields"
  kvs.toArray.mapM fun (name, v) => do
    let what := s!"the source `{name}`"
    unless isSourceName name do
      throw s!"{what} needs a name of letters, digits and `_`, in parts separated by `.`"
    let fs ← v.getObj? |>.mapError fun _ => s!"{what} is not an object"
    let mut title : Option String := none
    let mut fields : Array (String × String) := #[]
    let mut entries : Array (String × Array (String × String)) := #[]
    for (k, f) in fs.toArray do
      match k, f with
      | "title", .str t => title := some t
      | "title", _ => throw s!"the `title` of {what} is not a string"
      | "uri", .obj _ =>
        for (p, t) in ← stringFields f s!"the field `uri` of {what}" do
          fields := fields.push (s!"uri.{p}", t)
      | "entries", .obj es =>
        for (e, ef) in es.toArray do
          match ef with
          | .str t => entries := entries.push (e, #[("title", t)])
          | _ => entries := entries.push (e, ← stringFields ef s!"the entry `{e}` of {what}")
      | "entries", _ => throw s!"the `entries` of {what} is not an object"
      | k, .str s => fields := fields.push (k, s)
      | k, _ => throw s!"the field `{k}` of {what} is not a string"
    let some t := title | throw s!"{what} has no `title`"
    return ({ name := name.toName, title := t, fields, entries } : Source)

/-- Hover text as this version of Lean keeps it in `DelabTermInfo`: a string up to Lean 4.30, an
action from Lean 4.31. -/
class HoverText (α : Type) where
  ofString : String → α

instance : HoverText String := ⟨id⟩
instance : HoverText (PPContext → IO String) := ⟨fun s _ => pure s⟩

/-- Show `text`, in Markdown, on hovering over `stx`. -/
def addHover {m : Type → Type} [Monad m] [Elab.MonadInfoTree m] (stx : Syntax) (text : String) :
    m Unit :=
  Elab.pushInfoLeaf <| .ofDelabTermInfo <| Elab.DelabTermInfo.mk
    { elaborator := .anonymous, stx := stx, lctx := .empty, expectedType? := none,
      expr := mkStrLit text }
    none (some (HoverText.ofString text)) true

/-- What a citation is attached to. -/
inductive Target where
  /-- A declaration, by its full name. -/
  | decl (name : Name)
  /-- A command that declares nothing by name, such as an `example` or a `recall`: its module, the
  line of its keyword (after any docstring, attributes and modifiers), its last line, and the
  keyword. -/
  | lines (module : Name) (line stop : Nat) (keyword : String)
  deriving Inhabited, Repr, BEq

/-- `target` formalizes the entry `id` of the source `source`. -/
structure Citation where
  /-- The cited source. -/
  source : Name
  /-- The entry of the source, such as `"3.21"` or `"Exercise 1A.4"`. -/
  id : String
  /-- What cites it. -/
  target : Target
  /-- How the entry relates to the target, one of `relations`; empty when not stated. -/
  rel : String := ""
  /-- How the target takes part, such as `helper`; empty for the default. -/
  role : String := ""
  /-- A part of the entry, such as `"a"` for part (a) of an exercise; empty for the whole. -/
  part : String := ""
  /-- A free-text comment. -/
  comment : String := ""
  /-- The module that made the citation, which for `attribute [cite …] n` is not `n`'s. -/
  module : Name := .anonymous
  deriving Inhabited, Repr, BEq

/-- Lines that carry out steps of the proof of an entry, marked by syntax: a tactic block, a term,
a whole command or a command's statement. -/
structure StepTag where
  source : Name
  id : String
  steps : Array Nat
  /-- A relation from `relations`, or empty. -/
  rel : String := ""
  module : Name
  /-- The first and last marked line, from 1. -/
  start : Nat
  stop : Nat
  /-- What marks them: `tactic`, `term`, `command` or `statement`. -/
  form : String
  deriving Inhabited, Repr, BEq

/-- Add a declaration of a source to the registry. -/
def addSourceDecl (m : NameMap (Array Source)) (s : Source) : NameMap (Array Source) :=
  m.insert s.name (((m.find? s.name).getD #[]).push s)

/-- The registry of sources: those declared in this module and in every imported one, by name.
Two modules that do not import each other can declare the same name; `findSource` then refuses
it, naming both. -/
initialize sourceExt : SimplePersistentEnvExtension Source (NameMap (Array Source)) ←
  registerSimplePersistentEnvExtension {
    addEntryFn := addSourceDecl
    addImportedFn := fun as => as.foldl (init := {}) fun m a => a.foldl (init := m) addSourceDecl
  }

/-- The citations recorded by `@[cite]` and `cite … in`. `addImportedFn` is constant, as in
Mathlib's `tagExt`, so that importing many modules costs nothing until the citations are read. -/
initialize citeExt : SimplePersistentEnvExtension Citation (Array (Array Citation)) ←
  registerSimplePersistentEnvExtension {
    addImportedFn := id
    addEntryFn := fun s _ => s
  }

/-- The steps marked by syntax. A tactic or a term inside a proof records its step while the proof
is elaborated, which may be in a task of its own; an extension in mode `.sync` keeps what every
such task adds, and Lean saves all of it. A tactic that runs twice, under `all_goals` say, records
twice; readers drop the repeats. -/
initialize stepExt : SimplePersistentEnvExtension StepTag (Array (Array StepTag)) ←
  registerSimplePersistentEnvExtension {
    addImportedFn := id
    addEntryFn := fun s _ => s
    asyncMode := .sync
  }

/-- Every step marked by syntax, those of imported modules first, repeats left out. -/
def stepTags (env : Environment) : Array StepTag :=
  let s := PersistentEnvExtension.getState stepExt env
  (s.2.flatten ++ s.1.reverse.toArray).foldl (init := #[]) fun acc t =>
    if acc.contains t then acc else acc.push t

/-- Record a step marked by syntax, in the current module. -/
def addStepTag {m : Type → Type} [MonadEnv m] (t : StepTag) : m Unit :=
  modifyEnv (stepExt.addEntry · t)

/-- The declarations of the source named `name`: none, one, or more when modules clash. -/
def sourceDecls (env : Environment) (name : Name) : Array Source :=
  ((sourceExt.getState env).find? name).getD #[]

/-- The source named `name`, declared here or in an imported module, or why there is none. -/
def findSource (env : Environment) (name : Name) : Except MessageData Source :=
  match sourceDecls env name with
  | #[s] => .ok s
  | #[] => .error m!"unknown source `{name}`; declare it with `cite_source`"
  | ss => .error m!"the source `{name}` is declared in several modules: \
      {", ".intercalate (ss.toList.map (·.module.toString))}"

/-- Every declared source, ordered by name, clashing declarations included. -/
def sources (env : Environment) : Array Source :=
  (sourceExt.getState env).toArray.flatMap (·.2) |>.qsort (·.name.toString < ·.name.toString)

/-- Every citation, those of imported modules first, in the order they were made. -/
def citations (env : Environment) : Array Citation :=
  let s := PersistentEnvExtension.getState citeExt env
  s.2.flatten ++ s.1.reverse.toArray

/-- Record a citation in the current module, unless the module already made the same one; whether
it was new. -/
def addCitation {m : Type → Type} [Monad m] [MonadEnv m] (c : Citation) : m Bool := do
  if (citeExt.getEntries (← getEnv)).contains c then return false
  modifyEnv (citeExt.addEntry · c)
  return true

end Cite
