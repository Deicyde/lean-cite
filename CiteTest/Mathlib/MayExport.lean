import Cite
import CiteTest.Mathlib.MayTagged

/-! Mathlib's cross-references in the layout from 2026-05-13: two tagged in an imported module and
`third` in this one. -/

theorem third : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``third, database := .kerodon, tag := "0002", comment := "" })

/-- info: 0 citations, 0 steps in 1 modules, 3 Mathlib cross-references → .lake/cite-mathlib-may.json -/
#guard_msgs in
#cite_export ".lake/cite-mathlib-may.json" CiteTest.Mathlib.MayTagged

open Lean in
/--
info: ("Mathlib.CrossRef.tagExt",
  [["CiteTest.Mathlib.MayTagged.first", "stacks", "00FN", "https://stacks.math.columbia.edu/tag/00FN", ""],
    ["CiteTest.Mathlib.MayTagged.second", "wikidata", "Q42", "https://www.wikidata.org/wiki/Q42", "a comment"],
    ["third", "kerodon", "0002", "https://kerodon.net/tag/0002", ""]])
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-mathlib-may.json")
  let rows ← IO.ofExcept <| j.getObjValAs? (Array Json) "mathlib"
  return ((j.getObjValAs? String "mathlibExtension").toOption.getD "",
    rows.toList.map fun r => ["declaration", "database", "id", "url", "comment"].map fun k =>
      (r.getObjValAs? String k).toOption.getD "")
