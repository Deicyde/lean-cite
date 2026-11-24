#!/usr/bin/env python3
"""Write Literature Links 1.0 annotations from Mathlib's cross-reference export.

    crossrefs_ll.py crossrefs.json --out <file.jsonl>

`crossrefs.json` is what Mathlib's `scripts/export_crossrefs.lean` writes, and what
leanprover-community/crossref-exports publishes after each build of Mathlib's `master`. Each
reference must carry its `url`, which Mathlib writes since #45902. Each reference becomes one
annotation, from the database entry (an `html` end with its identifier) to the declaration in Mathlib
at the export's commit. The end's title is the text of Mathlib's docstring link: the database's
`label` if the reference has one, else its entry in `LABELS`, then the identifier, then the comment
in parentheses unless it is already parenthesized, as in `Stacks Tag 05GG (1)` for the comment `(1)`. The comment is free text that usually names a part of
the entry, so it belongs to the subject rather than to a note about the link. The end also keeps the
reference's `db`, `id` and `comment` unchanged under the extension `EXTENSION`, so the reference
can be read back exactly. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MATHLIB = "https://github.com/leanprover-community/mathlib4"
#: `Database.label` in Mathlib's CrossRefAttribute.lean, by `Database.shortName`.
LABELS = {"dlmf": "DLMF", "kerodon": "Kerodon Tag", "lmfdb": "LMFDB", "oeis": "OEIS",
          "pibase-topology": "π-Base (Topology)", "stacks": "Stacks Tag", "wikidata": "Wikidata"}
#: The extension key, on the subject end, for the reference as `crossrefs.json` has it.
EXTENSION = "org.leanprover-community.mathlib4.crossref"


def annotations(export: dict) -> list[dict]:
    """One annotation per reference, in the export's order."""
    commit = export.get("commit", "")
    if len(commit) != 40:
        sys.exit(f"the export's commit {commit!r} is not a full commit")
    out = []
    for entry in export["entries"]:
        location = {"declaration": entry["decl"], **({"module": entry["module"]} if entry.get("module") else {})}
        for ref in entry["refs"]:
            if "url" not in ref:
                sys.exit(f"{entry['decl']}: a reference without `url`; export it with a Mathlib whose "
                         "export_crossrefs.lean writes it (#45902)")
            label = ref.get("label") or LABELS.get(ref["db"], ref["db"])
            comment = ref.get("comment", "")
            # Mathlib's docstring link reads `[label id](url) (comment)`; a comment such as `(1)`,
            # already in parentheses, is not wrapped again
            shown = comment if comment.startswith("(") and comment.endswith(")") else f"({comment})"
            title = f"{label} {ref['id']}" + (f" {shown}" if comment else "")
            out.append({
                "id": f"{ref['db']}:{ref['id']}",
                "subject": [{"type": "html", "uri": ref["url"], "title": title,
                             "identifiers": {ref["db"]: ref["id"]},
                             "extensions": {EXTENSION: {"db": ref["db"], "id": ref["id"], "comment": comment}}}],
                "object": [{"type": "lean", "uri": MATHLIB, "version": commit, "location": location}]})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("export", type=Path, help="crossrefs.json")
    ap.add_argument("--out", type=Path, required=True, help="the JSONL file to write")
    args = ap.parse_args()
    rows = annotations(json.loads(args.export.read_text(encoding="utf-8")))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    print(json.dumps({"annotations": len(rows), "out": str(args.out)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
