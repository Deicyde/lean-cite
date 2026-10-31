# Cross-reference link proposal

Lost `@[stacks]`, `@[wikidata]` and other cross-reference links on documented Mathlib declarations.

- [PROPOSAL.md](PROPOSAL.md): cause, tested candidates, recommendation.
- [DRAFT-POST.md](DRAFT-POST.md): draft Zulip post. Not posted.
- `patches/lean/`: apply with `git am` on Lean `v4.36.0-rc2`.
- `patches/mathlib/`: apply with `git am` on Mathlib `9c3101a274` merged with mathlib4#44898 at `4ed145dbeb`.
- `harness/`: probes, sweep scripts and result tables.

The working clones and build output (19 GB) are not here; they are in `~/Desktop/LEAN/crossref-proposal/` on Jack's Mac, whose `harness/run-candidate.sh` needs them. It caps Lean at 3 Mathlib processes and has timeouts.
