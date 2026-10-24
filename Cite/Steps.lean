module

public meta import Cite.Basic
public meta import Lean.Linter.Basic

/-!
# Proof-step markers

A line comment marks the lines that carry out a step of a proof in the source. Here line 3 is
step 2 of the proof of item 1.26:

```
theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  -- cite ladr4e "1.26" step 2
  calc z = z + 0 := (add_zero z).symm
    _ = 0 + z := add_comm z 0
    _ = 0 := h 0
```

A marker is a line comment alone on its line, outside block comments, docstrings and strings:
`--`, then the words `cite`, a source, an entry in double quotes, `step`, one or more step
numbers, and optionally a relation. Words are separated by spaces or tabs. The source is ASCII
letters, digits and `_`, in parts separated by `.`, not starting with a digit. The entry cannot
hold a double quote. Step numbers are ASCII digits, from 1. The line `-- cite end` ends a range.
A line comment that starts with `cite` and has a quoted entry or the word `step` must parse, or
it is reported as malformed; other comments are prose.

A marker opens a range at the next line of code. Lines of code here are lines with something
outside comments; blank lines and comment lines are not. The range ends before the first of:

* the next marker, malformed marker or `-- cite end`;
* the next line of code indented less than the marker's column, or, for a marker in the first
  column, the next line of code that starts in the first column (usually the next command).

Blank and comment lines at the end of the range are left out. Markers on consecutive lines start
their ranges at the same line, and each ends its range by its own column.

Lines end at line feeds, as in Lean's own positions; a lone carriage return does not end a line.

Markers are comments, so they fit where a tactic cannot: before a declaration's statement, in a
term-mode `calc`. `#cite_export` reads them from the source; a linter cannot record them, since
Lean runs linters under `withoutModifyingEnv` or in a separate task. The linter
`linter.cite.steps` checks the markers of each command while it compiles: that they parse, cite a
declared source, and mark lines inside the command.
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
  /-- Only comments, none of them a marker. -/
  | comment
  | marker (m : Marker)
  /-- `-- cite end`. -/
  | stop
  /-- A line comment that starts like a marker but does not parse: the reason. -/
  | malformed (msg : String)
  | code
  deriving Inhabited

/-- Is `c` a space or a tab? -/
def isBlank (c : Char) : Bool := c == ' ' || c == '\t'

/-- The number of leading spaces and tabs. -/
def indentOf (s : String) : Nat :=
  (s.toList.takeWhile isBlank).length

/-- The words of a comment's text: runs of characters other than spaces and tabs, a `"` starting
a word that runs to the next `"`, or to the end of the text when there is none. -/
partial def words (s : List Char) (acc : Array String := #[]) : Array String :=
  match s.dropWhile isBlank with
  | [] => acc
  | '"' :: rest =>
    let body := rest.takeWhile (· != '"')
    let closed := body.length < rest.length
    words (rest.drop (body.length + 1))
      (acc.push ("\"" ++ String.ofList body ++ if closed then "\"" else ""))
  | cs =>
    let w := cs.takeWhile (!isBlank ·)
    words (cs.drop w.length) (acc.push (String.ofList w))

/-- Is `w` a source name: parts of ASCII letters, digits and `_`, separated by `.`, none starting
with a digit? -/
def isSourceName (w : String) : Bool :=
  !w.isEmpty && (w.splitOn ".").all fun part =>
    match part.toList with
    | c :: cs => (c.isAlpha || c == '_') && cs.all (fun c => c.isAlphanum || c == '_')
    | [] => false

/-- Classify a line comment's text, after its `--`, on line `line` at column `column`. -/
def classifyComment (line column : Nat) (text : String) : LineKind := Id.run do
  let ws := words text.toList
  unless ws[0]? == some "cite" do return .comment
  if ws[1]? == some "end" then
    return if ws.size == 2 then .stop else .malformed "`-- cite end` takes nothing after it"
  -- prose that starts with `cite` has neither a quoted entry nor the word `step`
  unless ws.size ≥ 3 && (ws[2]!.startsWith "\"" || ws.contains "step") do return .comment
  let fail (msg : String) : LineKind := .malformed msg
  unless isSourceName ws[1]! do return fail s!"the source `{ws[1]!}` is not a name"
  unless ws[2]!.startsWith "\"" do return fail "the entry is not a string"
  unless ws[2]!.length ≥ 2 && ws[2]!.endsWith "\"" do return fail "the entry has no closing `\"`"
  let id := ((ws[2]!.drop 1).dropEnd 1).toString
  if id.all Char.isWhitespace then return fail "the entry is empty"
  unless ws[3]? == some "step" do return fail "expected `step` after the entry"
  let nums := (ws.extract 4 ws.size).toList.takeWhile fun w => !w.isEmpty && w.all Char.isDigit
  if nums.isEmpty then return fail "expected step numbers after `step`"
  if nums.any (·.toNat! == 0) then return fail "steps are numbered from 1"
  let rest := ws.extract (4 + nums.length) ws.size
  if rest.size > 1 then return fail s!"unexpected `{rest[1]!}`"
  let rel := rest[0]?.getD ""
  unless rel.isEmpty || relations.contains rel do
    return fail s!"unknown relation `{rel}`; the relations are {", ".intercalate relations}"
  return .marker { line, column, source := ws[1]!.toName, id,
                   steps := nums.toArray.map (·.toNat!), rel }

/-- Classify each of `lines`, the first being line `first` of its file, with a lexer that follows
nested block comments (docstrings included), strings and line comments. When the lines start
inside a block comment, which shows as a block-comment closer with nothing open, the lines up to
it are comment. -/
def classifyLines (lines : Array String) (first : Nat := 1) : Array LineKind := Id.run do
  let mut out : Array LineKind := #[]
  let mut depth := 0
  let mut inString := false
  for h : i in [0:lines.size] do
    let cs := lines[i].toList.toArray
    let mut hasCode := false
    let mut onlyComments := true
    let mut lineComment : Option Nat := none
    let mut j := 0
    while j < cs.size do
      let c := cs[j]!
      let next := cs[j + 1]?
      if inString then
        hasCode := true
        if c == '\\' then j := j + 2
        else
          if c == '"' then inString := false
          j := j + 1
      else if depth > 0 then
        if c == '/' && next == some '-' then depth := depth + 1; j := j + 2
        else if c == '-' && next == some '/' then depth := depth - 1; j := j + 2
        else j := j + 1
      else if c == '-' && next == some '-' then
        lineComment := some j; j := cs.size
      else if c == '/' && next == some '-' then depth := 1; j := j + 2
      else if c == '-' && next == some '/' then
        -- the lines began inside a block comment: up to here, all of it is comment
        out := out.map fun _ => .comment
        hasCode := false
        j := j + 2
      else if c == '\'' && cs[j + 1]? == some '"' && cs[j + 2]? == some '\'' then
        hasCode := true; j := j + 3
      else if c == '"' then hasCode := true; inString := true; j := j + 1
      else
        if !isBlank c then hasCode := true
        j := j + 1
    onlyComments := !hasCode
    let kind : LineKind :=
      if !onlyComments then .code
      else match lineComment with
        | some col =>
          if (cs.extract 0 col).all isBlank then
            classifyComment (first + i) col (String.ofList (cs.extract (col + 2) cs.size).toList)
          else .comment
        | none => if cs.all isBlank then .blank else .comment
    out := out.push kind
  return out

/-- A marker with the lines it marks, `[start, stop]` from 1. -/
structure Mark where
  marker : Marker
  start : Nat
  stop : Nat
  deriving Inhabited, Repr

/-- What `scan` finds in some lines of a file. -/
structure Scan where
  /-- Every marker, whether or not it marks anything. -/
  markers : Array Marker := #[]
  /-- The markers that mark lines, with those lines. -/
  marks : Array Mark := #[]
  /-- Problems, as (line, message). -/
  problems : Array (Nat × String) := #[]
  deriving Inhabited

/-- The markers in `lines`, the first being line `first` of its file, and the lines they mark. -/
def scan (lines : Array String) (first : Nat := 1) : Scan := Id.run do
  let kinds := classifyLines lines first
  let n := kinds.size
  let isCode (k : Nat) : Bool := match kinds[k]! with | .code => true | _ => false
  let isBoundary (k : Nat) : Bool := match kinds[k]! with
    | .marker _ | .stop | .malformed _ => true | _ => false
  let mut r : Scan := {}
  let mut i := 0
  while i < n do
    match kinds[i]! with
    | .malformed msg =>
      r := { r with problems := r.problems.push (first + i, s!"malformed `-- cite` marker: {msg}") }
      i := i + 1
    | .marker _ =>
      let mut group := #[]
      let mut j := i
      while j < n do
        let .marker m := kinds[j]! | break
        group := group.push m
        j := j + 1
      r := { r with markers := r.markers ++ group }
      let mut s := j
      while s < n && !isCode s && !isBoundary s do s := s + 1
      if s ≥ n || !isCode s then
        r := { r with problems := r.problems.push (first + i, "the `-- cite` marker marks no code") }
      else
        for m in group do
          let mut k := s + 1
          while k < n && !isBoundary k &&
              !(isCode k && (if m.column == 0 then indentOf lines[k]! == 0
                             else indentOf lines[k]! < m.column)) do
            k := k + 1
          let mut e := k - 1
          while e > s && !isCode e do e := e - 1
          r := { r with marks := r.marks.push { marker := m, start := first + s, stop := first + e } }
      i := j
    | _ => i := i + 1
  return r

/-- The lines of a source file. Lines end at line feeds, as in Lean's positions. -/
def splitLines (src : String) : Array String :=
  (src.crlfToLf.splitOn "\n").toArray

register_option linter.cite.steps : Bool := {
  defValue := true
  descr := "check the `-- cite … step` markers of each command"
}

/-- A reference to line `line` of the file, for messages. -/
def lineRef (fm : FileMap) (line : Nat) : Syntax :=
  let pos := fm.lineStart line
  .node (.synthetic pos pos) nullKind #[]

/-- Line `line` of the file, from 1, without its line feed. -/
def lineOf (fm : FileMap) (line : Nat) : String :=
  let text := String.Pos.Raw.extract fm.source (fm.lineStart line) (fm.lineStart (line + 1))
  if text.endsWith "\n" then (text.dropEnd 1).toString else text

/-- Checks the markers in a command and in the comment lines just above it: that they parse, cite
a declared source, and mark lines inside the command. It reads only those lines and the lines up
to the next line of code in the first column, so it costs each command its own length. -/
def stepsLinter : Linter where
  run := withSetOptionIn fun stx => do
    unless Linter.getLinterValue linter.cite.steps (← Linter.getLinterOptions) do return
    let some range := stx.getRange? | return
    let fm ← getFileMap
    let start := fm.toPosition range.start
    let first := start.line
    let last := (fm.toPosition range.stop).line
    let lastLine := fm.getLastLine
    -- the comment and blank lines just above the command belong to it, unless another command
    -- starts earlier on its first line
    let mut top := first
    if start.column == indentOf (lineOf fm first) then
      while top > 1 && (match (classifyLines #[lineOf fm (top - 1)] (top - 1))[0]! with
          | .code => false | _ => true) do
        top := top - 1
    else top := first + 1
    -- the lines after the command, up to the next line of code in the first column, show where
    -- a range that runs past it would end
    let mut bottom := last
    while bottom < lastLine && !(indentOf (lineOf fm (bottom + 1)) == 0 &&
        (match (classifyLines #[lineOf fm (bottom + 1)] (bottom + 1))[0]! with
          | .code => true | _ => false)) do
      bottom := bottom + 1
    let lines := (Array.range (bottom - top + 1)).map (lineOf fm <| top + ·)
    let r := scan lines top
    let env ← getEnv
    for (line, msg) in r.problems do
      if line ≤ last then Linter.logLint linter.cite.steps (lineRef fm line) m!"{msg}"
    for m in r.markers do
      if m.line > last then continue
      if let .error msg := findSource env m.source then
        Linter.logLint linter.cite.steps (lineRef fm m.line) msg
    for mk in r.marks do
      if mk.marker.line > last then continue
      unless first ≤ mk.start && mk.stop ≤ last do
        Linter.logLint linter.cite.steps (lineRef fm mk.marker.line)
          m!"the marker marks lines {mk.start}–{mk.stop}, which run outside the command on lines \
            {first}–{last}; end the range with `-- cite end`"

initialize addLinter stepsLinter

end Cite
