#!/usr/bin/env python3
"""Write one chapter's book-to-Lean links into the Lean, as `@[cite]` tags and step markers.

The links come from the companion's own exporter, which infers them from Rado Kirov's
conventions (`/-! 2.6 … -/` headers, `exercise_2A_4a` names) and its curated overrides, and from
its proof-step data. Each attribution of a declaration to an item of the chapter becomes a tag:

* a named declaration gets `@[cite ladr4e "<item>" …]`, merged into its attribute list if it has one;
* an `example`, an unnamed `instance` or a `recall` is wrapped in `cite ladr4e "<item>" … in`;
* a mathlib declaration the companion adopts gets `attribute [cite ladr4e "<item>"] <name>`.

Each proof step's Lean lines get a `-- cite ladr4e "<item>" step <k> <relation>` marker, placed
so that `Cite.scan` (ported in cite_scan.py) marks those lines; where it cannot, the loss is
reported.

The tagged files are always rebuilt from the untagged ones, so the script can be rerun. It writes
`migration-report.json` and the book side of the chapter's proof steps, `book-steps.json`: what
is about the PDF (each step's lines, first words and title) and the notes, which stay outside Lean.

    migrate.py --companion <companion repo> --original <Rado's repo at 94a528c> \
        --tagged <a branch of it> --chapter 1 --out <dir>
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

from cite_scan import scan

SOURCE = "ladr4e"
SOURCES_MODULE = "LinearAlgebraDoneRightLean.Sources"
SOURCES_FILE = '''import Cite

/-!
# The sources this companion cites

{lit}`@[cite ladr4e "3.21"]` and {lit}`-- cite ladr4e "3.21" step 2` refer to items of the book as
Axler numbers them, and to exercises as {lit}`"Exercise 3B.4"`.
-/

/-- Sheldon Axler, *Linear Algebra Done Right*, 4th edition (Springer, 2024). -/
cite_source ladr4e "Linear Algebra Done Right, 4th edition"
  (type := "pdf") (uri := "https://linear.axler.net/LADR4e.pdf")
'''
# --- tags ----------------------------------------------------------------------------------

def quote(s: str) -> str:
    # neither a citation's entry in Lean nor a marker's can hold a quote; Lean's string escapes
    # are not read by the scanner
    if '"' in s or "\\" in s:
        sys.exit(f"the entry {s!r} holds a quote or a backslash")
    return f'"{s}"'


def cite_args(item: str, rel: str = "", role: str = "", part: str = "") -> str:
    opts = "".join(f" ({k} := {v})" for k, v in (("rel", rel), ("role", role)) if v)
    opts += f" (part := {quote(part)})" if part else ""
    return f"{SOURCE} {quote(item)}{opts}"


def item_of(target: tuple) -> str:
    return target[1] if target[0] == "item" else f"Exercise {target[1]}.{target[2]}"


def in_chapter(item: str, chapter: str) -> bool:
    if item.startswith("Exercise "):
        return re.match(rf"{chapter}[A-F]?\.", item.removeprefix("Exercise ")) is not None
    return item.split(".")[0] == chapter


def command_start(lines: list[str], k: int) -> int:
    """The first line (from 1) of the command whose keyword is on line k: above it, its attribute
    lines and its docstring, which ends on the line above those."""
    line = lambda i: lines[i - 1]
    i = k
    while i > 1 and line(i - 1).lstrip().startswith("@["):
        i -= 1
    if i > 1 and line(i - 1).rstrip().endswith("-/"):
        j = i - 1
        while j >= 1 and "/-" not in line(j):
            j -= 1
        if j >= 1 and line(j).lstrip().startswith("/--"):
            i = j
    return i


def attribute_block(lines: list[str], k: int) -> int | None:
    """The line (from 1) where the attribute list of the declaration on line k opens, if it has one:
    on line k itself, or ending on the line above, however its lines are laid out."""
    line = lambda i: lines[i - 1]
    if line(k).lstrip().startswith("@["):
        return k
    if k == 1 or not line(k - 1).rstrip().endswith("]"):
        return None
    i = k - 1
    while i >= 1 and line(i).strip() and not line(i).rstrip().endswith("-/"):
        if line(i).lstrip().startswith("@["):
            text = "\n".join(lines[i - 1:k - 1])
            return i if text.count("[") == text.count("]") else None
        i -= 1
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--companion", type=Path, required=True)
    ap.add_argument("--original", type=Path, required=True)
    ap.add_argument("--tagged", type=Path, required=True)
    ap.add_argument("--chapter", default="1")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    sys.path.insert(0, str(args.companion / "scripts"))
    import export_annotations as ea

    files = sorted(str(p.relative_to(args.original)) for p in (args.original / "LinearAlgebraDoneRightLean").glob("*.lean"))
    lean = [ea.parse_lean(args.original, rel) for rel in files]
    _, external, _, _ = ea.apply_overrides(lean, args.companion / "scripts" / "annotation_overrides.json")
    chapter_files = {lf.path for lf in lean if lf.section.startswith(args.chapter) and lf.section[len(args.chapter):] in ("", "A", "B", "C", "D", "E", "F")}

    # (file, keyword line) -> [cite arguments]; anonymous ones are wrapped, named ones tagged
    tags: dict[tuple[str, int], list[str]] = collections.defaultdict(list)
    named: dict[tuple[str, int], bool] = {}
    report = collections.Counter()
    for lf in lean:
        for d in lf.decls:
            if d.item is None:
                continue
            item = item_of(d.item)
            if lf.path not in chapter_files and not in_chapter(item, args.chapter):
                continue
            tags[(lf.path, d.line)].append(cite_args(item, d.relation, d.role if d.role != "key" else "", d.sub))
            named[(lf.path, d.line)] = bool(d.name) and d.keyword != "recall"
            report["tags.named" if named[(lf.path, d.line)] else f"tags.anonymous.{d.keyword}"] += 1
    adopted = [e for e in external if in_chapter(e["item"], args.chapter)]

    steps = json.loads((args.companion / "scripts" / "proof_steps.json").read_text(encoding="utf-8"))["proofs"]
    steps = [p for p in steps if in_chapter(p["item"], args.chapter)]
    # (file) -> [(a, b, item, k, relation)]
    ranges: dict[str, list[tuple]] = collections.defaultdict(list)
    for p in steps:
        for k, st in enumerate(p["steps"], 1):
            for t in st["lean"]:
                ranges[t["file"]].append((*t["lines"], p["item"], k, st["relation"]))

    touched = sorted({f for f, _ in tags} | set(ranges) | {f"LinearAlgebraDoneRightLean/Section_{e['section']}.lean" for e in adopted})
    problems = []
    for rel in touched:
        lines = (args.original / rel).read_text(encoding="utf-8").split("\n")
        before: dict[int, list[str]] = collections.defaultdict(list)   # original line -> lines inserted above it
        after: dict[int, list[str]] = collections.defaultdict(list)    # original line -> lines inserted below it
        edited = list(lines)
        for (f, k), args_list in sorted(tags.items()):
            if f != rel:
                continue
            indent = re.match(r"\s*", lines[k - 1]).group(0)
            if named[(f, k)]:
                block = attribute_block(lines, k)
                if block is not None:
                    edited[block - 1] = edited[block - 1].replace("@[", "@[" + ", ".join(f"cite {a}" for a in args_list) + ", ", 1)
                else:
                    before[k].append(indent + "@[" + ", ".join(f"cite {a}" for a in args_list) + "]")
            else:
                start = command_start(lines, k)
                before[start] = [indent + f"cite {a} in" for a in args_list] + before[start]

        # step markers: one group above each distinct start line, at the least indentation of the
        # range's code so that no dedent inside the range ends it
        by_start: dict[int, list[tuple]] = collections.defaultdict(list)
        for a, b, item, k, relation in ranges.get(rel, []):
            by_start[a].append((a, b, item, k, relation))
        for a, group in sorted(by_start.items()):
            ends = {b for _, b, *_ in group}
            if len(ends) > 1:
                problems.append({"file": rel, "line": a, "problem": f"ranges starting on one line end on different lines {sorted(ends)}"})
            b = max(ends)
            col = min(len(t) - len(t.lstrip(" ")) for t in lines[a - 1:b] if t.strip() and not t.lstrip().startswith("--"))
            merged: dict[tuple, list[int]] = collections.defaultdict(list)
            for _, _, item, k, relation in group:
                merged[(item, relation)].append(k)
            for (item, relation), ks in merged.items():
                before[a].append(" " * col + f"-- cite {SOURCE} {quote(item)} step {' '.join(map(str, sorted(ks)))}" + (f" {relation}" if relation else ""))

        def render() -> tuple[list[str], list[int | None]]:
            out, origin = [], []
            for i, text in enumerate(edited, 1):
                for extra in before.get(i, []):
                    out.append(extra)
                    origin.append(None)
                out.append(text)
                origin.append(i)
                for extra in after.get(i, []):
                    out.append(extra)
                    origin.append(None)
            return out, origin

        # close ranges that the scanner would run past their last line, then check every range
        for _ in range(3):
            out, origin = render()
            got = collections.defaultdict(set)
            for m in scan(out)["marks"]:
                a = next(o for o in origin[m["start"] - 1:] if o is not None)
                b = next(o for o in reversed(origin[:m["stop"]]) if o is not None)
                for k in m["steps"]:
                    got[(m["id"], k, m["rel"])].add((a, b))
            missing = []
            for a, b, item, k, relation in ranges.get(rel, []):
                if (a, b) in got[(item, k, relation)]:
                    continue
                runs = sorted(r for r in got[(item, k, relation)] if r[0] == a)
                if runs and runs[0][1] > b and "-- cite end" not in "".join(after.get(b, [])):
                    after[b].append(" " * (len(lines[a - 1]) - len(lines[a - 1].lstrip(" "))) + "-- cite end")
                else:
                    missing.append((a, b, item, k, relation, sorted(got[(item, k, relation)])))
            if not missing:
                break
        for a, b, item, k, relation, have in missing:
            problems.append({"file": rel, "item": item, "step": k, "want": [a, b], "got": have})
        report["markers.ranges"] += len(ranges.get(rel, []))
        report["markers.ranges_unreproduced"] += len(missing)
        report["markers.cite_end"] += sum(t.strip() == "-- cite end" for ts in after.values() for t in ts)
        for e in adopted:
            if f"LinearAlgebraDoneRightLean/Section_{e['section']}.lean" == rel:
                edited.extend([f"attribute [cite {cite_args(e['item'], e.get('relation', ''))}] "
                               f"{e['mathlib']['declaration']}", ""])
                report["tags.mathlib"] += 1
        out, _ = render()
        # the file imports the module that declares the source, after its last import
        last_import = max(i for i, t in enumerate(out) if t.startswith("import "))
        out.insert(last_import + 1, f"import {SOURCES_MODULE}")
        (args.tagged / rel).write_text("\n".join(out), encoding="utf-8")
        report["files"] += 1

    (args.tagged / "LinearAlgebraDoneRightLean" / "Sources.lean").write_text(SOURCES_FILE, encoding="utf-8")
    root = (args.original / "LinearAlgebraDoneRightLean.lean").read_text(encoding="utf-8")
    if f"import {SOURCES_MODULE}" not in root:
        root = f"import {SOURCES_MODULE}\n" + root
    (args.tagged / "LinearAlgebraDoneRightLean.lean").write_text(root, encoding="utf-8")

    book = {"about": "The book side of the chapter's proof steps: each step's lines in the proof "
                     "(`book`, as export_annotations.find_proofs reads them), first words, title and "
                     "note, and the relation of a step that no Lean carries out. The Lean side, which "
                     "lines carry out a step and how, is in the `-- cite … step` markers.",
            "proofs": [{"item": p["item"], "steps": [
                {k: v for k, v in st.items() if k != "lean" and (k != "relation" or not st["lean"])}
                for st in p["steps"]]} for p in steps]}
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "book-steps.json").write_text(json.dumps(book, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    summary = {"chapter": args.chapter, "files": touched, "counts": dict(sorted(report.items())), "problems": problems}
    (args.out / "migration-report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k != "problems"}, indent=1))
    print(f"{len(problems)} problems")
    for p in problems:
        print(" ", json.dumps(p, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
