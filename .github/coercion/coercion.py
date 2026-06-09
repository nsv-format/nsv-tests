import io, os, sys, nsv

mode, indir, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
for name in sorted(n for n in os.listdir(indir) if n.endswith('.nsv')):
    with open(os.path.join(indir, name), newline='') as f:
        if mode == 'batch':
            out = nsv.dumps(nsv.loads(f.read()))
        else:
            buf = io.StringIO()
            nsv.Writer(buf).write_rows(nsv.Reader(f))
            out = buf.getvalue()
    with open(os.path.join(outdir, name), 'w', newline='') as f:
        f.write(out)
