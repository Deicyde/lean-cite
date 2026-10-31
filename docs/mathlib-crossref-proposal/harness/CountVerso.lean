/-
For every tag entry, whether the declaration has a Markdown entry, a Verso entry, or both.
Both means the Markdown link written by the attribute hides the Verso docstring at lookup.
Writes crossref-verso.tsv in the working directory.
-/
import Mathlib
open Lean Mathlib.CrossRef

run_cmd do
  let env ← getEnv
  let (_, imported) := PersistentEnvExtension.getState tagExt env
  let mut out := ""
  let mut both : Nat := 0
  let mut mdOnly : Nat := 0
  let mut versoOnly : Nat := 0
  let mut neither : Nat := 0
  for tags in imported do
    for t in tags do
      let md := docStringExt.find? (level := .server) env t.declName
      let v := (versoDocStringExt.find? (level := .server) env t.declName).isSome
      match md.isSome, v with
      | true, true => both := both + 1
      | true, false => mdOnly := mdOnly + 1
      | false, true => versoOnly := versoOnly + 1
      | false, false => neither := neither + 1
      let linked := md.any (·.contains (t.database.url t.tag))
      out := out ++ s!"{t.declName}\t{t.database.shortName}\t{t.tag}\t{md.isSome}\t{v}\t{linked}\n"
  IO.FS.writeFile "crossref-verso.tsv" out
  logInfo m!"md only {mdOnly}; verso only {versoOnly}; both {both}; neither {neither}"
