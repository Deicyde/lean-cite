/-
Writes every Markdown and Verso docstring of `Init`, `Std` and `Lean` to the file named by `DOCS_OUT`,
one `name<TAB>format<TAB>escaped text` per line. Comparing the dumps of two stages shows which
docstrings a change to docstring writing altered.
-/
import Lean
import Std
open Lean

run_cmd do
  let env ← getEnv
  let some path ← IO.getEnv "DOCS_OUT" | throwError "DOCS_OUT is not set"
  IO.FS.withFile path .write fun h => do
    for modIdx in [:env.header.moduleNames.size] do
      for (n, d) in docStringExt.getModuleEntries (level := .server) env modIdx do
        h.putStrLn s!"{n}\tmd\t{d.quote}"
      for (n, v) in versoDocStringExt.getModuleEntries (level := .server) env modIdx do
        h.putStrLn s!"{n}\tverso\t{v.text.size} blocks, {v.subsections.size} parts"
