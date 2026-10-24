import Cite

/-- A book. -/
cite_source book "A Book" (type := "pdf") (uri := "https://example.org/book.pdf")
cite_source db "A Database" (type := "html") (uri := "https://example.org/entry/{id}")

/-- error: the source `book` is already declared, in module `CiteTest.Basic` -/
#guard_msgs in
cite_source book "Again"

@[cite book "1.2"]
theorem t12 : 1 + 1 = 2 := rfl

@[simp, cite book "1.3" (rel := hasPart) (role := helper) "a comment", cite book "Exercise 1A.4" (part := "a")]
theorem t13 (n : Nat) : n + 0 = n := rfl

/-- The doc. -/
@[cite db "Q42"]
def answer : Nat := 42

/-- info: The doc. -/
#guard_msgs in
open Lean in
run_meta do logInfo ((← findDocString? (← getEnv) ``answer).getD "")

/-- error: an `example` is discarded after elaboration, together with what `@[cite]` records; write `cite … in` before the `example` instead -/
#guard_msgs in
@[cite book "1.4"]
example : True := trivial

cite book "1.5" in
cite book "1.6" (rel := closeMatch) in
/-- A documented example. -/
example : True :=
  trivial

/-- warning: `theorem` declares a name; `@[cite …]` on it records the name, which outlives line numbers -/
#guard_msgs in
cite book "1.7" in
theorem t17 : True := trivial

attribute [cite book "1.8"] Nat.add_comm

/-- error: unknown source `nobook`; declare it with `cite_source` -/
#guard_msgs in
@[cite nobook "1"] theorem bad1 : True := trivial

/-- error: unknown relation `sameAs`; the relations are exactMatch, closeMatch, broadMatch, narrowMatch, relatedMatch, hasPart, noMatch -/
#guard_msgs in
@[cite book "1" (rel := sameAs)] theorem bad2 : True := trivial

/-- error: unknown option `foo` of `cite`; the options are `rel`, `role` and `part` -/
#guard_msgs in
@[cite book "1" (foo := "x")] theorem bad3 : True := trivial

/--
info: book 1.2: t12
book 1.3 (rel := hasPart) (role := helper) "a comment": t13
book Exercise 1A.4 (part := a): t13
book 1.6 (rel := closeMatch): the example at CiteTest.Basic:34
book 1.5: the example at CiteTest.Basic:34
book 1.7: the theorem at CiteTest.Basic:40
book 1.8: Nat.add_comm
-/
#guard_msgs in
#cite_tags book
