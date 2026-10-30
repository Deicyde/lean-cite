#!/usr/bin/env python3
"""Compare the links `cite_ll.py` wrote from the tags with the companion's, for one chapter.

A link is its id, relation and set of Lean ends, each end being where it points, its role and its
title (an exercise's part). Kind and status are not compared: cite_ll.py takes both from the
layout. The tags' line numbers are those of the tagged branch, so they are mapped back to the
untagged files first; a range whose first or last line the tagging added is reported. Checked
absences (`noMatch`, whose Lean end is at most the declarations of the item's proof) are the book's
side, which no tag states, and are counted apart.

    compare_links.py <generic source.jsonl> <annotations/> <untagged repo> <tagged repo> <chapter>
"""
import collections
import json
import sys
from pathlib import Path

from export_from_tags import in_chapter, line_map

generic, annotations, original, tagged, chapter = sys.argv[1:6]
maps = {}


def back(module, lines):
    rel = module.replace(".", "/") + ".lean"
    if rel not in maps:
        maps[rel] = line_map((Path(original) / rel).read_text(encoding="utf-8").split("\n"),
                             (Path(tagged) / rel).read_text(encoding="utf-8").split("\n"))
    m = maps[rel]
    if any(k not in m for k in lines):
        print(f"a range on lines the tagging added: {module} {lines}")
        return ["added"]
    return [m[k] for k in lines]


def where(end, mapped):
    loc = dict(end["location"])
    # only the companion's own lines moved; mathlib's did not
    if mapped and "lines" in loc and end["uri"].endswith("linear-algebra-done-right-lean"):
        loc["lines"] = back(loc["module"], loc["lines"])
    return (end.get("uri", "companion"), json.dumps(loc, sort_keys=True, ensure_ascii=False), end.get("role", "key"),
            end.get("title", ""))


def key(rec, mapped):
    ends = tuple(sorted(where(e, mapped) for e in rec.get("object", [])))
    return (rec["id"], rec.get("relation", ""), ends)


ours = collections.Counter(key(json.loads(l), True) for l in open(generic, encoding="utf-8"))
theirs, absences = collections.Counter(), 0
for p in Path(annotations).rglob("*.json"):
    if p.name == "_defaults.json":
        continue
    rec = json.loads(p.read_text(encoding="utf-8"))
    if not in_chapter(rec["id"].split(" proof, step ")[0], chapter):
        continue
    if rec.get("relation") == "noMatch":
        absences += 1
        continue
    # the companion's Lean ends inherit the repository from the folder defaults
    rec["object"] = [e if "uri" in e else {**e, "uri": "https://github.com/rkirov/linear-algebra-done-right-lean"}
                     for e in rec.get("object", [])]
    theirs[key(rec, False)] += 1
only_ours, only_theirs = ours - theirs, theirs - ours
print(json.dumps({"links from tags": sum(ours.values()), "links in annotations": sum(theirs.values()),
                  "same": sum((ours & theirs).values()), "only from tags": sum(only_ours.values()),
                  "only in annotations": sum(only_theirs.values()), "checked absences (book side)": absences}, indent=1))
for k in only_ours:
    print("only from tags:", k)
for k in only_theirs:
    print("only in annotations:", k)
