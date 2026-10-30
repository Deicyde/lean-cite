import CiteTest.Mathlib.September

/-! Two declarations tagged through the layout's extension, as Mathlib's attribute would. -/

namespace CiteTest.Mathlib.SeptemberTagged

theorem first : True := trivial

theorem second : True := trivial

run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``first, database := .pibase .topology, tag := "S000001", comment := "" })
run_cmd Lean.modifyEnv (Mathlib.CrossRef.tagExt.addEntry · { declName := ``second, database := .dlmf, tag := "5.2.1", comment := "a comment" })

end CiteTest.Mathlib.SeptemberTagged
