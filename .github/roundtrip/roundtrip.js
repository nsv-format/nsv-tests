const fs = require('fs'), path = require('path');
const n = require('/tmp/nsv-js/index.js');
const dir = process.argv[2];
const files = fs.readdirSync(dir).filter(f => f.endsWith('.nsv')).sort();
let passed = 0; const fails = [];
for (const f of files) {
    const p = path.join(dir, f), orig = fs.readFileSync(p, 'utf8');
    n.stringify(n.parse(orig)) === orig ? passed++ : fails.push(f);
}
console.log(`  ${passed}/${passed + fails.length} passed`);
fails.forEach(f => console.log(`  ${f}`));
if (fails.length) process.exit(1);
