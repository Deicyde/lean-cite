module

public meta import Cite.Attribute
public meta import Lean.Linter.Basic

/-!
# Steps marked by syntax

A step of a proof in the source can be marked by wrapping the Lean that carries it out. The
wrapper records the lines of what it wraps; the proof term is the same. A wrapper of tactics
re-indents them.

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
Lean checks the source and the relation. Wrappers of the same lines nest, and each marks the lines
after the heads of those nested at its start. Wrappers nest, so two steps whose lines cross, neither
holding the other, need a comment marker (`Cite/Steps.lean`) for one of them.

A wrapper records its step while the proof around it is elaborated, which may be in a task of its
own; `stepExt` keeps what every task adds. A wrapper that runs twice records twice, and readers
drop the repeat. Some wrappers record nothing where they are written:

* one that is never elaborated, such as one in a branch of `first` that fails;
* one in an `example`, a `recall`, a `#`-command or `decreasing_by`, whose environment Lean
  discards;
* one in an autoParam (`(h : p := by …)`), whose tactic Lean runs where an argument is left out.

The linter `linter.cite.wrappers` warns about each, since the step then needs a comment marker. A
bad source or relation is reported, and what the wrapper holds still runs.
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

/-- The lines a wrapper marks: those of `body`, starting after the heads of any wrappers nested at
its start, so that wrappers of the same lines mark the same lines. -/
partial def wrappedLines (body : Syntax) : CoreM (Nat × Nat) := do
  let (_, b) ← linesOf body
  let inner := body.find? fun s => (s.getKind == `Cite.citeStepTac || s.getKind == `Cite.citeStepTerm) &&
    s.getPos? == body.getPos?
  match inner with
  | some w => return ((← wrappedLines w[7]).1, b)
  | none => return ((← linesOf body).1, b)

/-- Record the step that the arguments of a wrapper describe, for the lines of `body`; a bad one is
reported, not thrown. Nothing is recorded when `body` was not read from the file. -/
def recordStep (src : Ident) (id : StrLit) (ks : Array NumLit) (rel : Option Ident) (body : Syntax)
    (form : String) : CoreM Unit := do
  -- an autoParam's tactic runs where an argument is left out, with positions from there
  unless body.getHeadInfo matches .original .. do return
  try
    let (a, b) ← wrappedLines body
    let relName := (rel.map (·.getId.eraseMacroScopes.toString)).getD ""
    addStepTag (← mkStepTag src id (ks.map (·.getNat)) relName ((rel.map (·.raw)).getD .missing)
      a b form)
  catch e => logException e

/-- `cite src "id" step k₁ … [relation] =>` followed by a block of tactics runs the block, and
records that its lines carry out steps `kᵢ` of the proof of the entry `id` of the source `src`. -/
syntax (name := citeStepTac) "cite " Lean.Parser.rawIdent ppSpace str ppSpace &"step"
  (ppSpace num)+ (ppSpace ident)? " =>" ppIndent(ppLine tacticSeq) : tactic

@[tactic citeStepTac] def evalCiteStep : Tactic
  | `(tactic| cite $src:ident $id:str step $ks* $[$rel:ident]? => $tacs) => do
    recordStep src id ks rel tacs "tactic"
    evalTactic tacs
  | _ => throwUnsupportedSyntax

/-- `cite src "id" step k₁ … [relation] in e` elaborates the term `e`, and records that its lines
carry out steps `kᵢ` of the proof of the entry `id` of the source `src`. -/
syntax:lead (name := citeStepTerm) "cite " Lean.Parser.rawIdent ppSpace str ppSpace &"step"
  (ppSpace num)+ (ppSpace ident)? " in" ppLine term : term

@[term_elab citeStepTerm] def elabCiteStepTerm : TermElab
  | `(cite $src:ident $id:str step $ks* $[$rel:ident]? in $e), expectedType? => do
    recordStep src id ks rel e "term"
    elabTerm e expectedType?
  | _, _ => throwUnsupportedSyntax

register_option linter.cite.wrappers : Bool := {
  defValue := true
  descr := "warn about a `cite … step` wrapper that recorded nothing where it is written"
}

/-- The wrappers in `stx`, with the syntax each holds. -/
def wrappersIn (stx : Syntax) : Array (Syntax × Syntax) := Id.run do
  let mut out := #[]
  for s in stx.topDown do
    if s.isOfKind ``citeStepTac || s.isOfKind ``citeStepTerm then
      out := out.push (s, s[7])
  return out

/-- Warns about each wrapper of a command that recorded no step at its own lines. Lean discards
what an `example`, a `recall`, a `#`-command or `decreasing_by` records, and runs an autoParam's
tactic where the argument is left out, so a wrapper there records nothing where it is written;
its step needs a comment marker. The linter reads the steps after the command's proofs are done. -/
def wrappersLinter : Command.Linter where
  run := Lean.withSetOptionIn fun stx => do
    unless Lean.Linter.getLinterValue linter.cite.wrappers (← Lean.Linter.getLinterOptions) do return
    let ws := wrappersIn stx
    if ws.isEmpty then return
    let mod ← getMainModule
    let tags := stepTags (← getEnv) |>.filter (·.module == mod)
    for (w, body) in ws do
      -- a wrapper with a bad source or entry was already reported
      let reported : Bool := match findSource (← getEnv) w[1].getId.eraseMacroScopes with
        | .error _ => true
        | .ok s => !(s.entries.isEmpty || (s.entry? (w[2].isStrLit?.getD "")).isSome)
      if reported then continue
      let some (a, b) ← (try some <$> Command.liftCoreM (wrappedLines body) catch _ => pure none) | continue
      unless tags.any (fun t => t.start == a && t.stop == b) do
        Lean.Linter.logLint linter.cite.wrappers w m!"Lean discards what an `example`, a \
          `recall`, a `#`-command or `decreasing_by` records, runs an autoParam's tactic where \
          the argument is left out, and skips a branch that fails; this wrapper recorded no step \
          here, so mark the step with a comment marker (`-- cite … step …`)"

initialize Command.addLinter wrappersLinter

end Cite
