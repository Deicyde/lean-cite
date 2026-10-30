import CiteTest.Mathlib.July

/-! Two declarations tagged through the layout's extension, as Mathlib's attribute would. -/

namespace CiteTest.Mathlib.JulyTagged

theorem first : True := trivial

theorem second : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``first, database := .lmfdb, tag := "ec.q", comment := "" })
run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``second, database := .stacks, tag := "00FN", comment := "a comment" })

end CiteTest.Mathlib.JulyTagged
