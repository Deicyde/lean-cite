import Cite
import CiteTest.Mathlib.Unknown

/-! A `tagExt` in a layout no reader knows: the export warns and goes on without it. -/

/--
warning: Mathlib's cross-references are left out: `Mathlib.CrossRef.tagExt` is imported, but none of the 3 readers for its layouts fits this Mathlib
---
info: 0 citations, 0 steps in 1 modules, 0 Mathlib cross-references → .lake/cite-mathlib-unknown.json
-/
#guard_msgs in
#cite_export ".lake/cite-mathlib-unknown.json" CiteTest.Mathlib.Unknown
