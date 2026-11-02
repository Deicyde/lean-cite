import Lean
import Cite.CrossRef
import CiteTest.Sources

/-! Hovers over the sources and entries of citations, and over the identifiers of cross-references.
`#hovers cmd` elaborates `cmd` and prints each hover it records, after the text it is over. -/

open Lean Elab Command

set_option Elab.async false

elab "#hovers " cmd:command : command => do
  let saved := (← get).infoState
  modify fun s => { s with infoState.enabled := true, infoState.trees := {} }
  elabCommand cmd
  let trees := (← get).infoState.trees
  modify fun s => { s with infoState := saved }
  let fm ← getFileMap
  let mut found : Array (Nat × String × String) := #[]
  for t in trees do
    let infos := t.foldInfo (init := (#[] : Array (ContextInfo × Info))) fun ctx i acc => acc.push (ctx, i)
    for (ctx, i) in infos do
      let .ofDelabTermInfo _ := i | continue
      let (some a, some b) := (i.stx.getPos?, i.stx.getTailPos?) | continue
      let some text ← ctx.runMetaM i.lctx i.docString? | continue
      found := found.push (a.byteIdx, String.Pos.Raw.extract fm.source a b, text)
  for (_, over, text) in found.qsort (·.1 < ·.1) do
    logInfo m!"{over}: {text}"

/--
info: notes: **Lecture notes**

Notes for a course.

* `type`: pdf
* `uri`: https://example.org/notes.pdf
---
info: "1.2": **Lecture notes**, 1.2: Associativity

* `page`: 4

Notes for a course.
-/
#guard_msgs in
#hovers
@[cite notes "1.2"] def hoverDef : Nat := 1

/--
info: atlas: **An atlas**

* `uri.`: https://example.org/{id}
* `uri.P`: https://example.org/p/{id}
* `uri.PQ`: https://example.org/pq/{id}
---
info: "P1": **An atlas**, P1

<https://example.org/p/P1>
-/
#guard_msgs in
#hovers
def hoverStep : Nat := by
  cite atlas "P1" step 1 =>
    exact 1

/--
info: 0BR2: **The Stacks Project**, 0BR2

<https://stacks.math.columbia.edu/tag/0BR2>

An open source textbook and reference work on algebraic stacks and the algebraic geometry needed to define them. Each result has a tag of four digits or uppercase letters, such as `0BR2`.
-/
#guard_msgs in
#hovers
@[stacks 0BR2] def hoverStacks : Nat := 1
