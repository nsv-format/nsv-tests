const fs = require('fs'), path = require('path');
const n = require('/tmp/nsv-js/index.js');
const [mode, indir, outdir] = process.argv.slice(2);

(async () => {
  for (const f of fs.readdirSync(indir).filter(f => f.endsWith('.nsv')).sort()) {
    const text = fs.readFileSync(path.join(indir, f), 'utf8');
    let out;
    if (mode === 'batch') {
      out = n.stringify(n.parse(text));
    } else {
      const rows = await new n.Reader(text).readRows();
      let buf = '';
      const sink = {
        write(chunk, enc, cb) {
          buf += chunk;
          const done = typeof enc === 'function' ? enc : cb;
          if (done) done();
          return true;
        },
      };
      await new n.Writer(sink).writeRows(rows);
      out = buf;
    }
    fs.writeFileSync(path.join(outdir, f), out);
  }
})();
