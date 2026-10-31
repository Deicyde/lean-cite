import Lean

/-!
Text written about a declaration before it is elaborated, as an attribute with application time
`beforeElaboration` does, follows the declaration's own docstring. This must also hold for a theorem
elaborated asynchronously, whose docstring is written on the theorem's own branch.
-/

open Lean Elab Command

set_option Elab.async true

def showDoc (n : Name) : CommandElabM Unit := do
  logInfo m!"{repr (← findDocString? (← getEnv) n)}"

run_cmd addDocStringCore `thmDoc "earlier"
/-- own -/
theorem thmDoc : True := .intro

/-- info: some "own\n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``thmDoc

run_cmd addDocStringCore `thmUndoc "earlier"
theorem thmUndoc : True := .intro

/-- info: some "earlier" -/
#guard_msgs in
run_cmd showDoc ``thmUndoc

run_cmd addDocStringCore `defDoc "earlier"
/-- own -/
def defDoc : Nat := 0

/-- info: some "own\n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``defDoc

run_cmd addDocStringCore `structDoc "earlier"
/-- own -/
structure structDoc where

/-- info: some "own\n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``structDoc

/-! A recursive definition is added in several steps, and must not repeat its docstring. -/

run_cmd addDocStringCore `recDoc "earlier"
/-- own -/
def recDoc : Nat → Nat
  | 0 => 0
  | n + 1 => recDoc n

/-- info: some "own\n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``recDoc

/-! Writing a docstring through `addDocStringCore` still replaces, for metaprograms that read and
rewrite it. -/

/-- own -/
def replaced : Nat := 0

run_cmd addDocStringCore ``replaced "new"

/-- info: some "new" -/
#guard_msgs in
run_cmd showDoc ``replaced

/-! Verso -/

def earlierVerso : VersoDocString :=
  { text := #[.para #[.text "earlier"]], subsections := #[] }

set_option doc.verso true

run_cmd addVersoDocStringCore `versoThm earlierVerso #[]
/-- own -/
theorem versoThm : True := .intro

/-- info: some "own \n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``versoThm

run_cmd addVersoDocStringCore `versoDef earlierVerso #[]
/-- own -/
def versoDef : Nat := 0

/-- info: some "own \n\nearlier" -/
#guard_msgs in
run_cmd showDoc ``versoDef
