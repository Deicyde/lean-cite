#!/usr/bin/env python3
"""Write one chapter's book-to-Lean links into the Lean, as `@[cite]` tags and step markers.

The links come from the companion's own exporter, which infers them from Rado Kirov's
conventions (`/-! 2.6 … -/` headers, `exercise_2A_4a` names) and its curated overrides, and from
its proof-step data. Each attribution of a declaration to an item of the chapter becomes a tag:

* a named declaration gets `@[cite ladr4e "<item>" …]`, merged into its attribute list if it has one;
* an `example`, an unnamed `instance` or a `recall` is wrapped in `cite ladr4e "<item>" … in`;
* a mathlib declaration the companion adopts gets `attribute [cite ladr4e "<item>"] <name>`.

Each proof step's Lean lines are marked in one of two ways:

* `--steps comments` (the default): a `-- cite ladr4e "<item>" step <k> <relation>` marker, placed
  so that `Cite.scan` (ported in cite_scan.py) marks those lines;
* `--steps wrappers`: a wrapper where the lines are whole syntax that a wrapper on lines of its own
  can hold (a command, its statement, a run of tactics, a term that fills its block), and a comment
  marker elsewhere. `migration-report.json` gives each range's form, and why a comment marks it.
  `--demote` names ranges to mark with comments regardless; wrap_chapter.py passes the ranges
  whose wrappers Lean showed to be wrong.

Comment ranges are checked here, against the scanner; a range it cannot reproduce is reported.
Wrapper ranges are checked by wrap_chapter.py, against what Lean records.

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

from cite_scan import classify_lines, scan

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


# --- choosing a wrapper for a step's lines ---------------------------------------------------

def indent_of(t: str) -> int:
    return len(t) - len(t.lstrip(" "))


def code_part(t: str) -> str:
    """The line without a trailing line comment."""
    return re.split(r"\s--", " " + t, maxsplit=1)[0][1:].rstrip()


def signature_end(lines: list[str], s: int, e: int) -> int | None:
    """The line where the statement of the declaration on lines s..e ends: its first `:=`, `where`
    or `|` outside brackets, so that a named argument `(x := y)` does not count."""
    depth = 0
    for i in range(s, e + 1):
        t = code_part(lines[i - 1])
        for j, ch in enumerate(t):
            if ch in "([{⟨":
                depth += 1
            elif ch in ")]}⟩":
                depth -= 1
            elif depth == 0 and (t.startswith(":=", j) or (ch == "|" and i > s)):
                return i
        if depth == 0 and re.search(r"\bwhere$", t):
            return i
    return None


def wrapper_form(lines: list[str], kinds: list[tuple], span: tuple, a: int, b: int) -> tuple[str | None, str]:
    """How to mark lines a..b of the declaration `span` = (keyword, start, end) by syntax: (`command`,
    `statement`, `tactic` or `term`, ""), or (None, why only a comment marker can)."""
    keyword, s, e = span
    code = lambda i: kinds[i - 1][0] == "code"
    if not code(a):
        return None, "starts at a comment, which a wrapper's lines leave out"
    if (a, b) == (s, e):
        return "command", ""
    sig = signature_end(lines, s, e)
    if a == s:
        if b == sig and b < e:
            return "statement", ""
        return None, ("is part of the statement" if sig is not None and b < sig
                      else "starts at the statement and runs past it")
    # Lean discards an example together with what a wrapper in its proof records
    if keyword == "example":
        return None, "inside an example"
    c = indent_of(lines[a - 1])
    if any(code(i) and indent_of(lines[i - 1]) < c for i in range(a, b + 1)):
        return None, "runs out of its block"
    if lines[a - 1].lstrip().startswith(("|", "_", ")", "]", "}", "<;>")):
        return None, "starts inside a construct, such as a calc step or a match arm"
    nxt = next((i for i in range(b + 1, e + 1) if code(i)), None)
    nxt_indent = indent_of(lines[nxt - 1]) if nxt else -1
    # the line that opens the block: the nearest above that is less indented, or a line of the
    # statement, whose continuation lines are indented more than the proof
    parent = next((i for i in range(a - 1, s - 1, -1)
                   if code(i) and (indent_of(lines[i - 1]) < c or (sig is not None and i <= sig))), None)
    if parent is None:
        return None, "has no enclosing block"
    pt = code_part(lines[parent - 1])
    tactic_opener = pt.endswith(" by") or pt.strip() == "by" or pt.lstrip().startswith(("· ", ". ")) \
        or pt.strip() in ("·", ".") or (pt.endswith("=>") and "fun " not in pt and "λ" not in pt
                                        and not pt.lstrip().startswith("conv"))
    if tactic_opener:
        # a run of sibling tactics: it ends where the block ends or the next sibling starts
        if nxt_indent > c:
            return None, "ends inside a tactic's block"
        nxt_text = lines[nxt - 1].lstrip() if nxt else ""
        if nxt_text.startswith(("|", "<;>", ")", "]", "}")) or code_part(lines[b - 1]).endswith(" with"):
            return None, "ends inside a construct that continues, such as `induction … with`"
        # `classical` acts on the tactics after it in its block; a wrapper would end its scope early
        if nxt_indent == c and any(code(i) and indent_of(lines[i - 1]) == c and
                                   code_part(lines[i - 1]).strip() == "classical" for i in range(a, b + 1)):
            return None, "holds a `classical` whose block goes on"
        return "tactic", ""
    if pt.endswith(":=") or pt.endswith("<|"):
        # a term: it fills the rest of its block, right after the line that takes it
        if nxt_indent >= c or any(code(i) for i in range(parent + 1, a)):
            return None, "is part of a term"
        return "term", ""
    return None, "is part of a term"

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--companion", type=Path, required=True)
    ap.add_argument("--original", type=Path, required=True)
    ap.add_argument("--tagged", type=Path, required=True)
    ap.add_argument("--chapter", default="1")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--steps", choices=("comments", "wrappers"), default="comments",
                    help="mark proof steps with comment markers, or with wrappers where the syntax allows")
    ap.add_argument("--demote", type=Path,
                    help="a JSON list of {file, lines, item, step} to mark with comments, not wrappers")
    args = ap.parse_args()
    sys.path.insert(0, str(args.companion / "scripts"))
    import export_annotations as ea

    files = sorted(str(p.relative_to(args.original)) for p in (args.original / "LinearAlgebraDoneRightLean").glob("*.lean"))
    lean = [ea.parse_lean(args.original, rel) for rel in files]
    _, external, *_ = ea.apply_overrides(lean, args.companion / "scripts" / "annotation_overrides.json")
    by_path = {lf.path: lf for lf in lean}
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

    forms: list[dict] = []
    demoted = {(d["file"], *d["lines"], d["item"], d["step"])
               for d in (json.loads(args.demote.read_text(encoding="utf-8")) if args.demote else [])}
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

        # how each step range is marked: by a wrapper where the syntax allows, else by a comment
        kinds, _ = classify_lines(lines)
        spans = [(d.keyword, s0, e0) for d, s0, e0 in ea.declaration_spans(args.original, by_path[rel])] \
            if rel in by_path else []
        commented: list[tuple] = []
        wraps: list[dict] = []
        groups: dict[tuple, list[int]] = collections.defaultdict(list)
        for a, b, item, k, relation in ranges.get(rel, []):
            span = min((sp for sp in spans if sp[1] <= a and b <= sp[2]),
                       key=lambda sp: sp[2] - sp[1], default=None)
            form, why = (wrapper_form(lines, kinds, span, a, b) if args.steps == "wrappers" and span
                         else (None, "comments asked for" if span else "outside any declaration"))
            if form and (rel, a, b, item, k) in demoted:
                form, why = None, "demoted: as a wrapper it did not build or recorded other lines"
            forms.append({"file": rel, "lines": [a, b], "item": item, "step": k, "form": form or "comment",
                          **({"why": why} if why else {})})
            if form is None:
                commented.append((a, b, item, k, relation))
            else:
                groups[(a, b, form, item, relation, span[1])].append(k)
        for (a, b, form, item, relation, start), ks in groups.items():
            wraps.append({"a": a, "b": b, "form": form, "item": item, "ks": sorted(ks), "rel": relation,
                          "start": start})
        # wrappers nest: of two whose lines cross, neither holding the other, the smaller is a comment
        kept: list[dict] = []
        for w in sorted(wraps, key=lambda w: w["a"] - w["b"]):
            inner = w["form"] in ("tactic", "term")
            if inner and any(o["form"] in ("tactic", "term") and w["a"] <= o["b"] and o["a"] <= w["b"]
                             and not (o["a"] <= w["a"] and w["b"] <= o["b"]) for o in kept):
                commented += [(w["a"], w["b"], w["item"], k, w["rel"]) for k in w["ks"]]
                report["steps.crossing"] += len(w["ks"])
                for f in forms:
                    if f["file"] == rel and f["lines"] == [w["a"], w["b"]] and f["item"] == w["item"]:
                        f.update(form="comment", why="crosses another wrapper")
            else:
                kept.append(w)
        shift = collections.Counter()
        headers: dict[int, list[str]] = collections.defaultdict(list)
        for w in sorted(kept, key=lambda w: (w["a"], -w["b"])):
            report[f"steps.{w['form']}"] += len(w["ks"])
            rel_opt = f" (rel := {w['rel']})" if w["rel"] else ""
            if w["form"] in ("command", "statement"):
                cmd = command_start(lines, w["start"])
                before[cmd] = [f"cite {SOURCE} {quote(w['item'])} ({w['form'] if w['form'] == 'statement' else 'step'} "
                               f":= {k}){rel_opt} in" for k in w["ks"]] + before[cmd]
                continue
            pad = " " * (indent_of(lines[w["a"] - 1]) + shift[w["a"]])
            steps_text = " ".join(map(str, w["ks"])) + (f" {w['rel']}" if w["rel"] else "")
            if w["form"] == "tactic":
                headers[w["a"]].append(f"{pad}cite {SOURCE} {quote(w['item'])} step {steps_text} =>")
                for i in range(w["a"], w["b"] + 1):
                    shift[i] += 2
            else:
                headers[w["a"]].append(f"{pad}cite {SOURCE} {quote(w['item'])} step {steps_text} in")
        report["steps.comment"] += len(commented)

        # comment markers: one group above each distinct start line, at the least indentation of the
        # range's code so that no dedent inside the range ends it. A spec is [column, text, end].
        specs: dict[int, list[list]] = collections.defaultdict(list)
        by_start: dict[int, list[tuple]] = collections.defaultdict(list)
        for a, b, item, k, relation in commented:
            by_start[a].append((a, b, item, k, relation))
        for a, group in sorted(by_start.items()):
            ends = sorted({b for _, b, *_ in group})
            col = min(indent_of(lines[i - 1]) + shift[i] for i in range(a, max(ends) + 1)
                      if lines[i - 1].strip() and not lines[i - 1].lstrip().startswith("--"))
            for end in ends:
                merged: dict[tuple, list[int]] = collections.defaultdict(list)
                for _, b, item, k, relation in group:
                    if b == end:
                        merged[(item, relation)].append(k)
                for (item, relation), ks in merged.items():
                    specs[a].append([col, f"-- cite {SOURCE} {quote(item)} step {' '.join(map(str, sorted(ks)))}"
                                          + (f" {relation}" if relation else ""), end])

        def render() -> tuple[list[str], list[int | None]]:
            out, origin = [], []
            for i, text in enumerate(edited, 1):
                for extra in before.get(i, []) + headers.get(i, []) + [" " * c + t for c, t, _ in specs.get(i, [])]:
                    out.append(extra)
                    origin.append(None)
                out.append(" " * shift[i] + text if text.strip() else text)
                origin.append(i)
                for extra in after.get(i, []):
                    out.append(extra)
                    origin.append(None)
            return out, origin

        def check() -> tuple[list[tuple], dict]:
            """The comment ranges the scanner does not reproduce, and what it gives: for each
            (item, step, relation), the set of (first, last) untagged lines, None for a line the
            tagging added."""
            out, origin = render()
            got = collections.defaultdict(set)
            for m in scan(out)["marks"]:
                for k in m["steps"]:
                    got[(m["id"], k, m["rel"])].add((origin[m["start"] - 1], origin[m["stop"] - 1], m["stop"]))
            tagged_line = {o: i + 1 for i, o in enumerate(origin) if o is not None}
            missing = [(a, b, item, k, relation) for a, b, item, k, relation in commented
                       if not any(r[:2] == (a, b) for r in got[(item, k, relation)])]
            return missing, {"got": got, "tagged_line": tagged_line}

        # close ranges that the scanner runs past their last line; where markers share a start
        # line, end each range by its marker's column instead, since `-- cite end` ends them all
        for _ in range(4):
            missing, info = check()
            if not missing:
                break
            for a, b, item, k, relation in missing:
                spec = next((x for x in specs.get(a, []) if x[2] == b), None)
                if spec is None:
                    continue
                # a column at which the range ends where it should, without breaking the others; the
                # rendered lines, wrapper heads included, decide
                before_missing = set(missing)
                col0 = spec[0]
                shared = any(x[2] > b for x in specs[a])

                def attempt(col: int) -> str:
                    """`exact`, `over` (runs past b, and nothing else breaks) or `no`, at column col."""
                    spec[0] = col
                    now, inf = check()
                    now = set(now)
                    if (a, b, item, k, relation) not in now and now <= before_missing:
                        return "exact"
                    runs = [r for r in inf["got"][(item, k, relation)] if r[0] == a]
                    if runs and now - {(a, b, item, k, relation)} <= before_missing \
                            and min(r[2] for r in runs) > inf["tagged_line"].get(b, 10**9):
                        return "over"
                    return "no"

                # the marker's own column with `-- cite end` reads best; other columns come next,
                # those to the left first, and a range sharing its start with a longer one may end
                # only by its column
                order = [col0] + list(range(col0 - 1, -1, -1)) + list(range(col0 + 1, 80))
                done = False
                if not shared and attempt(col0) == "over" and "-- cite end" not in "".join(after.get(b, [])):
                    after[b].append(" " * (indent_of(lines[a - 1]) + shift[a]) + "-- cite end")
                    spec[0], done = col0, True
                for col in order if not done else []:
                    if attempt(col) == "exact":
                        done = True
                        break
                for col in order if not done and not shared else []:
                    if attempt(col) == "over" and "-- cite end" not in "".join(after.get(b, [])):
                        after[b].append(" " * (indent_of(lines[a - 1]) + shift[a]) + "-- cite end")
                        done = True
                        break
                if not done:
                    spec[0] = col0
        missing, info = check()
        missing = [(a, b, item, k, relation, sorted((r[0], r[1]) for r in info["got"][(item, k, relation)]))
                   for a, b, item, k, relation in missing]
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
    summary = {"chapter": args.chapter, "steps": args.steps, "files": touched,
               "counts": dict(sorted(report.items())), "problems": problems, "step_forms": forms}
    (args.out / "migration-report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("problems", "step_forms")}, indent=1))
    print(f"{len(problems)} problems")
    for p in problems:
        print(" ", json.dumps(p, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
