#!/usr/bin/env python3
"""Compare the constants of an untagged build with those of tagged builds.

Each file is what `DumpTerms.lean` writes: a line per constant, with its type and value as raw
expressions. A difference is counted under the first of these that accounts for it:

- only a `sorry`'s recorded position: a `sorry` names the line and column it is written on, as
  numbers after the module's name, so moving it changes the term;
- only hygiene numbers: the numbers after `_hyg` or `_hygCtx` in inaccessible names, which a wrapper
  shifts by using up macro scopes;
- anything else, which makes this script exit 1. So does a constant only one build has.

Usage: compare_terms.py <untagged.tsv> <tagged.tsv> [<tagged.tsv> ...]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

NUMERAL = r"\(OfNat\.ofNat\.\{0\} Nat \d+ \(instOfNatNat \d+\)\)\)"
SORRY_POSITION = re.compile(rf'(\\"Section_\w+\\"\))(?: {NUMERAL})+')
HYGIENE = re.compile(r"_hyg(?:Ctx)?\.\d+")


def load(path: str) -> dict[str, tuple[str, str]]:
    terms = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        name, type_, value = line.split("\t")
        terms[name] = (type_, value)
    return terms


def classify(a: tuple[str, str], b: tuple[str, str]) -> str:
    if a == b:
        return "identical"
    a, b = (tuple(SORRY_POSITION.sub(r"\1 POSITION", s) for s in t) for t in (a, b))
    if a == b:
        return "sorry position"
    a, b = (tuple(HYGIENE.sub("_hyg.N", s) for s in t) for t in (a, b))
    if a == b:
        return "hygiene numbers"
    return "anything else"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    untagged = load(sys.argv[1])
    print(f"{len(untagged)} constants in {sys.argv[1]}")
    ok = True
    for path in sys.argv[2:]:
        tagged = load(path)
        counts = {"identical": 0, "sorry position": 0, "hygiene numbers": 0, "anything else": 0}
        others = []
        for name in sorted(untagged.keys() & tagged.keys()):
            kind = classify(untagged[name], tagged[name])
            counts[kind] += 1
            if kind == "anything else":
                others.append(name)
        only = sorted(untagged.keys() ^ tagged.keys())
        print(path, counts, f"in one build only: {len(only)}")
        for name in others + only:
            print(f"  {name}")
        ok = ok and not others and not only
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
