// Every checker, in one go. Run this before calling anything done.
//
//   node tools/check-all.mjs

import { execFileSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const here = fileURLToPath(new URL('.', import.meta.url));

const checkers = readdirSync(here)
    .filter(f => f.startsWith('check-') && f.endsWith('.mjs') && f !== 'check-all.mjs')
    .sort();

let failed = 0;

for (const checker of checkers) {
    try {
        const out = execFileSync(process.execPath, [join(here, checker)], { encoding: 'utf8' });
        process.stdout.write(out);
    } catch (error) {
        process.stdout.write(error.stdout || '');
        process.stdout.write(error.stderr || '');
        failed += 1;
    }
}

console.log(failed === 0
    ? `\nall ${checkers.length} checkers passed`
    : `\n${failed} of ${checkers.length} checkers failed`);

process.exit(failed === 0 ? 0 : 1);
