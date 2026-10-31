import Lean
open Lean Elab Tactic in
elab "slow" : tactic => IO.sleep 1000
set_option doc.verso true
/-- first -/
theorem t0 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t1 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t2 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t3 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t4 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t5 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t6 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t7 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t8 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t9 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t10 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t11 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t12 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t13 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t14 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t15 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t16 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t17 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t18 : True := by
  slow
  trivial

/-- Uses {name}`Nat.add` and {lean}`True`. -/
theorem t19 : True := by
  slow
  trivial

