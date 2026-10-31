/-
For every entry of `Mathlib.CrossRef.tagExt` in the imported environment, report whether
`findDocString?` shows the link, and whether the declaration has any text besides links.
Run with `lake env lean` from a built Mathlib; prints one TSV line per entry, then a summary.
-/
import Mathlib
open Lean Mathlib.CrossRef

def kindOf (env : Environment) (n : Name) : String :=
  match env.find? n with
  | some (.thmInfo _) => "theorem"
  | some (.defnInfo _) => "def"
  | some (.axiomInfo _) => "axiom"
  | some (.opaqueInfo _) => "opaque"
  | some (.inductInfo _) => "inductive"
  | some (.ctorInfo _) => "ctor"
  | some (.recInfo _) => "rec"
  | some (.quotInfo _) => "quot"
  | none => "missing"

run_cmd do
  let env ← getEnv
  let (_, imported) := PersistentEnvExtension.getState tagExt env
  let mut total : Nat := 0
  let mut withLink : Nat := 0
  let mut noLink : Nat := 0
  let mut noLinkKinds : Std.HashMap String Nat := {}
  let mut allKinds : Std.HashMap String Nat := {}
  let mut decls : NameSet := {}
  let mut lostDecls : NameSet := {}
  let mut out := ""
  for tags in imported do
    for t in tags do
      total := total + 1
      decls := decls.insert t.declName
      let doc ← findDocString? env t.declName
      let url := t.database.url t.tag
      let shows := doc.any (·.contains url)
      let k := kindOf env t.declName
      allKinds := allKinds.insert k (allKinds.getD k 0 + 1)
      if shows then withLink := withLink + 1
      else
        noLink := noLink + 1
        lostDecls := lostDecls.insert t.declName
        noLinkKinds := noLinkKinds.insert k (noLinkKinds.getD k 0 + 1)
      out := out ++ s!"{t.declName}\t{k}\t{t.database.shortName}\t{t.tag}\t{shows}\t{doc.isSome}\n"
  IO.FS.writeFile "crossref-links.tsv" out
  logInfo m!"tag entries {total}; distinct decls {decls.size}; link shown {withLink}; link lost {noLink}; decls losing a link {lostDecls.size}\nall kinds {allKinds.toList}\nlost kinds {noLinkKinds.toList}"
