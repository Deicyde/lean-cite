import CiteTest.Mathlib.Stacks

/-! Two declarations tagged through the layout's extension, as Mathlib's attribute would. -/

namespace CiteTest.Mathlib.StacksTagged

theorem first : True := trivial

theorem second : True := trivial

run_cmd Lean.modifyEnv (Mathlib.StacksTag.tagExt.addEntry · { declName := ``first, database := .stacks, tag := "00FN", comment := "" })
run_cmd Lean.modifyEnv (Mathlib.StacksTag.tagExt.addEntry · { declName := ``second, database := .kerodon, tag := "0001", comment := "a comment" })

end CiteTest.Mathlib.StacksTagged
