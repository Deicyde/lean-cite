"""The step-marker scanner of `Cite/Steps.lean`, in Python, for scripts that place markers.

It follows `Cite.classifyLines`, `Cite.classifyComment` and `Cite.scan` step for step; the Lean is
the definition. `test_cite_scan.py` checks the two agree on `CiteTest/scan_cases.json`.
"""
from __future__ import annotations

RELATIONS = ["exactMatch", "closeMatch", "broadMatch", "narrowMatch", "relatedMatch", "hasPart", "noMatch"]


def is_blank(c: str) -> bool:
    return c in " \t"


def indent_of(s: str) -> int:
    n = 0
    while n < len(s) and is_blank(s[n]):
        n += 1
    return n


def is_digit(c: str) -> bool:
    return "0" <= c <= "9"


def is_alpha(c: str) -> bool:
    return "a" <= c <= "z" or "A" <= c <= "Z"


def words(s: str) -> list[str]:
    out, i, n = [], 0, len(s)
    while True:
        while i < n and is_blank(s[i]):
            i += 1
        if i >= n:
            return out
        if s[i] == '"':
            j = s.find('"', i + 1)
            if j < 0:
                out.append(s[i:])
                return out
            out.append(s[i:j + 1])
            i = j + 1
        else:
            j = i
            while j < n and not is_blank(s[j]):
                j += 1
            out.append(s[i:j])
            i = j


def is_source_name(w: str) -> bool:
    if not w:
        return False
    for part in w.split("."):
        if not part or not (is_alpha(part[0]) or part[0] == "_"):
            return False
        if not all(is_alpha(c) or is_digit(c) or c == "_" for c in part[1:]):
            return False
    return True


def classify_comment(line: int, column: int, text: str):
    ws = words(text)
    if not ws or ws[0] != "cite":
        return ("comment",)
    if len(ws) > 1 and ws[1] == "end":
        return ("stop",) if len(ws) == 2 else ("malformed", "`-- cite end` takes nothing after it")
    if not (len(ws) >= 3 and (ws[2].startswith('"') or "step" in ws)):
        return ("comment",)
    if not is_source_name(ws[1]):
        return ("malformed", f"the source `{ws[1]}` is not a name")
    if not ws[2].startswith('"'):
        return ("malformed", "the entry is not a string")
    if not (len(ws[2]) >= 2 and ws[2].endswith('"')):
        return ("malformed", 'the entry has no closing `"`')
    entry = ws[2][1:-1]
    if all(c.isspace() for c in entry):
        return ("malformed", "the entry is empty")
    if ws[3:4] != ["step"]:
        return ("malformed", "expected `step` after the entry")
    nums = []
    for w in ws[4:]:
        if not w or not all(is_digit(c) for c in w):
            break
        nums.append(w)
    if not nums:
        return ("malformed", "expected step numbers after `step`")
    if any(int(w) == 0 for w in nums):
        return ("malformed", "steps are numbered from 1")
    rest = ws[4 + len(nums):]
    if len(rest) > 1:
        return ("malformed", f"unexpected `{rest[1]}`")
    rel = rest[0] if rest else ""
    if rel and rel not in RELATIONS:
        return ("malformed", f"unknown relation `{rel}`; the relations are {', '.join(RELATIONS)}")
    return ("marker", {"line": line, "column": column, "source": ws[1], "id": entry,
                       "steps": [int(w) for w in nums], "rel": rel})


def classify_lines(lines: list[str], first: int = 1) -> list[tuple]:
    out: list[tuple] = []
    depth, in_string = 0, False
    for i, text in enumerate(lines):
        cs = text
        has_code, line_comment, j = False, None, 0
        while j < len(cs):
            c = cs[j]
            nxt = cs[j + 1] if j + 1 < len(cs) else None
            if in_string:
                has_code = True
                if c == "\\":
                    j += 2
                else:
                    if c == '"':
                        in_string = False
                    j += 1
            elif depth > 0:
                if c == "/" and nxt == "-":
                    depth += 1
                    j += 2
                elif c == "-" and nxt == "/":
                    depth -= 1
                    j += 2
                else:
                    j += 1
            elif c == "-" and nxt == "-":
                line_comment = j
                j = len(cs)
            elif c == "/" and nxt == "-":
                depth = 1
                j += 2
            elif c == "-" and nxt == "/":
                out = [("comment",) for _ in out]
                has_code = False
                j += 2
            elif c == "'" and cs[j + 1:j + 3] == "\"'":
                has_code = True
                j += 3
            elif c == '"':
                has_code = True
                in_string = True
                j += 1
            else:
                if not is_blank(c):
                    has_code = True
                j += 1
        if has_code:
            kind = ("code",)
        elif line_comment is not None:
            kind = (classify_comment(first + i, line_comment, cs[line_comment + 2:])
                    if all(is_blank(c) for c in cs[:line_comment]) else ("comment",))
        else:
            kind = ("blank",) if all(is_blank(c) for c in cs) else ("comment",)
        out.append(kind)
    return out


def scan(lines: list[str], first: int = 1) -> dict:
    """{"markers", "marks", "problems"} as `Cite.scan` returns them; a mark is the marker's fields
    with `start` and `stop`."""
    kinds = classify_lines(lines, first)
    n = len(kinds)
    code = lambda k: kinds[k][0] == "code"
    boundary = lambda k: kinds[k][0] in ("marker", "stop", "malformed")
    r = {"markers": [], "marks": [], "problems": []}
    i = 0
    while i < n:
        kind = kinds[i][0]
        if kind == "malformed":
            r["problems"].append((first + i, f"malformed `-- cite` marker: {kinds[i][1]}"))
            i += 1
        elif kind == "marker":
            group, j = [], i
            while j < n and kinds[j][0] == "marker":
                group.append(kinds[j][1])
                j += 1
            r["markers"] += group
            s = j
            while s < n and not code(s) and not boundary(s):
                s += 1
            if s >= n or not code(s):
                r["problems"].append((first + i, "the `-- cite` marker marks no code"))
            else:
                for m in group:
                    k = s + 1
                    while k < n and not boundary(k) and not (
                            code(k) and (indent_of(lines[k]) == 0 if m["column"] == 0
                                         else indent_of(lines[k]) < m["column"])):
                        k += 1
                    e = k - 1
                    while e > s and not code(e):
                        e -= 1
                    r["marks"].append({**m, "start": first + s, "stop": first + e})
            i = j
        else:
            i += 1
    return r


def split_lines(src: str) -> list[str]:
    """Lines end at line feeds, as in Lean's positions."""
    return src.replace("\r\n", "\n").split("\n")
