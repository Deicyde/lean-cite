#!/usr/bin/env python3
"""Check that cite_scan.py agrees with Cite.scan on CiteTest/scan_cases.json.

`lake build CiteTest` writes Lean's results to .lake/scan_results.json; run it first.
"""
import json
import sys
from pathlib import Path

from cite_scan import scan, split_lines

root = Path(__file__).resolve().parents[2]
cases = json.loads((root / "CiteTest" / "scan_cases.json").read_text(encoding="utf-8"))
lean = {r["name"]: r for r in json.loads((root / ".lake" / "scan_results.json").read_text(encoding="utf-8"))}
bad = 0
for case in cases:
    r = scan(split_lines("\n".join(case["lines"])))
    ours = {"markers": [{k: m[k] for k in ("line", "column", "source", "id", "steps", "rel")} for m in r["markers"]],
            "marks": [{"line": m["line"], "start": m["start"], "stop": m["stop"]} for m in r["marks"]],
            "problems": [{"line": l, "message": msg} for l, msg in r["problems"]]}
    theirs = {k: lean[case["name"]][k] for k in ("markers", "marks", "problems")}
    if ours != theirs:
        bad += 1
        print(f"{case['name']}:\n  python {json.dumps(ours, ensure_ascii=False)}\n  lean   {json.dumps(theirs, ensure_ascii=False)}")
print(f"{len(cases) - bad} of {len(cases)} cases agree")
sys.exit(1 if bad else 0)
