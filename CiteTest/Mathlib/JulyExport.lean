import Cite
import CiteTest.Mathlib.JulyTagged

/-! Mathlib's cross-references in the layout from 2026-07-04: two tagged in an imported module and
`third` in this one. -/

theorem third : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``third, database := .wikidata, tag := "Q1", comment := "" })

/-- info: 0 citations, 0 steps in 1 modules, 3 Mathlib cross-references → .lake/cite-mathlib-july.json -/
#guard_msgs in
#cite_export ".lake/cite-mathlib-july.json" CiteTest.Mathlib.JulyTagged

open Lean in
/--
info: ("Mathlib.CrossRef.tagExt",
  [["CiteTest.Mathlib.JulyTagged.first", "lmfdb", "ec.q", "https://www.lmfdb.org/knowledge/show/ec.q", ""],
    ["CiteTest.Mathlib.JulyTagged.second", "stacks", "00FN", "https://stacks.math.columbia.edu/tag/00FN", "a comment"],
    ["third", "wikidata", "Q1", "https://www.wikidata.org/wiki/Q1", ""]])
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-mathlib-july.json")
  let rows ← IO.ofExcept <| j.getObjValAs? (Array Json) "mathlib"
  return ((j.getObjValAs? String "mathlibExtension").toOption.getD "",
    rows.toList.map fun r => ["declaration", "database", "id", "url", "comment"].map fun k =>
      (r.getObjValAs? String k).toOption.getD "")
