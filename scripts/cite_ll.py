#!/usr/bin/env python3
"""Write Literature Links 2.0 annotations from what `#cite_export` read out of a Lean project.

    cite_ll.py dump.json --project <repository URL> --commit <sha> --out <dir>
        [--mathlib <repository URL> --mathlib-commit <sha>] [--layout layout.json]

For each source the project cites, `<out>/<source>.jsonl` holds one annotation per citation and
one per proof step:

* the subject is the source's entry. A source whose `uri` is a template with `{id}` gives each
  entry its own address and an identifier; any other source is the whole document, with the entry
  as the end's title, unless `--layout` places the entry: a JSON object mapping a source's name
  to its entries, and an entry such as `"3.21"` or `"3.21 proof, step 2"` to
  `{"subject": [ends], "kind": …, "status": …}`. A book's layout tooling writes that file; the
  tags say what is linked, the layout where it is on the page.
* the object is the Lean: `{declaration, module}` for a declaration, `{module, lines: [n]}` for an
  `example` or other command without a name (the item that starts on line n), and
  `{declaration, module, lines: [a, b]}` for the lines of a proof step.

`<out>/mathlib.jsonl` holds Mathlib's own cross-references, one annotation per tag, each from the
database entry (an `html` end with its identifier) to the Mathlib declaration.

Every annotation is valid on its own; no folder defaults are written. Standard library only.
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
from pathlib import Path

LABELS = {"stacks": "Stacks Project", "kerodon": "Kerodon", "wikidata": "Wikidata", "lmfdb": "LMFDB",
          "dlmf": "DLMF", "oeis": "OEIS"}


def lean_end(uri: str, version: str, location: dict, **extra) -> dict:
    return {"type": "lean", "uri": uri, "version": version, "location": location, **extra}


def target_location(t: dict) -> dict:
    if "declaration" in t:
        return {"declaration": t["declaration"], **({"module": t["module"]} if t.get("module") else {})}
    return {"module": t["module"], "lines": [t["lines"][0]]}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dump", type=Path)
    ap.add_argument("--project", required=True, help="the project's repository URL, or a path to its checkout")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--mathlib", default="https://github.com/leanprover-community/mathlib4")
    ap.add_argument("--mathlib-commit")
    ap.add_argument("--layout", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    dump = json.loads(args.dump.read_text(encoding="utf-8"))
    layout = json.loads(args.layout.read_text(encoding="utf-8")) if args.layout else {}
    sources = {s["name"]: s for s in dump["sources"]}

    def subject(src: str, entry: str, title: str) -> tuple[list[dict], dict]:
        """The subject ends of an entry, and the annotation fields its layout gives."""
        placed = layout.get(src, {}).get(entry)
        if placed:
            return placed["subject"], {k: placed[k] for k in ("kind", "status") if k in placed}
        s = sources[src]
        fields = s.get("fields", {})
        uri = fields.get("uri", src)
        end = {"type": fields.get("type", "generic"), "title": title}
        if "{id}" in uri:
            base = entry.split(" proof, step ")[0]
            end |= {"uri": uri.replace("{id}", base), "identifiers": {src: base}}
        else:
            end["uri"] = uri
        return [end], {}

    def from_project(t: dict) -> bool:
        return not t.get("module", "").startswith(("Mathlib.", "Init.", "Lean.", "Std.", "Batteries."))

    out: dict[str, list[dict]] = collections.defaultdict(list)
    counts = collections.Counter()
    for c in dump["citations"]:
        t = c["target"]
        title = f"{c['id']}({c['part']})" if c.get("part") else c["id"]
        ends, fields = subject(c["source"], c["id"], title)
        if from_project(t):
            obj = lean_end(args.project, args.commit, target_location(t))
        elif t["module"].startswith("Mathlib.") and args.mathlib_commit:
            obj = lean_end(args.mathlib, args.mathlib_commit, target_location(t))
        else:
            print(f"skipped {c['source']} {c['id']}: {t.get('declaration')} is in {t.get('module')}, "
                  "whose commit is not given", file=sys.stderr)
            counts["skipped"] += 1
            continue
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
        for k in s["steps"]:
            steps[(s["source"], s["id"], k)].append(s)
    for (src, entry, k), marks in sorted(steps.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2])):
        rels = {m.get("rel", "") for m in marks}
        if len(rels) > 1:
            sys.exit(f"{src} {entry} step {k}: its markers disagree on the relation: {sorted(rels)}")
        name = f"{entry} proof, step {k}"
        ends, fields = subject(src, name, name)
        objects = [lean_end(args.project, args.commit,
                            {**({"declaration": m["declaration"]} if m.get("declaration") else {}),
                             "module": m["module"], "lines": m["lines"]})
                   for m in sorted(marks, key=lambda m: (m["module"], m["lines"]))]
        rel = rels.pop()
        out[src].append({"id": name, "kind": "proof_step", **fields, **({"relation": rel} if rel else {}),
                         "subject": ends, "object": objects})
        counts["steps"] += 1

    if dump.get("mathlib") and args.mathlib_commit:
        for m in dump["mathlib"]:
            label = LABELS.get(m["database"], m["database"])
            out["mathlib"].append({
                "id": f"{m['database']}:{m['id']}",
                **({"note": m["comment"]} if m.get("comment") else {}),
                "subject": [{"type": "html", "uri": m["url"], "title": f"{label} {m['id']}",
                             "identifiers": {m["database"]: m["id"]}}],
                "object": [lean_end(args.mathlib, args.mathlib_commit,
                                    {"declaration": m["declaration"], **({"module": m["module"]} if m.get("module") else {})})]})
            counts["mathlib"] += 1
    elif dump.get("mathlib"):
        print(f"skipped {len(dump['mathlib'])} Mathlib cross-references: give --mathlib-commit", file=sys.stderr)

    args.out.mkdir(parents=True, exist_ok=True)
    for name, annotations in out.items():
        with (args.out / f"{name}.jsonl").open("w", encoding="utf-8") as f:
            for a in annotations:
                f.write(json.dumps(a, ensure_ascii=False) + "\n")
    print(json.dumps({**counts, "files": sorted(f"{n}.jsonl" for n in out)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
