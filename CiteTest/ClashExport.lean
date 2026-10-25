import CiteTest.ClashA
import CiteTest.ClashB
import CiteTest.Marked

/--
warning: the source `dup` is declared in several modules: CiteTest.ClashA, CiteTest.ClashB; no citation uses it
---
info: 15 citations, 6 steps in 1 modules, 0 Mathlib cross-references → .lake/cite-clash-export.json
-/
#guard_msgs in
#cite_export ".lake/cite-clash-export.json" CiteTest.Marked
