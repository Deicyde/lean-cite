#!/usr/bin/env python3
"""Check cite_ll.py on the committed chapter-1 dump, with no checkout but this one.

The layout is read back from the committed links in out/generic/, whose subjects the layout
placed, so converting out/dump.json again must reproduce them byte for byte. Then a mistyped
item and a step past the end of its proof must each be named, and `--strict` must refuse to
write anything.
"""
import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
cite_ll = here.parents[1] / "scripts" / "cite_ll.py"
generic = here / "out" / "generic"
links = [json.loads(line) for line in (generic / "ladr4e.jsonl").read_text(encoding="utf-8").splitlines()]
layout = {"ladr4e": {r["id"]: {"subject": r["subject"], **{k: r[k] for k in ("kind", "status") if k in r}}
                     for r in links}}
project = "https://github.com/rkirov/linear-algebra-done-right-lean"
commit = next(e["version"] for r in links for e in r["object"] if e["uri"] == project)
mathlib = json.loads((generic / "mathlib.jsonl").read_text(encoding="utf-8").splitlines()[0])["object"][0]["version"]
failures = []


def run(dump: dict, work: Path, *extra: str) -> subprocess.CompletedProcess:
    shutil.rmtree(work / "out", ignore_errors=True)
    (work / "dump.json").write_text(json.dumps(dump, ensure_ascii=False), encoding="utf-8")
    return subprocess.run([sys.executable, "-I", cite_ll, work / "dump.json", "--project", project, "--commit", commit,
                           "--mathlib-commit", mathlib, "--layout", work / "layout.json", "--out", work / "out", *extra],
                          capture_output=True, text=True)


with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    (work / "layout.json").write_text(json.dumps(layout, ensure_ascii=False), encoding="utf-8")
    dump = json.loads((here / "out" / "dump.json").read_text(encoding="utf-8"))

    r = run(dump, work, "--strict")
    if r.returncode or any((work / "out" / n).read_bytes() != (generic / n).read_bytes()
                           for n in ("ladr4e.jsonl", "mathlib.jsonl")):
        failures.append(f"the committed dump does not reproduce out/generic/: {r.stderr.strip()}")

    typo = copy.deepcopy(dump)
    next(c for c in typo["citations"] if c["id"] == "1.4")["id"] = "1.99"
    step = next(s for s in typo["steps"] if s["id"] == "1.14")
    step["steps"] = [9]
    wanted = ["ladr4e '1.99': not in the layout", "ladr4e '1.14 proof, step 9': not in the layout"]
    r = run(typo, work)
    if r.returncode or any(w not in r.stderr for w in wanted) or json.loads(r.stdout)["unplaced"] != 2:
        failures.append(f"a mistyped item and step were not both named: {r.stderr.strip()}")
    r = run(typo, work, "--strict")
    if r.returncode == 0 or any(w not in r.stderr for w in wanted) or (work / "out").exists():
        failures.append(f"--strict wrote links with unplaced entries: exit {r.returncode}, {r.stderr.strip()}")

for f in failures:
    print(f)
print(f"{3 - len(failures)} of 3 checks pass")
sys.exit(1 if failures else 0)
