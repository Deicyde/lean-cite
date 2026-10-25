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

-- in a branch of first that fails, nothing is recorded, and the linter says so
/--
warning: Lean discards what an `example`, a `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where the argument is left out, and skips a branch that fails; this wrapper recorded no step here, so mark the step with a comment marker (`-- cite … step …`)

Note: This linter can be disabled with `set_option linter.cite.wrappers false`
-/
#guard_msgs in
theorem branch : True := by
  first
  | cite book "4.6" step 1 => exact absurd rfl (by decide : (1 : Nat) ≠ 1)
  | cite book "4.6" step 2 => trivial

-- in an example, which keeps nothing, a wrapper warns
/--
warning: Lean discards what an `example`, a `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where the argument is left out, and skips a branch that fails; this wrapper recorded no step here, so mark the step with a comment marker (`-- cite … step …`)

Note: This linter can be disabled with `set_option linter.cite.wrappers false`
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

-- in an example's `where` helper, and in decreasing_by
/--
warning: Lean discards what an `example`, a `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where the argument is left out, and skips a branch that fails; this wrapper recorded no step here, so mark the step with a comment marker (`-- cite … step …`)

Note: This linter can be disabled with `set_option linter.cite.wrappers false`
-/
#guard_msgs in
example : True := aux
where aux : True := cite book "4.11" step 1 in trivial

/--
warning: Lean discards what an `example`, a `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where the argument is left out, and skips a branch that fails; this wrapper recorded no step here, so mark the step with a comment marker (`-- cite … step …`)

Note: This linter can be disabled with `set_option linter.cite.wrappers false`
-/
#guard_msgs in
def countDown (n : Nat) : Nat := if n = 0 then 0 else countDown (n - 1)
termination_by n
decreasing_by
  cite book "4.12" step 1 =>
    omega

/-- error: an `example` is discarded after elaboration, together with what `@[cite]` records; write `cite … in` before the `example` instead -/
#guard_msgs in
example : True := aux
where @[cite book "4.13"] aux : True := trivial

-- an autoParam's wrapper records nothing, here or where the argument is left out
/--
warning: Lean discards what an `example`, a `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where the argument is left out, and skips a branch that fails; this wrapper recorded no step here, so mark the step with a comment marker (`-- cite … step …`)

Note: This linter can be disabled with `set_option linter.cite.wrappers false`
-/
#guard_msgs in
theorem withAuto (n : Nat) (_h : n = n := by
    cite book "4.14" step 1 =>
      rfl) : True := trivial

theorem usesAuto : True := withAuto 3

-- the statement form on declarations with no signature
cite book "4.15" (statement := 1) in
structure NoSig where
  x : Nat

cite book "4.15" (statement := 2) in
def noType := 3

/-- error: a `mutual` block has several statements; mark each declaration's instead -/
#guard_msgs in
cite book "4.16" (statement := 1) in
mutual
theorem m1 : True := trivial
end

-- two wrappers of the same lines mark the same lines
theorem sameLines : True := by
  cite book "4.17" step 1 =>
    cite book "4.18" step 2 =>
      trivial

end Wrapped
