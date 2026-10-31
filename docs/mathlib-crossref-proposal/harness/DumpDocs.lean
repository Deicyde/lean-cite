/-
Writes every Markdown and Verso docstring of the imported environment to the file named by the
environment variable `DOCS_OUT`, one `name<TAB>format<TAB>escaped text` per line, sorted by the
caller. Comparing two dumps shows which docstrings a candidate changed.
-/
import Mathlib
open Lean

run_cmd do
  let env ← getEnv
  let some path ← IO.getEnv "DOCS_OUT" | throwError "DOCS_OUT is not set"
  IO.FS.withFile path .write fun h => do
    for modIdx in [:env.header.moduleNames.size] do
      for (n, d) in docStringExt.getModuleEntries (level := .server) env modIdx do
        h.putStrLn s!"{n}\tmd\t{d.quote}"
      for (n, _) in versoDocStringExt.getModuleEntries (level := .server) env modIdx do
        h.putStrLn s!"{n}\tverso\t"
