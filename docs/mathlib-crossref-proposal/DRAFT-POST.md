**Draft for the #mathlib4 thread "Cross-reference attributes don't change the docstring". Not posted.**

Following up on the TODO in #44898: I tried a few ways to keep cross-reference links on documented declarations. Measured from the oleans, 669 of the 885 entries in `tagExt` will have no link after #44898.

The attribute and a theorem's docstring are on two branches because `docStringExt` is `.async .asyncEnv` and the docstring is written on the proof's branch. So I tried writing a theorem's docstring on the main branch, right after the proof's task starts, with both extensions `.async .mainEnv`, and having `DocM.exec` read the signature with `findConstVal?`. That is +9 −4 in Lean, plus moving the six attributes to `.afterCompilation`, on top of #44898.

With that, on `v4.36.0-rc2`:
- re-elaborating the 442 tagged files shows all 885 links, and each changed docstring is the old text plus links (10 entries change format, as #44898 intends);
- Lean's test suite passes, excluding the Lake tests, which I didn't run on this branch;
- stage2 has the same core docstrings as stage1;
- reading a theorem's docstring no longer waits for its proof;
- real Verso files take the same time, but Verso docstrings on theorems now elaborate on the main thread, so a slow role would stall the next command.

A smaller alternative is to have `addMarkdownDocString` and `addVersoDocString` keep any text already on the branch (+16 −6, no Mathlib code change). It also shows all 885, but `attribute [stacks X] thm` on an earlier theorem still doesn't show in that theorem's own file. A Mathlib-only version also works (elaborate tagged theorems synchronously through a `command_elab` on `declaration`), but it runs on every declaration, so I'd keep it as a last resort.

None of this needs to hold up #44898. Would the FRO take the first change, or prefer the second? I can open a Lean issue with whichever is preferred. I haven't run a full Mathlib build or doc-gen4 on these. The prototypes and tests were written with Claude.
