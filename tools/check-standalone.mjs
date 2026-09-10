// No XS script may require another XS script. A bridge may name one as
// one option among several; runtime code may not reach for one directly, or
// this stops being standalone.
//
//   node tools/check-standalone.mjs

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

// Where naming another XS resource is legitimate: the bridges that pick a
// backend, and the manifest comment that lists what is supported.
const ALLOWED = ['bridge' + sep, 'fxmanifest.lua', 'config.lua'];

const NAME = /\b(?:XS-(?!Paintball)[A-Za-z]+|cipher-[a-z]+)\b/g;

const files = [];
const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
        if (entry === 'node_modules' || entry === '.git' || entry === 'tools') continue;
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) walk(full);
        else if (entry.endsWith('.lua') || entry.endsWith('.js')) files.push(full);
    }
};

walk(root);

let problems = 0;

for (const file of files) {
    const relative = file.slice(root.length);
    if (ALLOWED.some(a => relative.startsWith(a))) continue;

    const src = readFileSync(file, 'utf8');
    const hits = new Set();
    for (const m of src.matchAll(NAME)) hits.add(m[0]);

    if (hits.size > 0) {
        console.log(`  ${relative} reaches for ${[...hits].join(', ')}`);
        problems += 1;
    }
}

// Each bridge has to degrade to something that works with none of its options.
const target = readFileSync(join(root, 'bridge', 'target.lua'), 'utf8');
if (!target.includes("Target = { name = 'none' }")) {
    console.log('  bridge/target.lua has no built-in interaction fallback');
    problems += 1;
}

const inventory = readFileSync(join(root, 'bridge', 'inventory.lua'), 'utf8');
if (!inventory.includes("Inventory = { name = 'none' }")) {
    console.log('  bridge/inventory.lua has no no-inventory fallback');
    problems += 1;
}

const main = readFileSync(join(root, 'client', 'main.lua'), 'utf8');
if (!main.includes("Target.name == 'none'")) {
    console.log('  client/main.lua never falls back to the marker prompt');
    problems += 1;
}

console.log(problems === 0
    ? `check-standalone: ${files.length} files, nothing depends on another XS script`
    : `check-standalone: ${problems} coupling problem(s)`);

process.exit(problems === 0 ? 0 : 1);
