import CiteTest.Marked

/--
info: 15 citations, 6 step markers in 1 modules, 0 Mathlib cross-references → .lake/cite-test-export.json
-/
#guard_msgs in
#cite_export ".lake/cite-test-export.json" CiteTest.Marked

open Lean in
/--
info: [("2.1", [8, 10], "Marked.two_one"), ("2.2", [13, 13], "Marked.two_two"), ("2.3", [18, 18], ""),
  ("3.1", [25, 26], "Holders.S"), ("3.2", [29, 31], "Holders.Color"), ("3.3", [35, 35], "Holders.priv")]
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-test-export.json")
  let steps ← IO.ofExcept <| j.getObjValAs? (Array Json) "steps"
  return steps.toList.map fun s =>
    ((s.getObjValAs? String "id").toOption.getD "", (s.getObjValAs? (List Nat) "lines").toOption.getD [],
     (s.getObjValAs? String "declaration").toOption.getD "")
