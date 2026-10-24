# Chapter 1 of *Linear Algebra Done Right*, tagged

The companion Deicyde/linear-algebra-done-right-companion links Axler's book to Rado Kirov's
Lean companion (rkirov/linear-algebra-done-right-lean at `94a528c`).

- Its exporter infers which declaration formalizes which item from Rado's conventions,
  `/-! 2.6 … -/` headers and `exercise_2A_4a` names, and 103 curated attributions. Those are among
  its 109 overrides; the other 6 are about the book.
- It takes proof steps from `proof_steps.json`.

Here chapter 1's links are written into the Lean instead, and exported back.

## What was done

1. `migrate.py` wrote every link of chapter 1 into the Lean, on the local branch `cite-prototype`
   (commit `0be8137`, in the worktree `~/Desktop/LEAN/linear-algebra-done-right-lean-cite`; not
   pushed). It reads the exporter's own inputs, the ones that produced the companion's
   annotations.
   - 122 named declarations got 134 `@[cite …]` tags, merged into their attribute lists. One of
     them is in Section 6A; it is linked to Exercise 1B.8.
   - 72 `example`s got 82 `cite … in`, and 16 `recall`s got 16.
   - Mathlib's `Submodule` got `attribute [cite ladr4e "1.33"] Submodule`.
   - The chapter's 34 proof steps have 45 Lean ranges, which got 44 markers and one `-- cite end`.
     One marker states two steps.

   The source is declared in a new `LinearAlgebraDoneRightLean/Sources.lean`.
2. `#cite_export` wrote `out/dump.json` from the tagged branch: 233 citations, 44 step markers,
   and the 31 Stacks tags of the Mathlib modules these files import.
3. `export_from_tags.py` ran the companion's exporter with chapter 1's attributions and step
   ranges taken only from the dump.
   - It drops the 42 overrides about chapter 1 and ignores Rado's conventions in the chapter's
     files.
   - Rado's headers still place each record in its section's folder, which is a fact about the
     book.
   - Tag lines are mapped back to the untagged files at `94a528c`, the commit the annotations pin.
4. `cite_ll.py`, the package's own exporter, wrote `out/generic/ladr4e.jsonl` and
   `out/generic/mathlib.jsonl`.
   - The PDF regions, kinds and statuses come from `out/layout.json`, which
     `layout_from_annotations.py` read from the companion's annotations. Where an item is on the
     page does not depend on what links it.
   - The Literature Links checker reports 295 annotations and 0 problems.

## Results

`compare.py` checks the files of step 3 against the companion's `annotations/`:

| | Files |
|---|---|
| identical | 3,442 |
| only `provenance.method` differs | 233 |
| any other difference | 0 |
| missing or extra | 0 |

The 233 records whose provenance changed are chapter 1's item and exercise links:

| `provenance.method` | Records |
|---|---|
| `convention` → `tag` | 191 |
| `curation` → `tag` | 19 |
| `audit` → `tag` | 22 |
| `audit` → `curation` (`Submodule`, an adopted mathlib declaration) | 1 |

Every proof step is identical, and so is every record outside chapter 1.

`compare_links.py` checks the links of step 4 against the companion's links for chapter 1. A link
is its id and relation, and each Lean end's location, role and title (an exercise's part). All 264
match: 233 item links and 31 proof steps. The chapter's 4 checked absences are not tags: one item
and 3 proof steps that no Lean carries out.

`mutate.py` damages the dump in ten ways: it deletes, moves or changes a citation's relation, role
or part, deletes the adopted mathlib link, and shifts, pads, drops or changes a step marker. Both
paths catch all ten. Each either reports a difference or refuses the dump.

## What the tags carry, and what they do not

The tags carry:

- which declaration or command formalizes which item or exercise;
- the relation, role and exercise part;
- the mathlib declarations the companion adopts;
- which Lean lines carry out each step, and the step's relation.

The book's side stays outside the Lean:

- where each item and each step is on the page;
- each step's first words and title;
- the notes;
- checked absences.

`out/book-steps.json` holds the chapter's steps without their Lean side.

The tags were generated from the exporter's own inputs. The comparison therefore shows that tags
can carry everything the annotations say about the Lean, without loss. It does not check that any
link is right. Those links were made and checked by agents, and no person has reviewed them.

## Reproduce

```sh
L=~/Desktop/LEAN
python3 migrate.py --companion $L/linear-algebra-done-right-companion \
  --original $L/linear-algebra-done-right-lean-litlinks \
  --tagged $L/linear-algebra-done-right-lean-cite --chapter 1 --out out
(cd $L/linear-algebra-done-right-lean-cite && lake build && lake env lean .lake/cite-scratch/Export.lean)
python3 export_from_tags.py --dump out/dump.json --book-steps out/book-steps.json \
  --companion $L/linear-algebra-done-right-companion \
  --original $L/linear-algebra-done-right-lean-litlinks \
  --tagged $L/linear-algebra-done-right-lean-cite --chapter 1 --out out/annotations
python3 compare.py $L/linear-algebra-done-right-companion/annotations out/annotations \
  --ignore 'extensions.org.mathlib-initiative.formal-companion.overlay.provenance.method'
python3 layout_from_annotations.py $L/linear-algebra-done-right-companion/annotations ladr4e > out/layout.json
python3 ../../scripts/cite_ll.py out/dump.json --project https://github.com/rkirov/linear-algebra-done-right-lean \
  --commit <cite-prototype's commit> --mathlib-commit 5450b53e5ddc75d46418fabb605edbf36bd0beb6 \
  --layout out/layout.json --out out/generic
python3 compare_links.py out/generic/ladr4e.jsonl $L/linear-algebra-done-right-companion/annotations \
  $L/linear-algebra-done-right-lean-litlinks $L/linear-algebra-done-right-lean-cite 1
python3 mutate.py $L/linear-algebra-done-right-companion $L/linear-algebra-done-right-lean-litlinks \
  $L/linear-algebra-done-right-lean-cite <a scratch directory>
python3 test_cite_scan.py   # after `lake build CiteTest` in the package
```

`.lake/cite-scratch/Export.lean` in the tagged worktree imports Sections 1A, 1B, 1C and 6A and runs
`#cite_export`. `migrate.py` rewrites the tagged files from the untagged ones, so rerunning it
discards hand edits. `cite_scan.py` is the step scanner in Python, which `migrate.py` uses to place
markers. `test_cite_scan.py` checks it against the Lean scanner on the package's test corpus.
