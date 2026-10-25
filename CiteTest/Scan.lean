import Cite

/-!
The scanner on the cases of `scan_cases.json`. Lake does not see that file, so after changing it,
change this one (the expected output below) to have it run again. The results are also written to
`.lake/scan_results.json`, against which `examples/ladr/test_cite_scan.py` checks the Python port.
-/

open Lean Cite

structure ScanCase where
  name : String
  lines : Array String
  deriving FromJson

/-- `s` with its control characters written as `\x..`, so that the expected output is text. -/
def visible (s : String) : String :=
  String.join <| s.toList.map fun c =>
    if c.val < 32 || c.val == 127 then
      let h := Nat.toDigits 16 c.val.toNat
      "\\x" ++ String.ofList (if h.length < 2 then '0' :: h else h)
    else c.toString

def scanCorpus : IO String := do
  let cases ← IO.ofExcept <| (Json.parse (← IO.FS.readFile "CiteTest/scan_cases.json")).bind
    (fromJson? (α := Array ScanCase))
  let mut text := #[]
  let mut json := #[]
  for c in cases do
    let r := scan (splitLines ("\n".intercalate c.lines.toList))
    let marks := r.marks.map fun mk =>
      s!"{mk.marker.source} {mk.marker.id} {mk.marker.steps.toList} {mk.marker.rel} {mk.start}-{mk.stop}"
    let problems := r.problems.map fun (l, m) => s!"{l}: {m}"
    text := text.push (visible s!"{c.name}: {marks.toList} {problems.toList}")
    json := json.push <| Json.mkObj [("name", toJson c.name),
      ("markers", toJson (r.markers.map fun m => Json.mkObj [("line", toJson m.line),
        ("column", toJson m.column), ("source", toJson m.source.toString), ("id", toJson m.id),
        ("steps", toJson m.steps), ("rel", toJson m.rel)])),
      ("marks", toJson (r.marks.map fun mk => Json.mkObj [("line", toJson mk.marker.line),
        ("start", toJson mk.start), ("stop", toJson mk.stop)])),
      ("problems", toJson (r.problems.map fun (l, m) => Json.mkObj [("line", toJson l), ("message", toJson m)]))]
  IO.FS.writeFile ".lake/scan_results.json" ((toJson json).pretty ++ "\n")
  return "\n".intercalate text.toList

/--
info: basic: [book 1 [2]  2-2, book 1 [3]  4-5, book 1 [4]  8-8, book 2 [5]  8-8, book 1 [6, 7]  11-11, book 1 [1]  13-13, book 1 [7]  15-15] []
in block comment: [] []
in docstring: [] []
in module doc: [] []
nested comments: [book 1 [2]  5-5] []
in string: [] []
char literal quote: [book 1 [1]  3-3] []
starts inside comment: [book 1 [1]  3-3, book 1 [2]  5-5] [3: a block-comment closer that closes nothing; the scanner may have misread this file]
code then comment: [book 1 [2]  3-3] []
comment then code: [book 1 [2]  3-3] []
lone cr: [book 1 [1]  3-3] []
tabs: [book 1 [1]  3-3, book 1 [2]  5-5] []
nbsp: [] []
step zero: [] [2: malformed `-- cite` marker: steps are numbered from 1, 4: malformed `-- cite` marker: steps are numbered from 1]
step underscore: [] [1: malformed `-- cite` marker: expected step numbers after `step`]
unicode digits: [] [1: malformed `-- cite` marker: expected step numbers after `step`, 3: malformed `-- cite` marker: expected step numbers after `step`]
empty entry: [] [1: malformed `-- cite` marker: the entry is empty, 3: malformed `-- cite` marker: the entry is empty]
unterminated: [] [1: malformed `-- cite` marker: the entry has no closing `"`]
bad source: [] [1: malformed `-- cite` marker: the source `x-y` is not a name, 3: malformed `-- cite` marker: the source `1abc` is not a name, 5: malformed `-- cite` marker: the source `«x»` is not a name]
dotted source: [my.book_2 1 [1]  2-2] []
prose: [] [3: malformed `-- cite` marker: the entry is not a string, 5: malformed `-- cite` marker: `-- cite end` takes nothing after it]
relation: [book 1 [1] closeMatch 2-2] [3: malformed `-- cite` marker: unknown relation `sameAs`; the relations are exactMatch, closeMatch, broadMatch, narrowMatch, relatedMatch, hasPart, noMatch, 5: malformed `-- cite` marker: unexpected `extra`]
no code: [] [3: the `-- cite` marker marks no code]
at end of file: [] [2: the `-- cite` marker marks no code]
col0 match arms: [book 1 [1]  2-2] []
consecutive columns: [book 1 [1]  4-4, book 1 [2]  4-6] []
separated markers: [book 1 [2]  5-5] [2: the `-- cite` marker marks no code]
trailing blank and comments: [book 1 [1]  3-6] []
spaced entry: [book Exercise 1A.4 [2, 3]  2-2] []
no space: [book 1 [1]  2-2] []
review: raw string backslash: [book 1 [1]  4-4] []
review: raw string hash quote: [book 1 [1]  4-4] []
review: char escaped quote: [book 1 [1]  4-4] []
review: char escaped quote then docstring wipe: [book 1 [1]  2-3] []
review: guillemet block opener: [book 1 [1]  3-3] []
review: guillemet line comment: [book 1 [1]  3-3] []
review: guillemet quote: [book 1 [1]  3-3] []
review: docstring dash slash: [book 1 [1]  3-3] []
review: nbsp entry: [book   [1]  2-2] []
review: form feed entry: [book \x0c [1]  2-2] []
review: em space entry: [book   [1]  2-2] []
review: vertical tab entry: [book \x0b [1]  2-2] []
review: ideographic space entry: [book 　　 [1]  2-2] []
review: stray closer after code: [book 1 [1]  2-2] [3: a block-comment closer that closes nothing; the scanner may have misread this file]
review: string gap: [book 1 [1]  4-4] []
review: string with marker text: [book 1 [1]  3-3] []
review: multiline string with marker line: [] []
review: nested depth three: [book 1 [1]  5-5] []
review: quote inside comment: [book 1 [1]  3-3] []
review: closer in quotes in comment: [] []
review: docstring then code same line: [book 1 [1]  3-3] []
review: module doc then marker same line: [] []
review: line comment with opener: [book 1 [1]  3-3] []
review: line comment with closer: [book 1 [1]  3-3] []
review: char slash dash: [book 1 [1]  3-3] []
review: char apostrophe: [book 1 [1]  3-3] []
review: primes and quote: [book 1 [1]  3-3] []
review: escaped backslash string: [book 1 [1]  3-3] []
review: escaped backslash quote: [book 1 [1]  3-3] []
review: unterminated string eof: [] []
review: tab indent marker: [book 1 [1]  3-4] []
review: tab cite end: [book 1 [1]  3-3] []
review: no space cite end: [book 1 [1]  3-3] []
review: four dashes: [] []
review: three dashes: [] []
review: many steps rel: [book 1 [1, 2, 3] exactMatch 2-2] []
review: leading zero: [book 1 [1, 7]  2-2] []
review: huge step: [book 1 [99999999999999999999999]  2-2] []
review: quote in middle: [] [1: malformed `-- cite` marker: expected `step` after the entry]
review: source glued to entry: [] [1: malformed `-- cite` marker: the source `book"1"` is not a name]
review: entry glued to step: [book 1 [1]  2-2] []
review: unicode source: [] [1: malformed `-- cite` marker: the source `bóok` is not a name]
review: odd sources: [_ 1 [1]  2-2, a._b 1 [1]  4-4] [5: malformed `-- cite` marker: the source `a..b` is not a name, 7: malformed `-- cite` marker: the source `.a` is not a name, 9: malformed `-- cite` marker: the source `a.` is not a name]
review: tab in entry: [book a\x09b [1]  2-2] []
review: trailing spaces: [book 1 [1]  2-2] []
review: empty file: [] []
review: single newline: [] []
review: marker eof no newline: [] [3: the `-- cite` marker marks no code]
review: crlf file: [book 1 [1]  3-3] []
review: lone cr in code: [] []
review: lone cr at end of marker: [book 1 [1]  3-3] []
review: nbsp before dashes: [] []
review: astral chars: [book 𝔽😀 [1]  3-3] []
review: combining entry: [book é [1]  2-2] []
review: cite end extra: [book 1 [1]  3-3] [4: malformed `-- cite` marker: `-- cite end` takes nothing after it]
review: cite end alone first: [] []
review: prose with step word: [] [1: malformed `-- cite` marker: the entry is not a string]
review: prose with quote: [] [1: malformed `-- cite` marker: expected `step` after the entry]
review: only cite: [] []
review: cite source only: [] []
review: block comment then line comment: [] []
review: code then block comment open: [] []
review: close then code: [book 1 [1]  5-5] []
review: char literal quote then string: [book 1 [1]  3-3] []
review: interpolated nested string: [book 1 [1]  3-3] []
review: col0 marker before indented namespace: [book 1 [1]  2-4] []
review: marker col4 then skip col2: [book 1 [1]  3-4] []
review: docstring line followed by code: [book 1 [1]  4-4] []
review: stray closer first line: [book 1 [1]  3-3] [1: a block-comment closer that closes nothing; the scanner may have misread this file]
review: two stray closers: [book 1 [1]  2-2, book 1 [1]  5-5, book 1 [1]  8-8] [3: a block-comment closer that closes nothing; the scanner may have misread this file, 6: a block-comment closer that closes nothing; the scanner may have misread this file]
review: cr cr lf: [book 1 [1]  3-3] []
review: trailing lone cr eof: [book 1 [1]  2-2] []
review: only crs: [] []
review: nul in code: [book 1 [1]  3-3] []
review: nul in entry: [book a\x00b [1]  2-2] []
review: line separator char: [book 1 [1]  3-3] []
review: interp char quote: [book 1 [1]  3-3] []
review: unicode digits in source: [] [1: malformed `-- cite` marker: the source `book١` is not a name]
review: fullwidth digits step: [] [1: malformed `-- cite` marker: expected step numbers after `step`]
review: kelvin sign source: [] [1: malformed `-- cite` marker: the source `Kelvin` is not a name]
review: dotless i source: [] [1: malformed `-- cite` marker: the source `ıbook` is not a name]
review: cite end then code col0: [book 1 [1]  2-3] []
review: marker col0 inside proof: [book 1 [1]  3-4] []
review: marker group mixed malformed: [] [2: the `-- cite` marker marks no code, 3: malformed `-- cite` marker: expected step numbers after `step`]
review: deep indent marker shallow code: [book 1 [1]  3-3] []
review: nested block opener in line comment in block: [] []
review: block closer then opener same line: [] []
review: string then comment opener: [] []
review: char then line comment: [] []
review: empty step list rel: [] [1: malformed `-- cite` marker: expected step numbers after `step`]
review: step twice: [] [1: malformed `-- cite` marker: unexpected `2`]
review: very long line: [book xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx [1]  2-2] []
review: many markers group: [book 0 [1]  31-31, book 1 [2]  31-31, book 2 [3]  31-31, book 3 [4]  31-31, book 4 [5]  31-31, book 5 [6]  31-31, book 6 [7]  31-31, book 7 [8]  31-31, book 8 [9]  31-31, book 9 [10]  31-31, book 10 [11]  31-31, book 11 [12]  31-31, book 12 [13]  31-31, book 13 [14]  31-31, book 14 [15]  31-31, book 15 [16]  31-31, book 16 [17]  31-31, book 17 [18]  31-31, book 18 [19]  31-31, book 19 [20]  31-31, book 20 [21]  31-31, book 21 [22]  31-31, book 22 [23]  31-31, book 23 [24]  31-31, book 24 [25]  31-31, book 25 [26]  31-31, book 26 [27]  31-31, book 27 [28]  31-31, book 28 [29]  31-31, book 29 [30]  31-31] []
raw string with comment opener: [book 1 [1]  3-3] []
raw string over lines: [book 1 [2]  5-5] []
interpolation with nested string: [book 1 [1]  3-3] []
interpolation with braces: [book 1 [1]  3-3] []
char escaped backslash: [book 1 [1]  3-3] []
char escaped apostrophe: [book 1 [1]  3-3] []
primes in names: [book 1 [1]  3-3] []
guillemets: [book 1 [1]  3-3] []
stray closer in whole file: [book 1 [1]  3-3, book 1 [2]  6-6] [4: a block-comment closer that closes nothing; the scanner may have misread this file]
unicode space entry: [book   [1]  2-2] []
leading comment: [book 1 [1]  3-4, book 1 [2]  6-6] []
blank then comment: [book 1 [1]  4-5] []
marker before docstring: [book 1 [1]  2-3] []
only comments then boundary: [] [2: the `-- cite` marker marks no code]
-/
#guard_msgs in
#eval do IO.println (← scanCorpus)
