# WORK IN PROGRESS

Write, in the Lean source, which passage of a book, paper or database each declaration and each
proof step formalizes. Export those links as
[Literature Links](https://github.com/mathlib-initiative/literature-links) annotations;
[Terms](#terms) has the basics.

```lean
@[cite ladr4e "3.21"]                       -- this theorem is item 3.21 of the book
theorem finrank_ker_add_finrank_range … := by
  cite ladr4e "3.21" step 2 =>              -- these tactics carry out step 2 of its proof
    …
```

Links kept in the Lean move with the code: renaming a declaration or editing a proof keeps them
attached. On every build Lean checks that each tag names a declared source and a valid relation,
and that each step marker marks code. Whether a link is mathematically right stays a person's call.

**Status.** A prototype, in the private repository Deicyde/lean-cite. It depends on Lean core only.
CI builds and tests it with Lean 4.30.0-rc2, its pinned toolchain, and 4.36.0-rc1. The package
alone has also been built with 4.31.0, 4.32.0, 4.33.1 and 4.35.0.

The package, its tests and the reviews named in its history were done by AI agents.

It was tested on *Linear Algebra Done Right*. Rado Kirov's Lean formalization of the book is
rkirov/linear-algebra-done-right-lean; Deicyde/linear-algebra-done-right-companion, called the
companion below, keeps links from the book to it outside the Lean. Each chapter's links were written into the Lean as tags. The companion's own exporter was
then run with that chapter's links to the Lean taken only from what `#cite_export` read back, and
the book's side, such as where each passage is on the page, from the companion as before. It
reproduced the companion's annotations, apart from `provenance.method`, which records where each
link came from, and one of the 1,561 proof-step ranges, which loses a line. On chapter 1, this
package's `cite_ll.py` also reproduced the Lean side of all 264 of the companion's links. See
[`examples/ladr`](examples/ladr/README.md). To try it, the tagged chapter is in
[Deicyde/linear-algebra-done-right-lean-cite](https://github.com/Deicyde/linear-algebra-done-right-lean-cite),
also private; [`examples/ladr`](examples/ladr/README.md#try-it) says how to build it.

## Terms

- **Literature Links** is a small JSON format with one annotation per link: a `.json` file holds one
  annotation, and a `.jsonl` file one per line. An annotation has a subject (here, the passage), an
  object (here, the Lean) and a relation between them. Each side is a list of *ends*: a region of a
  PDF, a web page, a Lean declaration, some lines of a Lean file.
- The **relations** are `exactMatch`, `closeMatch`, `broadMatch`, `narrowMatch`, `relatedMatch`,
  `hasPart` and `noMatch`. They read from the passage to the Lean: `broadMatch` says the Lean is
  more general than the passage, `narrowMatch` that it is a special case, `hasPart` that it states
  one part of the passage. A tag may leave the relation out; its annotation then has none.
- A **source** is a book, paper or database, declared once with `cite_source`. An **entry** is an
  item of it: `"3.21"`, `"Exercise 1B.8"`, a Stacks tag.
- A **proof step** is a numbered part of a proof in the source. The package does not number steps:
  a tag uses the numbering of whatever splits the source's proofs into steps, such as the data of
  the *Linear Algebra Done Right* companion. Step k of entry e becomes the annotation
  `e proof, step k`.

## How it fits together

```
Lean source: @[cite] tags, step wrappers, step comments
        │  lake build: Lean checks each tag and wrapper, and records it
        ▼
#cite_export "out.json" MyProject         (in Lean; reads step comments from the source)
        │  JSON: sources, citations, steps, Mathlib's own cross-references
        ▼
python3 scripts/cite_ll.py out.json …     (Python, standard library only)
        │
        ▼
Literature Links annotations (.jsonl) → viewers and other tools
```

## Quick start

1. Clone this repository beside the project (Deicyde/lean-cite is private for now), and require it
   by path. The package is named `cite`, and its library `Cite`. In `lakefile.toml`:

   ```toml
   [[require]]
   name = "cite"
   path = "../lean-cite"
   ```

   or, in `lakefile.lean`, `require cite from "../lean-cite"`. Then run `lake update cite`.
   To fetch it instead, use `git = "https://github.com/Deicyde/lean-cite"` and a `rev` in place of
   `path`; git then needs credentials that can read the repository.
   `import Cite` makes `cite` a keyword in the importing file; write `«cite»` for an identifier of
   that name.

2. In a module of the project, such as `MyProject/Basic.lean` imported by `MyProject.lean`, declare
   the source once, and tag what formalizes it. This example uses Mathlib for `V`:

   ```lean
   import Mathlib
   import Cite

   /-- Sheldon Axler, *Linear Algebra Done Right*, 4th edition. -/
   cite_source ladr4e "Linear Algebra Done Right, 4th edition"
     (type := "pdf") (uri := "https://linear.axler.net/LADR4e.pdf")

   variable {V : Type*} [AddCommGroup V]

   -- In the companion's data, step 1 of 1.26 is its statement and step 2 the chain of equalities.
   @[cite ladr4e "1.26"]
   theorem unique_zero (z : V) (h : ∀ v : V, v + z = v) : z = 0 :=
     cite ladr4e "1.26" step 2 in
     calc z = z + 0 := (add_zero z).symm
       _ = 0 + z := add_comm z 0
       _ = 0 := h 0
   ```

3. Write a file such as `Export.lean` that imports the tagged modules:

   ```lean
   import MyProject
   #cite_export "out.json" MyProject
   ```

   Then, from the project's root:

   ```sh
   lake build
   lake env lean Export.lean
   python3 ../lean-cite/scripts/cite_ll.py out.json \
     --project <repository URL> --commit <sha> --out annotations/
   ```

   This writes `annotations/ladr4e.jsonl`, with one annotation for the citation of 1.26 and one for
   its step 2. Without `--mathlib-commit <sha>`, Mathlib's own cross-references are left out, with
   a message on stderr for each Mathlib module that has them.

`#cite_tags` lists every citation in scope, which is handy while tagging.

## Tagging

### Sources

`cite_source name "title" (field := "value") …` declares a source; any project declares its own.
Fields are free-form; `cite_ll.py` reads these:

| Field | Meaning |
|---|---|
| `uri` | the source's address, which `cite_ll.py` needs unless a layout (see [Exporting](#exporting)) places every entry. With `{id}` in it, a template for each entry's address, as for a web database |
| `type` | the Literature Links type of its ends: `pdf`, `html`, …; by default `html` for a template and `generic` otherwise |
| `registry` | for a template, the key under which each end records its entry in `identifiers`: with `(registry := "wikidata")`, the entry `"Q42"` gets `"identifiers": {"wikidata": "Q42"}`. By default the source's name |

A docstring on `cite_source` is kept as the field `doc`. Two modules that do not import each other
may declare the same name; citing it is then an error that names both.

### Declarations

| Write | For |
|---|---|
| `@[cite src "id"]` | a named declaration |
| `attribute [cite src "id"] n` | a declaration of another project, such as one of Mathlib's |
| `cite src "id" in` before the command | an `example`, a `recall`, an unnamed `instance` |

Options go after the entry: `(rel := closeMatch)`, a relation; `(role := helper)`, a free-form
role of the declaration in the link; `(part := "a")` for part (a) of an exercise. A last string is a
comment: `@[cite ladr4e "1.3" (rel := hasPart) "associativity"]`.

Lean elaborates an `example` and then discards it, together with what an attribute recorded about
it. `@[cite]` on an `example` is therefore an error; write `cite src "id" in` before it instead.

### Proof steps

A step is marked by wrapping the Lean that carries it out:

| Write | Marks |
|---|---|
| `cite src "id" step k =>` and an indented block of tactics | the tactics |
| `cite src "id" step k in` and a term | the term, such as a `calc` |
| `cite src "id" (statement := k) in` before a declaration | its statement, for a step that the binders, hypotheses and type carry out, such as a proof's opening "Suppose …" |
| `cite src "id" (step := k) in` before a declaration | the whole declaration, such as a helper lemma that carries out the step |

- A relation can end the head (`step 2 closeMatch =>`), or go in `(rel := closeMatch)` before a
  declaration.
- A wrapper leaves the proof term unchanged, apart from the numbers inside inaccessible names, and
  the position a `sorry` records if the wrapper moves it. The tactics in a tactic wrapper are
  indented under it, so wrapping a block shifts its lines.
- Steps of one entry with one relation can share a wrapper: `step 2 4`. Other steps carried out by
  the same lines take wrappers nested directly inside each other, which all mark the innermost
  body.
- Before a declaration, the lines start at its keyword, after any docstring, attributes,
  modifiers, `open … in` and `set_option … in`.
- A step is recorded apart from any citation. The declaration that holds it need not cite the
  step's entry, so a helper lemma can carry a step of 3.21. The step's Lean end names the
  declaration that holds its lines.

Where a wrapper cannot go, a comment marks the step:

```lean
  -- cite ladr4e "1.45" step 4 exactMatch
  have hzero : u - v = 0 := by
    apply (h _).mp
  -- cite end
```

The range starts at the first line after the marker that is not blank, so a comment on the step
belongs to it, and must include the first line of code after the marker. It ends before the next
marker or `-- cite end`, or before the next line of code indented less than the marker. A marker in
the first column ends instead before the next line of code in the first column, usually the next
command. `Cite/Steps.lean` states the grammar and the rule exactly.

Use a comment for:

- lines that are only part of some syntax, such as a `have` and the first line of its proof;
- a step whose lines cross another step's;
- a step inside an `example`, a `recall`, a `#`-command or `decreasing_by`, whose environment Lean
  discards with what a wrapper recorded;
- a step inside an autoParam (`(h : p := by …)`), whose tactic Lean runs where the argument is
  left out, not where it is written.

## What Lean checks

`@[cite]`, `cite … in` and the wrappers are checked as they elaborate.

| Mistake | Reported |
|---|---|
| unknown source, misspelled relation or option, a field or option given twice | an error where it is written |
| a citation the module already made | an error |
| `cite src "id" in`, without `step` or `statement`, before a declaration that has a name | a warning: write `@[cite]`, which records the name |
| a wrapper that recorded no step (in an `example`, `decreasing_by`, a branch that failed, …) | a warning of `linter.cite.wrappers` |

Comment markers are checked by `linter.cite.steps`, with warnings for a marker that does not parse,
marks no code, cites an unknown source, or runs outside its command. Warnings do not fail the
build. `set_option linter.cite.steps false` and `set_option linter.cite.wrappers false` turn the
linters off.

## Exporting

`#cite_export "out.json" Root₁ Root₂ …` writes:

- every source and every citation in the environment;
- the steps marked in the modules named `Rootᵢ` or `Rootᵢ.…`, by wrappers and by comments;
- the cross-references of Mathlib's attributes (`@[stacks]`, `@[kerodon]`, `@[wikidata]`, …),
  when Mathlib is imported, on Mathlib's declarations and the project's.

After `lake build`, run it with `lake env lean` from a file that imports what it should see and
does not start with `module`.

`scripts/cite_ll.py` turns that JSON into Literature Links:

```sh
python3 scripts/cite_ll.py out.json --project <repository URL> --commit <sha> \
  [--mathlib-commit <sha>] [--lean-repo <module prefix>=<URL>@<sha> …] \
  [--layout layout.json [--strict]] --out annotations/
```

- It writes one `<source>.jsonl` per cited source, with an annotation for each citation and each
  proof step, and `mathlib.jsonl` for Mathlib's cross-references. Each annotation is complete on
  its own, and a file is written only when it has one.
- A Lean end names the repository and commit of its module: the project's for modules under the
  export's roots, Mathlib's with `--mathlib-commit`, another with `--lean-repo`. A module of no
  known repository is left out, with a message.
- A web database's entry gets its own address and an identifier. A book's entry needs its place on
  the page, which the tags cannot know. Without a layout, the end is the whole document, titled
  with the entry. A layout is a JSON file, written by hand or by any tool that knows where entries
  sit on the page. It maps a source's name to its entries, and an entry such as `"3.21"` or
  `"3.21 proof, step 2"` to `{"subject": [ends], "kind": …, "status": …}`; `cite_ll.py --help` has
  the details. `examples/ladr/layout_from_annotations.py` writes one from existing annotations.
- A layout is also the only check of a tag against the book. Each entry it lacks, such as a
  mistyped item or a step past the end of its proof, is named on stderr and linked to the whole
  document. With `--strict` it is an error, and nothing is written.

## Limits and design notes

- **`cite` is a keyword** wherever the package is imported, as `stacks` is wherever Mathlib is. A
  command cannot start with a non-reserved word, and `cite … in` must.
- **Wrapping a declaration** makes it an inner command, so linters that look only at top-level
  commands, such as `linter.missingDocs`, skip it. Mathlib's `linter.style.multiGoal` warns about
  a wrapper around a `·` block while another goal is open.
- **A citation is recorded even when its proof fails.** Proofs are elaborated asynchronously, after
  the citation is recorded.
- **`@[cite]` does not touch docstrings**; its links reach readers through `#cite_export`. Lean
  writes a declaration's docstring after compiling it, replacing what an attribute appended before
  then. Mathlib's cross-reference attributes append their links that way, so they lose them on
  documented declarations. This was checked at Mathlib `5450b53` and at a Mathlib of 2026-10-21.
- **Line numbers are Lean's.** Lines end at line feeds. Literature Links also ends a line at a lone
  carriage return, so in a file with one, later lines are numbered one less here than there.
- **How wrappers record.** A wrapper records its lines while the proof is elaborated, often in a
  task of its own. An environment extension in mode `.sync` keeps what such tasks add, and Lean
  saves it. A linter cannot record anything, since Lean runs linters under `withoutModifyingEnv`
  or in a separate task. Comment markers are therefore read from the source by the export.
- **Mathlib's cross-references** are read through Mathlib's own API, by evaluating a term, so the
  package does not depend on Mathlib. Mathlib's attribute has had four layouts, and each has a
  term; the first that elaborates is used:

  | Mathlib | Extension | Address and name |
  |---|---|---|
  | to 2026-05-12 | `Mathlib.StacksTag.tagExt` | Stacks or Kerodon |
  | 2026-05-13 to 07-03 | `Mathlib.CrossRef.tagExt` | `databaseURL db ++ tag`; the name is the label's first word |
  | 2026-07-04 to 08-31 | `Mathlib.CrossRef.tagExt` | `db.url ++ tag`, `db.shortName` |
  | from 2026-09-01 (v4.34.0) | `Mathlib.CrossRef.tagExt` | `db.url tag`, `db.shortName` |

  When the extension is imported but no term fits, the export warns and leaves Mathlib out.
  `CiteTest/Mathlib/` tests each layout on a copy of its API. Each was also read from a real
  Mathlib: v4.30.0-rc2 (Rado's), v4.31.0's attribute file built alone, v4.32.0,
  v4.33.1 and v4.35.0.
- **Cost.** The comment-marker linter reads each command's lines and those up to the next command.
  A file of 1,500 documented theorems with a marker each (6,004 lines) elaborates in 0.67 s with it
  and 0.57 s without.

## License

Apache License 2.0; see [LICENSE](LICENSE).

Some files come from other projects, also under Apache 2.0, and keep their notices:

- `CiteTest/Mathlib/` holds excerpts of Mathlib's cross-reference attribute files, © 2024 Damiano Testa.
- A few short Lean examples, in this README, in the docstrings of `Cite/Steps.lean` and
  `Cite/StepSyntax.lean`, and in `examples/ladr/`, come from Rado Kirov's
  [linear-algebra-done-right-lean](https://github.com/rkirov/linear-algebra-done-right-lean), whose
  README declares Apache-2.0.

`examples/ladr/out/` records facts about Sheldon Axler's *Linear Algebra Done Right*, 4th edition
(© 2024 Sheldon Axler, CC BY-NC 4.0): item numbers, short item titles, pages and positions on the
page. It quotes none of the book's text.

## Files

| Path | What |
|---|---|
| `Cite/Basic.lean` | sources, citations, steps, and the environment extensions that hold them |
| `Cite/Attribute.lean` | `cite_source`, `@[cite]`, `cite … in` with its `(step := k)` and `(statement := k)` forms, `#cite_tags` |
| `Cite/StepSyntax.lean` | the tactic and term wrappers, and `linter.cite.wrappers` |
| `Cite/Steps.lean` | the comment markers: their scanner and `linter.cite.steps` |
| `Cite/Export.lean` | `#cite_export`, and the reader of Mathlib's cross-references |
| `CiteTest/` | the tests: `lake build CiteTest`. `scan_cases.json` is the scanner's corpus; `Mathlib/` has a copy of each layout of Mathlib's cross-reference API; `SameTerm.lean` checks that a wrapper leaves the proof term unchanged |
| `scripts/cite_ll.py` | the converter to Literature Links |
| `examples/ladr/` | the test on *Linear Algebra Done Right*: the scripts that tag it and check the tags against its annotations, and their outputs. `test_cite_scan.py` and `test_cite_ll.py` need nothing outside this repository |
| `.github/workflows/ci.yml` | CI: `lake build Cite CiteTest`, then both Python tests |
