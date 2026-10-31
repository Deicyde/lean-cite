# Keeping cross-reference links on documented declarations

Sources: Lean `v4.36.0-rc2` (`b35cb10cf2`), Mathlib master `9c3101a274`, mathlib4#44898 at `4ed145dbeb` (open, on the maintainer queue on 2026-10-30).

## Size

`tagExt` holds 885 entries on 868 declarations. At master the attribute's link is missing from the docstring on 666 entries (649 declarations). On 3 more, the link shows and hides the declaration's Verso docstring, and #44898 turns these into the first kind. So 669 of 885 entries are affected, and 216 work.

## Cause

1. `@[stacks]` and the others run `.beforeElaboration` (`Mathlib/Tactic/CrossRefAttribute.lean:511`, called from `Lean/Elab/MutualDef.lean:256`).
2. A declaration's own docstring is written later: after compilation for a definition (`Elab/PreDefinition/Basic.lean:227`), and on the asynchronous branch for a theorem (`MutualDef.lean:1326`, through the same call).
3. That write replaces the entry: `allowOverwrite := true` at `DocString/Add.lean:364` for Markdown and `:380` for Verso. A documented declaration loses the link. An undocumented one keeps it, because nothing overwrites it.
4. Under `doc.verso` at master the attribute writes Markdown and the declaration writes Verso, so nothing is overwritten. `findInternalDocString?` reads Markdown first (`DocString/Extension.lean:206`), so the link hides the docstring. #44898 writes Verso instead, which reduces this case to step 3.

Moving the attribute to `.afterCompilation` fixes definitions, whose docstring exists by then. Theorems differ:

5. `docStringExt` and `versoDocStringExt` are `.async .asyncEnv` (`Extension.lean:129,141`). A read of an asynchronous theorem's entry goes to that theorem's branch (`Environment.lean:1746`), which started at the fork and which the main branch cannot change. `.afterCompilation` attributes run on the main branch (`MutualDef.lean:1346`).
6. A main-branch write also goes to `checked` (`Environment.lean:1687`), which becomes the `.olean`, and applies after the theorem's branch. So `modifyState` reaches importers, not the theorem's own file.

The TODO in #44898 names this: the attribute and the docstring are on two branches.

## Candidates

Each ran on #44898 merged into master, with `Elab.async` at its default. "Files" re-elaborates the 442 tagged Mathlib files with the candidate against cached oleans of their imports, then counts links through `import Mathlib`. "Own file" is `findDocString?` in the declaring file.

| | Lean diff | Mathlib diff | Files: links shown | Own file: documented theorem | Own file: tag added later | Lean tests |
|---|---|---|---|---|---|---|
| #44898 alone | | | 216 of 885 | doc | doc | |
| **C′** theorem docstring on the main branch | +9 −4, 3 files | attributes `.afterCompilation`; flip 2 expectations | 885 | doc + link | doc + link | 4469/4469 |
| **A** docstring keeps earlier text | +16 −6, 1 file | flip 2 expectations | 885 | doc + link | doc | 4560/4565 |
| **B** separate suffix extension | +30 −3, 2 files | handler rewritten; flip 3 expectations | 885 | doc + link | doc + link | 4469/4469 |
| **M2** Mathlib: tagged theorems synchronous | none | +63 −27 | 885 | doc + link | doc | not affected |
| **M1** Mathlib: `.afterCompilation` + `modifyState` | none | +42 −27 | not swept | doc | doc | not affected |

"Tag added later" means `attribute [stacks X] thm` and `to_additive (attr := stacks X)` on a source theorem (together 16 uses in a text search of Mathlib). Importers see the link under every candidate.

Every candidate's sweep compiled all 442 files. Lean test counts for B and C′ exclude Lake's tests. A's count includes them: its 5 failures are Lake tests that fail identically on unpatched Lean. The fix for lean4#15817, which can break Verso files at random, is in rc2 (backport `acc3373aa`), so no failure needed a rerun.

**C′.** `docStringExt` and `versoDocStringExt` become `.async .mainEnv`. `elabAsync` writes the docstring on the main branch right after starting the proof's task. `DocM.exec` reads the signature with `findConstVal?` instead of `Environment.constants`. Mathlib's attributes then run `.afterCompilation` with the read-then-write handler they have today.

- Reads of a theorem's docstring stop waiting for its proof.
- Each change is load-bearing. Writing before the task starts deadlocks a Verso docstring: `DocM.exec` → `Environment.constants` → `checked`, which waits for the task this thread has not started. Keeping `constants` after that fix serializes Verso-documented theorems: 20 theorems with 1 s proofs take 22.7 s, against 3.4 s unpatched and 4.5 s with `findConstVal?`.
- `{name}` and `{lean}` roles and code elements do not block (about 3.0 s on the same file). On the real Verso files with the most documented theorems, the time is unchanged within noise (1.3, 1.5 and 1.6 s against 1.4, 1.6 and 1.7 s).
- Verso docstrings on theorems now elaborate on the main thread, as they already do on definitions. A slow custom role would stall the next command. Not measured.
- Stage2 built with C′ has all 22,507 core docstrings identical to stage1.

**A.** `addMarkdownDocString` and `addVersoDocString`, which write a docstring from source syntax, put their text before any entry on the branch. `addDocStringCore` and `addVersoDocStringCore` still replace. Nothing changes for Mathlib's handler.

- Only the theorem's own branch can see both texts, at the moment it writes the docstring, and A merges there.
- Replace becomes keep for anything writing before elaboration. In Mathlib and its dependencies only `CrossRefAttribute.lean` does. Stage2 has all 22,507 core docstrings identical.
- Earlier text carrying Verso deferred checks would collide on check indices. The link text carries none.

**B.** `addDocStringSuffix` stores text in its own extension on the main branch, and `findDocString?` appends it, as it does for tactic extensions. It takes the links out of the docstring entries, so doc-gen4 sees no docstring on 191 tagged declarations (`getDocString?` returns early on `findInternalDocString?`) and needs a change for those and for Verso. That change is neither written nor tested.

**M2.** M1 plus a `@[command_elab declaration, incremental]` elaborator that sets `Elab.async false` for a tagged `theorem` and falls through otherwise. `incremental` is required: `elabCommandUsing` cancels the old snapshot before trying a non-incremental elaborator (`Elab/Command.lean:694`). A `lean --server` session confirms reuse survives. No overhead shows on three Mathlib files timed three times each. It runs on every declaration downstream, and 416 tagged theorems lose parallelism. It conflicts with #44898's handler.

**M1.** Costs the link on 182 undocumented tagged theorems in their own file, and breaks 7 expectations. That is the local branch `crossref-doc-after-compile` rebased.

**Verso role `{stacks}`...** (suggested in the Zulip thread). In a probe the link renders in the own file and importers. The tag record does not survive: `DocM.exec` runs under `withoutModifyingEnv` (`Elab/DocString.lean:231`), so `#stacks_tags` and the JSON export would lose it. Each docstring would also have to be Verso.

**Links only in `tagExt`, rendered by doc-gen4.** `tagExt` is complete, as the counts above show. doc-gen4 does not depend on Mathlib, so it needs a generic mechanism or the JSON export, and hovers lose even the 216 links that work today. Not prototyped.

## What changes in the docs

Comparing all 115,400 docstrings against master under A, C′ and M2, each change is the old text plus links, apart from M2's edit to `addCrossRefDoc`'s own docstring and these:

- 10 entries change format, as #44898 intends: 7 undocumented declarations move from Markdown to Verso, and 3 drop the Markdown link that hid a Verso docstring.
- 6 declarations have the same URL in their own text, so they now show it twice. Those manual links can be deleted.
- 10 untagged declarations under A, and 7 under C′ and M2, are aliases, `to_additive` or `reassoc` copies that copy the source's docstring and so now carry its link. Master already does this for undocumented sources.

## Recommendation

C′ removes the two-branch condition itself, so no merging is needed, every cell above is filled, and reads stop blocking. A is the fallback if the FRO would rather not move docstring writes: it is one file and needs no Mathlib code. M2 is the fallback if the FRO declines both.

- **Mathlib maintainers:** merge #44898 as it stands; A and C′ build on it. After the Lean change reaches a toolchain, flip the expectations and delete the TODO. Under C′ also change the six `applicationTime`s. Until that bump, Mathlib behaves as it does now.
- **Lean FRO:** decide between C′ and A. Sebastian Ullrich wrote #15359, which kept replacement "as metaprograms such as cross-reference attributes write them before a declaration's own docstring is added", and David Thrane Christiansen owns Verso docstrings. Lean's process expects an issue first.

## Not tested

- A full Mathlib build on any candidate. The sweeps cover only the 442 tagged files, on rc2.
- doc-gen4 output on any candidate.
- Lean's Lake tests on B and C′.
- Against Lean master. All three Lean branches apply cleanly to `b4e5cf2007`, but ran on rc2.
- The rest of `MathlibTest` beyond `CrossRefAttribute.lean`. Under A, three other docstring-sensitive tests give output identical to rc2.

## Prototypes (local, nothing pushed)

Lean, in `lean4/`: `crossref/C-doc-before-fork` (`d0d378fbda`, with `tests/elab/docStringMainBranch.lean`), `crossref/A-merge-at-source` (`48a2cb959d`, with `tests/elab/docStringKeepsEarlier.lean`), `crossref/B-suffix-ext` (`5391e99f85`). Each regression test fails on rc2 and passes on its branch.

Mathlib, in `mathlib-master/`, under `crossref-proposal/`: `for-core-C` (`0c3b0ba796`), `for-core-A` (`fe0659099b`), `for-core-B` (`b45eade4be`), `m2-sync-tagged` (`2bb8dad65b`), `m1-modifystate` (`d584adda4d`), on `pr44898-merged` (`cfd1fe327a`). The upstream test passes unchanged in `for-core-C` and `for-core-A` against their Lean branches. `for-core-B` and `m2-sync-tagged` keep the old expectations.
