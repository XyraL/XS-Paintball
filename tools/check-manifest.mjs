// The manifest and the folder have to agree. Two ways they drift, both of which
// have bitten this resource:
//   1. a file is on disk but not in fxmanifest, so it never loads and the first
//      thing that touches its global dies on a nil index
//   2. fxmanifest names a file that is not there, which FiveM warns about once
//      at startup and is easy to scroll past
//
// It also checks the html files{} list, because a panel script missing from
// there is a 404 nobody sees until the tab is blank.
//
//   node tools/check-manifest.mjs

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const manifest = readFileSync(join(root, 'fxmanifest.lua'), 'utf8');

// Every quoted path in the manifest, minus the @resource/ imports.
const listed = new Set(
    [...manifest.matchAll(/'([^']+\.(?:lua|js|css|html))'/g)]
        .map(m => m[1])
        .filter(p => !p.startsWith('@'))
);

const onDisk = [];
const walk = (dir, prefix) => {
    for (const entry of readdirSync(join(root, dir))) {
        const rel = prefix ? `${prefix}/${entry}` : entry;
        if (statSync(join(root, dir, entry)).isDirectory()) {
            walk(join(dir, entry), rel);
        } else if (/\.(lua|js|css|html)$/.test(entry)) {
            onDisk.push(rel);
        }
    }
};

for (const dir of ['bridge', 'shared', 'client', 'server', 'html']) {
    if (existsSync(join(root, dir))) walk(dir, dir);
}

const problems = [];

// Files that are deliberately not shipped or not loaded by the manifest.
const IGNORED = [
    'html/index.html',        // ui_page, not a files{} entry we parse as a path
];

for (const file of onDisk) {
    if (listed.has(file) || IGNORED.includes(file)) continue;
    problems.push(`  ${file} is on disk but not in fxmanifest.lua — it will never load`);
}

for (const file of listed) {
    if (!existsSync(join(root, file))) {
        problems.push(`  fxmanifest.lua names ${file}, which does not exist`);
    }
}

// Anything index.html pulls in has to be in files{} or CEF cannot fetch it.
const html = readFileSync(join(root, 'html', 'index.html'), 'utf8');
for (const m of html.matchAll(/(?:src|href)="((?!https?:)[^"]+)"/g)) {
    const rel = `html/${m[1]}`;
    if (!listed.has(rel)) {
        problems.push(`  html/index.html loads ${m[1]} but files{} does not list it — 404 in game`);
    }
}

problems.forEach(p => console.log(p));

console.log(problems.length === 0
    ? `check-manifest: ${onDisk.length} file(s), manifest and folder agree`
    : `check-manifest: ${problems.length} problem(s)`);

process.exit(problems.length === 0 ? 0 : 1);
