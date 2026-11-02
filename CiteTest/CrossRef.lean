import Cite
import Cite.CrossRef

/-!
Mathlib's test of its cross-reference attributes, `MathlibTest/CrossRefAttribute.lean` at
`675c456f9e` (Apache-2.0), with `#parse`, which is Mathlib's, replaced by `parse` below, whose
`runParser` follows that test's `captureException`. Then the databases as sources, their addresses, and
the export.
-/

open Lean Parser in
/-- Run `fn` on `input`: its error, or the identifier it parsed as a node of kind `kind`. -/
def runParser (env : Environment) (fn : ParserFn) (kind : SyntaxNodeKind) (input : String) :
    Except String String :=
  let ictx := mkInputContext input "<input>"
  let s := fn.run ictx { env, options := {} } (getTokenTable env) (mkParserState input)
  if !s.allErrors.isEmpty then .error (s.toErrorMsg ictx)
  else if !ictx.atEnd s.pos then .error ((s.mkError "end of input").toErrorMsg ictx)
  else .ok ((Syntax.isLit? kind s.stxStack.back).getD "not an identifier")

/-- `parse fn kind "input"` prints what `runParser` gives. -/
macro "parse " fn:ident kind:ident input:str : command =>
  `(open Cite.CrossRef in
    run_cmd Lean.logInfo (← Lean.ofExcept (runParser (← Lean.getEnv) $fn $kind $input)))

/-- info: No tags found. -/
#guard_msgs in
#stacks_tags

namespace X

@[stacks A04Q "A comment", kerodon B15R "Also a comment"]
theorem tagged : True := .intro

end X

/--
info: some ([Stacks Tag A04Q](https://stacks.math.columbia.edu/tag/A04Q) (A comment)

[Kerodon Tag B15R](https://kerodon.net/tag/B15R) (Also a comment))
-/
#guard_msgs in
run_cmd
  Lean.logInfo m!"{← Lean.findDocString? (← Lean.getEnv) `X.tagged}"

#guard_msgs in
@[stacks 0BR2, kerodon 0X12]
example : True := .intro

@[stacks 0BR2, stacks 0X14 "I can also have a comment"]
example : True := .intro

@[stacks 0X14 "I can also have a comment"]
example : True := .intro

@[stacks 0BR2, stacks 0X14 "I can also have a comment"]
example : True := .intro

@[stacks 0X14 "I can also have a comment"]
example : True := .intro

/-- error: <input>:1:3: Stacks tags must be exactly 4 characters -/
#guard_msgs in parse stacksTagFn stacksTagKind "A05"

/-- error: <input>:1:4: Stacks tags must consist only of digits and uppercase letters. -/
#guard_msgs in parse stacksTagFn stacksTagKind "A05b"

/-- info: 0BD5 -/
#guard_msgs in parse stacksTagFn stacksTagKind "0BD5"

/--
info:
[Stacks Tag A04Q](https://stacks.math.columbia.edu/tag/A04Q) corresponds to declaration 'X.tagged'. (A comment)
-/
#guard_msgs in
#stacks_tags

/--
info:
[Stacks Tag A04Q](https://stacks.math.columbia.edu/tag/A04Q) corresponds to declaration 'X.tagged'. (A comment)
True
-/
#guard_msgs in
#stacks_tags!

/--
info:
[Kerodon Tag B15R](https://kerodon.net/tag/B15R) corresponds to declaration 'X.tagged'. (Also a comment)
True
-/
#guard_msgs in
#kerodon_tags!

namespace W

@[wikidata Q12345 "A Wikidata comment"]
theorem wikiTagged : True := .intro

end W

/-- info: some ([Wikidata Q12345](https://www.wikidata.org/wiki/Q12345) (A Wikidata comment)) -/
#guard_msgs in
run_cmd
  Lean.logInfo m!"{← Lean.findDocString? (← Lean.getEnv) `W.wikiTagged}"

/--
info:
[Wikidata Q12345](https://www.wikidata.org/wiki/Q12345) corresponds to declaration 'W.wikiTagged'. (A Wikidata comment)
-/
#guard_msgs in
#wikidata_tags

/-- error: <input>:1:5: Wikidata ids must consist of the letter Q followed by digits. -/
#guard_msgs in parse wikidataIdFn wikidataIdKind "Q12X3"

/-- error: <input>:1:6: Wikidata ids must start with the letter Q followed by one or more digits. -/
#guard_msgs in parse wikidataIdFn wikidataIdKind "P12345"

/-- info: Q42 -/
#guard_msgs in parse wikidataIdFn wikidataIdKind "Q42"

namespace LMFDB

@[lmfdb group.abelian "A vacuous comment"]
theorem IsAbelian : 1 + 1 = 2 := by
  rfl

/--
info: some ([LMFDB group.abelian](https://www.lmfdb.org/knowledge/show/group.abelian) (A vacuous comment))
-/
#guard_msgs in
run_cmd
  Lean.logInfo m!"{← Lean.findDocString? (← Lean.getEnv) `LMFDB.IsAbelian}"

/--
error: <input>:1:9: LMFDB ids must consist only of lowercase letters, digits, periods, and underscores.
-/
#guard_msgs in parse lmfdbIdFn lmfdbIdKind "LMFDB.tag"

/-- info: lmfdb.tag_99 -/
#guard_msgs in parse lmfdbIdFn lmfdbIdKind "lmfdb.tag_99"

/--
error: <input>:1:5: LMFDB ids must consist only of lowercase letters, digits, periods, and underscores.
-/
#guard_msgs in parse lmfdbIdFn lmfdbIdKind "LMFDB&tag"

/--
info:
[LMFDB group.abelian](https://www.lmfdb.org/knowledge/show/group.abelian) corresponds to declaration 'IsAbelian'. (A vacuous comment)
-/
#guard_msgs in
#lmfdb_tags

end LMFDB

namespace Pibase

@[pibase topology P000001 "A vacuous comment"]
theorem p : True := .intro

@[pibase topology S000023]
theorem s : True := .intro

@[pibase topology T000001]
theorem t : True := .intro

/--
info: some ([π-Base (Topology) P000001](https://topology.pi-base.org/properties/P000001) (A vacuous comment))
-/
#guard_msgs in
run_cmd
  Lean.logInfo m!"{← Lean.findDocString? (← Lean.getEnv) `Pibase.p}"

/--
info:
[π-Base (Topology) P000001](https://topology.pi-base.org/properties/P000001) corresponds to declaration 'p'. (A vacuous comment)
[π-Base (Topology) S000023](https://topology.pi-base.org/spaces/S000023) corresponds to declaration 's'.
[π-Base (Topology) T000001](https://topology.pi-base.org/theorems/T000001) corresponds to declaration 't'.
-/
#guard_msgs in
#pibase_tags topology

-- The `topology` topic token is non-reserved: `topology` must remain usable as an identifier
-- (it appears as one throughout Mathlib, e.g. `AlgebraicGeometry.ProEt.topology`).
example (topology : Nat) : Nat := topology

/-- error: <input>:1:3: π-Base ids must have exactly six digits after P/S/T. -/
#guard_msgs in parse pibaseIdFn pibaseIdKind "P42"

/-- error: <input>:1:7: π-Base ids must consist of P, S, or T followed by six digits. -/
#guard_msgs in parse pibaseIdFn pibaseIdKind "P00001X"

/-- error: <input>:1:7: π-Base ids must start with P, S, or T. -/
#guard_msgs in parse pibaseIdFn pibaseIdKind "Q000001"

/-- info: S000023 -/
#guard_msgs in parse pibaseIdFn pibaseIdKind "S000023"

end Pibase

namespace DLMF

@[dlmf 5.5.E1 "A vacuous comment"]
theorem test : 1 + 1 = 2 := by
  rfl

/--
info: some ([DLMF 5.5.E1](https://dlmf.nist.gov/5.5.E1) (A vacuous comment))
-/
#guard_msgs in
run_cmd
  Lean.logInfo m!"{← Lean.findDocString? (← Lean.getEnv) `DLMF.test}"

/--
error: <input>:1:6: DLMF references must consist only of (lowercase) roman numerals, the letters E/T/F, digits, periods, and underscores.
-/
#guard_msgs in parse dlmfIdFn dlmfIdKind "random*string"

/-- info: 18.30.iv -/
#guard_msgs in parse dlmfIdFn dlmfIdKind "18.30.iv"

/--
info:
[DLMF 5.5.E1](https://dlmf.nist.gov/5.5.E1) corresponds to declaration 'test'. (A vacuous comment)
-/
#guard_msgs in
#dlmf_tags

end DLMF

/-! The databases are sources: `crossref.json` describes each, and `cite` takes them. -/

open Lean Cite Cite.CrossRef in
/--
info: dlmf: DLMF https://dlmf.nist.gov/5.4.E1
kerodon: Kerodon Tag https://kerodon.net/tag/0X12
lmfdb: LMFDB https://www.lmfdb.org/knowledge/show/group.abelian
pibase-topology: π-Base (Topology) https://topology.pi-base.org/spaces/S000023
stacks: Stacks Tag https://stacks.math.columbia.edu/tag/0BR2
wikidata: Wikidata https://www.wikidata.org/wiki/Q42
-/
#guard_msgs in
run_cmd do
  let env ← getEnv
  let ids := ["5.4.E1", "0X12", "group.abelian", "S000023", "0BR2", "Q42"]
  let lines ← (Database.all.zip ids).mapM fun (db, id) => do
    unless (findSource env db.source).toBool do throwError "no source for {db.shortName}"
    return s!"{db.shortName}: {db.label env} {db.url env id}"
  logInfo ("\n".intercalate lines)

namespace Y

-- a database's name is a keyword, which `cite` reads as a name
@[cite stacks "0BR2"]
theorem cited : True := trivial

theorem stepped : True := by
  cite wikidata "Q42" step 1 =>
    trivial

end Y

/-- info: stacks 0BR2: Y.cited -/
#guard_msgs in
#cite_tags stacks

/-! The export reads this package's cross-references. -/

/-- info: 1 citations, 0 steps in 0 modules, 8 Mathlib cross-references → .lake/cite-crossref.json -/
#guard_msgs in
#cite_export ".lake/cite-crossref.json"

open Lean in
/--
info: Cite.CrossRef.tagExt
DLMF.test dlmf 5.5.E1 https://dlmf.nist.gov/5.5.E1
LMFDB.IsAbelian lmfdb group.abelian https://www.lmfdb.org/knowledge/show/group.abelian
Pibase.p pibase-topology P000001 https://topology.pi-base.org/properties/P000001
Pibase.s pibase-topology S000023 https://topology.pi-base.org/spaces/S000023
Pibase.t pibase-topology T000001 https://topology.pi-base.org/theorems/T000001
W.wikiTagged wikidata Q12345 https://www.wikidata.org/wiki/Q12345
X.tagged kerodon B15R https://kerodon.net/tag/B15R
X.tagged stacks A04Q https://stacks.math.columbia.edu/tag/A04Q
-/
#guard_msgs in
run_cmd do
  let j ← IO.ofExcept <| Json.parse (← IO.FS.readFile ".lake/cite-crossref.json")
  let rows ← IO.ofExcept <| j.getObjValAs? (Array Json) "mathlib"
  let field (r : Json) (k : String) := (r.getObjValAs? String k).toOption.getD ""
  let lines := rows.map fun r => " ".intercalate (["declaration", "database", "id", "url"].map (field r))
  logInfo ("\n".intercalate ((field j "mathlibExtension") :: (lines.qsort (· < ·)).toList))
