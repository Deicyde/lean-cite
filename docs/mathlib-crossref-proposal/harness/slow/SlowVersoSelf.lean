import Lean
open Lean Elab Tactic in
elab "slow" : tactic => IO.sleep 1000
set_option doc.verso true
/-- first -/
theorem t0 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t1 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t2 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t3 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t4 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t5 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t6 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t7 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t8 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t9 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t10 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t11 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t12 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t13 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t14 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t15 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t16 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t17 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t18 : True := by
  slow
  trivial

/-- Uses {name}`t0`. -/
theorem t19 : True := by
  slow
  trivial

