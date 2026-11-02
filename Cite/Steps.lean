module

public meta import Cite.Basic
public meta import Lean.Linter.Basic

/-!
# Proof-step markers

A line comment marks the lines that carry out a step of a proof in the source. Here lines 3–5 are
step 2 of the proof of item 1.26:

```
theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  -- cite ladr4e "1.26" step 2
  calc z = z + 0 := (add_zero z).symm
    _ = 0 + z := add_comm z 0
    _ = 0 := h 0
```

A marker is a line comment alone on its line, outside block comments, docstrings and strings. After
its `--`, its words are `cite`, a source, an entry, `step`, one or more step numbers, and optionally
a relation.

* Words are separated by spaces or tabs. An entry is a word from a `"` to the next `"`, and the
  next word may follow it directly.
* A source is ASCII letters, digits and `_`, in parts separated by `.`, none starting with a digit.
* An entry holds no `"`, and not only spaces, tabs and line breaks.
* Step numbers are ASCII digits, from 1.
* The comment `-- cite end` ends a range; `-- cite end` followed by anything is malformed.
* A line comment whose first word is `cite` and that has at least three words, the third quoted or
  one of them `step`, must parse as a marker, or is reported as malformed. Other comments are prose.

A line of code is a line with something outside comments; blank lines and comment lines are not
code. A marker opens a range at the next line that is not blank, so that a comment on the step
belongs to it, and the range holds the line of code after that. From there, the range ends before
the first of:

* the next marker, malformed marker or `-- cite end`;
* the next line of code indented less than the marker's column or, for a marker in the first
  column, the next line of code in the first column, usually where the next command starts.

Blank and comment lines at the end of the range are left out. Markers on consecutive lines start
their ranges at the same line, and each ends its range by its own column. Indentation counts spaces
and tabs. Lines end at line feeds, as in Lean's positions; a lone carriage return does not end one.

The lexer follows nested block comments and docstrings, line comments, strings with the code in an
interpolated string's braces, raw strings, character literals and `«…»` names. A block-comment
closer that closes nothing shows that it has lost its place, and the scan reports it.

Comment markers change no line of the proof, and fit where the wrappers of `Cite/StepSyntax.lean`
cannot: in an `example`'s proof, which Lean discards with what a wrapper records, on lines that are
only part of a syntax node, and on lines that cross another step's. Lean runs linters under `withoutModifyingEnv` or in a separate task, so a
linter cannot record what it reads; `#cite_export` reads the markers from the source. The linter
`linter.cite.steps` checks each command's markers while it compiles: that they parse, mark code,
cite a declared source and one of its entries when it lists them, and mark lines inside the
command.
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

/-- Where the lexer is, outside block comments. -/
inductive Mode where
  /-- In a string; `interp` for an interpolated one such as `s!"…"`. -/
  | str (interp : Bool)
  /-- In a raw string, which this many `#` after a `"` close. -/
  | raw (hashes : Nat)
  /-- In code inside `{…}` of an interpolated string, with this many more braces open. -/
  | interp (braces : Nat)
  deriving Inhabited, BEq

/-- Can `c` continue an identifier, so that a `'` or an `r` after it is part of the identifier? -/
def isIdentChar (c : Char) : Bool :=
  c.isAlphanum || c == '_' || c == '\'' || c == '!' || c == '?' || c.val > 127

/-- Classify each of `lines`, the first being line `first` of its file, with a lexer that follows
nested block comments (docstrings included), line comments, strings (interpolated ones too, with
the code in their braces), raw strings, character literals and `«…»` names. Also returns the lines
on which a block-comment closer closes nothing. When `slice` holds, the lines may start inside a
block comment, which such a closer shows: the lines up to it are then comment. -/
def classifyLines (lines : Array String) (first : Nat := 1) (slice := false) :
    Array LineKind × Array Nat := Id.run do
  let mut out : Array LineKind := #[]
  let mut strays : Array Nat := #[]
  let mut depth := 0
  let mut stack : List Mode := []
  for h : i in [0:lines.size] do
    let cs := lines[i].toList.toArray
    let n := cs.size
    let mut hasCode := false
    let mut lineComment : Option Nat := none
    let mut j := 0
    while j < n do
      let c := cs[j]!
      let next := cs[j + 1]?
      let prevIdent := j > 0 && isIdentChar cs[j - 1]!
      match stack with
      | .str interp :: rest =>
        hasCode := true
        if c == '\\' then j := j + 2
        else if c == '"' then stack := rest; j := j + 1
        else if interp && c == '{' then stack := .interp 0 :: stack; j := j + 1
        else j := j + 1
      | .raw hashes :: rest =>
        hasCode := true
        if c == '"' && (List.range hashes).all (fun k => cs[j + 1 + k]? == some '#') then
          stack := rest; j := j + 1 + hashes
        else j := j + 1
      | _ =>
        if depth > 0 then
          if c == '/' && next == some '-' then depth := depth + 1; j := j + 2
          else if c == '-' && next == some '/' then depth := depth - 1; j := j + 2
          else j := j + 1
        else if c == '-' && next == some '-' then
          lineComment := some j; j := n
        else if c == '/' && next == some '-' then depth := 1; j := j + 2
        else if c == '-' && next == some '/' then
          if slice then
            -- the lines began inside a block comment: up to here, all of it is comment
            out := out.map fun _ => .comment
            hasCode := false
          else
            strays := strays.push (first + i)
            hasCode := true
          j := j + 2
        else if c == '«' then
          hasCode := true
          j := ((cs.extract (j + 1) n).findIdx? (· == '»')).map (j + 2 + ·) |>.getD n
        else if c == '"' then
          let interp := j ≥ 2 && cs[j - 1]! == '!' && isIdentChar cs[j - 2]!
          stack := .str interp :: stack; hasCode := true; j := j + 1
        else if c == 'r' && !prevIdent &&
            (let k := ((cs.extract (j + 1) n).toList.takeWhile (· == '#')).length
             cs[j + 1 + k]? == some '"') then
          let k := ((cs.extract (j + 1) n).toList.takeWhile (· == '#')).length
          stack := .raw k :: stack; hasCode := true; j := j + 2 + k
        else if c == '\'' && !prevIdent && next == some '\\' then
          -- an escaped character literal runs to its closing `'`
          hasCode := true
          j := ((cs.extract (j + 3) (min n (j + 12))).findIdx? (· == '\'')).map (j + 4 + ·)
            |>.getD (j + 1)
        else if c == '\'' && !prevIdent && cs[j + 2]? == some '\'' then
          hasCode := true; j := j + 3
        else
          match stack with
          | .interp b :: rest =>
            if c == '{' then stack := .interp (b + 1) :: rest
            else if c == '}' then stack := if b == 0 then rest else .interp (b - 1) :: rest
          | _ => pure ()
          if !isBlank c then hasCode := true
          j := j + 1
    let kind : LineKind :=
      if hasCode then .code
      else match lineComment with
        | some col =>
          if (cs.extract 0 col).all isBlank then
            classifyComment (first + i) col (String.ofList (cs.extract (col + 2) n).toList)
          else .comment
        | none => if cs.all isBlank then .blank else .comment
    out := out.push kind
  return (out, strays)

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

/-- The markers in `lines`, the first being line `first` of its file, and the lines they mark.
`slice` is for lines that may start inside a block comment; see `classifyLines`. -/
def scan (lines : Array String) (first : Nat := 1) (slice := false) : Scan := Id.run do
  let (kinds, strays) := classifyLines lines first slice
  let n := kinds.size
  let isCode (k : Nat) : Bool := match kinds[k]! with | .code => true | _ => false
  let isBoundary (k : Nat) : Bool := match kinds[k]! with
    | .marker _ | .stop | .malformed _ => true | _ => false
  let stray := "a block-comment closer that closes nothing; the scanner may have misread this file"
  let mut r : Scan := { problems := strays.map fun l => (l, stray) }
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
      -- the range opens at the next line that is not blank, a comment on the step included, and
      -- needs a line of code
      let mut s := j
      while s < n && (match kinds[s]! with | .blank => true | _ => false) do s := s + 1
      let mut c := s
      while c < n && !isCode c && !isBoundary c do c := c + 1
      if c ≥ n || !isCode c then
        r := { r with problems := r.problems.push (first + i, "the `-- cite` marker marks no code") }
      else
        for m in group do
          let mut k := c + 1
          while k < n && !isBoundary k &&
              !(isCode k && (if m.column == 0 then indentOf lines[k]! == 0
                             else indentOf lines[k]! < m.column)) do
            k := k + 1
          let mut e := k - 1
          while e > c && !isCode e do e := e - 1
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

/-- Is the text code, to a lexer that starts outside comments and strings? -/
def isCodeText (text : String) : Bool :=
  match (classifyLines #[text]).1[0]? with | some LineKind.code => true | _ => false

/-- Checks the markers in a command and in the comment lines just above it: that they parse, cite
a declared source and one of its entries when it lists them, and mark lines inside the command. It
reads those lines and the lines after the command up to the next line of code indented no more
than the command, so each command costs about its own length. -/
def stepsLinter : Linter where
  run := withSetOptionIn fun stx => do
    unless Linter.getLinterValue linter.cite.steps (← Linter.getLinterOptions) do return
    let some range := stx.getRange? | return
    let fm ← getFileMap
    let start := fm.toPosition range.start
    let first := start.line
    let last := (fm.toPosition range.stop).line
    let firstLine := lineOf fm first
    let indent := indentOf firstLine
    -- the comment and blank lines just above the command belong to it, unless code before the
    -- command on its first line shows that another command ends there
    let mut top := first
    if isCodeText (String.ofList (firstLine.toList.take start.column)) then
      top := first + 1
    else
      while top > 1 && !isCodeText (lineOf fm (top - 1)) do
        top := top - 1
    -- the lines after the command, up to the next command at its indentation or less, show where
    -- a range that runs past it would end
    let mut bottom := last
    while bottom < fm.getLastLine && !(isCodeText (lineOf fm (bottom + 1)) &&
        indentOf (lineOf fm (bottom + 1)) ≤ indent) do
      bottom := bottom + 1
    let r := scan ((Array.range (bottom - top + 1)).map (lineOf fm <| top + ·)) top (slice := true)
    let env ← getEnv
    for (line, msg) in r.problems do
      if line ≤ last then Linter.logLint linter.cite.steps (lineRef fm line) m!"{msg}"
    for m in r.markers do
      if m.line > last then continue
      match findSource env m.source with
      | .error msg => Linter.logLint linter.cite.steps (lineRef fm m.line) msg
      | .ok s =>
        unless s.entries.isEmpty || (s.entry? m.id).isSome do
          Linter.logLint linter.cite.steps (lineRef fm m.line) (s.unknownEntry m.id)
    for mk in r.marks do
      if mk.marker.line > last then continue
      unless first ≤ mk.start && mk.stop ≤ last do
        Linter.logLint linter.cite.steps (lineRef fm mk.marker.line)
          m!"the marker marks lines {mk.start}–{mk.stop}, which run outside the command on lines \
            {first}–{last}; end the range with `-- cite end`"

initialize addLinter stepsLinter

end Cite
