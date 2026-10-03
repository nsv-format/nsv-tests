import os, sys, nsv


def path_to_seqseq(name):
    stem = name.removesuffix('.nsv')
    if not stem:
        return []
    S0, S1, S2, S3 = 0, 1, 2, 3
    state = S0
    rows = []
    row = cell = None
    content = {'a': 'a', 'b': '\\', 'n': '\n'}
    for ch in stem:
        if state == S0:
            row = []; state = S1
        elif state == S1:
            if ch == '0': rows.append(row); state = S0
            elif ch == '1': row.append('')
            elif ch == '2': cell = []; state = S2
        elif state == S2:
            cell.append(content[ch]); state = S3
        elif state == S3:
            if ch == '1': row.append(''.join(cell)); cell = None; state = S1
            else: cell.append(content[ch])
    if state == S1: rows.append(row)
    return rows


d = sys.argv[1]
entries = sorted(e for e in os.listdir(d) if e.endswith('.nsv'))
fails = [n for n in entries
         if nsv.loads(open(os.path.join(d, n)).read()) != path_to_seqseq(n)]
passed = len(entries) - len(fails)
print(f'  {passed}/{len(entries)} passed')
for f in fails: print(f'  {f}')
sys.exit(1 if fails else 0)
