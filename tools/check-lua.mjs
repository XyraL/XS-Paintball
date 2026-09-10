// There is no Lua binary on this machine, so nothing parses these files until
// the server starts and refuses to load the resource. This catches the two
// failures that actually happen while writing a lot of Lua at once:
//   1. block or bracket imbalance, which is a real syntax error
//   2. a `local function` called above the line that declares it, which
//      silently resolves to a nil global and only breaks on that code path
//
//   node tools/check-lua.mjs [path]
//   node tools/check-lua.mjs --selftest

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Blanks comments and string bodies, keeping every newline so line numbers
// still line up with the original file.
function blank(src) {
    let out = '';
    let i = 0;

    const keepNewlines = (text) => {
        for (const ch of text) out += ch === '\n' ? '\n' : ' ';
    };

    const longLevel = (p) => {
        if (src[p] !== '[') return -1;
        let q = p + 1;
        let level = 0;
        while (src[q] === '=') { level += 1; q += 1; }
        return src[q] === '[' ? level : -1;
    };

    const readLong = (p, level) => {
        const close = ']' + '='.repeat(level) + ']';
        const end = src.indexOf(close, p);
        return end === -1 ? src.length : end + close.length;
    };

    while (i < src.length) {
        const ch = src[i];

        if (ch === '-' && src[i + 1] === '-') {
            const level = longLevel(i + 2);

            if (level >= 0) {
                const end = readLong(i + 2, level);
                keepNewlines(src.slice(i, end));
                i = end;
            } else {
                const end = src.indexOf('\n', i);
                const stop = end === -1 ? src.length : end;
                keepNewlines(src.slice(i, stop));
                i = stop;
            }
            continue;
        }

        const level = longLevel(i);
        if (level >= 0) {
            const end = readLong(i, level);
            keepNewlines(src.slice(i, end));
            i = end;
            continue;
        }

        if (ch === '"' || ch === "'") {
            let j = i + 1;
            while (j < src.length) {
                if (src[j] === '\\') { j += 2; continue; }
                if (src[j] === ch || src[j] === '\n') break;
                j += 1;
            }
            keepNewlines(src.slice(i, Math.min(j + 1, src.length)));
            i = j + 1;
            continue;
        }

        out += ch;
        i += 1;
    }

    return out;
}

const OPENERS = new Set(['function', 'if', 'do', 'repeat']);
const CLOSERS = new Set(['end', 'until']);

function checkFile(file, src) {
    const problems = [];
    const code = blank(src);
    const lineOf = (index) => code.slice(0, index).split('\n').length;

    let depth = 0;
    const stack = [];

    for (const match of code.matchAll(/\b[A-Za-z_][A-Za-z0-9_]*\b/g)) {
        const word = match[0];

        if (OPENERS.has(word)) {
            depth += 1;
            stack.push({ word, line: lineOf(match.index) });
        } else if (CLOSERS.has(word)) {
            depth -= 1;
            const open = stack.pop();

            if (depth < 0) {
                problems.push(`${file}:${lineOf(match.index)} stray "${word}" — more ends than blocks`);
                depth = 0;
            } else if (word === 'until' && open && open.word !== 'repeat') {
                problems.push(`${file}:${lineOf(match.index)} "until" closes a "${open.word}" opened on line ${open.line}`);
            }
        }
    }

    if (depth > 0) {
        const open = stack[stack.length - 1];
        problems.push(`${file} ends with ${depth} unclosed block(s), innermost "${open.word}" from line ${open.line}`);
    }

    const pairs = { '(': ')', '[': ']', '{': '}' };
    const closers = { ')': '(', ']': '[', '}': '{' };
    const brackets = [];

    for (let i = 0; i < code.length; i += 1) {
        const ch = code[i];

        if (pairs[ch]) {
            brackets.push({ ch, line: lineOf(i) });
        } else if (closers[ch]) {
            const open = brackets.pop();
            if (!open) {
                problems.push(`${file}:${lineOf(i)} stray "${ch}"`);
            } else if (open.ch !== closers[ch]) {
                problems.push(`${file}:${lineOf(i)} "${ch}" closes a "${open.ch}" opened on line ${open.line}`);
            }
        }
    }

    if (brackets.length) {
        const open = brackets[brackets.length - 1];
        problems.push(`${file} leaves "${open.ch}" from line ${open.line} unclosed`);
    }

    const declared = new Map();
    for (const match of code.matchAll(/\blocal\s+function\s+([A-Za-z_][A-Za-z0-9_]*)/g)) {
        if (!declared.has(match[1])) declared.set(match[1], match.index);
    }

    for (const [name, at] of declared) {
        const uses = [...code.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))];
        for (const use of uses) {
            if (use.index < at) {
                problems.push(`${file}:${lineOf(use.index)} calls local function "${name}" declared later on line ${lineOf(at)}`);
                break;
            }
        }
    }

    return problems;
}

function selftest() {
    const cases = [
        ['function a() if true then end', /unclosed block/],
        ['local t = { 1, 2', /unclosed/],
        ['local function a() end\nlocal function b() a() end', null],
        ['local function b() a() end\nlocal function a() end', /declared later/],
        ['-- [[ not a long comment start\nlocal x = 1', null],
        ['local s = "-- end end end"\nlocal function f() end', null],
        ['for i = 1, 3 do print(i) end', null],
        ['repeat local x = 1 until x', null],
        ['while true do if x then else end end', null],
    ];

    let failed = 0;

    cases.forEach(([src, expect], index) => {
        const problems = checkFile('selftest', src);
        const matched = expect === null ? problems.length === 0 : problems.some(p => expect.test(p));

        if (!matched) {
            failed += 1;
            console.log(`selftest ${index} failed:`, JSON.stringify(src), '->', problems);
        }
    });

    console.log(failed === 0 ? 'selftest passed' : `selftest failed ${failed} case(s)`);
    process.exit(failed === 0 ? 0 : 1);
}

if (process.argv.includes('--selftest')) selftest();

const base = process.argv[2] || fileURLToPath(new URL('..', import.meta.url));
const files = [];

const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
        if (entry === 'node_modules' || entry === '.git' || entry === 'tools') continue;
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) walk(full);
        else if (entry.endsWith('.lua')) files.push(full);
    }
};

walk(base);

let total = 0;

for (const file of files.sort()) {
    const problems = checkFile(file.replace(base, '').replace(/\\/g, '/').replace(/^\//, ''),
        readFileSync(file, 'utf8'));

    problems.forEach(p => console.log(p));
    total += problems.length;
}

console.log(total === 0
    ? `check-lua: ${files.length} file(s) clean`
    : `check-lua: ${total} problem(s) across ${files.length} file(s)`);

process.exit(total === 0 ? 0 : 1);
