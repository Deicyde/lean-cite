"""Does editing a later tactic block reuse elaboration of earlier tactics?

Opens a file with `lean --server`, edits the last tactic, and prints `trace.Elab.reuse`-based
evidence: `dbg_trace`s go to stderr; the proof's `dbg_trace` marker counts how many tactics re-ran.
Usage: lsp_reuse.py <mathlib-checkout> <untagged|tagged>
"""
import json, os, subprocess, sys, threading, time
root, mode = sys.argv[1], sys.argv[2]
attr = "@[stacks 0001]\n" if mode == "tagged" else ""
marks = os.path.abspath("lsp-marks.txt"); open(marks, "w").close()
text = f"""import Mathlib.Tactic.CrossRefAttribute
open Lean Elab Tactic in
elab "mark" s:str : tactic => do
  IO.FS.withFile "{marks}" .append (·.putStrLn s.getString)
  
{attr}theorem t : True := by
  mark "first"
  mark "second"
  trivial
"""
edit_from = "mark \"second\""
p = subprocess.Popen(["lake", "env", "lean", "--server"], cwd=root, stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
ran = []
def err():
    for l in p.stderr:
        l = l.decode(errors="replace").strip()
        if "RAN" in l: ran.append(l)
threading.Thread(target=err, daemon=True).start()
done = {}
def out():
    while True:
        h = {}
        while True:
            l = p.stdout.readline()
            if not l: return
            l = l.decode().strip()
            if not l: break
            k, v = l.split(": "); h[k] = v
        m = json.loads(p.stdout.read(int(h["Content-Length"])))
        if m.get("method") == "$/lean/fileProgress" and not m["params"]["processing"]:
            done[m["params"]["textDocument"]["version"]] = True
threading.Thread(target=out, daemon=True).start()
def send(o):
    b = json.dumps({"jsonrpc": "2.0", **o}).encode()
    p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(b) + b); p.stdin.flush()
uri = "file://" + os.path.join(os.path.abspath(root), "LspReuseProbe.lean")
send({"id": 1, "method": "initialize", "params": {"capabilities": {}, "rootUri": None, "processId": None}})
time.sleep(1); send({"method": "initialized", "params": {}})
send({"method": "textDocument/didOpen", "params": {"textDocument": {"uri": uri, "languageId": "lean4", "version": 1, "text": text}}})
def wait(v, t=240):
    e = time.time() + t
    while time.time() < e and v not in done: time.sleep(0.2)
    return v in done
def take():
    r = open(marks).read().split(); open(marks, "w").close(); return r
print("v1 done", wait(1)); time.sleep(1); print("v1 ran", take())
line = text[:text.index(edit_from)].count("\n")
send({"method": "textDocument/didChange", "params": {"textDocument": {"uri": uri, "version": 2},
      "contentChanges": [{"range": {"start": {"line": line, "character": 8}, "end": {"line": line, "character": 8}}, "text": "2"}]}})
print("v2 done", wait(2)); time.sleep(1); print("v2 ran", take())
p.kill()
