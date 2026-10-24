module

public meta import Lean.Elab.Command

/-!
# Citations: sources and the records of what cites them

A *source* is a work that Lean declarations cite: a book, an article, or a web database such as the
Stacks Project. `cite_source` declares one, and the registry is open: any project can declare its
own sources beside those another project declared.

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
  /-- The module that declared the source. -/
  module : Name := .anonymous
  deriving Inhabited, Repr

/-- The value of a field of the source. -/
def Source.field? (s : Source) (key : String) : Option String :=
  s.fields.find? (·.1 == key) |>.map (·.2)

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
