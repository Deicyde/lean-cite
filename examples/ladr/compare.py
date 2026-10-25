#!/usr/bin/env python3
"""Compare two trees of Literature Links annotations, field by field.

    compare.py <expected annotations/> <actual annotations/> [--ignore <dotted path> …] [--json out]

Prints the files only one tree has and, for each file both have, the fields that differ, as dotted
paths. The ends of a side are compared as a set, as Literature Links reads them. Fields named with
`--ignore` (a path whose parts may be `*`) are counted apart. Exits 0 when nothing differs beyond
the ignored fields.
"""
from __future__ import annotations

import argparse
import collections
import fnmatch
import json
import sys
from pathlib import Path


def leaves(value, path=""):
    if isinstance(value, dict):
        if not value:
            yield path, {}
        for k, v in value.items():
            yield from leaves(v, f"{path}.{k}" if path else k)
    elif isinstance(value, list):
        if not value:
            yield path, []
        for i, v in enumerate(value):
            yield from leaves(v, f"{path}[{i}]")
    else:
        yield path, value


def unordered(rec):
    """The annotation with the ends of each side in a fixed order: in Literature Links the order of
    the ends on a side carries no meaning."""
    if isinstance(rec, dict):
        for side in ("subject", "object"):
            if isinstance(rec.get(side), list):
                rec[side] = sorted(rec[side], key=lambda e: json.dumps(e, sort_keys=True, ensure_ascii=False))
    return rec


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("expected", type=Path)
    ap.add_argument("actual", type=Path)
    ap.add_argument("--ignore", action="append", default=[])
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    files = lambda root: {str(p.relative_to(root)) for p in root.rglob("*.json")}
    a, b = files(args.expected), files(args.actual)
    out = {"only_expected": sorted(a - b), "only_actual": sorted(b - a), "identical": 0,
           "ignored_only": 0, "ignored": collections.Counter(), "differing": {}}
    for rel in sorted(a & b):
        x = dict(leaves(unordered(json.loads((args.expected / rel).read_text(encoding="utf-8")))))
        y = dict(leaves(unordered(json.loads((args.actual / rel).read_text(encoding="utf-8")))))
        diffs = [p for p in sorted(x.keys() | y.keys()) if x.get(p, "<absent>") != y.get(p, "<absent>")]
        if not diffs:
            out["identical"] += 1
            continue
        kept = []
        for p in diffs:
            pattern = next((g for g in args.ignore if fnmatch.fnmatchcase(p, g)), None)
            if pattern:
                out["ignored"][f"{pattern}: {x.get(p, '<absent>')} -> {y.get(p, '<absent>')}"] += 1
            else:
                kept.append({"field": p, "expected": x.get(p, "<absent>"), "actual": y.get(p, "<absent>")})
        if kept:
            out["differing"][rel] = kept
        else:
            out["ignored_only"] += 1
    summary = {"files": len(a | b), "identical": out["identical"], "only ignored fields differ": out["ignored_only"],
               "other differences": len(out["differing"]), "only in expected": len(out["only_expected"]),
               "only in actual": len(out["only_actual"]), "ignored": dict(out["ignored"])}
    print(json.dumps(summary, ensure_ascii=False, indent=1))
    for rel, kept in out["differing"].items():
        print(rel)
        for d in kept:
            print(f"  {d['field']}: {json.dumps(d['expected'], ensure_ascii=False)} -> {json.dumps(d['actual'], ensure_ascii=False)}")
    for side in ("only_expected", "only_actual"):
        for rel in out[side]:
            print(f"{side}: {rel}")
    if args.json:
        args.json.write_text(json.dumps({**summary, "differing": out["differing"], "only_expected": out["only_expected"],
                                         "only_actual": out["only_actual"]}, ensure_ascii=False, indent=1) + "\n",
                             encoding="utf-8")
    return 0 if not (out["differing"] or out["only_expected"] or out["only_actual"]) else 1


if __name__ == "__main__":
    sys.exit(main())
