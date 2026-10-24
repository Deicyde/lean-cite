#!/usr/bin/env python3
"""Write Literature Links 2.0 annotations from what `#cite_export` read out of a Lean project.

    cite_ll.py dump.json --project <repository URL> --commit <sha> --out <dir>
        [--mathlib-commit <sha>] [--lean-repo <module prefix>=<repository URL>@<sha> …]
        [--layout layout.json]

A declaration's Lean end names the repository and commit of its module. Modules under the roots
given to `#cite_export` are the project's (`--project`, `--commit`); modules under a prefix given
with `--lean-repo`, or `Mathlib` with `--mathlib-commit`, are that repository's. A citation of a
declaration in any other module is left out, with a message.

For each source the project cites, `<out>/<source>.jsonl` holds one annotation per citation and
one per proof step:

* the subject is the source's entry. A source whose `uri` is a template with `{id}` gives each
  entry its own address (the id percent-encoded) and an identifier, keyed by the source's
  `registry` field or else its name; its ends are `html` unless the source gives a `type`. Any
  other source is the whole document, with the entry as the end's title, unless `--layout` places
  the entry. A layout is a JSON object mapping a source's name to its entries, and an entry such as
  `"3.21"` or `"3.21 proof, step 2"` to `{"subject": [ends], "kind": …, "status": …}`: what the
  book's layout tooling knows, which tags do not.
* the object is the Lean: `{declaration, module}` for a declaration; `{module, lines: [n]}` for an
  `example` or other command without a name, n being the line of its keyword, after any docstring
  and attributes; `{declaration, module, lines: [a, b]}` for the lines of a proof step.

`<out>/mathlib.jsonl` holds the cross-references of Mathlib's attributes (`@[stacks]` and the
rest), one annotation per tag on a declaration whose repository is known, from the database entry
(an `html` end with its identifier) to the declaration. A file is written only when it has an
annotation.

Line numbers are Lean's: lines end at line feeds. Literature Links also ends a line at a lone
carriage return, so in a file that has one, later lines are numbered one less here than there.

Identical annotations are written once. No folder defaults are written, so each annotation is
whole. Standard library only.
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
import urllib.parse
from pathlib import Path

LABELS = {"stacks": "Stacks Project", "kerodon": "Kerodon", "wikidata": "Wikidata", "lmfdb": "LMFDB",
          "dlmf": "DLMF", "oeis": "OEIS"}
MATHLIB = "https://github.com/leanprover-community/mathlib4"


def valid_key(key: str) -> bool:
    """An identifiers key contains no character that a Literature Links reference excludes."""
    bad = set(range(0x00, 0x21)) | set(range(0x7F, 0xA1)) | {0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
                                                              0xFEFF, 0xFFFE, 0xFFFF} \
        | set(range(0x2000, 0x200B)) | set(range(0x200B, 0x2010)) | set(range(0x202A, 0x202F)) | set(range(0x2066, 0x206A))
    return bool(key) and not any(ord(c) in bad for c in key)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dump", type=Path)
    ap.add_argument("--project", required=True, help="the project's repository URL, or a path to its checkout")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--mathlib-commit")
    ap.add_argument("--lean-repo", action="append", default=[], metavar="PREFIX=URL@SHA")
    ap.add_argument("--layout", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    dump = json.loads(args.dump.read_text(encoding="utf-8"))
    layout = json.loads(args.layout.read_text(encoding="utf-8")) if args.layout else {}
    sources = {s["name"]: s for s in dump["sources"]}
    # module prefix -> (repository, commit); an explicit --lean-repo overrides the rest
    repos = {root: (args.project, args.commit) for root in dump["roots"]}
    if args.mathlib_commit:
        repos["Mathlib"] = (MATHLIB, args.mathlib_commit)
    for spec in args.lean_repo:
        prefix, _, rest = spec.partition("=")
        url, _, sha = rest.rpartition("@")
        if not (prefix and url and sha):
            sys.exit(f"--lean-repo {spec}: expected PREFIX=URL@SHA")
        repos[prefix] = (url, sha)
    notes = collections.Counter()

    def repo_of(module: str | None) -> tuple[str, str] | None:
        if not module:
            return None
        hits = [p for p in repos if module == p or module.startswith(p + ".")]
        return repos[max(hits, key=len)] if hits else None

    def lean_end(module: str | None, location: dict) -> dict | None:
        repo = repo_of(module)
        return None if repo is None else {"type": "lean", "uri": repo[0], "version": repo[1], "location": location}

    def subject(src: str, entry: str, title: str) -> tuple[list[dict], dict]:
        placed = layout.get(src, {}).get(entry)
        if placed:
            return placed["subject"], {k: placed[k] for k in ("kind", "status") if placed.get(k)}
        fields = sources[src].get("fields", {})
        if "uri" not in fields:
            sys.exit(f"the source `{src}` has no `uri` field, which its ends need")
        uri = fields["uri"]
        if "{id}" in uri:
            base = entry.split(" proof, step ")[0]
            key = fields.get("registry", src)
            end = {"type": fields.get("type", "html"), "uri": uri.replace("{id}", urllib.parse.quote(base, safe="")),
                   "title": title}
            if valid_key(key):
                end["identifiers"] = {key: base}
            else:
                notes[f"source {src}: `{key}` cannot be an identifiers key"] += 1
            return [end], {}
        return [{"type": fields.get("type", "generic"), "uri": uri, "title": title}], {}

    out: dict[str, list[dict]] = collections.defaultdict(list)
    counts = collections.Counter()
    for c in dump["citations"]:
        if c["source"] not in sources:
            notes[f"unknown source {c['source']}"] += 1
            continue
        t = c["target"]
        location = ({"declaration": t["declaration"], **({"module": t["module"]} if t.get("module") else {})}
                    if "declaration" in t else {"module": t["module"], "lines": [t["lines"][0]]})
        obj = lean_end(t.get("module"), location)
        if obj is None:
            notes[f"left out: citations of declarations in {t.get('module') or 'the export file'}, "
                  "whose repository is not given"] += 1
            continue
        title = f"{c['id']}({c['part']})" if c.get("part") else c["id"]
        ends, fields = subject(c["source"], c["id"], title)
        if c.get("role"):
            obj["role"] = c["role"]
        if c.get("part"):
            obj["title"] = title
        out[c["source"]].append({"id": c["id"], **fields, **({"relation": c["rel"]} if c.get("rel") else {}),
                                 **({"note": c["comment"]} if c.get("comment") else {}),
                                 "subject": ends, "object": [obj]})
        counts["citations"] += 1

    steps: dict[tuple[str, str, int], list[dict]] = collections.defaultdict(list)
    for s in dump["steps"]:
        if s["source"] not in sources:
            notes[f"unknown source {s['source']}"] += 1
            continue
        for k in s["steps"]:
            steps[(s["source"], s["id"], k)].append(s)
    for (src, entry, k), marks in sorted(steps.items()):
        # a relation stated on one of a step's markers holds for the step; two that differ conflict
        rels = {m["rel"] for m in marks if m.get("rel")}
        if len(rels) > 1:
            sys.exit(f"{src} {entry} step {k}: its markers state different relations: {sorted(rels)}")
        name = f"{entry} proof, step {k}"
        ends, fields = subject(src, name, name)
        objects = []
        for m in sorted(marks, key=lambda m: (m["module"], m["lines"])):
            end = lean_end(m["module"], {**({"declaration": m["declaration"]} if m.get("declaration") else {}),
                                         "module": m["module"], "lines": m["lines"]})
            if end is None:
                notes[f"left out: step markers in {m['module']}, whose repository is not given"] += 1
            else:
                objects.append(end)
        out[src].append({"id": name, "kind": "proof_step", **fields, **({"relation": rels.pop()} if rels else {}),
                         "subject": ends, "object": objects})
        counts["steps"] += 1

    for m in dump.get("mathlib", []):
        obj = lean_end(m.get("module"), {"declaration": m["declaration"], **({"module": m["module"]} if m.get("module") else {})})
        if obj is None:
            notes[f"left out: Mathlib cross-references on declarations in {m.get('module') or 'the export file'}, "
                  "whose repository is not given"] += 1
            continue
        label = LABELS.get(m["database"], m["database"])
        out["mathlib"].append({
            "id": f"{m['database']}:{m['id']}", **({"note": m["comment"]} if m.get("comment") else {}),
            "subject": [{"type": "html", "uri": m["url"], "title": f"{label} {m['id']}",
                         "identifiers": {m["database"]: m["id"]}}],
            "object": [obj]})
        counts["mathlib"] += 1

    args.out.mkdir(parents=True, exist_ok=True)
    for name, annotations in out.items():
        seen, kept = set(), []
        for a in annotations:
            line = json.dumps(a, ensure_ascii=False)
            if line in seen:
                counts["duplicates"] += 1
                continue
            seen.add(line)
            kept.append(line)
        (args.out / f"{name}.jsonl").write_text("".join(l + "\n" for l in kept), encoding="utf-8")
    for note, n in notes.items():
        print(f"{note} ({n})", file=sys.stderr)
    print(json.dumps({**counts, "files": sorted(f"{n}.jsonl" for n in out)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
