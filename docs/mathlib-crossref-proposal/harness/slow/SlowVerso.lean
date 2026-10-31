import Lean
open Lean Elab Tactic in
elab "slow" : tactic => IO.sleep 1000
set_option doc.verso true
/-- doc -/
theorem t0 : True := by
  slow
  trivial

/-- doc -/
theorem t1 : True := by
  slow
  trivial

/-- doc -/
theorem t2 : True := by
  slow
  trivial

/-- doc -/
theorem t3 : True := by
  slow
  trivial

/-- doc -/
theorem t4 : True := by
  slow
  trivial

/-- doc -/
theorem t5 : True := by
  slow
  trivial

/-- doc -/
theorem t6 : True := by
  slow
  trivial

/-- doc -/
theorem t7 : True := by
  slow
  trivial

/-- doc -/
theorem t8 : True := by
  slow
  trivial

/-- doc -/
theorem t9 : True := by
  slow
  trivial

/-- doc -/
theorem t10 : True := by
  slow
  trivial

/-- doc -/
theorem t11 : True := by
  slow
  trivial

/-- doc -/
theorem t12 : True := by
  slow
  trivial

/-- doc -/
theorem t13 : True := by
  slow
  trivial

/-- doc -/
theorem t14 : True := by
  slow
  trivial

/-- doc -/
theorem t15 : True := by
  slow
  trivial

/-- doc -/
theorem t16 : True := by
  slow
  trivial

/-- doc -/
theorem t17 : True := by
  slow
  trivial

/-- doc -/
theorem t18 : True := by
  slow
  trivial

/-- doc -/
theorem t19 : True := by
  slow
  trivial

