module

public meta import Cite.Attribute

/-!
# Steps marked by syntax

A step of a proof in the source can be marked by wrapping the Lean that carries it out. The
wrapper records the lines of what it wraps, and changes nothing else:

```
theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  cite ladr4e "1.26" step 2 in
  calc z = z + 0 := (add_zero z).symm
    _ = 0 + z := add_comm z 0
    _ = 0 := h 0

theorem add_comm_pi (x y : Fin n → F) : x + y = y + x := by
  cite ladr4e "1.14" step 2 exactMatch =>
    funext i
    exact add_comm (x i) (y i)
```

* `cite src "id" step k₁ k₂ … [relation] =>` and a block of tactics runs the block, and marks its
  lines.
* `cite src "id" step k₁ k₂ … [relation] in e` elaborates the term `e`, and marks its lines.
* Before a command, `cite src "id" (step := k) in` marks the command from its keyword, and
  `cite src "id" (statement := k) in` its statement; see `Cite.citeIn`.

The lines are those of the syntax, so they move with the code and need no rule about indentation;
Lean checks the source and the relation. Wrappers nest, so two steps whose lines cross, neither
holding the other, need a comment marker (`Cite/Steps.lean`) for one of them.

A wrapper records its step while the proof around it is elaborated, which may be in a task of its
own; `stepExt` keeps what every task adds. A wrapper that is never elaborated, such as one in a
branch of `first` that is not taken, records nothing, and one that runs twice records twice.
Lean discards an `example` after elaborating it, together with what a wrapper in its proof
records; such a wrapper warns, and the step needs a comment marker. A bad source or relation is
reported, and what the wrapper holds still runs.
-/

public meta section

open Lean Elab Term Tactic

namespace Cite

/-- The first and last line `stx` spans, from 1. -/
def linesOf (stx : Syntax) : CoreM (Nat × Nat) := do
  let fm ← getFileMap
  let some a := stx.getPos? | throwErrorAt stx "no position"
  let some b := stx.getTailPos? | throwErrorAt stx "no position"
  return ((fm.toPosition a).line, (fm.toPosition b).line)

/-- Record the step that the arguments of a wrapper describe, for the lines of `body`, inside the
declaration `decl`; a bad one is reported, not thrown. -/
def recordStep (src : Ident) (id : StrLit) (ks : Array NumLit) (rel : Option Ident) (body : Syntax)
    (form : String) (decl : Option Name) : CoreM Unit := do
  if decl.any isExampleName then
    logWarningAt src "an `example` is discarded after elaboration, together with what this \
      wrapper records; mark the step with a comment marker (`-- cite … step …`) instead"
    return
  try
    let (a, b) ← linesOf body
    let relName := (rel.map (·.getId.eraseMacroScopes.toString)).getD ""
    addStepTag (← mkStepTag src id (ks.map (·.getNat)) relName ((rel.map (·.raw)).getD .missing)
      a b form)
  catch e => logException e

/-- `cite src "id" step k₁ … [relation] =>` followed by a block of tactics runs the block, and
records that its lines carry out steps `kᵢ` of the proof of the entry `id` of the source `src`. -/
syntax (name := citeStepTac) "cite " ident ppSpace str ppSpace &"step" (ppSpace num)+
  (ppSpace ident)? " =>" ppIndent(tacticSeq) : tactic

@[tactic citeStepTac] def evalCiteStep : Tactic
  | `(tactic| cite $src:ident $id:str step $ks* $[$rel:ident]? => $tacs) => do
    recordStep src id ks rel tacs "tactic" (← getDeclName?)
    evalTactic tacs
  | _ => throwUnsupportedSyntax

/-- `cite src "id" step k₁ … [relation] in e` elaborates the term `e`, and records that its lines
carry out steps `kᵢ` of the proof of the entry `id` of the source `src`. -/
syntax:lead (name := citeStepTerm) "cite " ident ppSpace str ppSpace &"step" (ppSpace num)+
  (ppSpace ident)? " in" ppLine term : term

@[term_elab citeStepTerm] def elabCiteStepTerm : TermElab
  | `(cite $src:ident $id:str step $ks* $[$rel:ident]? in $e), expectedType? => do
    recordStep src id ks rel e "term" (← getDeclName?)
    elabTerm e expectedType?
  | _, _ => throwUnsupportedSyntax

end Cite
