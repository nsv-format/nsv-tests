import os, sys, nsv

d = sys.argv[1]
entries = sorted(e for e in os.listdir(d) if e.endswith('.nsv'))
fails = [n for n in entries
         if nsv.dumps(nsv.loads(open(os.path.join(d, n)).read()))
            != open(os.path.join(d, n)).read()]
passed = len(entries) - len(fails)
print(f'  {passed}/{len(entries)} passed')
for f in fails: print(f'  {f}')
sys.exit(1 if fails else 0)
