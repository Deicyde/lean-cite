import Cite

cite_source book "A Book"

open Cite in
/--
info: [("1", [2], 2, 2), ("1", [3], 4, 5), ("1", [4], 8, 8), ("2", [5], 8, 8), ("1", [6, 7], 11, 11), ("1", [1], 13, 13),
  ("1", [7], 15, 15)]
-/
#guard_msgs in
#eval
  let src := "-- cite book \"1\" step 2
theorem foo : True := by
  -- cite book \"1\" step 3
  have h : True := by
    trivial
  -- cite book \"1\" step 4
  -- cite book \"2\" step 5
  exact h

  -- cite book \"1\" step 6 7
  skip
-- cite book \"1\" step 1
theorem bar : True := by
  -- cite book \"1\" step 7
  trivial
  -- cite end
  trivial"
  (scan (splitLines src)).marks.toList.map fun (m : Mark) =>
    (m.marker.id, m.marker.steps.toList, m.start, m.stop)

theorem t1 : 1 + 1 = 2 := by
  -- cite book "1.2" step 1
  rfl

/--
warning: unknown source `nobook`; declare it with `cite_source`

Note: This linter can be disabled with `set_option linter.cite.steps false`
-/
#guard_msgs in
theorem t2 : 1 + 1 = 2 := by
  -- cite nobook "1.2" step 1
  rfl

/--
warning: malformed `-- cite` marker: expected `step` after the entry

Note: This linter can be disabled with `set_option linter.cite.steps false`
---
warning: malformed `-- cite` marker: unknown relation `sameAs`; the relations are exactMatch, closeMatch, broadMatch, narrowMatch, relatedMatch, hasPart, noMatch

Note: This linter can be disabled with `set_option linter.cite.steps false`
-/
#guard_msgs in
theorem t3 : True ∧ True := by
  -- cite book "1.2" stpe 1
  constructor
  -- cite book "1.2" step 2 sameAs
  · trivial
  · trivial

-- cite the book here, prose not a marker
theorem t4 : True := trivial
