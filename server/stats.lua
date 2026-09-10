Stats = { cache = {} }

local P = Config.Progression

function Stats.Threshold(level)
    if level <= 1 then return 0 end
    return math.floor(P.levelBase * ((level - 1) ^ P.levelCurve))
end

function Stats.LevelFor(xp)
    if not P.enabled then return 1 end

    local level = 1
    while level < P.maxLevel and xp >= Stats.Threshold(level + 1) do
        level = level + 1
    end
    return level
end

local function blank(citizenid, name)
    return {
        citizenid = citizenid, name = name,
        kills = 0, deaths = 0, assists = 0, headshots = 0, captures = 0,
        wins = 0, losses = 0, matches = 0, best_streak = 0, xp = 0, level = 1,
        tint = 0, kit = nil,
    }
end

function Stats.Load(citizenid, name)
    if Stats.cache[citizenid] then return Stats.cache[citizenid] end

    local row = MySQL.single.await('SELECT * FROM xs_paintball_stats WHERE citizenid = ?', { citizenid })

    if not row then
        row = blank(citizenid, name)
        MySQL.prepare.await('INSERT IGNORE INTO xs_paintball_stats (citizenid, name) VALUES (?, ?)',
            { citizenid, name })
    end

    row.level = Stats.LevelFor(row.xp or 0)
    Stats.cache[citizenid] = row

    return row
end

function Stats.Get(citizenid)
    return Stats.cache[citizenid]
end

function Stats.Profile(citizenid)
    local row = Stats.cache[citizenid]
    if not row then return nil end

    local level = row.level or 1
    local floorXp = Stats.Threshold(level)
    local nextXp  = level >= P.maxLevel and floorXp or Stats.Threshold(level + 1)
    local span    = math.max(1, nextXp - floorXp)

    return {
        citizenid  = row.citizenid or citizenid,
        name       = row.name,
        kills      = row.kills,
        deaths     = row.deaths,
        assists    = row.assists,
        headshots  = row.headshots,
        captures   = row.captures,
        wins       = row.wins,
        losses     = row.losses,
        matches    = row.matches,
        bestStreak = row.best_streak,
        xp         = row.xp,
        level      = level,
        levelFloor = floorXp,
        levelNext  = nextXp,
        levelPct   = math.min(100, math.floor(((row.xp - floorXp) / span) * 100)),
        kd         = row.deaths > 0 and Util.round(row.kills / row.deaths, 2) or row.kills,
        cosmetics  = Cosmetics.Sanitise({ tint = row.tint, kit = row.kit }, { level = level, wins = row.wins }),
    }
end

function Stats.SaveCosmetics(citizenid, choice)
    local row = Stats.cache[citizenid]
    if not row then return nil end

    local clean = Cosmetics.Sanitise(choice, { level = row.level or 1, wins = row.wins or 0 })

    row.tint = clean.tint
    row.kit  = clean.kit

    MySQL.prepare.await('UPDATE xs_paintball_stats SET tint = ?, kit = ? WHERE citizenid = ?',
        { clean.tint, clean.kit, citizenid })

    return clean
end

local function weekKey()
    return os.date('%Y-W%V')
end

function Stats.Apply(citizenid, name, delta)
    local row = Stats.Load(citizenid, name)

    row.name       = name or row.name
    row.kills      = row.kills + (delta.kills or 0)
    row.deaths     = row.deaths + (delta.deaths or 0)
    row.assists    = row.assists + (delta.assists or 0)
    row.headshots  = row.headshots + (delta.headshots or 0)
    row.captures   = row.captures + (delta.captures or 0)
    row.wins       = row.wins + (delta.wins or 0)
    row.losses     = row.losses + (delta.losses or 0)
    row.matches    = row.matches + (delta.matches or 0)
    row.xp         = math.max(0, row.xp + (delta.xp or 0))

    if (delta.streak or 0) > row.best_streak then row.best_streak = delta.streak end

    local before = row.level
    row.level = Stats.LevelFor(row.xp)

    MySQL.prepare.await([[
        UPDATE xs_paintball_stats
        SET name = ?, kills = ?, deaths = ?, assists = ?, headshots = ?, captures = ?,
            wins = ?, losses = ?, matches = ?, best_streak = ?, xp = ?, level = ?
        WHERE citizenid = ?
    ]], {
        row.name, row.kills, row.deaths, row.assists, row.headshots, row.captures,
        row.wins, row.losses, row.matches, row.best_streak, row.xp, row.level, citizenid,
    })

    if Config.Leaderboard.weekly then
        MySQL.prepare.await([[
            INSERT INTO xs_paintball_weekly (citizenid, week, name, kills, deaths, wins, xp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                kills = kills + VALUES(kills),
                deaths = deaths + VALUES(deaths),
                wins = wins + VALUES(wins),
                xp = xp + VALUES(xp)
        ]], {
            citizenid, weekKey(), row.name,
            delta.kills or 0, delta.deaths or 0, delta.wins or 0, delta.xp or 0,
        })
    end

    return row, row.level > before and row.level or nil
end

local SORTS = {
    kills = 'kills DESC, xp DESC',
    wins  = 'wins DESC, kills DESC',
    xp    = 'xp DESC, kills DESC',
    kd    = '(kills / GREATEST(deaths, 1)) DESC, kills DESC',
}

function Stats.Leaderboard(scope, sortBy)
    if not Config.Leaderboard.enabled then return {} end

    local order = SORTS[sortBy] or SORTS[Config.Leaderboard.sortBy] or SORTS.kills
    local size  = Config.Leaderboard.size

    if scope == 'weekly' and Config.Leaderboard.weekly then
        local rows = MySQL.query.await(([[
            SELECT citizenid, name, kills, deaths, wins, xp
            FROM xs_paintball_weekly WHERE week = ?
            ORDER BY %s LIMIT %d
        ]]):format(order, size), { weekKey() }) or {}

        for _, row in ipairs(rows) do
            row.kd = row.deaths > 0 and Util.round(row.kills / row.deaths, 2) or row.kills
        end
        return rows
    end

    local rows = MySQL.query.await(([[
        SELECT citizenid, name, kills, deaths, wins, losses, matches, xp, level
        FROM xs_paintball_stats ORDER BY %s LIMIT %d
    ]]):format(order, size)) or {}

    for _, row in ipairs(rows) do
        row.kd = row.deaths > 0 and Util.round(row.kills / row.deaths, 2) or row.kills
    end

    return rows
end

function Stats.RecordMatch(record)
    if not Config.History.enabled then return end

    MySQL.prepare.await([[
        INSERT INTO xs_paintball_history (map, mode, winner, duration, pot, players)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        record.map, record.mode, record.winner, record.duration, record.pot,
        json.encode(record.players or {}),
    })

    MySQL.prepare.await(([[
        DELETE FROM xs_paintball_history
        WHERE id NOT IN (SELECT id FROM (SELECT id FROM xs_paintball_history ORDER BY id DESC LIMIT %d) keep)
    ]]):format(math.floor(Config.History.keep)))
end

function Stats.History(limit)
    if not Config.History.enabled then return {} end

    local rows = MySQL.query.await(([[
        SELECT * FROM xs_paintball_history ORDER BY id DESC LIMIT %d
    ]]):format(math.floor(math.min(limit or 20, 50)))) or {}

    for _, row in ipairs(rows) do
        row.players = json.decode(row.players or '[]') or {}
    end

    return rows
end

function Stats.LoadLoadouts(citizenid)
    local rows = MySQL.query.await(
        'SELECT slot, label, data FROM xs_paintball_loadouts WHERE citizenid = ? ORDER BY slot',
        { citizenid }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            slot  = row.slot,
            label = row.label,
            data  = json.decode(row.data or '{}') or {},
        }
    end

    return out
end

function Stats.SaveLoadout(citizenid, slot, label, loadout)
    slot = math.floor(Util.clamp(tonumber(slot) or 1, 1, Config.Loadout.presets))

    MySQL.prepare.await([[
        INSERT INTO xs_paintball_loadouts (citizenid, slot, label, data)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), data = VALUES(data)
    ]], { citizenid, slot, Util.trim(label):sub(1, 32), json.encode(loadout) })

    return true
end

function Stats.SaveOutfit(citizenid, team, data)
    MySQL.prepare.await([[
        INSERT INTO xs_paintball_outfits (citizenid, team, data)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]], { citizenid, team, json.encode(data) })

    return true
end

function Stats.GetOutfit(citizenid, team)
    local row = MySQL.single.await(
        'SELECT data FROM xs_paintball_outfits WHERE citizenid = ? AND team = ?',
        { citizenid, team })

    if not row then return nil end
    return json.decode(row.data or 'null')
end

function Stats.Drop(citizenid)
    Stats.cache[citizenid] = nil
end
