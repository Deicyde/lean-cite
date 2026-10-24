import CiteTest.Basic

namespace Marked

@[cite book "2.1"]
theorem two_one (a b : Nat) : a + b = b + a := by
  -- cite book "2.1" step 1
  induction a with
  | zero => simp
  | succ n ih => omega

-- cite book "2.2" step 1
theorem two_two : True := trivial

cite book "2.3" in
example (n : Nat) : n = n := by
  -- cite book "2.3" step 1 closeMatch
  rfl

end Marked
