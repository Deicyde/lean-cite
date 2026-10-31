# *Linear Algebra Done Right*, tagged

A test of the package on a real book: can tags in the Lean carry all the links between a book and
its formalization that are now kept outside the Lean?

## The setting

- **The formalization** is Rado Kirov's rkirov/linear-algebra-done-right-lean, at `94a528c`, which
  Rado's README calls a Lean companion to Axler's book.
- **The companion**, in this file, is Deicyde/linear-algebra-done-right-companion at its tag
  `cite-demo-pin`, which links the two at `94a528c`. That repository's own README uses the word for
  Rado's Lean, and its `main` will move on to newer commits of Rado's. The companion's exporter writes
  `annotations/`, 3,675 [Literature Links](../../README.md#terms) files:
  - one for each pair of an item or exercise and a Lean declaration that formalizes it (2,459), so
    an item formalized by several declarations has several files;
  - one for each step of a proof (1,197);
  - one for each checked absence, an item or exercise of the PDF that nothing links (18);
  - `_defaults.json`, with what they all share: the PDF and the Lean repository's commit.

  Each says where the passage is in the PDF and which Lean formalizes it, or that none does.

The companion finds the Lean from three inputs, none of them a link written in the Lean:

- Rado's conventions, such as `/-! 2.6 … -/` section headers and names like `exercise_2A_4a`;
- 113 curated overrides: 104 attributions, the note of one checked absence, 5 that mark displayed
  equations inside other items' boxes in the PDF, and 3 titles that the PDF's text layer garbles;
- `proof_steps.json`, which splits each proof in the book into numbered steps and gives, for each,
  the Lean lines that carry it out (its *ranges*; a step may have several), or `noMatch`.

The test writes a chapter's links into the Lean as tags (see [the package README](../../README.md)).
From the tagged `Section_1B.lean`:

```lean
cite ladr4e "1.26" (statement := 1) (rel := closeMatch) in   -- its statement carries out step 1
@[cite ladr4e "1.26"]                         -- this declaration formalizes item 1.26
theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  cite ladr4e "1.26" step 2 exactMatch in     -- a wrapper: this term carries out step 2
  calc z = z + 0     := (add_zero z).symm
    _    = 0 + z     := add_comm z 0
    _    = 0         := h 0
```

From inside the proof of 1.45 in the tagged `Section_1C.lean`, a comment marker where no wrapper
fits:

```lean
  -- cite ladr4e "1.45" step 4 exactMatch
  have hzero : u - v = 0 := by
    apply (h _).mp
  -- cite end
```

The test then reads the tags back with `#cite_export`, regenerates the annotations with the
chapter's links to the Lean taken only from the tags and everything else made as before, and
compares the result with the companion's.

## Results

| Run | Steps marked by | Regenerated annotations |
|---|---|---|
| chapter 1 | comment markers | identical, apart from `provenance.method` |
| chapter 1 | wrappers, and comments where `migrate.py` places no wrapper | identical, apart from `provenance.method` |
| each chapter, 1 to 9 | wrappers, and comments where `migrate.py` places no wrapper | identical, apart from `provenance.method`, except one of the 1,561 step ranges |
| each chapter, 1 to 9 | comment markers alone | not exported through Lean (only `Section_9C` was compiled in this form, for [the failure table](#intermittent-build-failures)); `migrate.py`'s scanner finds that 67 of the 1,561 ranges would come back with other lines (0, 2, 8, 4, 16, 5, 16, 4 and 12 by chapter), and 74 with every chapter in one tree (`--chapter all`) |

- `provenance.method` records how the exporter made an item's or exercise's link: `convention`
  from Rado's conventions, `curation` or `audit` from an override. The chapter's item links now
  come from tags, and become `tag`. The exporter marks every proof step `audit`, wherever its lines
  come from, so the steps' method does not change.
- The exception is a range of 5.34 step 1 that crosses a range of step 3. Both need comment
  markers, and comment ranges cannot cross, so it loses its last line.
- Lean judged every wrapper: `wrap_chapter.py` builds the tagged files and turns into a comment any
  wrapper that sits where the build keeps failing or records lines other than its step's. In no
  chapter did it turn one. A failed build is run again before a wrapper is blamed; see
  [Intermittent build failures](#intermittent-build-failures).
- `migrate.py` rewrites each file it touches from the untagged one, so each chapter was tagged
  alone, in a copy reset to the untagged files. The whole book has never been built with its tags in
  one branch; `--chapter all` writes them, for the scanner's count above.
- On chapter 1, the package's own converter `cite_ll.py` also reproduces the Lean side of all 264
  of the companion's links (233 for items and exercises, 31 for proof steps). Ten deliberate
  mutations of chapter 1's exported tags are each caught.
- The tags were generated from the companion's own inputs. The comparison therefore shows that tags
  can carry everything the annotations say about the Lean, except where two step ranges cross and
  both need comments (once in the book). It does not check that any link is right. Those links
  were made and checked by AI agents, and no person has reviewed them.
- The tagged Lean is in the private repository
  [Deicyde/linear-algebra-done-right-lean-cite](https://github.com/Deicyde/linear-algebra-done-right-lean-cite).
  Its `main` is Rado's repository at `94a528c`, and two branches tag chapter 1:
  [`comment-markers`](https://github.com/Deicyde/linear-algebra-done-right-lean-cite/compare/main...comment-markers)
  (`a6974f1`, on the prototype commit `0be8137`) and
  [`wrappers`](https://github.com/Deicyde/linear-algebra-done-right-lean-cite/compare/main...wrappers)
  (`f5463ff`, on `d2d0b54`). The tip of each requires this package from GitHub at `2de6db2`, and
  adds `CiteExport.lean`. The rest of this file calls the two prototype commits by the local
  branch names they have on the machine where this ran, `cite-prototype` and
  `cite-prototype-wrappers`.
- The Lean ends in `out/generic/` and `out/wrappers/generic/` name Rado's repository, so that they
  compare with the companion's links, but the commits they name, `0be8137` and `d2d0b54`, exist
  only in the demo repository above. A consumer holding only Rado's repository would report those
  ends as unresolved.

## Try it

The demo builds from a fresh clone, once you can read both private repositories. The clone and the
lakefile's fetch of this package both go over HTTPS, so git needs GitHub credentials (`gh auth login`
and `gh auth setup-git`, for one).

```sh
git clone https://github.com/Deicyde/linear-algebra-done-right-lean-cite
cd linear-algebra-done-right-lean-cite
git checkout comment-markers
lake exe cache get && lake build && lake env lean CiteExport.lean
python3 .lake/packages/cite/scripts/cite_ll.py cite-export.json \
  --project https://github.com/Deicyde/linear-algebra-done-right-lean-cite \
  --commit "$(git rev-parse HEAD)" --mathlib-commit 5450b53e5ddc75d46418fabb605edbf36bd0beb6 --out links
```

For the other form, run `git checkout wrappers` and the commands after it again.

`CiteExport.lean` writes what the tags say to `cite-export.json`, and `cite_ll.py` turns that into
Literature Links. Without the book's layout, each link's subject is the whole PDF, titled with the
item, so these links say which item but not where it is on the page.

On success, `lake build` ends with `Build completed successfully (3062 jobs).`, Lean prints
`233 citations, 44 steps in 5 modules, 31 Mathlib cross-references → cite-export.json`, and
`cite_ll.py` prints `{"citations": 233, "steps": 31, "mathlib": 31, "files": ["ladr4e.jsonl", "mathlib.jsonl"]}`
with nothing on stderr. Lean's 44 counts marks, one per marker or wrapper. `cite_ll.py`'s `steps`
counts the 31 proof steps they mark; the chapter has 34, and 3 have no Lean. Its `mathlib` is
unrelated: the Stacks tags of the Mathlib modules these files import.

If `lake build` fails with `elaboration function for … has not been implemented` or
`failed to synthesize …`, run it again; see
[Intermittent build failures](#intermittent-build-failures).

## How the test runs

```
the companion's inputs: Rado's conventions, its overrides, proof_steps.json
   │  migrate.py
   ▼
Rado's Lean files, tagged ── lake build, #cite_export ──▶ out/dump.json
                                                            │
             ┌──────────────────────────────────────────────┴──────────────┐
             ▼                                                             ▼
export_from_tags.py: the companion's exporter,              cite_ll.py: this package's
the chapter's links read only from the dump                 converter to Literature Links
             │                                                             │
             ▼                                                             ▼
   regenerated annotations/                                  out/generic/ladr4e.jsonl
             │  compare.py, against the                                    │  compare_links.py, against
             ▼  companion's annotations/                                   ▼  the companion's links
```

These are the test's two paths.

- `export_from_tags.py` runs the companion's exporter without the attribution overrides for the
  chapter, and without using Rado's conventions to attribute the chapter's declarations. The
  equation and title overrides, which are about the PDF, and the absence note stay. Rado's headers still
  place each item's annotations in its section's folder (an exercise's folder is in its number), a
  fact about the book. The book side of the chapter's steps (each step's first words, title and
  note) comes from `out/book-steps.json`, which `migrate.py` writes. Tag lines are mapped back to
  the untagged files at `94a528c`, the commit the annotations pin.
- `cite_ll.py` needs to know where each item is on the page, which the tags cannot say.
  `layout_from_annotations.py` copies those regions, with each item's kind and formalization
  status, from the companion's annotations into `out/layout.json`. `compare_links.py` compares none
  of what it copies.
- `mutate.py` damages the dump in ten ways. It deletes a citation, moves one to another
  declaration, changes one's relation or role, removes one's exercise part, and deletes the link to
  Mathlib's `Submodule`. It moves a step's first line one line down, or one line up onto the line
  the tagging added above it (its marker or its wrapper's head), drops a step, and changes a step's
  relation. The unmutated dump runs first, as a control that both paths pass. Each mutation must
  then make both paths report a difference or refuse the dump.

## Chapter 1, with comment markers

`migrate.py` wrote every link of chapter 1 into the Lean, on the branch `cite-prototype`.

- 122 named declarations got 134 `@[cite …]` tags: merged into the attribute list where the
  declaration had one (24), on a new `@[…]` line otherwise (98). One of them, in Section 6A, is
  linked to Exercise 1B.8.
- 72 `example`s got 82 `cite … in`, and 16 `recall`s got 16.
- Mathlib's `Submodule`, which Rado's Lean adopts for item 1.33, got
  `attribute [cite ladr4e "1.33"] Submodule`.
- The chapter's 34 proof steps have 45 ranges, which got 44 markers and one `-- cite end`. One
  marker states two steps.
- The source is declared in a new `LinearAlgebraDoneRightLean/Sources.lean`.

`#cite_export` wrote `out/dump.json`: 233 citations, 44 step markers, and the 31 Stacks tags of
the Mathlib modules these files import.

`compare.py` checks the regenerated annotations against the companion's `annotations/`:

| | Files |
|---|---|
| identical | 3,442 |
| only `provenance.method` differs | 233 |
| any other difference | 0 |
| missing or extra | 0 |

The 233 are chapter 1's item and exercise links:

| `provenance.method` | Annotations |
|---|---|
| `convention` → `tag` | 191 |
| `curation` → `tag` | 19 |
| `audit` → `tag` | 22 |
| `audit` → `curation` (`Submodule`, an adopted Mathlib declaration, which `attribute [cite]` tags from outside) | 1 |

Every proof step is identical, and so is every annotation outside chapter 1.

`compare_links.py` checks `out/generic/ladr4e.jsonl` against the companion's links for chapter 1.
A link is its id and relation, and each Lean end's location, role and title (an exercise's part).
All 264 match. One item and 3 proof steps have no Lean that carries them out; these 4 checked
absences are not tags. `cite_ll.py` also wrote the dump's 31 Stacks tags to
`out/generic/mathlib.jsonl`. The Literature Links checker reports 295 annotations in the two files
and 0 problems.

Both tagged branches build in full (3,062 jobs each).

## Chapter 1, with wrappers

`migrate.py --steps wrappers` marks a step's lines with a wrapper where they are whole syntax that a
wrapper on lines of its own can hold, and with a comment marker elsewhere. It wrote the branch
`cite-prototype-wrappers`, on top of `cite-prototype`. The outputs are in `out/wrappers/`.

| Form | Ranges |
|---|---|
| a whole command, `cite … (step := k) in` | 21 |
| a statement, `cite … (statement := k) in` | 3 |
| a block of tactics, `cite … step k =>` | 16 |
| a term, `cite … step k in` | 3 |
| a comment marker | 2 |

A wrapper with several step numbers marks several ranges: 1.46 steps 2 and 4 share one tactic
wrapper, so 43 ranges take 42 wrappers.

In 1.32, step 2 is the function at the head of a term whose argument is step 1. In 1.45, step 4 is
a `have` and the first line of its proof, whose other lines are step 3. These two take comment
markers. A wrapper in parentheses could hold the first, but the script places wrappers only on
lines of their own. `out/wrappers/migration-report.json` gives each range's form, and why a comment
marks it.

`wrap_chapter.py` lets Lean judge each wrapper. It builds the tagged files, exports them, and turns
into a comment any wrapper that recorded other lines or sits where the build fails, until nothing
changes. For chapter 1 it changes nothing. Both comparisons give the same results as with comment
markers, and `mutate.py` again catches all ten mutations against a clean control. In Sections 1A,
1B and 1C, which hold all of the chapter's steps, the comment markers add 45 lines. The wrappers
add 46 and re-indent the 43 lines of the tactic blocks they wrap.

## The whole book

`all_chapters.py` runs `wrap_chapter.py`, `export_from_tags.py` and `compare.py` on each chapter in
turn, in one tagged copy reset to the untagged files each time. In every chapter the tagged files
build in the first round, and `wrap_chapter.py` turns no wrapper into a comment.

| Chapter | Ranges | Marked by a wrapper | Marked by a comment | Files that differ beyond provenance |
|---|---|---|---|---|
| 1 | 45 | 43 | 2 | 0 |
| 2 | 120 | 89 | 31 | 0 |
| 3 | 260 | 182 | 78 | 0 |
| 4 | 76 | 60 | 16 | 0 |
| 5 | 299 | 237 | 62 | 1 |
| 6 | 150 | 127 | 23 | 0 |
| 7 | 340 | 290 | 50 | 0 |
| 8 | 114 | 98 | 16 | 0 |
| 9 | 157 | 127 | 30 | 0 |
| all | 1,561 | 1,253 | 308 | 1 |

Of the 1,253 ranges that wrappers mark, 1,058 are tactic blocks, 93 are terms, 82 are whole
commands and 20 are statements. `migrate.py` marks the rest with comments:

| Why a comment | Ranges |
|---|---|
| ends inside a tactic's block | 105 |
| is part of a term | 74 |
| inside an `example`, where Lean discards what a wrapper records | 45 |
| runs out of its block | 19 |
| starts at the statement and runs past it | 18 |
| is part of the statement | 16 |
| ends inside a construct that continues, such as `induction … with` | 11 |
| starts inside a construct, such as a calc step | 11 |
| starts at a comment | 4 |
| crosses another wrapper | 4 |
| holds a `classical` whose block goes on | 1 |

The one difference is one of the two ranges of 5.34 step 1. It is the statement and the first line
of the proof, and a range of step 3 is that line and the next. The two ranges cross, and both need
comments; comment ranges cannot cross, so step 1's range loses its last line. With every chapter in
one tree (`--chapter all --steps wrappers`, not run through Lean), the scanner finds that same range
as the only loss, with 310 comments.

## Intermittent build failures

A build of this project can fail at random, with or without tags, because of a bug in Lean, and
pass when run again. With `doc.verso = true`, which Rado's repository sets, elaborating a module
docstring (`/-! … -/`) empties a process-wide list of scoped extensions while it runs. An
`open … in` on another thread then activates nothing, and a declaration's docstring that starts in
that window can leave the list empty for the rest of the file. This is
[leanprover/lean4#15817](https://github.com/leanprover/lean4/issues/15817). It was fixed by
[#15839](https://github.com/leanprover/lean4/pull/15839) on 2026-10-21 and backported to
v4.36.0-rc2 by [#15843](https://github.com/leanprover/lean4/pull/15843). As of 2026-10-30, no stable
release has it: the newest is v4.35.0, and this project is on v4.30.0-rc2.

Here it shows as `elaboration function for 'Matrix.«term_ᴴ»' has not been implemented`, under
`open scoped Matrix in`; in upstream's report, as `failed to synthesize Decidable p` at a
`by_cases`. Measured on 2026-10-30, at Lean v4.30.0-rc2 except where it says otherwise:

| What ran | Failed |
|---|---|
| upstream's reproducer, with neither Mathlib nor this package | 61 of 200 |
| the same, on v4.36.0-rc1 | 123 of 200 |
| the same, on v4.36.0-rc2, which has the fix | 0 of 300 |
| `Section_9C` tagged, with wrappers or comment markers | 5 of 210 |
| the same with comment markers, and probes added to the file | 4 of 700 |
| `Section_9C` with comment markers and `-DElab.async=false` | 0 of 150 |
| `Section_9C` untagged | 0 of 180 |

5 of 210 against 0 of 180 does not settle whether tags make the failure more frequent. If the two
files had one rate, all 5 failures would land on the tagged one about one time in 23, and the file
with probes failed less often than the plain tagged one, so these rates are not stable. Nor does
0 of 180 show that the untagged file is safe. The failure has also hit Rado's own Pages deploys, in builds with no lean-cite at
all: `e16d6df` at lines 512 and 513 of `Section_9C`, and apparently `682a386` in `Section_7D`, as
`failed to synthesize` for `LT 𝕜` and `PartialOrder 𝕜` under `open scoped ComplexOrder in`. Lean
Action CI passed on both commits. Those are 2 of the 34 Pages deploys since `open scoped Matrix in`
entered `Section_9C` on 2026-08-01; a third failure, `66333e1`, also failed Lean Action CI, so it is
something else.

Of the four literate builds run here, two failed in `Section_9C`, both on the `comment-markers`
branch, where that file has no tags but still imports `Cite` through `Sources`. One kept its message,
at the same two lines; the other's was overwritten. The next build on that branch passed, as did the
one on `wrappers`. No untagged literate build has run here, so these four do not compare the two.

In a failing run, a probe found the list empty (0 extensions, against 145) even though Lean had
elaborated the `section` and the `open`. The tags do not touch this list.

If a build fails like this, build again. `wrap_chapter.py` does so before it blames a wrapper. It
did not at first: in the whole-book run behind chapters 1 to 8 of `out/all-chapters-summary.json`,
this failure made it turn four wrappers of 9.66 into comments. With the rebuild added, chapter 9 was
run again; its first build failed the same way and the next passed, and its row records it.

## What the tags change in the Lean

Nothing mathematical, on chapter 1. For all 291 constants of Sections 1A, 1B, 1C and 6A, the type
and the value on each tagged branch were compared with the untagged build, as raw expressions,
binder names included:

| | Identical | Only a `sorry`'s recorded position | Only hygiene numbers | Anything else |
|---|---|---|---|---|
| `comment-markers` | 191 | 100 | 0 | 0 |
| `wrappers` | 183 | 100 | 8 | 0 |

A `sorry` records the line and column it is written on, so any edit that moves it changes the term,
comments included. The 8 differ in the numbers inside inaccessible names such as
`h._@…_hygCtx.87`, because a wrapper uses up macro scopes. `CiteTest/SameTerm.lean` checks each form
of wrapper against a plain twin on every build. [Reproduce](#reproduce) has the commands for the
table.

`example`s and `recall`s leave no constants, so these are not compared; the tags go in front of
them, and no wrapper goes inside one.

The tags do show on Rado's literate site. `lake query :literateHtml` builds on both branches, and the
pages show the `@[cite …]` attributes along with `-- cite …` lines or `cite … =>` heads, which take
up about one line per tag or step mark. A `Sources` page, from `Sources.lean`, also joins the
sidebar.

## What the tags carry, and what they do not

The tags carry:

- which declaration or command formalizes which item or exercise;
- the relation, role and exercise part;
- the Mathlib declarations Rado's Lean adopts;
- which Lean lines carry out each step, and the step's relation.

The book's side stays outside the Lean:

- where each item and each step is on the page;
- each step's first words and title;
- the notes;
- checked absences.

## Reproduce

`L` below is the directory that holds these checkouts. The block takes it to be the one above this
repository; if yours are elsewhere, set it yourself. It holds:

- `linear-algebra-done-right-companion`, the companion, checked out at its tag `cite-demo-pin`, with
  the PDF build its annotations pin at `.lake/overlay-pdf/axler-ladr-4e.pdf` (sha256 `2c79b287…63ec`, 2,795,184 bytes) and the literate
  site of `94a528c` at `.lake/verso`. Since 2026-10-30 Axler's URL serves a later build, so ask Jack
  for this one. The exporter writes the PDF's hash and size into `_defaults.json`, so with another
  build `compare.py` reports at least that file. Rado's live site is also past `94a528c`, so build
  the site at that commit with `lake query :literateHtml` and copy the folder it prints to
  `.lake/verso`. The exporter calls poppler's `pdftotext` and `pdftocairo`.
- `linear-algebra-done-right-lean-litlinks`, the untagged checkout: Rado's repository at `94a528c`,
  the `--original` of every script, with Mathlib's sources at `.lake/packages/mathlib`, which need
  not be built.
- `linear-algebra-done-right-lean-cite` and `linear-algebra-done-right-lean-cite-wrappers`, the
  tagged worktrees: the demo repository at `0be8137` and `d2d0b54`.
- `lean-cite`, this package, which those two commits require at `../lean-cite`.

`.lake/cite-scratch/Export.lean` in a tagged worktree imports Sections 1A, 1B, 1C and 6A, and
writes the dump to an absolute path in this directory. It is not in the repository; the demo's
`CiteExport.lean` is the same but for one more import, writing to `cite-export.json`.

Comment markers, chapter 1, from this directory:

```sh
L=$(cd ../../.. && pwd)
python3 migrate.py --companion $L/linear-algebra-done-right-companion \
  --original $L/linear-algebra-done-right-lean-litlinks \
  --tagged $L/linear-algebra-done-right-lean-cite --chapter 1 --out out
(cd $L/linear-algebra-done-right-lean-cite && lake build && lake env lean .lake/cite-scratch/Export.lean)
python3 export_from_tags.py --dump out/dump.json --book-steps out/book-steps.json \
  --companion $L/linear-algebra-done-right-companion \
  --original $L/linear-algebra-done-right-lean-litlinks \
  --tagged $L/linear-algebra-done-right-lean-cite --chapter 1 --out out/annotations
python3 compare.py $L/linear-algebra-done-right-companion/annotations out/annotations \
  --ignore 'extensions.org.mathlib-initiative.formal-companion.overlay.provenance.method' \
  --json out/compare.json
python3 layout_from_annotations.py $L/linear-algebra-done-right-companion/annotations ladr4e > out/layout.json
python3 ../../scripts/cite_ll.py out/dump.json --project https://github.com/rkirov/linear-algebra-done-right-lean \
  --commit "$(git -C $L/linear-algebra-done-right-lean-cite rev-parse HEAD)" \
  --mathlib-commit 5450b53e5ddc75d46418fabb605edbf36bd0beb6 \
  --layout out/layout.json --strict --out out/generic
python3 compare_links.py out/generic/ladr4e.jsonl $L/linear-algebra-done-right-companion/annotations \
  $L/linear-algebra-done-right-lean-litlinks $L/linear-algebra-done-right-lean-cite 1
python3 mutate.py $L/linear-algebra-done-right-companion $L/linear-algebra-done-right-lean-litlinks \
  $L/linear-algebra-done-right-lean-cite "$(mktemp -d)"
python3 test_cite_scan.py
python3 test_cite_ll.py
```

`test_cite_scan.py` needs `lake build CiteTest` in the package first. `test_cite_ll.py` runs
`cite_ll.py` on `out/dump.json`, with the layout read back from `out/generic`. `migrate.py` rewrites
the tagged files from the untagged ones, so rerunning it discards hand edits.

Wrappers, chapter 1: in place of `migrate.py` and the `lake` line, run

```sh
python3 wrap_chapter.py --companion $L/linear-algebra-done-right-companion \
  --original $L/linear-algebra-done-right-lean-litlinks \
  --tagged $L/linear-algebra-done-right-lean-cite-wrappers --chapter 1 --out out/wrappers
```

which builds and writes `out/wrappers/dump.json` itself. Then run the other commands with
`out/wrappers/` in place of `out/`, and `$L/linear-algebra-done-right-lean-cite-wrappers` in place of
the tagged worktree, which also sets `--commit`; give `mutate.py` the
dump `out/wrappers/dump.json` as its last argument.

The whole book: run `all_chapters.py` with the same `--companion` and `--original`, a `--tagged`
copy of the wrappers worktree without `.git` in a directory that also holds this package as
`lean-cite`, an `--out` directory, and the chapters. It writes `<out>/summary.json`;
`out/all-chapters-summary.json` gathers the rows of two such runs, without the per-chapter pass
flags: chapters 1 to 8 from one, and chapter 9 from a rerun (see
[Intermittent build failures](#intermittent-build-failures)).

The term table: in a clone of the demo, after `lake exe cache get`, on each of `main`, `comment-markers` and `wrappers` in turn,
with `$B` as the branch and `$E` as this directory, run

```sh
lake build LinearAlgebraDoneRightLean.Section_1A LinearAlgebraDoneRightLean.Section_1B LinearAlgebraDoneRightLean.Section_1C LinearAlgebraDoneRightLean.Section_6A &&
TERMS_OUT=$B.tsv lake env lean $E/DumpTerms.lean
```

and then `python3 $E/compare_terms.py main.tsv comment-markers.tsv wrappers.tsv`.

The failure table: its `Section_9C` rows ran Lean as `sample_build.sh` does, in a built checkout, at
most three at a time. Upstream's reproducer is in
[its issue](https://github.com/leanprover/lean4/issues/15817).

## Files

| Script | What it does |
|---|---|
| `migrate.py` | writes one chapter's links into the Lean, as tags and step markers |
| `wrap_chapter.py` | runs `migrate.py --steps wrappers` and lets Lean judge each wrapper |
| `all_chapters.py` | runs the wrappers pipeline on each chapter in turn |
| `export_from_tags.py` | runs the companion's exporter with the chapter's links read from the tags |
| `compare.py` | compares two trees of annotations, field by field |
| `layout_from_annotations.py` | writes the layout `cite_ll.py --layout` reads |
| `compare_links.py` | compares `cite_ll.py`'s links with the companion's, for one chapter |
| `mutate.py` | checks that both comparisons catch ten kinds of wrong tag |
| `cite_scan.py` | the step-comment scanner of `Cite/Steps.lean`, in Python, for placing markers |
| `test_cite_scan.py` | checks `cite_scan.py` against the Lean scanner on the package's corpus |
| `test_cite_ll.py` | checks `cite_ll.py` on the committed chapter 1 dump, with no checkout but this one |
| `DumpTerms.lean` | writes each constant of the files chapter 1's tags touch, with its whole type and value |
| `compare_terms.py` | classifies how those constants differ between builds |
| `sample_build.sh` | runs Lean on one module N times, as Lake runs it, and counts the failures |
