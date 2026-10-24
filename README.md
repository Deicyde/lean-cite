# cite

Tags in Lean source that say which entry of a book, article or database a declaration
formalizes, and an exporter that turns them into
[Literature Links](https://github.com/mathlib-initiative/literature-links) 2.0 annotations.
It also reads the cross-references of Mathlib's own attributes (`@[stacks]`, `@[kerodon]`,
`@[wikidata]` and the rest).

A prototype, kept locally. It depends on Lean core only, and builds with Lean 4.30.0-rc2 and
4.36.0-rc1.

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

- `cite_source` declares a source. Any project declares its own, beside those of the projects it
  imports. Two modules that do not import each other can declare the same name. Citing that name
  is then an error that names both modules, and so is `#cite_export` when some citation or marker
  uses it.
- A source's fields are free-form, for exporters. A `uri` containing `{id}` is a template for each
  entry's address, as for a web database. `type` is the Literature Links type of its ends.
  `registry` is its key in Literature Links `identifiers`.
- `@[cite src "id"]` records that a declaration formalizes an entry. The options are
  `(rel := …)`, one of the Literature Links relations; `(role := …)`; and `(part := "a")`. A last
  string is a comment. `attribute [cite …] n` tags a declaration of another project, such as one
  of Mathlib's.
- `cite src "id" in cmd` tags a command that has no name of its own: an `example`, a `recall`, an
  unnamed `instance`. Lean elaborates an `example` and then discards it, together with what an
  attribute on it recorded, so `@[cite]` on an `example` is an error that points here.
  - The form records the lines of the command, from its keyword, after any docstring, attributes,
    modifiers, `open … in` and `set_option … in`.
  - A command cannot start with a non-reserved word, so `cite` becomes a keyword wherever the
    package is imported, as `stacks` and `kerodon` are wherever Mathlib is.
  - A proof is elaborated asynchronously, so its errors come after the citation is recorded. A
    citation is therefore recorded even when its command fails, as with `@[cite]`.
- `-- cite src "id" step k₁ k₂ … [relation]` marks the lines that carry out steps of a proof.
  - A marker is a line comment alone on its line, outside block comments, docstrings and strings.
  - The range starts at the next line of code. It ends before the next marker or `-- cite end`,
    or before the first line of code indented less than the marker. A marker in the first column
    ends before the next line of code in the first column, which is usually the next command.
  - `Cite/Steps.lean` states the grammar and the rule exactly.
- `#cite_tags [src]` lists the citations, imported ones included.
- `#cite_export "out.json" Root…` writes, as JSON:
  - the sources and the citations;
  - the step markers in the modules under each `Root`;
  - the cross-references of Mathlib's attributes.

  Run it with `lake env lean` from a file that imports what it should see and does not start
  with `module`.

A tactic cannot mark a declaration's statement or a term-mode `calc`. In chapter 1 of *Linear
Algebra Done Right*, 28 of the 45 Lean ranges of proof steps start at a statement or in term mode.
Lean 4.30 runs linters under `withoutModifyingEnv` or in a separate task, so a linter cannot record
what it reads either. Step markers are therefore comments, which `#cite_export` reads from the
source, and the linter `linter.cite.steps` only checks them while a file compiles. It reports:

- markers that do not parse, and markers that mark no code;
- sources that are not declared;
- ranges that run outside their command.

The linter reads each command's lines and those up to the next command. A file of 1,500
documented theorems with a marker each (6,004 lines) elaborates in 0.67 s with the linter and
0.57 s without. Indented in a namespace, it takes 0.76–0.79 s and 0.57–0.58 s.

Lean writes a declaration's own docstring after compiling it, and that write replaces what an
attribute appended before elaboration. Mathlib's cross-reference attributes append their links
then: inline in `@[stacks]` at Mathlib `5450b53`, through `addCrossRefDoc` since May 2026. So
Mathlib's link is lost on any declaration that has a docstring. This was checked with `@[stacks …]`
at Mathlib `5450b53` (Lean 4.30.0-rc2), and with `@[stacks …]` and `@[wikidata …]` at a Mathlib of
2026-10-21 (Lean 4.36.0-rc1). Mathlib's own test tags only an undocumented declaration. `@[cite]`
leaves docstrings alone, and links come from the exporter.

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
  [--mathlib-commit <sha>] [--lean-repo <module prefix>=<URL>@<sha> …] \
  [--layout layout.json] --out annotations/
```

The output is one `<source>.jsonl` per cited source and, when some cross-reference's repository
is known, `mathlib.jsonl`. Each annotation is whole, and identical ones are written once. Line
numbers are Lean's: lines end at line feeds. Literature Links also ends a line at a lone carriage
return, so in a file that has one, later lines are numbered one less here than there.

- A declaration's end names the repository of its module. Modules under the export's roots are the
  project's; Mathlib's are Mathlib's with `--mathlib-commit`; others need `--lean-repo` or are
  left out, with a message.
- A templated source's entry becomes an end at its own address, `html` unless the source gives a
  `type`, with the entry as an identifier.
- A book's entry needs its place on the page, which tags cannot know. `--layout` supplies it from
  the book's layout tooling, with each entry's kind and status. Without a layout, the end is the
  whole document, with the entry as its title.

## Files

| Path | What |
|---|---|
| `Cite/Basic.lean` | sources, citations, the environment extensions |
| `Cite/Attribute.lean` | `cite_source`, `@[cite]`, `cite … in`, `#cite_tags` |
| `Cite/Steps.lean` | the step-marker scanner and its linter |
| `Cite/Export.lean` | `#cite_export` and the reader of Mathlib's tags |
| `CiteTest/` | tests (`lake build CiteTest`); `scan_cases.json` is the scanner's corpus |
| `scripts/cite_ll.py` | the Literature Links exporter |
| `examples/ladr/` | chapter 1 of *Linear Algebra Done Right*, tagged and compared with its annotations |
