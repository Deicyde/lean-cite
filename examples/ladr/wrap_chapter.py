#!/usr/bin/env python3
"""Mark a chapter's proof steps with wrappers, with Lean as the judge of each one.

    wrap_chapter.py --companion <repo> --original <untagged repo> --tagged <a tagged copy> \
        --chapter N --out <dir>

Runs migrate.py --steps wrappers, builds the files it touched, runs #cite_export, and checks that
every wrapper recorded exactly the lines it was meant to. A wrapper that recorded other lines, or
that sits in a declaration that does not build, is demoted to a comment marker, and the loop runs
again until it changes nothing. `<out>/demoted.json` lists the demotions, with the reason.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from export_from_tags import line_map

here = Path(__file__).resolve().parent


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for a in ("--companion", "--original", "--tagged", "--out"):
        ap.add_argument(a, type=Path, required=True)
    ap.add_argument("--chapter", required=True)
    ap.add_argument("--rounds", type=int, default=5)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    demote_path = args.out / "demoted.json"
    demoted: list[dict] = json.loads(demote_path.read_text()) if demote_path.exists() else []
    for round_ in range(1, args.rounds + 1):
        demote_path.write_text(json.dumps(demoted, ensure_ascii=False, indent=1) + "\n")
        subprocess.run([sys.executable, str(here / "migrate.py"), "--companion", args.companion,
                        "--original", args.original, "--tagged", args.tagged, "--chapter", args.chapter,
                        "--out", args.out, "--steps", "wrappers", "--demote", demote_path],
                       check=True, capture_output=True)
        report = json.loads((args.out / "migration-report.json").read_text())
        mods = ["LinearAlgebraDoneRightLean.Sources"] + [f.removesuffix(".lean").replace("/", ".") for f in report["files"]]
        build = subprocess.run(["lake", "build", *mods], cwd=args.tagged, capture_output=True, text=True)
        wrappers = [f for f in report["step_forms"] if f["form"] in ("tactic", "term", "command", "statement")]
        new: list[dict] = []
        if build.returncode != 0:
            # demote every wrapper of a declaration that has an error
            errors = re.findall(r"error: (LinearAlgebraDoneRightLean/[^:]+\.lean):(\d+):", build.stdout + build.stderr)
            if not errors:
                print(build.stdout[-3000:], build.stderr[-3000:])
                return 1
            for f, line in set(errors):
                m = line_map((args.original / f).read_text().split("\n"), (args.tagged / f).read_text().split("\n"))
                orig = max((o for t, o in m.items() if t <= int(line)), default=0)
                # the wrappers nearest the error: those holding it or ending just before it
                for window in (3, 15, 60):
                    near = [w for w in wrappers if w["file"] == f
                            and w["lines"][0] - window <= orig <= w["lines"][1] + window]
                    if near:
                        break
                new += [{**{k: w[k] for k in ("file", "lines", "item", "step")}, "why": f"build error at {f}:{line}"}
                        for w in near if w not in new]
        else:
            # the export file goes under .lake, out of the repository's sight
            export = args.tagged / ".lake" / f"CiteExport{args.chapter}.lean"
            dump = (args.out / "dump.json").resolve()
            export.write_text("".join(f"import {m}\n" for m in mods) +
                              f'\n#cite_export "{dump}" LinearAlgebraDoneRightLean\n')
            subprocess.run(["lake", "env", "lean", str(export.relative_to(args.tagged))], cwd=args.tagged,
                           check=True, capture_output=True)
            steps = json.loads(dump.read_text())["steps"]
            maps: dict[str, dict[int, int]] = {}
            got = set()
            for st in steps:
                if st["form"] == "comment":
                    continue
                f = st["module"].replace(".", "/") + ".lean"
                if f not in maps:
                    maps[f] = line_map((args.original / f).read_text().split("\n"), (args.tagged / f).read_text().split("\n"))
                a, b = maps[f].get(st["lines"][0]), maps[f].get(st["lines"][1])
                for k in st["steps"]:
                    got.add((f, a, b, st["id"], k))
            for w in wrappers:
                if (w["file"], *w["lines"], w["item"], w["step"]) not in got:
                    new.append({**{k: w[k] for k in ("file", "lines", "item", "step")}, "why": "recorded other lines, or none"})
        print(f"round {round_}: build {'ok' if build.returncode == 0 else 'failed'}, "
              f"{len(wrappers)} wrappers, {len(new)} demoted")
        if not new:
            return 0
        demoted += new
    print("still demoting after the last round")
    return 1


if __name__ == "__main__":
    sys.exit(main())
