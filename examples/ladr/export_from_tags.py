#!/usr/bin/env python3
"""Run the companion's exporter with one chapter's links read from Lean tags.

The companion's exporter (`scripts/export_annotations.py` in Deicyde/linear-algebra-done-right-
companion) attributes declarations to the book's items by Rado Kirov's conventions and by curated
overrides, and reads proof steps from `proof_steps.json`. Here, for the chapter, the attributions
come only from `@[cite]` and `cite … in`, and the Lean side of the proof steps only from the
`-- cite … step` markers, all as `#cite_export` wrote them from the tagged branch. Everything else
the exporter does is unchanged: the PDF regions, labels, snippets, notes and checked absences.

The tagged branch adds lines, so the tags' line numbers are mapped back to the untagged files at
the annotations' commit, and the exporter reads those files. The output is then comparable, file
for file, with the companion's `annotations/`.

    export_from_tags.py --dump dump.json --book-steps book-steps.json --companion <repo> \
        --original <Rado's repo at 94a528c> --tagged <the tagged branch> --chapter 1 --out <dir>
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
import tempfile
from pathlib import Path

SOURCE = "ladr4e"
PACKAGE = "LinearAlgebraDoneRightLean"


def in_chapter(item: str, chapter: str) -> bool:
    if item.startswith("Exercise "):
        return re.match(rf"{chapter}[A-F]?\.", item.removeprefix("Exercise ")) is not None
    return item.split(".")[0] == chapter


def line_map(original: list[str], tagged: list[str]) -> dict[int, int]:
    """Tagged line -> original line, from 1, for the lines the tagging kept or edited in place."""
    out = {}
    sm = difflib.SequenceMatcher(None, original, tagged, autojunk=False)
    for op, a0, a1, b0, b1 in sm.get_opcodes():
        if op == "equal" or (op == "replace" and a1 - a0 == b1 - b0):
            for k in range(a1 - a0):
                out[b0 + k + 1] = a0 + k + 1
        elif op == "replace":
            # an attribute list that gained tags is one edited line among inserted ones
            sub = difflib.SequenceMatcher(None, original[a0:a1], tagged[b0:b1], autojunk=False)
            for block in sub.get_matching_blocks():
                for k in range(block.size):
                    out[b0 + block.b + k + 1] = a0 + block.a + k + 1
            for i in range(a0, a1):
                if i + 1 not in out.values():
                    j = next((b for b in range(b0, b1) if b + 1 not in out
                              and original[i].strip("@[]") in tagged[b]), None)
                    if j is not None:
                        out[j + 1] = i + 1
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dump", type=Path, required=True)
    ap.add_argument("--book-steps", type=Path, required=True)
    ap.add_argument("--companion", type=Path, required=True)
    ap.add_argument("--original", type=Path, required=True)
    ap.add_argument("--tagged", type=Path, required=True)
    ap.add_argument("--chapter", default="1")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    sys.path.insert(0, str(args.companion / "scripts"))
    import export_annotations as ea

    dump = json.loads(args.dump.read_text(encoding="utf-8"))
    path_of = lambda module: module.replace(".", "/") + ".lean"
    maps: dict[str, dict[int, int]] = {}

    def to_original(module: str) -> dict[int, int]:
        rel = path_of(module)
        if rel not in maps:
            maps[rel] = line_map((args.original / rel).read_text(encoding="utf-8").split("\n"),
                                 (args.tagged / rel).read_text(encoding="utf-8").split("\n"))
        return maps[rel]

    def span(module: str, a: int, b: int) -> tuple[int, int]:
        """The untagged lines of a tagged range. The scanner starts and ends a range on a line of
        code, so its first and last lines are lines of the untagged file, never added ones."""
        m = to_original(module)
        if a not in m or b not in m:
            sys.exit(f"{module} {a}-{b}: the range starts or ends on a line the tagging added")
        return m[a], m[b]

    cites = [c for c in dump["citations"] if c["source"] == SOURCE]
    steps = [s for s in dump["steps"] if s["source"] == SOURCE]

    # Overrides that the tags replace: those about the chapter's items or in its files. The book's
    # own overrides (displayed equations, notes on absences) stay.
    overrides = json.loads((args.companion / "scripts" / "annotation_overrides.json").read_text(encoding="utf-8"))
    chapter_files = {f"{PACKAGE}/Section_{args.chapter}{x}.lean" for x in "ABCDEF"} | \
        {f"{PACKAGE}/Chapter_{args.chapter}.lean"}
    kept = [e for e in overrides if "equation" in e or "absence" in e or
            not (in_chapter(e["item"], args.chapter) or e.get("file") in chapter_files)]
    tmp = Path(tempfile.mkdtemp(prefix="cite-ladr-"))
    (tmp / "overrides.json").write_text(json.dumps(kept, ensure_ascii=False), encoding="utf-8")

    original_apply = ea.apply_overrides
    report = {"tags.declaration": 0, "tags.lines": 0, "tags.mathlib": 0,
              "overrides.kept": len(kept), "overrides.replaced": len(overrides) - len(kept)}

    def apply_with_tags(lean, path):
        n, external, equations, absences = original_apply(lean, path)
        for lf in lean:
            templates = {}
            for d in lf.decls:
                templates.setdefault(d.line, ea.Decl(**{**d.__dict__, "item": None, "sub": "", "role": "key",
                                                        "relation": "", "method": "convention"}))
            # the chapter's links in any file, and every link in the chapter's files, come from tags
            drop = lambda d: d.item is not None and (lf.path in chapter_files or
                                                     in_chapter(d.item[1] if d.item[0] == "item" else f"Exercise {d.item[1]}.{d.item[2]}", args.chapter))
            lf.decls = [d for d in lf.decls if not drop(d)]
            lines_with = {d.line for d in lf.decls}
            lf.decls += [t for line, t in templates.items() if line not in lines_with]
            for c in cites:
                t = c["target"]
                if path_of(t.get("module", "")) != lf.path:
                    continue
                if "declaration" in t:
                    hits = [d for d in templates.values() if d.name == t["declaration"]]
                    report["tags.declaration"] += 1
                else:
                    line = to_original(t["module"]).get(t["lines"][0])
                    hits = [d for d in templates.values() if d.line == line]
                    report["tags.lines"] += 1
                if len(hits) != 1:
                    sys.exit(f"{json.dumps(c, ensure_ascii=False)} matches {len(hits)} declarations of {lf.path}")
                lf.decls.append(ea.Decl(**{**hits[0].__dict__, "item": ea._target(c["id"]), "sub": c.get("part", ""),
                                           "role": c.get("role") or "key", "relation": c.get("rel", ""),
                                           "method": "tag"}))
            lf.decls = [d for d in lf.decls if d.item is not None or not any(
                o.line == d.line and o.item is not None for o in lf.decls)]
            lf.decls.sort(key=lambda d: d.line)
        # mathlib declarations the companion adopts, tagged by `attribute [cite …]`
        external = [e for e in external if not in_chapter(e["item"], args.chapter)]
        mathlib = Path(args.original / ".lake" / "packages" / "mathlib")
        for c in cites:
            t = c["target"]
            if not t.get("module", "").startswith("Mathlib."):
                continue
            rel = path_of(t["module"])
            text = (mathlib / rel).read_text(encoding="utf-8").split("\n")
            # the declaration's keyword line: its range starts at its docstring
            line, end = t["lines"]
            if text[line - 1].lstrip().startswith("/--"):
                while not text[line - 1].rstrip().endswith("-/"):
                    line += 1
                line += 1
            while text[line - 1].lstrip().startswith("@["):
                line += 1
            statement, truncated = ea.statement_of(text, line, end + 1)
            external.append({"item": c["id"], "section": c["citedIn"].rsplit("_", 1)[-1],
                             **({"relation": c["rel"]} if c.get("rel") else {}),
                             "mathlib": {"declaration": t["declaration"], "path": rel, "line": line,
                                         "kind": t["kind"], "statement": statement, "truncated": truncated}})
            report["tags.mathlib"] += 1
        return n, external, equations, absences

    ea.apply_overrides = apply_with_tags

    # The chapter's proof steps: the book side from book-steps.json, the Lean side from markers.
    book = json.loads(args.book_steps.read_text(encoding="utf-8"))["proofs"]
    all_steps = json.loads((args.companion / "scripts" / "proof_steps.json").read_text(encoding="utf-8"))
    by_item = {p["item"]: p for p in book}
    marks: dict[tuple[str, int], list] = {}
    for s in steps:
        a, b = span(s["module"], *s["lines"])
        for k in s["steps"]:
            marks.setdefault((s["id"], k), []).append((path_of(s["module"]), a, b, s.get("rel", "")))
    proofs, unused = [], set(marks)
    for p in all_steps["proofs"]:
        if not in_chapter(p["item"], args.chapter):
            proofs.append(p)
            continue
        if p["item"] not in by_item:
            sys.exit(f"{p['item']}: a proof of the chapter that {args.book_steps} does not have")
        out = []
        for k, st in enumerate(by_item[p["item"]]["steps"], 1):
            found = sorted(marks.get((p["item"], k), []))
            unused.discard((p["item"], k))
            rels = {r for *_, r in found if r}
            if len(rels) > 1:
                sys.exit(f"{p['item']} step {k}: its markers state different relations: {rels}")
            if found and not rels:
                sys.exit(f"{p['item']} step {k}: no marker states its relation, which the exporter needs")
            relation = rels.pop() if found else st.get("relation")
            if relation is None:
                sys.exit(f"{p['item']} step {k}: no marker and no relation in the book steps")
            out.append({**{k2: v for k2, v in st.items() if k2 != "relation"},
                        "lean": [{"file": f, "lines": [a, b]} for f, a, b, _ in found], "relation": relation})
        proofs.append({"item": p["item"], "steps": out})
    if unused:
        sys.exit(f"markers for steps the book does not have: {sorted(unused)}")
    (tmp / "proof_steps.json").write_text(json.dumps({**all_steps, "proofs": proofs}, ensure_ascii=False), encoding="utf-8")
    report["steps.markers"] = len(steps)

    companion = args.companion
    sys.argv = ["export_annotations.py", "--repo", str(args.original),
                "--pdf", str(companion / ".lake" / "overlay-pdf" / "axler-ladr-4e.pdf"),
                "--commit", "94a528c13c1ba4fb342377e62299ee4288f841ab", "--retrieved", "2026-05-03",
                "--site-dir", str(companion / ".lake" / "verso"), "--out", str(args.out),
                "--overrides", str(tmp / "overrides.json"), "--proof-steps", str(tmp / "proof_steps.json"),
                *(["--report", str(args.report)] if args.report else [])]
    status = ea.main()
    print(json.dumps(report, indent=1))
    return status


if __name__ == "__main__":
    sys.exit(main())
