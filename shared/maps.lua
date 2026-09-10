Maps = {}

local WEATHERS = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY',
    'RAIN', 'THUNDER', 'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD', 'HALLOWEEN',
}

Maps.Weathers = WEATHERS

local function num(v, fallback)
    v = tonumber(v)
    if v == nil then return fallback end
    return v
end

local function point(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = num(p.x), num(p.y), num(p.z)
    if not x or not y or not z then return nil end
    return {
        x = Util.round(x, 3),
        y = Util.round(y, 3),
        z = Util.round(z, 3),
        h = Util.round(num(p.h, 0.0), 1),
    }
end

local function pointList(list, limit)
    local out = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        local clean = point(p)
        if clean then
            out[#out + 1] = clean
            if limit and #out >= limit then break end
        end
    end
    return out
end

function Maps.EmptyMap()
    return {
        name        = 'New Map',
        description = '',
        author      = '',
        weather     = 'EXTRASUNNY',
        time        = 12,
        bounds      = { kind = 'circle', center = nil, radius = 80.0, points = {}, minZ = -20.0, maxZ = 60.0 },
        lobby       = nil,
        spawns      = { red = {}, blue = {}, green = {}, yellow = {}, ffa = {} },
        flags       = {},
        capturePoints = {},
        props       = {},
        spectate    = {},
    }
end

function Maps.Sanitise(data)
    data = type(data) == 'table' and data or {}
    local limits = Config.Builder.limits
    local map = Maps.EmptyMap()

    map.name        = Util.trim(data.name):sub(1, 48)
    map.description = Util.trim(data.description):sub(1, 200)
    map.author      = Util.trim(data.author):sub(1, 48)

    if map.name == '' then map.name = 'New Map' end

    map.weather = Util.contains(WEATHERS, data.weather) and data.weather or 'EXTRASUNNY'
    map.time    = math.floor(Util.clamp(num(data.time, 12), 0, 23))

    local bounds = type(data.bounds) == 'table' and data.bounds or {}
    map.bounds.kind   = bounds.kind == 'poly' and 'poly' or 'circle'
    map.bounds.center = point(bounds.center)
    map.bounds.radius = Util.round(Util.clamp(num(bounds.radius, 80.0), 5.0, 600.0), 1)
    map.bounds.points = pointList(bounds.points, limits.boundaryPoints)
    map.bounds.minZ   = Util.round(num(bounds.minZ, -20.0), 2)
    map.bounds.maxZ   = Util.round(num(bounds.maxZ, 60.0), 2)

    if map.bounds.maxZ <= map.bounds.minZ then
        map.bounds.maxZ = map.bounds.minZ + 10.0
    end

    map.lobby = point(data.lobby)

    local spawns = type(data.spawns) == 'table' and data.spawns or {}
    for _, team in ipairs(Config.TeamOrder) do
        map.spawns[team] = pointList(spawns[team], limits.spawnsPerTeam)
    end
    map.spawns.ffa = pointList(spawns.ffa, limits.spawnsPerTeam * 4)

    local flags = type(data.flags) == 'table' and data.flags or {}
    for _, team in ipairs(Config.TeamOrder) do
        local p = point(flags[team])
        if p then map.flags[team] = p end
    end

    local seen = {}
    for _, cp in ipairs(type(data.capturePoints) == 'table' and data.capturePoints or {}) do
        local p = point(cp)
        local id = Util.trim(cp.id):upper():sub(1, 2)

        if p and id ~= '' and not seen[id] then
            seen[id] = true
            map.capturePoints[#map.capturePoints + 1] = {
                id     = id,
                x      = p.x, y = p.y, z = p.z,
                radius = Util.round(Util.clamp(num(cp.radius, 6.0), 1.5, 40.0), 1),
            }
            if #map.capturePoints >= limits.capturePoints then break end
        end
    end

    for _, prop in ipairs(type(data.props) == 'table' and data.props or {}) do
        local p = point(prop)
        local model = Util.trim(prop.model)

        if p and model ~= '' then
            map.props[#map.props + 1] = {
                model = model:sub(1, 64),
                x = p.x, y = p.y, z = p.z,
                rx = Util.round(num(prop.rx, 0.0), 1),
                ry = Util.round(num(prop.ry, 0.0), 1),
                rz = Util.round(num(prop.rz, p.h or 0.0), 1),
                frozen = prop.frozen ~= false,
                -- Sit it on whatever is underneath rather than trusting the
                -- stored z. Props whose origin is their centre float without it.
                ground = prop.ground == true,
            }
            if #map.props >= limits.props then break end
        end
    end

    map.spectate = pointList(data.spectate, 8)

    if not map.bounds.center then
        map.bounds.center = Maps.DeriveCentre(map)
    end

    return map
end

function Maps.DeriveCentre(map)
    if map.bounds and map.bounds.kind == 'poly' and #map.bounds.points > 0 then
        local centre = Util.polygonCentre(map.bounds.points)
        centre.z = map.bounds.points[1].z
        return centre
    end

    local all = {}
    for _, team in ipairs(Config.TeamOrder) do
        for _, p in ipairs(map.spawns[team] or {}) do all[#all + 1] = p end
    end
    for _, p in ipairs(map.spawns.ffa or {}) do all[#all + 1] = p end

    if #all == 0 and map.lobby then return { x = map.lobby.x, y = map.lobby.y, z = map.lobby.z } end
    if #all == 0 then return { x = 0.0, y = 0.0, z = 0.0 } end

    return Util.polygonCentre(all)
end

function Maps.SupportedModes(map)
    local out = {}
    local teamsWithSpawns = 0

    for _, team in ipairs(Config.TeamOrder) do
        if #(map.spawns[team] or {}) > 0 then teamsWithSpawns = teamsWithSpawns + 1 end
    end

    local hasFfa   = #(map.spawns.ffa or {}) > 0
    local hasFlags = map.flags ~= nil and map.flags.red ~= nil and map.flags.blue ~= nil
    local hasPoints = #(map.capturePoints or {}) > 0

    for id, mode in pairs(Config.Modes) do
        if mode.enabled then
            local req = Modes.Requirements(id)
            local ok = true

            if req.teamSpawns and teamsWithSpawns < (mode.teams or 2) then ok = false end
            if req.ffaSpawns and not hasFfa then ok = false end
            if req.flags and not hasFlags then ok = false end
            if req.capturePoints and not hasPoints then ok = false end

            out[id] = ok
        end
    end

    return out
end

function Maps.Validate(map)
    local errors = {}
    local warnings = {}

    if map.bounds.kind == 'poly' then
        if #map.bounds.points < 3 then
            errors[#errors + 1] = 'A polygon boundary needs at least three points.'
        end
    elseif not map.bounds.center then
        errors[#errors + 1] = 'The boundary has no centre point.'
    end

    local supported = Maps.SupportedModes(map)
    local any = false
    for _, ok in pairs(supported) do
        if ok then any = true break end
    end

    if not any then
        errors[#errors + 1] = 'No game mode can run on this map yet. Add team spawns or free-for-all spawns.'
    end

    if not map.lobby then
        warnings[#warnings + 1] = 'No fallback point. Anyone spawning into a mode with no spawns placed lands at the arena centre.'
    end

    for _, team in ipairs({ 'red', 'blue' }) do
        local count = #(map.spawns[team] or {})
        if count > 0 and count < 3 then
            warnings[#warnings + 1] = ('%s only has %d spawn point(s). Three or more spreads players out.')
                :format(Config.Teams[team].label, count)
        end
    end

    if #(map.spawns.ffa or {}) > 0 and #map.spawns.ffa < 6 then
        warnings[#warnings + 1] = 'Free-for-all works better with six or more spawn points.'
    end

    if map.flags.red and not map.flags.blue then
        warnings[#warnings + 1] = 'Red has a flag stand but blue does not, so Capture The Flag is off.'
    end

    if #map.props > Config.Builder.limits.props * 0.8 then
        warnings[#warnings + 1] = 'This map is close to the prop limit.'
    end

    return {
        ok       = #errors == 0,
        errors   = errors,
        warnings = warnings,
        modes    = supported,
    }
end

function Maps.Summary(map)
    local spawnTotal = #(map.spawns.ffa or {})
    for _, team in ipairs(Config.TeamOrder) do
        spawnTotal = spawnTotal + #(map.spawns[team] or {})
    end

    local modes = Maps.SupportedModes(map)
    local list = {}
    for id, ok in pairs(modes) do
        if ok then list[#list + 1] = id end
    end
    table.sort(list)

    return {
        spawns   = spawnTotal,
        props    = #(map.props or {}),
        points   = #(map.capturePoints or {}),
        boundary = map.bounds.kind,
        radius   = map.bounds.radius,
        modes    = list,
    }
end

function Maps.InBounds(map, x, y, z)
    local b = map.bounds
    if z < b.minZ or z > b.maxZ then return false end

    if b.kind == 'poly' then
        if #b.points < 3 then return true end
        return Util.pointInPolygon(x, y, b.points)
    end

    local c = b.center
    if not c then return true end

    local dx, dy = x - c.x, y - c.y
    return (dx * dx + dy * dy) <= (b.radius * b.radius)
end
