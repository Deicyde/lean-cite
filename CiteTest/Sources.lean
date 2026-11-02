import Cite

/-! Sources read from a JSON file, with the entries they list. -/

cite_sources "sources.json"

/-- error: the source `atlas` is already declared, in module `CiteTest.Sources` -/
#guard_msgs in
cite_sources "sources.json"

/-- error: sources_untitled.json: the source `nameless` has no `title` -/
#guard_msgs in
cite_sources "sources_untitled.json"

namespace Sources

@[cite notes "1.2"]
theorem assoc : True := trivial

/--
error: the source `notes` has no entry "9.9"; its entries are listed in the JSON file that declares it, in module `CiteTest.Sources`
-/
#guard_msgs in
@[cite notes "9.9"]
theorem unlisted : True := trivial

-- a step of a listed entry
theorem stepped : True := by
  cite notes "1.3" step 1 =>
    trivial

-- a step of an entry the source does not list is reported, and the tactics still run
/--
error: the source `notes` has no entry "7.7"; its entries are listed in the JSON file that declares it, in module `CiteTest.Sources`
-/
#guard_msgs in
theorem steppedBad : True := by
  cite notes "7.7" step 1 =>
    trivial

/--
warning: the source `notes` has no entry "8.8"; its entries are listed in the JSON file that declares it, in module `CiteTest.Sources`

Note: This linter can be disabled with `set_option linter.cite.steps false`
-/
#guard_msgs in
theorem marked : True := by
  -- cite notes "8.8" step 1
  trivial

-- a source that lists no entries takes any
@[cite atlas "P42"]
theorem anyEntry : True := trivial

end Sources

/-- info: notes 1.2: Sources.assoc -/
#guard_msgs in
#cite_tags notes

-- an entry's own address, none for an entry of a document, and the template of the longest prefix
open Cite in
/--
info: https://example.org/notes/2.1, none, https://example.org/p/P1, https://example.org/pq/PQ1, https://example.org/Q1
-/
#guard_msgs in
#eval show Lean.CoreM Unit from do
  let env ← Lean.getEnv
  let .ok notes := findSource env `notes | throwError "no notes"
  let .ok atlas := findSource env `atlas | throwError "no atlas"
  let uris := [notes.entryUri? "2.1", notes.entryUri? "1.2", atlas.entryUri? "P1",
    atlas.entryUri? "PQ1", atlas.entryUri? "Q1"]
  Lean.logInfo (", ".intercalate (uris.map (·.getD "none")))
