import Cite
import CiteTest.Mathlib.StacksTagged

/-! Mathlib's cross-references in the layout to 2026-05-12: two tagged in an imported module and
`third` in this one. -/

theorem third : True := trivial

run_cmd Lean.modifyEnv (Mathlib.StacksTag.tagExt.addEntry · { declName := ``third, database := .stacks, tag := "01AB", comment := "" })

/-- info: 0 citations, 0 steps in 1 modules, 3 Mathlib cross-references → .lake/cite-mathlib-stacks.json -/
#guard_msgs in
#cite_export ".lake/cite-mathlib-stacks.json" CiteTest.Mathlib.StacksTagged

open Lean in
/--
info: ("Mathlib.StacksTag.tagExt",
  [["CiteTest.Mathlib.StacksTagged.first", "stacks", "00FN", "https://stacks.math.columbia.edu/tag/00FN", ""],
    ["CiteTest.Mathlib.StacksTagged.second", "kerodon", "0001", "https://kerodon.net/tag/0001", "a comment"],
    ["third", "stacks", "01AB", "https://stacks.math.columbia.edu/tag/01AB", ""]])
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-mathlib-stacks.json")
  let rows ← IO.ofExcept <| j.getObjValAs? (Array Json) "mathlib"
  return ((j.getObjValAs? String "mathlibExtension").toOption.getD "",
    rows.toList.map fun r => ["declaration", "database", "id", "url", "comment"].map fun k =>
      (r.getObjValAs? String k).toOption.getD "")
