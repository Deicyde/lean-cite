import Lean

/-!
A theorem's docstring is written on the main branch, so a later command or attribute can read and
extend it, and the file that declares the theorem sees the result.
-/

open Lean Elab Command

set_option Elab.async true

/-- own -/
theorem thm : True := .intro

/-- Appends to a docstring, as cross-reference attributes do. -/
def extendDoc (n : Name) : CommandElabM Unit := do
  let doc := (← findDocString? (← getEnv) n).getD ""
  addDocStringCore n s!"{doc}\n\nlink"

run_cmd extendDoc ``thm

/-- info: some "own\n\nlink" -/
#guard_msgs in
run_cmd logInfo m!"{repr (← findDocString? (← getEnv) ``thm)}"

theorem undoc : True := .intro

run_cmd addDocStringCore ``undoc "link"

/-- info: some "link" -/
#guard_msgs in
run_cmd logInfo m!"{repr (← findDocString? (← getEnv) ``undoc)}"

set_option doc.verso true

/-- Uses {name}`thm`. -/
theorem versoThm : True := .intro

/-- info: some "Uses `thm`. " -/
#guard_msgs in
run_cmd logInfo m!"{repr (← findDocString? (← getEnv) ``versoThm)}"
