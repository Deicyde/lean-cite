import os, re
pat = re.compile(r'\b(stacks|kerodon|wikidata|lmfdb|pibase|dlmf|oeis)\s+[A-Za-z0-9"(]')
for r, _, fs in sorted(os.walk('Mathlib')):
    for f in sorted(fs):
        if not f.endswith('.lean') or f == 'CrossRefAttribute.lean':
            continue
        p = os.path.join(r, f)
        s = open(p).read()
        blocks = re.findall(r'@\[((?:[^\[\]]|\[[^\]]*\])*)\]', s) + re.findall(r'^\s*attribute\s*\[([^\]]*)\]', s, re.M)
        if any(pat.search(b) for b in blocks):
            print(p)
