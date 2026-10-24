import Cite

/-!
The scanner on the cases of `scan_cases.json`. The results are also written to
`.lake/scan_results.json`, against which `examples/ladr/test_cite_scan.py` checks the Python port.
-/

open Lean Cite

structure ScanCase where
  name : String
  lines : Array String
  deriving FromJson

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
    text := text.push s!"{c.name}: {marks.toList} {problems.toList}"
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
starts inside comment: [book 1 [2]  5-5] []
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
-/
#guard_msgs in
#eval do IO.println (← scanCorpus)
