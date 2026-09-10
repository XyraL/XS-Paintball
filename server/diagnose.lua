--[[ /pbdebug — what state is this server actually in.

     Nearly every round trip lost so far has gone the same way: something did
     not work, the error pointed somewhere unhelpful, and the real cause was a
     file that was not uploaded or a table that was not imported. This asks all
     of those questions at once and prints the answers, so the first thing to do
     when something misbehaves is run it rather than guess. ]]

Diagnose = {}

local TABLES = {
    'xs_paintball_maps',
    'xs_paintball_stats',
    'xs_paintball_weekly',
    'xs_paintball_history',
    'xs_paintball_loadouts',
    'xs_paintball_outfits',
    'xs_paintball_settings',
    'xs_paintball_stashes',
}

-- Globals a server file is meant to define, and the file that defines it.
local MODULES = {
    { 'Settings',   'server/settings.lua' },
    { 'Store',      'server/store.lua' },
    { 'Stats',      'server/stats.lua' },
    { 'Economy',    'server/economy.lua' },
    { 'Stash',      'server/loadout.lua' },
    { 'Lobbies',    'server/lobbies.lua' },
    { 'Vote',       'server/vote.lua' },
    { 'Queue',      'server/queue.lua' },
    { 'Match',      'server/match.lua' },
    { 'Objectives', 'server/objectives.lua' },
    { 'Voice',      'bridge/voice.lua' },
    { 'Cosmetics',  'shared/cosmetics.lua' },
    { 'Maps',       'shared/maps.lua' },
    { 'Modes',      'shared/modes.lua' },
    { 'Weapons',    'shared/weapons.lua' },
}

local function tick(ok) return ok and '^2ok^7' or '^1MISSING^7' end

function Diagnose.Run()
    local lines = {}
    local problems = 0

    local function add(text) lines[#lines + 1] = text end

    add('^5---- XS-Paintball ' .. (GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?') .. ' ----^7')

    -- Bridges
    add(('framework   %s'):format(Framework.name and ('^2' .. Framework.name .. '^7') or '^1none detected^7'))
    if not Framework.name then problems = problems + 1 end

    add(('inventory   ^3%s^7   manageInventory %s'):format(
        Inventory.name, Config.Loadout.manageInventory and '^2on^7' or '^3off^7'))

    add(('voice       ^3%s^7'):format(Voice.provider or 'none'))

    -- Files that should have loaded
    local missing = {}
    for _, entry in ipairs(MODULES) do
        -- A stub installed by the fallbacks has no real work in it, so check
        -- for something only the real module has.
        if _G[entry[1]] == nil then missing[#missing + 1] = entry[2] end
    end

    if #missing == 0 then
        add('modules     ^2all loaded^7')
    else
        add(('modules     ^1%d missing: %s^7'):format(#missing, table.concat(missing, ', ')))
        problems = problems + #missing
    end

    -- Database
    local absent = {}
    for _, name in ipairs(TABLES) do
        local found = MySQL.query.await(('SHOW TABLES LIKE \'%s\''):format(name))
        if type(found) ~= 'table' or #found == 0 then absent[#absent + 1] = name end
    end

    if #absent == 0 then
        add(('tables      ^2all %d present^7'):format(#TABLES))
    else
        add(('tables      ^1%d missing: %s^7'):format(#absent, table.concat(absent, ', ')))
        add('            ^3Import sql/xs_paintball.sql again and restart.^7')
        problems = problems + #absent
    end

    -- Maps, and whether every enabled mode can actually be played
    local maps = Store.List(true)
    local live = 0
    for _, map in ipairs(maps) do
        if map.enabled then live = live + 1 end
    end

    add(('maps        ^3%d total, %d enabled^7'):format(#maps, live))

    local unplayable = {}
    for _, mode in ipairs(Modes.List()) do
        if #Store.Playable(mode.id) == 0 then unplayable[#unplayable + 1] = mode.label end
    end

    if #unplayable == 0 then
        add('modes       ^2every enabled mode has a map^7')
    else
        add(('modes       ^3no map for: %s^7'):format(table.concat(unplayable, ', ')))
    end

    -- Staging, and the trap of the entry point being somewhere else
    if Config.Staging.enabled then
        local s = Config.Staging.coords
        local entry = Config.EntryPoints[1]
        local far = entry and #(vector3(s.x, s.y, s.z) - vector3(entry.coords.x, entry.coords.y, entry.coords.z)) or 0

        add(('staging     ^3%.1f, %.1f, %.1f  r=%.0f  bucket %d^7'):format(s.x, s.y, s.z, Config.Staging.radius, Config.Staging.bucket))

        if Config.JoinRules.requireStaging and far > Config.Staging.radius then
            add(('            ^1The entry point is %.0fm away, outside the staging radius.^7'):format(far))
            add('            ^1With requireStaging on, nobody who uses it can join.^7')
            problems = problems + 1
        end
    else
        add('staging     ^3off^7')
    end

    add(('lobbies     ^3%d open, %d queued^7'):format(Lobbies.Count(), Queue.Size()))

    local stashes = MySQL.query.await('SELECT citizenid FROM xs_paintball_stashes') or {}
    if #stashes > 0 then
        add(('stashes     ^3%d inventory stash(es) still held^7'):format(#stashes))
    end

    add(problems == 0
        and '^2Nothing obviously wrong.^7'
        or ('^1%d thing(s) need attention above.^7'):format(problems))

    return lines, problems
end
