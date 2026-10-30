import Cite
import CiteTest.Mathlib.SeptemberTagged

/-! Mathlib's cross-references in the layout from 2026-09-01: two tagged in an imported module and
`third` in this one. -/

theorem third : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``third, database := .stacks, tag := "01AB", comment := "" })

/-- info: 0 citations, 0 steps in 1 modules, 3 Mathlib cross-references → .lake/cite-mathlib-september.json -/
#guard_msgs in
#cite_export ".lake/cite-mathlib-september.json" CiteTest.Mathlib.SeptemberTagged

open Lean in
/--
info: ("Mathlib.CrossRef.tagExt",
  [["CiteTest.Mathlib.SeptemberTagged.first", "pibase-topology", "S000001",
      "https://topology.pi-base.org/spaces/S000001", ""],
    ["CiteTest.Mathlib.SeptemberTagged.second", "dlmf", "5.2.1", "https://dlmf.nist.gov/5.2.1", "a comment"],
    ["third", "stacks", "01AB", "https://stacks.math.columbia.edu/tag/01AB", ""]])
-/
#guard_msgs in
#eval show IO _ from do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-mathlib-september.json")
  let rows ← IO.ofExcept <| j.getObjValAs? (Array Json) "mathlib"
  return ((j.getObjValAs? String "mathlibExtension").toOption.getD "",
    rows.toList.map fun r => ["declaration", "database", "id", "url", "comment"].map fun k =>
      (r.getObjValAs? String k).toOption.getD "")
