Settings = { cache = {} }

local DEFAULTS = {
    wagersEnabled   = Config.Economy.wager.enabled,
    killstreaks     = Config.Killstreaks.enabled,
    friendlyFire    = Config.Rules.friendlyFire,
    autoBalance     = Config.Lobbies.autoBalance,
    allowSpectators = Config.Lobbies.allowSpectators,
    progression     = Config.Progression.enabled,
    maxLobbies      = Config.Lobbies.max,
    houseCut        = Config.Economy.wager.houseCut,
}

local function coerce(key, value)
    local default = DEFAULTS[key]
    if type(default) == 'boolean' then return Util.truthy(value) end
    if type(default) == 'number' then return tonumber(value) or default end
    return value
end

function Settings.Get(key)
    local value = Settings.cache[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function Settings.All()
    local out = {}
    for key, default in pairs(DEFAULTS) do
        local value = Settings.cache[key]
        out[key] = value == nil and default or value
    end
    return out
end

function Settings.Set(key, value)
    if DEFAULTS[key] == nil then return false end

    local clean = coerce(key, value)
    Settings.cache[key] = clean

    local stored = type(clean) == 'boolean' and (clean and '1' or '0') or tostring(clean)
    MySQL.prepare.await(
        'INSERT INTO xs_paintball_settings (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
        { key, stored })

    return true
end

function Settings.Load()
    local rows = MySQL.query.await('SELECT k, v FROM xs_paintball_settings') or {}
    for _, row in ipairs(rows) do
        if DEFAULTS[row.k] ~= nil then
            Settings.cache[row.k] = coerce(row.k, row.v)
        end
    end
end

function Settings.Defaults()
    return DEFAULTS
end
