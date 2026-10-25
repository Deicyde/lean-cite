import CiteTest.Wrapped

/-- info: 14 citations, 9 steps in 1 modules, 0 Mathlib cross-references → .lake/cite-wrapped.json -/
#guard_msgs in
#cite_export ".lake/cite-wrapped.json" CiteTest.Wrapped

open Lean in
/--
info: [("4.1", [1], "tactic", [10, 10], "Wrapped.tac", "exactMatch"), ("4.2", [2], "term", [15, 16], "Wrapped.term", ""),
  ("4.3", [2], "command", [21, 23], "Wrapped.stmt", "closeMatch"),
  ("4.3", [1], "statement", [21, 22], "Wrapped.stmt", ""), ("4.4", [1], "tactic", [28, 30], "Wrapped.nested", ""),
  ("4.4", [2, 3], "tactic", [30, 30], "Wrapped.nested", ""), ("4.5", [1], "tactic", [36, 36], "Wrapped.twice", ""),
  ("4.6", [2], "tactic", [42, 42], "Wrapped.branch", ""), ("4.10", [1], "command", [77, 78], "", "")]
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-wrapped.json")
  let steps ← IO.ofExcept <| j.getObjValAs? (Array Json) "steps"
  return steps.toList.map fun s =>
    ((s.getObjValAs? String "id").toOption.getD "", (s.getObjValAs? (List Nat) "steps").toOption.getD [],
     (s.getObjValAs? String "form").toOption.getD "", (s.getObjValAs? (List Nat) "lines").toOption.getD [],
     (s.getObjValAs? String "declaration").toOption.getD "", (s.getObjValAs? String "rel").toOption.getD "")
