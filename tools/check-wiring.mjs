// Every call across the three boundaries in this resource is a plain string,
// and a typo in one of them fails silently: the panel button does nothing, the
// HUD never updates, the server never hears the event. This walks all four
// boundaries and reports anything that does not have a partner.
//
//   NUI endpoint   html/js  ->  RegisterNUICallback   client
//   ox_lib callback client   ->  lib.callback.register server
//   net event       client   ->  RegisterNetEvent      server
//   net event       server   ->  RegisterNetEvent      client
//   NUI message     client   ->  case in app.js / hud.js
//
//   node tools/check-wiring.mjs

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

const read = (relative) => readFileSync(join(root, relative), 'utf8');

const gather = (dir, extension) => {
    const out = [];
    const walk = (current) => {
        for (const entry of readdirSync(current)) {
            const full = join(current, entry);
            if (statSync(full).isDirectory()) walk(full);
            else if (entry.endsWith(extension)) out.push(full);
        }
    };
    walk(join(root, dir));
    return out.map(file => ({ file: file.replace(root, '').replace(/\\/g, '/'), src: readFileSync(file, 'utf8') }));
};

const matchAll = (src, regex) => [...src.matchAll(regex)].map(m => m[1]);

const clientLua = gather('client', '.lua');
const serverLua = gather('server', '.lua');
const bridgeLua = gather('bridge', '.lua');
const js = gather('html/js', '.js');

const clientSrc = clientLua.concat(bridgeLua).map(f => f.src).join('\n');
const serverSrc = serverLua.concat(bridgeLua).map(f => f.src).join('\n');
const jsSrc = js.map(f => f.src).join('\n');

const problems = [];
const notes = [];

// -- NUI endpoints ----------------------------------------------------------

const passthrough = new Set();
const listMatch = clientSrc.match(/local PASSTHROUGH = \{([\s\S]*?)\}/);
if (listMatch) {
    for (const name of matchAll(listMatch[1], /'([A-Za-z]+)'/g)) passthrough.add(name);
}

const registered = new Set(matchAll(clientSrc, /RegisterNUICallback\('([A-Za-z]+)'/g));
for (const name of passthrough) registered.add(name);

const called = new Set(matchAll(jsSrc, /\bnui\('([A-Za-z]+)'/g));

for (const name of called) {
    if (!registered.has(name)) problems.push(`NUI endpoint "${name}" is called from the panel but no client Lua registers it`);
}

for (const name of registered) {
    if (!called.has(name)) notes.push(`NUI endpoint "${name}" is registered but never called from the panel`);
}

// Everything in PASSTHROUGH forwards to a server callback of the same name.
const serverCallbacks = new Set(matchAll(serverSrc, /lib\.callback\.register\('XS-Paintball:([A-Za-z]+)'/g));

for (const name of passthrough) {
    if (!serverCallbacks.has(name)) problems.push(`PASSTHROUGH endpoint "${name}" has no lib.callback.register on the server`);
}

// -- ox_lib callbacks -------------------------------------------------------

const awaited = new Set(matchAll(clientSrc, /lib\.callback\.await\('XS-Paintball:([A-Za-z]+)'/g));

for (const name of awaited) {
    if (!serverCallbacks.has(name)) problems.push(`client awaits callback "${name}" that the server never registers`);
}

for (const name of serverCallbacks) {
    if (!awaited.has(name) && !passthrough.has(name)) {
        notes.push(`server callback "${name}" is never awaited by the client`);
    }
}

// -- net events -------------------------------------------------------------

const serverEventsRegistered = new Set(matchAll(serverSrc, /RegisterNetEvent\('(XS-Paintball:server:[A-Za-z]+)'/g));
const serverEventsTriggered = new Set(matchAll(clientSrc, /TriggerServerEvent\('(XS-Paintball:server:[A-Za-z]+)'/g));

for (const name of serverEventsTriggered) {
    if (!serverEventsRegistered.has(name)) problems.push(`client triggers "${name}" but the server does not register it`);
}

for (const name of serverEventsRegistered) {
    if (!serverEventsTriggered.has(name)) notes.push(`server registers "${name}" but nothing triggers it`);
}

const clientEventsRegistered = new Set(matchAll(clientSrc, /RegisterNetEvent\('(XS-Paintball:client:[A-Za-z]+)'/g));
const clientEventsTriggered = new Set(matchAll(serverSrc, /TriggerClientEvent\('(XS-Paintball:client:[A-Za-z]+)'/g));

// Some of them go out through the lobby broadcast helper rather than a direct
// TriggerClientEvent, so pick those names up too.
for (const name of matchAll(serverSrc, /\b(?:Match\.Broadcast|broadcast)\([A-Za-z]+, '(XS-Paintball:client:[A-Za-z]+)'/g)) {
    clientEventsTriggered.add(name);
}

for (const name of clientEventsTriggered) {
    if (!clientEventsRegistered.has(name)) problems.push(`server triggers "${name}" but the client does not register it`);
}

for (const name of clientEventsRegistered) {
    if (!clientEventsTriggered.has(name)) notes.push(`client registers "${name}" but the server never triggers it`);
}

// -- NUI messages -----------------------------------------------------------

const hudLua = read('client/hud.lua');
const hudSends = new Set(matchAll(hudLua, /\bsend\('([A-Za-z]+)'/g));
const hudCases = new Set(matchAll(read('html/js/hud.js'), /case '([A-Za-z]+)':/g));

for (const name of hudSends) {
    if (!hudCases.has(name)) problems.push(`client/hud.lua sends hud:${name} but hud.js has no case for it`);
}

for (const name of hudCases) {
    if (!hudSends.has(name)) notes.push(`hud.js handles hud:${name} but nothing sends it`);
}

const appSends = new Set(matchAll(clientSrc, /sendNui\('([A-Za-z]+)'/g));
const appCases = new Set(matchAll(read('html/js/app.js'), /case '([A-Za-z]+)':/g));

for (const name of appSends) {
    if (!appCases.has(name)) problems.push(`client sends the "${name}" panel message but app.js has no case for it`);
}

// -- mock coverage ----------------------------------------------------------

const mock = read('html/js/mock.js');
const mockHandlers = new Set(matchAll(mock, /^\s{8}([A-Za-z]+): \(/gm));

for (const name of called) {
    if (!mockHandlers.has(name)) notes.push(`mock.js has no handler for "${name}", so the browser preview cannot exercise it`);
}

// -- report -----------------------------------------------------------------

problems.forEach(p => console.log(`  broken  ${p}`));
notes.forEach(n => console.log(`  note    ${n}`));

console.log(problems.length === 0
    ? `check-wiring: every call has a partner (${notes.length} note(s))`
    : `check-wiring: ${problems.length} broken link(s)`);

process.exit(problems.length === 0 ? 0 : 1);
