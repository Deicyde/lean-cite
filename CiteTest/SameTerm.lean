import Cite

/-! A wrapper records lines and leaves the proof alone: each wrapped declaration below has exactly
the value of its plain twin, binder names included, in each form a wrapper takes. -/

cite_source sameTerm "A source for this test" (type := "pdf") (uri := "https://example.org/same.pdf")

namespace SameTerm

theorem tacPlain (a b : Nat) : a + b = b + a := by
  rw [Nat.add_comm]

theorem tacWrapped (a b : Nat) : a + b = b + a := by
  cite sameTerm "1" step 1 =>
    rw [Nat.add_comm]

theorem termPlain (a b : Nat) : a + b = b + a :=
  Nat.add_comm a b

theorem termWrapped (a b : Nat) : a + b = b + a :=
  cite sameTerm "2" step 1 in
  Nat.add_comm a b

theorem nestedPlain (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  constructor
  · exact hp
  · exact hq

theorem nestedWrapped (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  cite sameTerm "3" step 1 =>
    constructor
    cite sameTerm "3" step 2 exactMatch =>
      · exact hp
      · exact hq

theorem haveOutPlain (a : Nat) : a + 0 = a := by
  have h : a + 0 = a := Nat.add_zero a
  exact h

theorem haveOutWrapped (a : Nat) : a + 0 = a := by
  cite sameTerm "4" step 1 =>
    have h : a + 0 = a := Nat.add_zero a
  exact h

def commandPlain (a : Nat) : Nat := a + 1

cite sameTerm "5" (step := 1) in
def commandWrapped (a : Nat) : Nat := a + 1

theorem statementPlain (a : Nat) : a = a := rfl

cite sameTerm "6" (statement := 1) in
theorem statementWrapped (a : Nat) : a = a := rfl

end SameTerm

open Lean in
/-- info: [true, true, true, true, true, true] -/
#guard_msgs in
#eval show CoreM _ from do
  let same (a b : Name) : CoreM Bool := do
    let (a, b) := (`SameTerm ++ a, `SameTerm ++ b)
    let (ca, cb) := (← getConstInfo a, ← getConstInfo b)
    let (some va, some vb) := (ca.value? (allowOpaque := true), cb.value? (allowOpaque := true))
      | throwError "no value for {a} or {b}"
    -- `equal` also compares binder names and binder annotations, as `==` does not
    return ca.type.equal cb.type && va.equal vb
  [(`tacPlain, `tacWrapped), (`termPlain, `termWrapped), (`nestedPlain, `nestedWrapped),
    (`haveOutPlain, `haveOutWrapped), (`commandPlain, `commandWrapped),
    (`statementPlain, `statementWrapped)].mapM fun (a, b) => same a b
