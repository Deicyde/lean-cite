module

public meta import Cite.Basic
public meta import Lean.Linter.Basic

/-!
# Proof-step markers

A line comment marks the lines that carry out a step of a proof in the source:

```lean
theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  -- cite ladr4e "1.26" step 2
  calc z = z + 0 := (add_zero z).symm
    _ = 0 + z := add_comm z 0
    _ = 0 := h 0
```

The grammar is `-- cite src "id" step k₁ k₂ … [relation]`, alone on its line. A marker opens a
range at the next line of code. The range ends before the next marker, before a line `-- cite end`,
or before the first line of code indented less than the marker; a marker in the first column ends
instead before the next line of code in the first column, where the next command starts. Trailing
blank and comment lines are left out. Markers on consecutive lines open the same range, which is
how a line serves two steps or two proofs.

Markers are comments, so they cost elaboration nothing and fit anywhere: in a tactic block, in a
term-mode `calc`, before a declaration's statement. They are read from the source by
`#cite_export`, not recorded while elaborating: proofs are elaborated asynchronously, and what a
linter or a tactic would add to the environment there is discarded. The linter `linter.cite.steps`
checks each command's markers while it is compiled.
-/

public meta section

open Lean Elab Command

namespace Cite

/-- A marker: lines that carry out steps of the proof of an entry of a source. -/
structure Marker where
  /-- The marker's own line, from 1. -/
  line : Nat
  /-- The column where `--` starts. -/
  column : Nat
  source : Name
  id : String
  steps : Array Nat
  /-- A relation from `relations`, or empty. -/
  rel : String := ""
  deriving Inhabited, Repr

/-- What a line of source is, to the scanner. -/
inductive LineKind where
  | blank
  /-- A line holding only a `--` comment that is not a marker. -/
  | comment
  | marker (m : Marker)
  /-- `-- cite end`. -/
  | stop
  /-- A line that starts like a marker but does not parse: the reason. -/
  | malformed (msg : String)
  | code
  deriving Inhabited

/-- The number of leading spaces. -/
def indentOf (s : String) : Nat :=
  (s.toList.takeWhile (· == ' ')).length

/-- Split `s` into words, keeping a `"…"` string as one word with its quotes. -/
partial def words (s : List Char) (acc : Array String := #[]) : Array String :=
  match s.dropWhile (· == ' ') with
  | [] => acc
  | '"' :: rest =>
    let body := rest.takeWhile (· != '"')
    words (rest.drop (body.length + 1)) (acc.push ("\"" ++ String.ofList body ++ "\""))
  | cs =>
    let w := cs.takeWhile (· != ' ')
    words (cs.drop w.length) (acc.push (String.ofList w))

/-- Classify line `line` (from 1), whose text is `text`. -/
def classify (line : Nat) (text : String) : LineKind := Id.run do
  let body := text.trimAsciiStart.toString
  if body.isEmpty then return .blank
  unless body.startsWith "--" do return .code
  let ws := words (body.drop 2).toString.toList
  unless ws[0]? == some "cite" do return .comment
  if ws.size == 2 && ws[1]! == "end" then return .stop
  -- `-- cite` followed by prose, not by a source and an entry, is an ordinary comment
  unless ws.size ≥ 3 && ws[2]!.startsWith "\"" do return .comment
  let fail (msg : String) : LineKind := .malformed msg
  unless ws[2]!.length ≥ 3 && ws[2]!.endsWith "\"" do return fail "the entry is not a string"
  let id := ((ws[2]!.drop 1).dropEnd 1).toString
  unless ws[3]? == some "step" do return fail "expected `step` after the entry"
  let nums := (ws.extract 4 ws.size).toList.takeWhile (·.isNat)
  if nums.isEmpty then return fail "expected step numbers after `step`"
  if nums.any (· == "0") then return fail "steps are numbered from 1"
  let rest := ws.extract (4 + nums.length) ws.size
  if rest.size > 1 then return fail s!"unexpected `{rest[1]!}`"
  let rel := rest[0]?.getD ""
  unless rel.isEmpty || relations.contains rel do
    return fail s!"unknown relation `{rel}`; the relations are {", ".intercalate relations}"
  return .marker { line, column := indentOf text, source := ws[1]!.toName, id,
                   steps := nums.toArray.map (·.toNat!), rel }

/-- A marker with the lines it marks, `[start, stop]` from 1. -/
structure Mark where
  marker : Marker
  start : Nat
  stop : Nat
  deriving Inhabited, Repr

/-- The marks in a file, given its lines, and the problems found: (line, message). -/
def scan (lines : Array String) : Array Mark × Array (Nat × String) := Id.run do
  let kinds := lines.mapIdx fun i t => classify (i + 1) t
  let n := kinds.size
  let isCode (k : Nat) : Bool := match kinds[k]! with | .code => true | _ => false
  let isBoundary (k : Nat) : Bool := match kinds[k]! with
    | .marker _ | .stop | .malformed _ => true | _ => false
  let mut marks := #[]
  let mut problems := #[]
  let mut i := 0
  while i < n do
    match kinds[i]! with
    | .malformed msg => problems := problems.push (i + 1, msg); i := i + 1
    | .marker _ =>
      let mut group := #[]
      let mut j := i
      while j < n do
        let .marker m := kinds[j]! | break
        group := group.push m
        j := j + 1
      let mut s := j
      while s < n && !isCode s && !isBoundary s do s := s + 1
      if s ≥ n || !isCode s then
        problems := problems.push (i + 1, "the marker is followed by no code to mark")
      else
        for m in group do
          let lim := max m.column 1
          let mut k := s + 1
          while k < n && !isBoundary k && !(isCode k && indentOf lines[k]! < lim) do k := k + 1
          let mut e := k - 1
          while e > s && !isCode e do e := e - 1
          marks := marks.push { marker := m, start := s + 1, stop := e + 1 }
      i := j
    | _ => i := i + 1
  return (marks, problems)

/-- The lines of a source file. -/
def splitLines (src : String) : Array String :=
  ((src.replace "\r\n" "\n").replace "\r" "\n").splitOn "\n" |>.toArray

register_option linter.cite.steps : Bool := {
  defValue := true
  descr := "check the `-- cite … step` markers of each command"
}

/-- A reference to line `line` of the file, for messages. -/
def lineRef (fm : FileMap) (line : Nat) : Syntax :=
  let pos := fm.lineStart line
  .node (.synthetic pos pos) nullKind #[]

/-- Checks the markers in a command and in the comment lines just above it: that they parse, cite
a declared source, and mark lines inside the command. -/
def stepsLinter : Linter where
  run := withSetOptionIn fun stx => do
    unless Linter.getLinterValue linter.cite.steps (← Linter.getLinterOptions) do return
    let some range := stx.getRange? | return
    let fm ← getFileMap
    let first := (fm.toPosition range.start).line
    let last := (fm.toPosition range.stop).line
    let lines := splitLines fm.source
    -- the comment and blank lines just above the command belong to it
    let mut top := first
    while top > 1 && (match classify (top - 1) lines[top - 2]! with
        | .code => false | _ => true) do
      top := top - 1
    let (marks, problems) := scan lines
    for (line, msg) in problems do
      if top ≤ line && line ≤ last then
        Linter.logLint linter.cite.steps (lineRef fm line) m!"malformed `-- cite` marker: {msg}"
    for mk in marks do
      let m := mk.marker
      unless top ≤ m.line && m.line ≤ last do continue
      if (findSource? (← getEnv) m.source).isNone then
        Linter.logLint linter.cite.steps (lineRef fm m.line)
          m!"unknown source `{m.source}`; declare it with `cite_source`"
      unless first ≤ mk.start && mk.stop ≤ last do
        Linter.logLint linter.cite.steps (lineRef fm m.line)
          m!"the marker marks lines {mk.start}–{mk.stop}, which run outside the command on lines \
            {first}–{last}; end the range with `-- cite end`"

initialize addLinter stepsLinter

end Cite
