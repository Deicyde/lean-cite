/-
The declarations whose docstrings the candidates are compared on. `ProbeImport.lean` imports this
file and prints the same report, so a candidate is judged in the file that declares a tag and in a
file that imports it.
-/
module

public meta import Lean.Elab.Command
public import Mathlib.Tactic.CrossRefAttribute
public import Mathlib.Tactic.Lemma
public import Mathlib.Tactic.IrreducibleDef
public import Mathlib.Tactic.ToAdditive

@[expose] public section

namespace Probe

/-! ### Theorems: asynchronous when `Elab.async` is on -/

/-- DOC -/
@[stacks 0001]
theorem thmDoc : True := .intro

@[stacks 0002]
theorem thmUndoc : True := .intro

/-- DOC -/
@[stacks 0003]
lemma lemmaDoc : True := .intro

/-- DOC -/
@[stacks 0004, kerodon 0005 "A comment"]
theorem thmDocTwoTags : True := .intro

@[stacks 0006, kerodon 0007 "A comment"]
theorem thmUndocTwoTags : True := .intro

/-- DOC -/
@[stacks 0008]
theorem thmDocTactic : True := by
  trivial

/-! ### Declarations elaborated on the main branch -/

/-- DOC -/
@[stacks 0010]
def defDoc : Nat := 0

@[stacks 0011]
def defUndoc : Nat := 0

/-- DOC -/
@[stacks 0012]
abbrev abbrevDoc : Nat := 0

/-- DOC -/
@[stacks 0013]
instance instDoc : Inhabited Nat := ⟨0⟩

/-- DOC -/
@[stacks 0014]
structure StructDoc where
  /-- FIELD -/
  x : Nat

/-- DOC -/
@[stacks 0015]
class ClassDoc (α : Type) where
  /-- FIELD -/
  y : α

/-- DOC -/
@[stacks 0016]
inductive IndDoc where
  /-- CTOR -/
  | a

/-- DOC -/
@[stacks 0017]
axiom axiomDoc : True

/-- DOC -/
@[stacks 0018]
opaque opaqueDoc : Nat

/-- DOC -/
@[stacks 0019]
def structuralDoc : Nat → Nat
  | 0 => 0
  | n + 1 => structuralDoc n

/-- DOC -/
@[stacks 0020]
def wfDoc (n : Nat) : Nat := if h : n = 0 then 0 else wfDoc (n - 1)
termination_by n
decreasing_by omega

/-- DOC -/
@[stacks 0021]
partial def partialDoc (n : Nat) : Nat := partialDoc n

/-- DOC -/
@[stacks 0022]
unsafe def unsafeDoc : Nat := unsafeCast 0

/-- DOC -/
@[stacks 0023]
irreducible_def irredDoc : Nat := 0

mutual
/-- DOC -/
@[stacks 0024]
theorem mutualThmDoc : True := .intro
/-- DOC -/
@[stacks 0026]
theorem mutualThmDoc2 : True := .intro
end

mutual
/-- DOC -/
@[stacks 0025]
def mutualDefDoc : Nat → Nat
  | 0 => 0
  | n + 1 => mutualDefDoc2 n
/-- DOC -/
@[stacks 0027]
def mutualDefDoc2 : Nat → Nat
  | 0 => 0
  | n + 1 => mutualDefDoc n
end

/-! ### Tags added after the declaration -/

/-- DOC -/
theorem laterThmDoc : True := .intro
attribute [stacks 0030] laterThmDoc

theorem laterThmUndoc : True := .intro
attribute [stacks 0031] laterThmUndoc

/-- DOC -/
def laterDefDoc : Nat := 0
attribute [stacks 0032] laterDefDoc

/-! ### `to_additive` -/

/-- DOC -/
@[to_additive (attr := stacks 0040) /-- ADDDOC -/]
def mulDefDoc {α : Type} [Mul α] (a : α) : α := a * a

/-- DOC -/
@[to_additive (attr := stacks 0041) /-- ADDDOC -/]
theorem mulThmDoc {α : Type} [Mul α] (a b : α) (h : a = b) : a * a = b * b := by rw [h]

/-- DOC -/
@[stacks 0042, to_additive /-- ADDDOC -/]
def mulTaggedSrc {α : Type} [Mul α] (a : α) : α := a * a

/-! ### Verso -/

set_option doc.verso true

/-- DOC -/
@[stacks 0050]
theorem versoThmDoc : True := .intro

@[stacks 0051]
theorem versoThmUndoc : True := .intro

/-- DOC -/
@[stacks 0052, kerodon 0053 "A comment"]
theorem versoThmDocTwoTags : True := .intro

/-- DOC -/
@[stacks 0054]
def versoDefDoc : Nat := 0

@[stacks 0055]
def versoDefUndoc : Nat := 0

/-- DOC -/
@[stacks 0056]
structure VersoStructDoc where
  x : Nat

set_option doc.verso false

end Probe

/-- The names reported on, and whether each is documented with text the report looks for. -/
meta def probeNames : List Lean.Name := [
  ``Probe.thmDoc, ``Probe.thmUndoc, ``Probe.lemmaDoc, ``Probe.thmDocTwoTags,
  ``Probe.thmUndocTwoTags, ``Probe.thmDocTactic,
  ``Probe.defDoc, ``Probe.defUndoc, ``Probe.abbrevDoc, ``Probe.instDoc, ``Probe.StructDoc,
  ``Probe.ClassDoc, ``Probe.IndDoc, ``Probe.axiomDoc, ``Probe.opaqueDoc, ``Probe.structuralDoc,
  ``Probe.wfDoc, ``Probe.partialDoc, ``Probe.unsafeDoc, ``Probe.irredDoc, ``Probe.mutualThmDoc,
  ``Probe.mutualDefDoc,
  ``Probe.laterThmDoc, ``Probe.laterThmUndoc, ``Probe.laterDefDoc,
  ``Probe.mulDefDoc, ``Probe.addDefDoc, ``Probe.mulThmDoc, ``Probe.addThmDoc,
  ``Probe.mulTaggedSrc, ``Probe.addTaggedSrc,
  ``Probe.versoThmDoc, ``Probe.versoThmUndoc, ``Probe.versoThmDocTwoTags, ``Probe.versoDefDoc,
  ``Probe.versoDefUndoc, ``Probe.VersoStructDoc,
  ``Probe.StructDoc.x, ``Probe.IndDoc.a]

meta def reportDocs (where_ : String) : Lean.Elab.Command.CommandElabM Unit := do
  for n in probeNames do
    let env ← Lean.getEnv
    let doc ← Lean.findDocString? env n
    let raw := match (← Lean.findInternalDocString? env n) with
      | none => "none"
      | some (.inl _) => "md"
      | some (.inr _) => "verso"
    Lean.logInfo m!"PROBE\t{where_}\t{n}\t{raw}\t{repr doc}"

run_cmd reportDocs "same-file"
