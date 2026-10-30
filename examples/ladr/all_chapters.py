#!/usr/bin/env python3
"""Run the whole pipeline in wrappers mode on each chapter, one after another, in one tagged copy.

    all_chapters.py --companion <repo> --original <untagged repo> --tagged <a tagged copy> \
        --out <dir> 2 3 4 …

For each chapter: the copy's Lean files are reset to the untagged ones, wrap_chapter.py marks the
chapter (Lean judges every wrapper), export_from_tags.py feeds the dump to the companion's
exporter, and compare.py checks the result against the companion's annotations, ignoring
provenance. `<out>/summary.json` gathers, per chapter, the forms, the demotions, the comparison
and the time taken.
"""
from __future__ import annotations

import argparse
import collections
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

here = Path(__file__).resolve().parent
IGNORE = "extensions.org.mathlib-initiative.formal-companion.overlay.provenance.method"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for a in ("--companion", "--original", "--tagged", "--out"):
        ap.add_argument(a, type=Path, required=True)
    ap.add_argument("chapters", nargs="+")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    summary = {}
    for n in args.chapters:
        t0 = time.time()
        for src in (args.original / "LinearAlgebraDoneRightLean").glob("*.lean"):
            shutil.copy(src, args.tagged / "LinearAlgebraDoneRightLean" / src.name)
        shutil.copy(args.original / "LinearAlgebraDoneRightLean.lean", args.tagged / "LinearAlgebraDoneRightLean.lean")
        out = args.out / f"ch{n}"
        shutil.rmtree(out, ignore_errors=True)
        wrap = subprocess.run([sys.executable, str(here / "wrap_chapter.py"), "--companion", args.companion,
                               "--original", args.original, "--tagged", args.tagged, "--chapter", n,
                               "--out", out], capture_output=True, text=True)
        row = {"wrap": wrap.stdout.strip().splitlines(), "wrap_ok": wrap.returncode == 0}
        if wrap.returncode == 0:
            report = json.loads((out / "migration-report.json").read_text())
            row["forms"] = dict(collections.Counter(f["form"] for f in report["step_forms"]))
            row["why"] = dict(collections.Counter(f.get("why") for f in report["step_forms"] if f["form"] == "comment"))
            row["problems"] = report["problems"]
            row["demoted"] = json.loads((out / "demoted.json").read_text())
            ex = subprocess.run([sys.executable, str(here / "export_from_tags.py"), "--dump", out / "dump.json",
                                 "--book-steps", out / "book-steps.json", "--companion", args.companion,
                                 "--original", args.original, "--tagged", args.tagged, "--chapter", n,
                                 "--out", out / "annotations"], capture_output=True, text=True)
            row["export_ok"] = ex.returncode == 0
            if ex.returncode == 0:
                subprocess.run([sys.executable, str(here / "compare.py"), args.companion / "annotations",
                                out / "annotations", "--ignore", IGNORE, "--json", out / "compare.json"],
                               capture_output=True, text=True)
                cmp = json.loads((out / "compare.json").read_text())
                row["compare"] = {k: cmp[k] for k in ("identical", "only ignored fields differ",
                                                      "other differences", "only in expected", "only in actual")}
                row["differing"] = cmp["differing"]
            else:
                row["export_error"] = (ex.stderr or ex.stdout).strip().splitlines()[-3:]
        else:
            row["error"] = (wrap.stderr or wrap.stdout).strip().splitlines()[-5:]
        row["seconds"] = round(time.time() - t0)
        summary[n] = row
        (args.out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
        print(n, {k: row.get(k) for k in ("forms", "compare", "seconds")},
              {"demoted": len(row.get("demoted", []))}, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
