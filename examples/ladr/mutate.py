#!/usr/bin/env python3
"""Check that the comparisons notice a wrong tag: mutate out/dump.json in ten ways, and for each,
rerun both paths (export_from_tags.py with compare.py, and cite_ll.py with compare_links.py). The
unmutated dump runs first, as a control that both paths must pass.

    mutate.py <companion repo> <untagged repo> <tagged repo> <scratch dir> [<dump>]

A mutation is caught on a path when the path fails or reports a difference.
"""
import copy
import json
import subprocess
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
companion, original, tagged, scratch = map(Path, sys.argv[1:5])
# the dump of the tagged branch: out/dump.json for comment markers, out/wrappers/dump.json for wrappers
dump = json.loads((Path(sys.argv[5]) if len(sys.argv) > 5 else here / "out" / "dump.json").read_text(encoding="utf-8"))
commit = subprocess.run(["git", "-C", tagged, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
IGNORE = "extensions.org.mathlib-initiative.formal-companion.overlay.provenance.method"
# the Mathlib of the companion at 94a528c, which holds `Submodule`
MATHLIB_COMMIT = "5450b53e5ddc75d46418fabb605edbf36bd0beb6"


def cite(d, pred):
    return next(i for i, c in enumerate(d["citations"]) if pred(c))


def step(d, pred):
    return next(i for i, s in enumerate(d["steps"]) if pred(s))


def m_delete(d):
    del d["citations"][cite(d, lambda c: c["id"] == "1.4")]


def m_rel(d):
    d["citations"][cite(d, lambda c: c.get("rel") == "hasPart")]["rel"] = "relatedMatch"


def m_role(d):
    d["citations"][cite(d, lambda c: c["id"] == "1.4")]["role"] = "helper"


def m_part(d):
    d["citations"][cite(d, lambda c: c.get("part"))].pop("part")


def m_move(d):
    i = cite(d, lambda c: c["id"] == "1.4")
    j = cite(d, lambda c: "declaration" in c["target"] and c["id"] != "1.4" and "Section_1A" in c["target"].get("module", ""))
    d["citations"][i]["target"] = copy.deepcopy(d["citations"][j]["target"])


def m_shift(d):
    s = d["steps"][step(d, lambda s: s["lines"][1] > s["lines"][0])]
    s["lines"] = [s["lines"][0] + 1, s["lines"][1]]


def m_pad(d):
    # the line above a step's lines is one the tagging added: its marker, or its wrapper's header
    s = d["steps"][step(d, lambda s: s["id"] == "1.14" and 2 in s["steps"])]
    s["lines"] = [s["lines"][0] - 1, s["lines"][1]]


def m_drop_step(d):
    del d["steps"][step(d, lambda s: s["id"] == "1.26")]


def m_step_rel(d):
    d["steps"][step(d, lambda s: s.get("rel") == "exactMatch")]["rel"] = "closeMatch"


def m_submodule(d):
    del d["citations"][cite(d, lambda c: c["target"].get("declaration") == "Submodule")]


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, cwd=here)


def m_none(d):
    pass


results = {}
for name, mutate in [(f.__name__[2:], f) for f in (m_none, m_delete, m_rel, m_role, m_part, m_move, m_shift,
                                                    m_pad, m_drop_step, m_step_rel, m_submodule)]:
    d = copy.deepcopy(dump)
    mutate(d)
    work = scratch / name
    work.mkdir(parents=True, exist_ok=True)
    (work / "dump.json").write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
    a = run([sys.executable, "export_from_tags.py", "--dump", work / "dump.json", "--book-steps", "out/book-steps.json",
             "--companion", companion, "--original", original, "--tagged", tagged, "--chapter", "1",
             "--out", work / "annotations"])
    if a.returncode:
        first = "export_from_tags failed: " + a.stderr.strip().splitlines()[-1]
    else:
        c = run([sys.executable, "compare.py", companion / "annotations", work / "annotations", "--ignore", IGNORE])
        first = "compare.py found differences" if c.returncode else "NOT CAUGHT"
    g = run([sys.executable, "../../scripts/cite_ll.py", work / "dump.json", "--project",
             "https://github.com/rkirov/linear-algebra-done-right-lean", "--commit", commit,
             "--mathlib-commit", MATHLIB_COMMIT, "--layout", "out/layout.json", "--strict",
             "--out", work / "generic"])
    if g.returncode:
        second = "cite_ll failed: " + g.stderr.strip().splitlines()[-1]
    else:
        l = run([sys.executable, "compare_links.py", work / "generic" / "ladr4e.jsonl", companion / "annotations",
                 original, tagged, "1"])
        summary = json.loads(l.stdout[l.stdout.index("{"):l.stdout.index("}") + 1])
        flagged = "a range on lines the tagging added" in l.stdout
        second = ("compare_links found differences" if summary["only from tags"] or summary["only in annotations"]
                  else "compare_links flagged an added line" if flagged else "NOT CAUGHT")
    results[name] = (first, second)
    print(f"{name:10} | {first} | {second}")
# the unmutated dump is the control: both paths must find nothing there, or a catch means nothing
control = results.pop("none")
if control != ("NOT CAUGHT", "NOT CAUGHT"):
    print("the control run reports a difference, so the catches above show nothing")
    sys.exit(1)
sys.exit(1 if any("NOT CAUGHT" in r for pair in results.values() for r in pair) else 0)
