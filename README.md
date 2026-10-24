# cite

Tags in Lean source that say which entry of a book, article or database a declaration
formalizes, and an exporter that turns them into
[Literature Links](https://github.com/mathlib-initiative/literature-links) 2.0 annotations.
It also reads Mathlib's own cross-references (`@[stacks]`, `@[kerodon]`, `@[wikidata]` and the rest).

A prototype, kept locally; it depends on Lean core only. Built and tested with Lean 4.30.0-rc2
and 4.36.0-rc1.

## In Lean

```lean
import Cite

/-- Sheldon Axler, *Linear Algebra Done Right*, 4th edition. -/
cite_source ladr4e "Linear Algebra Done Right, 4th edition"
  (type := "pdf") (uri := "https://linear.axler.net/LADR4e.pdf")

@[cite ladr4e "3.21"]
theorem finrank_ker_add_finrank_range … := …

@[cite ladr4e "1.3" (rel := hasPart) (role := helper) "associativity"]
theorem exercise_1A_2 … := …

cite ladr4e "1.14" in
example : … := …

attribute [cite ladr4e "1.33"] Submodule

theorem unique_zero (z : V) (h : ∀ v, v + z = v) : z = 0 :=
  -- cite ladr4e "1.26" step 2 exactMatch
  calc z = z + 0 := (add_zero z).symm
    _ = 0 + z := add_comm z 0
    _ = 0 := h 0
```

- `cite_source` declares a source. The registry is open: any project declares its own, beside
  those of the projects it imports. A `uri` containing `{id}` is a template for each entry's
  address, as for a web database.
- `@[cite src "id"]` records that a declaration formalizes an entry. The options are
  `(rel := …)`, one of the Literature Links relations; `(role := …)`; and `(part := "a")`. A last
  string is a comment. `attribute [cite …] n` tags a declaration of another project, such as one
  of Mathlib's.
- `cite src "id" in cmd` tags a command that has no name of its own: an `example`, a `recall`,
  an unnamed `instance`. Lean elaborates an `example` and then discards it, together with what an
  attribute on it recorded, so `@[cite]` on an `example` is an error pointing here. The form records
  the lines of the command. A command cannot start with a non-reserved word, so `cite` becomes a
  keyword wherever the package is imported, as `stacks` and `kerodon` are wherever Mathlib is.
- `-- cite src "id" step k₁ k₂ … [relation]` marks the lines that carry out steps of a proof. The
  range starts at the next line of code and ends before the next marker, before `-- cite end`, or
  before the first line of code indented less than the marker. A marker in the first column ends
  before the next line of code in the first column, where the next command starts. Consecutive
  markers share one range.
- `#cite_tags [src]` lists the citations, imported ones included.
- `#cite_export "out.json" Root…` writes the sources, the citations, the step markers in the
  modules under each `Root`, and Mathlib's cross-references, as JSON. Run it with
  `lake env lean` from a file that imports what it should see.

Step markers are comments for three reasons:

- A tactic cannot mark a statement or a term-mode `calc`. In chapter 1 of *Linear Algebra Done
  Right*, 28 of the 45 Lean ranges of proof steps start at a declaration's statement or in term
  mode.
- A proof is elaborated asynchronously, and what a tactic records there is discarded.
- A linter cannot record either: Lean 4.30 runs linters under `withoutModifyingEnv`, or in a
  separate task.

The linter `linter.cite.steps` therefore only checks the markers while a file compiles. It
reports markers that do not parse, sources that are not declared, and ranges that run outside
their command. `#cite_export` reads the markers with the same scanner.

`@[cite]` leaves docstrings alone. Lean writes a declaration's own docstring after compiling it,
and that write replaces anything an attribute appended before elaboration. Mathlib's
`addCrossRefDoc` appends then, so Mathlib's link is lost on any declaration that has a docstring.
This was checked with `@[stacks …]` at Mathlib `5450b53` (Lean 4.30.0-rc2), and with `@[stacks …]`
and `@[wikidata …]` at a Mathlib of 2026-10-21 (Lean 4.36.0-rc1). Mathlib's own test tags only an
undocumented declaration.

## Mathlib's cross-references

The package does not depend on Mathlib, so it reads Mathlib's `tagExt` through Mathlib's own API:
`#cite_export` elaborates and evaluates a term that names the extension. There is one term for
each layout Mathlib has had:

| Layout | Extension | Databases |
|---|---|---|
| `Mathlib.Tactic.StacksAttribute` | `Mathlib.StacksTag.tagExt` | Stacks and Kerodon |
| `Mathlib.Tactic.CrossRefAttribute` (May 2026 on) | `Mathlib.CrossRef.tagExt` | every database, with Mathlib's own `Database.url` |

## To Literature Links

```sh
python3 scripts/cite_ll.py out.json --project <repository URL> --commit <sha> \
  --mathlib-commit <sha> [--layout layout.json] --out annotations/
```

The output is one `<source>.jsonl` per source and `mathlib.jsonl`, each annotation valid on its
own.

- A web database's entry becomes an `html` end with its identifier.
- A book's entry needs its place on the page, which tags cannot know. `--layout` supplies it,
  from the book's layout tooling.
- Without a layout, the end is the whole document, with the entry as its title.

## Files

| Path | What |
|---|---|
| `Cite/Basic.lean` | sources, citations, the environment extensions |
| `Cite/Attribute.lean` | `cite_source`, `@[cite]`, `cite … in`, `#cite_tags` |
| `Cite/Steps.lean` | the step-marker scanner and its linter |
| `Cite/Export.lean` | `#cite_export` and the reader of Mathlib's tags |
| `CiteTest/` | tests (`lake build CiteTest`) |
| `scripts/cite_ll.py` | the Literature Links exporter |
| `examples/ladr/` | chapter 1 of *Linear Algebra Done Right*, tagged and compared with its annotations |
