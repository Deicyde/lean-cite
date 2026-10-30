import CiteTest.Mathlib.May

/-! Two declarations tagged through the layout's extension, as Mathlib's attribute would. -/

namespace CiteTest.Mathlib.MayTagged

theorem first : True := trivial

theorem second : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``first, database := .stacks, tag := "00FN", comment := "" })
run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``second, database := .wikidata, tag := "Q42", comment := "a comment" })

end CiteTest.Mathlib.MayTagged
