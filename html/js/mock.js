(() => {
    // Never let any of this run in game. GetParentResourceName only exists in
    // CEF, which is the reliable signal. The hostname check is the backstop and
    // has to fold case: the browser lowercases the URL host, while the resource
    // name keeps its capitals.
    if (typeof GetParentResourceName === 'function') return;
    if (location.hostname.toLowerCase() === RESOURCE.toLowerCase()) return;

    const TEAMS = {
        red:    { label: 'Red',    colour: [235, 64, 64],  blip: 1 },
        blue:   { label: 'Blue',   colour: [64, 130, 255], blip: 3 },
        green:  { label: 'Green',  colour: [48, 209, 88],  blip: 2 },
        yellow: { label: 'Yellow', colour: [245, 200, 36], blip: 5 },
    };

    const WEAPONS = [
        ['WEAPON_ASSAULTRIFLE', 'Assault Rifle', 'primary', 'rifle', 'Rifles', 0],
        ['WEAPON_CARBINERIFLE', 'Carbine', 'primary', 'rifle', 'Rifles', 0],
        ['WEAPON_SPECIALCARBINE', 'Special Carbine', 'primary', 'rifle', 'Rifles', 0],
        ['WEAPON_SMG', 'SMG', 'primary', 'smg', 'SMGs', 0],
        ['WEAPON_MICROSMG', 'Micro SMG', 'primary', 'smg', 'SMGs', 0],
        ['WEAPON_ASSAULTSMG', 'Assault SMG', 'primary', 'smg', 'SMGs', 0],
        ['WEAPON_PUMPSHOTGUN', 'Pump Shotgun', 'primary', 'shotgun', 'Shotguns', 0],
        ['WEAPON_HEAVYSHOTGUN', 'Heavy Shotgun', 'primary', 'shotgun', 'Shotguns', 12],
        ['WEAPON_SNIPERRIFLE', 'Sniper Rifle', 'primary', 'sniper', 'Snipers', 0],
        ['WEAPON_HEAVYSNIPER', 'Heavy Sniper', 'primary', 'sniper', 'Snipers', 15],
        ['WEAPON_MARKSMANRIFLE', 'Marksman Rifle', 'primary', 'sniper', 'Snipers', 10],
        ['WEAPON_COMBATMG', 'Combat MG', 'primary', 'lmg', 'Light Machine Guns', 20],
        ['WEAPON_PETROLCAN', 'Paint Sprayer', 'primary', 'special', 'Special', 0, true],
        ['WEAPON_PISTOL', 'Pistol', 'secondary', 'pistol', 'Sidearms', 0],
        ['WEAPON_COMBATPISTOL', 'Combat Pistol', 'secondary', 'pistol', 'Sidearms', 0],
        ['WEAPON_REVOLVER', 'Revolver', 'secondary', 'pistol', 'Sidearms', 0],
        ['WEAPON_KNIFE', 'Knife', 'melee', 'melee', 'Melee', 0],
        ['WEAPON_BAT', 'Bat', 'melee', 'melee', 'Melee', 0],
        ['WEAPON_MACHETE', 'Machete', 'melee', 'melee', 'Melee', 0],
    ].map(w => ({
        name: w[0], label: w[1], slot: w[2], category: w[3],
        categoryLabel: w[4], unlock: w[5], paint: w[6] === true,
    }));

    const MODES = [
        { id: 'tdm', label: 'Team Deathmatch', description: 'First team to the score limit wins.', teams: 2, scoreLimit: 60, requires: { teamSpawns: true } },
        { id: 'ffa', label: 'Free For All', description: 'Everyone for themselves.', teams: 0, scoreLimit: 25, requires: { ffaSpawns: true } },
        { id: 'ctf', label: 'Capture The Flag', description: 'Take the enemy flag back to your own.', teams: 2, scoreLimit: 3, requires: { teamSpawns: true, flags: true } },
        { id: 'domination', label: 'Domination', description: 'Hold the capture points.', teams: 2, scoreLimit: 200, requires: { teamSpawns: true, capturePoints: true } },
        { id: 'confirmed', label: 'Kill Confirmed', description: 'Kills only count once someone picks up the tag.', teams: 2, scoreLimit: 50, requires: { teamSpawns: true } },
        { id: 'gungame', label: 'Gun Game', description: 'Every kill moves you up the weapon ladder.', teams: 0, scoreLimit: 16, requires: { ffaSpawns: true } },
        { id: 'oitc', label: 'One In The Chamber', description: 'One bullet, one hit kill.', teams: 0, scoreLimit: 25, requires: { ffaSpawns: true } },
        { id: 'hyo', label: 'Hold Your Own', description: 'Each team shares a pool of lives.', teams: 2, scoreLimit: 30, requires: { teamSpawns: true } },
    ];

    const PROPS = [
        ['prop_barrier_work05', 'Work Barrier', 'barrier'],
        ['prop_barrier_work06a', 'Barrier Long', 'barrier'],
        ['prop_mp_barrier_02b', 'MP Barrier', 'barrier'],
        ['prop_barier_conc_01a', 'Concrete Block', 'barrier'],
        ['prop_container_01mb', 'Container', 'cover'],
        ['prop_boxpile_07d', 'Box Pile', 'cover'],
        ['prop_rub_carwreck_2', 'Car Wreck', 'cover'],
        ['prop_dumpster_02a', 'Dumpster', 'cover'],
        ['prop_crate_02a', 'Crate', 'crate'],
        ['prop_crate_11a', 'Crate Tall', 'crate'],
        ['prop_mil_crate_01', 'Military Crate', 'crate'],
        ['prop_pipes_conc_01', 'Concrete Pipes', 'industry'],
        ['prop_water_tank_01', 'Water Tank', 'industry'],
        ['prop_worklight_03b', 'Work Light', 'industry'],
        ['prop_bush_med_02', 'Bush', 'nature'],
        ['prop_tree_cedar_02', 'Cedar Tree', 'nature'],
        ['prop_haybale_01', 'Hay Bale', 'nature'],
        ['prop_offroad_tyres01', 'Tyre Stack', 'decor'],
    ].map(p => ({ model: p[0], label: p[1], category: p[2] }));


    const COSMETICS = {
        tints: [
            { id: 0, label: 'Standard', unlocked: true,  requires: null },
            { id: 1, label: 'Green',    unlocked: true,  requires: 'Level 5' },
            { id: 2, label: 'Gold',     unlocked: false, requires: 'Level 40' },
            { id: 3, label: 'Pink',     unlocked: true,  requires: 'Level 10' },
            { id: 4, label: 'Army',     unlocked: true,  requires: 'Level 15' },
            { id: 5, label: 'Blue',     unlocked: true,  requires: 'Level 20' },
            { id: 6, label: 'Orange',   unlocked: false, requires: 'Level 30' },
            { id: 7, label: 'Platinum', unlocked: false, requires: '50 wins' },
        ],
        kits: [
            { id: 'none',       label: 'Your own clothes', unlocked: true,  requires: null,      pieces: 0 },
            { id: 'recruit',    label: 'Recruit',          unlocked: true,  requires: null,      pieces: 4 },
            { id: 'skirmisher', label: 'Skirmisher',       unlocked: true,  requires: 'Level 10', pieces: 2 },
            { id: 'veteran',    label: 'Veteran',          unlocked: false, requires: 'Level 25', pieces: 3 },
            { id: 'paintdevil', label: 'Paint Devil',      unlocked: false, requires: '50 wins',  pieces: 2 },
        ],
    };

    const point = (x, y, z, h) => ({ x, y, z, h: h || 0 });

    const MAPS = [
        {
            id: 1, name: 'Nuketown', author: 'XyraL', description: 'Two houses, one street, no hiding.',
            enabled: true, preset: true, spawns: 18, props: 42, points: 3,
            boundary: 'circle', radius: 70, modes: ['tdm', 'ffa', 'ctf', 'domination', 'confirmed', 'gungame', 'oitc', 'hyo'],
            centre: point(-1305, -1400, 4.5),
        },
        {
            id: 2, name: 'Dock Yard', author: 'XyraL', description: 'Containers and long sightlines.',
            enabled: true, preset: true, spawns: 22, props: 96, points: 2,
            boundary: 'poly', radius: 0, modes: ['tdm', 'ffa', 'domination', 'confirmed', 'gungame', 'oitc', 'hyo'],
            centre: point(880, -3100, 5.9),
        },
        {
            id: 3, name: 'Quarry Pit', author: 'Marc', description: 'Long range, very little cover.',
            enabled: false, preset: false, spawns: 12, props: 18, points: 0,
            boundary: 'circle', radius: 140, modes: ['tdm', 'ffa', 'gungame', 'oitc', 'hyo'],
            centre: point(2950, 2790, 41.0),
        },
    ];

    const FULL_MAP = {
        id: 1, name: 'Nuketown', description: 'Two houses, one street, no hiding.', author: 'XyraL',
        weather: 'EXTRASUNNY', time: 12,
        bounds: { kind: 'circle', center: point(-1305, -1400, 4.5), radius: 70, points: [], minZ: -20, maxZ: 60 },
        lobby: point(-1310, -1408, 4.5, 90),
        spawns: {
            red: [point(-1290, -1380, 4.5, 180), point(-1284, -1386, 4.5, 175), point(-1296, -1374, 4.5, 190)],
            blue: [point(-1322, -1420, 4.5, 0), point(-1316, -1426, 4.5, 5), point(-1328, -1414, 4.5, 355)],
            green: [], yellow: [],
            ffa: [point(-1300, -1400, 4.5), point(-1310, -1390, 4.5), point(-1290, -1410, 4.5),
                  point(-1320, -1400, 4.5), point(-1300, -1420, 4.5), point(-1295, -1395, 4.5)],
        },
        flags: { red: point(-1288, -1378, 4.5), blue: point(-1324, -1422, 4.5) },
        capturePoints: [
            { id: 'A', x: -1296, y: -1388, z: 4.5, radius: 7 },
            { id: 'B', x: -1305, y: -1400, z: 4.5, radius: 8 },
            { id: 'C', x: -1316, y: -1412, z: 4.5, radius: 7 },
        ],
        props: [
            { model: 'prop_container_01mb', x: -1300, y: -1392, z: 4.5, rx: 0, ry: 0, rz: 45 },
            { model: 'prop_barrier_work05', x: -1310, y: -1404, z: 4.5, rx: 0, ry: 0, rz: 90 },
            { model: 'prop_crate_02a', x: -1298, y: -1406, z: 4.5, rx: 0, ry: 0, rz: 0 },
            { model: 'prop_dumpster_02a', x: -1314, y: -1394, z: 4.5, rx: 0, ry: 0, rz: 120 },
        ],
        spectate: [point(-1305, -1400, 30)],
    };

    const ROSTER = [
        { source: 1, citizenid: 'ABC12345', name: 'Vincent Valentine', team: 'red', ready: true, host: true, level: 24, alive: true, kills: 14, deaths: 6, assists: 3, score: 14, ping: 32, loadout: { primary: 'WEAPON_CARBINERIFLE', secondary: 'WEAPON_PISTOL', melee: 'WEAPON_KNIFE' } },
        { source: 2, citizenid: 'DEF67890', name: 'Nadia Kowalski', team: 'red', ready: true, host: false, level: 11, alive: false, kills: 9, deaths: 11, assists: 5, score: 9, ping: 44 },
        { source: 3, citizenid: 'GHI11223', name: 'Byron Whitfield', team: 'blue', ready: false, host: false, level: 31, alive: true, kills: 17, deaths: 8, assists: 2, score: 17, ping: 28 },
        { source: 4, citizenid: 'JKL44556', name: 'Terrence Obi', team: 'blue', ready: true, host: false, level: 7, alive: true, kills: 4, deaths: 13, assists: 6, score: 4, ping: 61 },
        { source: 5, citizenid: 'MNO77889', name: 'Hollis Barnes', team: 'blue', ready: true, host: false, level: 19, alive: true, kills: 11, deaths: 9, assists: 1, score: 11, ping: 37 },
    ];

    const LOBBIES = [
        { id: 1, code: 'K7QP2', name: 'Friday scrim', state: 'waiting', mode: 'tdm', modeLabel: 'Team Deathmatch', map: 'Nuketown', mapId: 1, players: 5, max: 12, locked: false, wager: 2500, host: 'Vincent Valentine', teams: 2, spectators: 0, timeLeft: 600 },
        { id: 2, code: 'M3XZ8', name: 'Gun game grind', state: 'live', mode: 'gungame', modeLabel: 'Gun Game', map: 'Dock Yard', mapId: 2, players: 8, max: 16, locked: false, wager: 0, host: 'Byron Whitfield', teams: 0, spectators: 2, timeLeft: 214 },
        { id: 3, code: 'B9RT4', name: 'Private — league', state: 'waiting', mode: 'ctf', modeLabel: 'Capture The Flag', map: 'Nuketown', mapId: 1, players: 2, max: 10, locked: true, wager: 10000, host: 'Hollis Barnes', teams: 2, spectators: 0, timeLeft: 900 },
    ];

    const LOBBY_STATE = {
        id: 1, code: 'K7QP2', name: 'Friday scrim', state: 'waiting',
        mode: 'tdm', modeLabel: 'Team Deathmatch', scoreLabel: 'Score',
        mapId: 1, mapName: 'Nuketown',
        host: 'ABC12345', hostName: 'Vincent Valentine',
        rules: { scoreLimit: 60, timeLimit: 600, respawnTime: 4, spawnProtect: 4, friendlyFire: false, rounds: 3 },
        round: 1, roundWins: {},
        wager: 2500, maxPlayers: 12, locked: false,
        roster: ROSTER, scores: { red: 0, blue: 0 }, teams: ['red', 'blue'],
        countdown: null, timeLeft: 600, objectives: {}, result: null,
    };

    const SETTINGS = {
        wagersEnabled: true, killstreaks: true, friendlyFire: false, autoBalance: true,
        allowSpectators: true, progression: true, maxLobbies: 8, houseCut: 0.05,
    };

    const BOOT = {
        ok: true,
        isAdmin: true,
        profile: {
            citizenid: 'ABC12345', name: 'Vincent Valentine',
            kills: 1284, deaths: 902, assists: 210, headshots: 331, captures: 44,
            wins: 96, losses: 71, matches: 167, bestStreak: 14,
            cosmetics: { tint: 4, kit: 'recruit' },
            xp: 18420, level: 24, levelFloor: 17800, levelNext: 19400, levelPct: 39, kd: 1.42,
        },
        loadouts: [
            { slot: 1, label: 'Long range', data: { primary: 'WEAPON_MARKSMANRIFLE', secondary: 'WEAPON_PISTOL', melee: 'WEAPON_KNIFE' } },
            { slot: 2, label: 'Rush', data: { primary: 'WEAPON_ASSAULTSMG', secondary: 'WEAPON_REVOLVER', melee: 'WEAPON_MACHETE' } },
        ],
        lobbies: LOBBIES,
        lobby: null,
        modes: MODES,
        maps: MAPS,
        weapons: WEAPONS,
        ladder: ['WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTRIFLE', 'WEAPON_PUMPSHOTGUN', 'WEAPON_SNIPERRIFLE', 'WEAPON_PISTOL', 'WEAPON_KNIFE']
            .map(n => ({ name: n, label: (WEAPONS.find(w => w.name === n) || {}).label || n })),
        teams: TEAMS,
        teamOrder: ['red', 'blue', 'green', 'yellow'],
        rules: {
            scoreLimit: { default: 30, min: 5, max: 150 },
            timeLimit: { default: 600, min: 120, max: 1800 },
            respawnTime: { default: 4, min: 0, max: 15 },
            spawnProtect: { default: 4, min: 0, max: 10 },
        },
        loadout: { slots: { primary: true, secondary: true, melee: true }, presets: 3 },
        wager: { enabled: true, min: 0, max: 25000, default: 0, account: 'cash' },
        cosmetics: COSMETICS,
        rounds: [1, 3, 5, 7],
        queue: { size: 1, needed: 4, queued: false },
        killstreaks: [
            { id: 'uav', label: 'UAV', kills: 4, description: 'Every enemy shows on your team radar.' },
            { id: 'resupply', label: 'Resupply', kills: 6, description: 'Full ammo, instantly.' },
            { id: 'armour', label: 'Paint Vest', kills: 7, description: 'Adds to your paint pool for this life.' },
            { id: 'deathmachine', label: 'Death Machine', kills: 10, description: 'A minigun, for a little while.' },
        ],
        progression: { enabled: true, maxLevel: 100 },
        lobbyLimits: { maxPlayers: 24, minToStart: 2, passcodes: true, spectators: true },
        builder: {
            enabled: true,
            props: PROPS,
            categories: [
                { id: 'barrier', label: 'Barriers' }, { id: 'cover', label: 'Cover' },
                { id: 'crate', label: 'Crates' }, { id: 'industry', label: 'Industrial' },
                { id: 'nature', label: 'Nature' }, { id: 'decor', label: 'Decor' },
            ],
            limits: { props: 400, spawnsPerTeam: 32, capturePoints: 5, boundaryPoints: 32 },
            weathers: ['EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY', 'RAIN', 'THUNDER', 'SNOW'],
        },
    };

    const check = (map) => ({
        ok: true,
        errors: [],
        warnings: (map && map.lobby) ? [] : ['No staging point. Players will wait at the arena centre.'],
        modes: {
            tdm: true, ffa: true, ctf: !!(map && map.flags && map.flags.red && map.flags.blue),
            domination: !!(map && map.capturePoints && map.capturePoints.length),
            confirmed: true, gungame: true, oitc: true, hyo: true,
        },
    });

    let workingMap = null;

    const HANDLERS = {
        bootstrap: () => BOOT,
        lobbies: () => ({ ok: true, lobbies: LOBBIES }),
        mapsFor: (body) => ({ ok: true, maps: MAPS.filter(m => m.enabled && m.modes.includes(body.mode)) }),
        createLobby: () => ({ ok: true, lobby: LOBBY_STATE }),
        joinLobby: () => ({ ok: true, lobby: LOBBY_STATE }),
        leaveLobby: () => ({ ok: true }),
        setTeam: () => ({ ok: true }),
        setReady: () => ({ ok: true }),
        setLoadout: (body) => ({ ok: true, loadout: body.loadout }),
        queue: (body) => {
            if (body.leave) {
                BOOT.queue = { size: 0, needed: 4, queued: false };
                return { ok: true, queued: false, size: 0, needed: 4 };
            }
            BOOT.queue = { size: 2, needed: 4, queued: true };
            return { ok: true, queued: true, size: 2, needed: 4 };
        },
        setCosmetics: (body) => {
            BOOT.profile.cosmetics = body.cosmetics;
            return { ok: true, cosmetics: body.cosmetics, profile: BOOT.profile };
        },
        saveLoadoutPreset: () => ({ ok: true, loadouts: BOOT.loadouts }),
        updateLobby: () => ({ ok: true }),
        kickPlayer: () => ({ ok: true }),
        startMatch: () => ({ ok: true }),
        stats: () => ({
            ok: true,
            profile: BOOT.profile,
            weekly: true,
            leaderboard: ROSTER.map((r, i) => ({
                citizenid: r.citizenid, name: r.name,
                kills: 400 - i * 63, deaths: 300 - i * 40, wins: 40 - i * 6,
                xp: 20000 - i * 2600, kd: ((400 - i * 63) / (300 - i * 40)).toFixed(2),
            })),
            history: [
                { map: 'Nuketown', mode: 'tdm', winner: 'red', duration: 512, pot: 15000, players: ROSTER },
                { map: 'Dock Yard', mode: 'gungame', winner: 'Byron Whitfield', duration: 388, pot: 0, players: ROSTER },
                { map: 'Nuketown', mode: 'ctf', winner: 'blue', duration: 604, pot: 40000, players: ROSTER },
            ],
        }),
        adminMaps: () => ({ ok: true, maps: MAPS }),
        mapData: () => { workingMap = JSON.parse(JSON.stringify(FULL_MAP)); return { ok: true, map: workingMap, check: check(workingMap) }; },
        saveMap: (body) => ({ ok: true, map: body.map, check: check(body.map) }),
        validateMap: (body) => ({ ok: true, check: check(body.map), summary: {} }),
        toggleMap: (body) => {
            const map = MAPS.find(m => m.id === body.id);
            if (map) map.enabled = body.enabled;
            return { ok: true, maps: MAPS };
        },
        renameMap: (body) => {
            const map = MAPS.find(m => m.id === body.id);
            if (map) map.name = body.name;
            return { ok: true, maps: MAPS };
        },
        duplicateMap: () => ({ ok: true, maps: MAPS }),
        deleteMap: (body) => ({ ok: true, maps: MAPS.filter(m => m.id !== body.id) }),
        exportMap: () => ({ ok: true, map: FULL_MAP, json: JSON.stringify(FULL_MAP, null, 2) }),
        importMap: () => ({ ok: true, maps: MAPS }),
        settings: (body) => {
            if (body && body.set) Object.assign(SETTINGS, body.set);
            return { ok: true, settings: SETTINGS, defaults: SETTINGS };
        },
        builderOpen: (body) => {
            workingMap = body.map ? JSON.parse(JSON.stringify(body.map)) : JSON.parse(JSON.stringify(FULL_MAP));
            if (!body.map) {
                workingMap.id = null;
                workingMap.name = 'New Map';
            }
            return { ok: true, map: workingMap };
        },
        builderClose: () => ({ ok: true }),
        builderSync: (body) => { workingMap = body.map; return { ok: true, map: workingMap }; },
        builderPreview: () => ({ ok: true }),
        builderLook: () => ({ ok: true }),
        builderTeleport: () => ({ ok: true }),
        builderPlace: (body) => {
            const map = workingMap;
            const spot = { x: -1300 + Math.random() * 20, y: -1400 + Math.random() * 20, z: 4.5, h: Math.floor(Math.random() * 360) };

            if (body.kind === 'spawn') (map.spawns[body.team] = map.spawns[body.team] || []).push(spot);
            else if (body.kind === 'flag') map.flags[body.team] = spot;
            else if (body.kind === 'capture') map.capturePoints.push({ id: 'ABCDE'[map.capturePoints.length] || 'A', x: spot.x, y: spot.y, z: spot.z, radius: 8 });
            else if (body.kind === 'lobby') map.lobby = spot;
            else if (body.kind === 'spectate') map.spectate.push(spot);
            else if (body.kind === 'boundary') { map.bounds.kind = 'poly'; map.bounds.points.push(spot); }
            else if (body.kind === 'centre') { map.bounds.kind = 'circle'; map.bounds.center = spot; map.bounds.radius = 80; }
            else if (body.kind === 'prop') map.props.push({ model: body.model, x: spot.x, y: spot.y, z: spot.z, rx: 0, ry: 0, rz: spot.h });

            return { ok: true, map };
        },
        builderRemove: (body) => {
            const map = workingMap;

            if (body.kind === 'spawn') map.spawns[body.team].splice(body.index - 1, 1);
            else if (body.kind === 'flag') delete map.flags[body.team];
            else if (body.kind === 'capture') map.capturePoints.splice(body.index - 1, 1);
            else if (body.kind === 'prop') map.props.splice(body.index - 1, 1);
            else if (body.kind === 'spectate') map.spectate.splice(body.index - 1, 1);
            else if (body.kind === 'boundary') map.bounds.points.splice(body.index - 1, 1);
            else if (body.kind === 'lobby') map.lobby = null;

            return { ok: true, map };
        },
        hostPanel: () => ({ ok: true, roster: ROSTER, self: 1, mode: 'Team Deathmatch', map: 'Nuketown', maps: MAPS.filter(m => m.enabled), teams: ['red', 'blue'], state: 'live', round: 2, rounds: 3, admin: true }),
        hostAction: () => ({ ok: true }),
        hostClose: () => ({ ok: true }),
        close: () => ({ ok: true }),
    };

    const realFetch = window.fetch.bind(window);

    window.fetch = async (url, options) => {
        const target = String(url);
        if (!target.toLowerCase().includes(`${RESOURCE.toLowerCase()}/`)) return realFetch(url, options);

        const endpoint = target.split('/').pop();
        const body = options && options.body ? JSON.parse(options.body) : {};
        const handler = HANDLERS[endpoint];

        const payload = handler ? handler(body) : { ok: false, error: `No mock for ${endpoint}` };

        await new Promise(r => setTimeout(r, 40));
        return { json: async () => payload };
    };

    function demoHud() {
        hudHandle('self', 1);
        hudHandle('start', {
            mode: 'tdm', modeLabel: 'Team Deathmatch', map: 'Nuketown',
            team: 'red', teams: ['red', 'blue'], teamData: TEAMS,
            scoreLimit: 60, scoreLabel: 'Score', timeLeft: 428,
            paint: 72, paintMax: 100, wager: 2500, spectator: false,
        });

        hudHandle('update', { scores: { red: 41, blue: 37 }, roster: ROSTER, timeLeft: 428 });
        hudHandle('paint', { current: 72, max: 100 });
        hudHandle('protection', 0);
        hudHandle('streak', { label: 'UAV', remaining: 18 });

        hudHandle('killfeed', { killer: 'Vincent Valentine', killerTeam: 'red', victim: 'Terrence Obi', victimTeam: 'blue', weapon: 'Carbine', headshot: true });
        hudHandle('killfeed', { killer: 'Byron Whitfield', killerTeam: 'blue', victim: 'Nadia Kowalski', victimTeam: 'red', weapon: 'Assault SMG' });
        hudHandle('announce', { text: 'UAV overhead', tone: 'inform' });
    }

    window.PB_DEMO = {
        hud: demoHud,
        scoreboard: (on) => hudHandle('scoreboard', on !== false),
        respawn: () => { hudHandle('state', { state: 'dead' }); hudHandle('respawn', 4); },
        result: () => hudHandle('result', { winnerTeam: 'red', pot: 15000, share: 6800, duration: 512 }),
        stop: () => hudHandle('stop'),
        vote: () => hudHandle('vote', { options: [{ id: 1, name: 'Nuketown' }, { id: 2, name: 'Dock Yard' }, { id: 3, name: 'Quarry Pit' }], seconds: 20 }),
        voteTally: () => hudHandle('voteTally', { 1: 3, 2: 5, 3: 1 }),
        round: () => hudHandle('round', { round: 2, rounds: 3, winnerTeam: 'blue', roundWins: { red: 1, blue: 1 }, breakSeconds: 12, teams: ['red', 'blue'] }),
        queue: () => hudHandle('queue', { size: 2, needed: 4 }),
        host: () => window.postMessage({ action: 'host', data: { ok: true, roster: ROSTER, self: 1, mode: 'Team Deathmatch', map: 'Nuketown', maps: MAPS.filter(m => m.enabled), teams: ['red', 'blue'], state: 'live', round: 2, rounds: 3, admin: true } }, '*'),
        panel: (tab) => window.postMessage({ action: 'open', data: { boot: BOOT, tab: tab || 'play' } }, '*'),
    };

    window.addEventListener('load', () => {
        window.postMessage({ action: 'open', data: { boot: BOOT, tab: 'play' } }, '*');
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'h') demoHud();
        if (event.key === 'j') hudHandle('scoreboard', true);
        if (event.key === 'k') hudHandle('scoreboard', false);
    });
})();
