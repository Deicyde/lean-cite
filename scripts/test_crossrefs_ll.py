#!/usr/bin/env python3
"""Check crossrefs_ll.py on a two-entry export, with nothing outside this repository.

A declaration with two references must give two annotations. A comment must be added to the
subject's title in parentheses, as Mathlib's docstring links show it, but not a second time when
it is already parenthesized, and no annotation may have a note. Each subject must keep the reference's `db`, `id` and `comment` in its extension. A reference
with no `label` must be titled by its database, and an export whose references have no `url` must be
refused with nothing written.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

script = Path(__file__).resolve().parent / "crossrefs_ll.py"
commit = "29d0cdab4c" + "0" * 30
export = {"generated": "2026-11-12T00:00:00Z", "commit": commit, "entries": [
    {"decl": "AddAction", "module": "Mathlib.Algebra.Group.Action.Defs", "line": 117,
     "refs": [{"db": "wikidata", "id": "Q288465", "comment": "", "url": "https://www.wikidata.org/wiki/Q288465"}]},
    {"decl": "Nat.Prime", "module": "Mathlib.Data.Nat.Prime.Defs", "line": 50,
     "refs": [{"db": "oeis", "id": "A000040", "comment": "the primes", "url": "https://oeis.org/A000040",
               "label": "OEIS"},
              {"db": "wikidata", "id": "Q49008", "comment": "", "url": "https://www.wikidata.org/wiki/Q49008",
               "label": "Wikidata"}]},
    {"decl": "Subgroup.isOpen_of_mem_nhds", "module": "Mathlib.Topology.Algebra.OpenSubgroup", "line": 9,
     "refs": [{"db": "stacks", "id": "05GG", "comment": "(1)", "url": "https://stacks.math.columbia.edu/tag/05GG"}]}]}
failures = []

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    (tmp / "crossrefs.json").write_text(json.dumps(export), encoding="utf-8")
    run = subprocess.run([sys.executable, "-B", script, tmp / "crossrefs.json", "--out", tmp / "out.jsonl"],
                         capture_output=True, text=True)
    if run.returncode != 0:
        failures.append(f"exit {run.returncode}: {run.stderr}")
    else:
        rows = [json.loads(line) for line in (tmp / "out.jsonl").read_text(encoding="utf-8").splitlines()]
        if [r["id"] for r in rows] != ["wikidata:Q288465", "oeis:A000040", "wikidata:Q49008", "stacks:05GG"]:
            failures.append(f"ids: {[r['id'] for r in rows]}")
        if any("note" in r for r in rows):
            failures.append("no annotation may have a note")
        ext = "org.leanprover-community.mathlib4.crossref"
        if rows[1]["subject"][0] != {"type": "html", "uri": "https://oeis.org/A000040",
                                      "title": "OEIS A000040 (the primes)", "identifiers": {"oeis": "A000040"},
                                      "extensions": {ext: {"db": "oeis", "id": "A000040", "comment": "the primes"}}}:
            failures.append(f"subject: {rows[1]['subject']}")
        if rows[2]["subject"][0]["extensions"] != {ext: {"db": "wikidata", "id": "Q49008", "comment": ""}}:
            failures.append(f"an empty comment must be kept as empty: {rows[2]['subject'][0]}")
        if rows[3]["subject"][0]["title"] != "Stacks Tag 05GG (1)":
            failures.append(f"a parenthesized comment: {rows[3]['subject'][0]['title']!r}")
        if rows[0]["subject"][0]["title"] != "Wikidata Q288465":
            failures.append(f"a reference with no label: {rows[0]['subject'][0]['title']!r}")
        if rows[1]["object"][0] != {"type": "lean", "uri": "https://github.com/leanprover-community/mathlib4",
                                     "version": commit,
                                     "location": {"declaration": "Nat.Prime", "module": "Mathlib.Data.Nat.Prime.Defs"}}:
            failures.append(f"object: {rows[1]['object']}")

    for ref in (r for e in export["entries"] for r in e["refs"]):
        del ref["url"]
    (tmp / "old.json").write_text(json.dumps(export), encoding="utf-8")
    run = subprocess.run([sys.executable, "-B", script, tmp / "old.json", "--out", tmp / "old.jsonl"],
                         capture_output=True, text=True)
    if run.returncode == 0 or (tmp / "old.jsonl").exists():
        failures.append("an export without `url` must be refused, with nothing written")

for f in failures:
    print("FAIL", f)
print("ok" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
