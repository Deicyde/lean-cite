"""diff-docs.py <base.tsv> <new.tsv> <links.tsv>: which docstrings differ, and is each difference
exactly `base` followed by that declaration's links?"""
import csv, json, sys, collections
def load(p):
    d = {}
    for line in open(p, encoding='utf-8'):
        n, k, t = line.rstrip('\n').split('\t', 2)
        d[(n, k)] = json.loads(t) if t else ''
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
print('entries', len(a), len(b))
gone = [k for k in a if k not in b]; new = [k for k in b if k not in a]
print('only in base', len(gone), gone[:10]); print('only in new', len(new), new[:10])
diff = [k for k in a if k in b and a[k] != b[k]]
print('changed', len(diff))
ext, other = 0, []
for k in diff:
    x, y = a[k], b[k]
    if y.startswith(x + '\n\n') and '](http' in y[len(x):] and y[len(x):].count('\n\n') >= 1 and all(p.startswith('[') for p in y[len(x)+2:].split('\n\n')):
        ext += 1
    else:
        other.append(k)
print('changed by appending links only', ext, 'other', len(other))
for k in other[:15]:
    print(k, repr(a[k][-90:]), '=>', repr(b[k][-200:]))
