#!/usr/bin/env python3
"""Write the layout file `cite_ll.py --layout` reads, from the companion's annotations.

Where an item is in the PDF does not depend on what links it, so the regions the companion's
exporter found are the layout: for each item, exercise and proof step, its subject ends with the
folder defaults' template applied, and its kind and status.

    layout_from_annotations.py <annotations/> <source name> > layout.json
"""
import json
import sys
from pathlib import Path

root, source = Path(sys.argv[1]), sys.argv[2]
template = json.loads((root / "_defaults.json").read_text(encoding="utf-8"))["subject"]
entries = {}
for p in sorted(root.rglob("*.json")):
    if p.name == "_defaults.json":
        continue
    rec = json.loads(p.read_text(encoding="utf-8"))
    # an end with its own `uri` takes nothing from the template
    ends = [e if "uri" in e else {**template, **e} for e in rec["subject"]]
    entries.setdefault(rec["id"], {"subject": ends, "kind": rec.get("kind"), "status": rec.get("status")})
json.dump({source: entries}, sys.stdout, ensure_ascii=False)
