import CiteTest.Basic

/-! Steps marked by syntax. Each theorem is elaborated asynchronously, as `lake build` does. -/

namespace Wrapped

-- a tactic block, with a relation
theorem tac (x y : Nat) : x + y = y + x := by
  cite book "4.1" step 1 exactMatch =>
    omega

-- a term, here a calc
theorem term (a b : Nat) (h : a = b) : a + 0 = b :=
  cite book "4.2" step 2 in
  calc a + 0 = a := Nat.add_zero a
    _ = b := h

-- the statement, and the whole command
cite book "4.3" (statement := 1) in
cite book "4.3" (step := 2) (rel := closeMatch) in
theorem stmt (n : Nat) :
    n * 1 = n := by
  simp

-- nested wrappers, and one line in two steps
theorem nested : True ∧ True := by
  cite book "4.4" step 1 =>
    constructor
    cite book "4.4" step 2 3 =>
      trivial
  trivial

-- run twice by all_goals: recorded once in the export
theorem twice : True ∧ True := by
  constructor
  all_goals cite book "4.5" step 1 => trivial

-- in a branch of first that fails, nothing is recorded
theorem branch : True := by
  first
  | cite book "4.6" step 1 => exact absurd rfl (by decide : (1 : Nat) ≠ 1)
  | cite book "4.6" step 2 => trivial

-- in an example, which keeps nothing, a wrapper warns
/--
warning: an `example` is discarded after elaboration, together with what this wrapper records; mark the step with a comment marker (`-- cite … step …`) instead
-/
#guard_msgs in
cite book "4.7" in
example : 1 + 1 = 2 := by
  cite book "4.7" step 1 =>
    rfl

-- a bad source is reported, and the tactics still run
/-- error: unknown source `nobook`; declare it with `cite_source` -/
#guard_msgs in
theorem bad : True := by
  cite nobook "x" step 1 =>
    trivial

/-- error: a step takes `rel` and no `part` -/
#guard_msgs in
cite book "4.8" (step := 1) (part := "a") in
theorem badOpt : True := trivial

/--
error: a step needs the lines it marks; write `cite … (step := …) in` before the command, or wrap tactics or a term in `cite … step … =>` or `cite … step … in`
-/
#guard_msgs in
@[cite book "4.9" (step := 1)] theorem badAttr : True := trivial

-- `step` is still an identifier
def step : Nat := 3

-- a whole example as a step: recorded by the command, outside the example
cite book "4.10" (step := 1) in
example : True :=
  trivial

end Wrapped
