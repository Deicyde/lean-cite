import Lean
open Lean Elab Tactic in
elab "slow" : tactic => IO.sleep 1000
set_option doc.verso true
/-- first -/
theorem t0 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t1 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t2 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t3 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t4 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t5 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t6 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t7 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t8 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t9 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t10 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t11 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t12 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t13 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t14 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t15 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t16 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t17 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t18 : True := by
  slow
  trivial

/-- Uses `Nat.add` and `True` and `x + y`. -/
theorem t19 : True := by
  slow
  trivial

