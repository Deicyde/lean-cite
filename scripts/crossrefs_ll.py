#!/usr/bin/env python3
"""Write Literature Links 1.0 annotations from Mathlib's cross-reference export.

    crossrefs_ll.py crossrefs.json --out <file.jsonl>

`crossrefs.json` is what Mathlib's `scripts/export_crossrefs.lean` writes, and what
leanprover-community/crossref-exports publishes after each build of Mathlib's `master`. Each
reference must carry its `url` and `label`. Each reference becomes one annotation, from the database
entry (an `html` end with its identifier) to the declaration in Mathlib at the export's commit. The
reference's comment becomes the note. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MATHLIB = "https://github.com/leanprover-community/mathlib4"


def annotations(export: dict) -> list[dict]:
    """One annotation per reference, in the export's order."""
    commit = export.get("commit", "")
    if len(commit) != 40:
        sys.exit(f"the export's commit {commit!r} is not a full commit")
    out = []
    for entry in export["entries"]:
        location = {"declaration": entry["decl"], **({"module": entry["module"]} if entry.get("module") else {})}
        for ref in entry["refs"]:
            if "url" not in ref or "label" not in ref:
                sys.exit(f"{entry['decl']}: a reference without `url` and `label`; export it with a Mathlib whose "
                         "export_crossrefs.lean writes them")
            out.append({
                "id": f"{ref['db']}:{ref['id']}", **({"note": ref["comment"]} if ref.get("comment") else {}),
                "subject": [{"type": "html", "uri": ref["url"], "title": f"{ref['label']} {ref['id']}",
                             "identifiers": {ref["db"]: ref["id"]}}],
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
