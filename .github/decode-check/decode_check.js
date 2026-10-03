const fs = require('fs'), path = require('path');
const n = require('/tmp/nsv-js/index.js');

function pathToSeqseq(name) {
    const stem = name.replace(/\.nsv$/, '');
    if (!stem) return [];
    let state = 0;
    const rows = [];
    let row = [], cell = [];
    const content = {a: 'a', b: '\\', n: '\n'};
    for (const ch of stem) {
        if (state === 0) { row = []; state = 1; }
        else if (state === 1) {
            if (ch === '0') { rows.push(row); state = 0; }
            else if (ch === '1') row.push('');
            else if (ch === '2') { cell = []; state = 2; }
        } else if (state === 2) { cell.push(content[ch]); state = 3; }
        else if (state === 3) {
            if (ch === '1') { row.push(cell.join('')); cell = []; state = 1; }
            else cell.push(content[ch]);
        }
    }
    if (state === 1) rows.push(row);
    return rows;
}

function seqseqEqual(a, b) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
        if (a[i].length !== b[i].length) return false;
        for (let j = 0; j < a[i].length; j++)
            if (a[i][j] !== b[i][j]) return false;
    }
    return true;
}

const dir = process.argv[2];
const files = fs.readdirSync(dir).filter(f => f.endsWith('.nsv')).sort();
let passed = 0; const fails = [];
for (const f of files) {
    const p = path.join(dir, f), orig = fs.readFileSync(p, 'utf8');
    seqseqEqual(n.parse(orig), pathToSeqseq(f)) ? passed++ : fails.push(f);
}
console.log(`  ${passed}/${passed + fails.length} passed`);
fails.forEach(f => console.log(`  ${f}`));
if (fails.length) process.exit(1);
