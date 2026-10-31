import re, sys
rows = {}
for path in sys.argv[1:]:
    for line in open(path):
        if not line.startswith('PROBE\t'):
            continue
        _, where, name, raw, doc = line.rstrip('\n').split('\t', 4)
        marks = re.findall(r'\b(?:ADD)?DOC\b|FIELD|CTOR', doc)
        links = re.findall(r'(?:Stacks Tag|Kerodon Tag) (\d+)', doc)
        if doc == 'none':
            c = 'none'
        elif marks and links:
            c = f'doc+{len(links)}L'
        elif marks:
            c = 'doc'
        elif links:
            c = f'{len(links)}L'
        else:
            c = '?' + doc
        if len(marks) > 1:
            c += '!dupdoc'
        if len(set(links)) != len(links):
            c += '!duplink'
        rows.setdefault(name, {})[where] = f'{c} ({raw})'
print('decl\tsame-file\timported')
for n, r in rows.items():
    print(f"{n}\t{r.get('same-file', '-')}\t{r.get('imported', '-')}")
