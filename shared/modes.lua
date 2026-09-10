Modes = {}

local ORDER = { 'tdm', 'ffa', 'ctf', 'domination', 'confirmed', 'gungame', 'oitc', 'hyo' }

local REQUIREMENTS = {
    tdm        = { teamSpawns = true },
    ffa        = { ffaSpawns = true },
    ctf        = { teamSpawns = true, flags = true },
    domination = { teamSpawns = true, capturePoints = true },
    confirmed  = { teamSpawns = true },
    gungame    = { ffaSpawns = true },
    oitc       = { ffaSpawns = true },
    hyo        = { teamSpawns = true },
}

function Modes.Get(id)
    return Config.Modes[id]
end

function Modes.Requirements(id)
    return REQUIREMENTS[id] or {}
end

function Modes.IsTeamMode(id)
    local mode = Config.Modes[id]
    return mode ~= nil and (mode.teams or 0) > 0
end

function Modes.TeamCount(id)
    local mode = Config.Modes[id]
    if not mode then return 0 end
    return mode.teams or 0
end

function Modes.TeamsFor(id)
    local count = Modes.TeamCount(id)
    local out = {}
    for i = 1, count do
        out[#out + 1] = Config.TeamOrder[i]
    end
    return out
end

function Modes.DefaultScoreLimit(id)
    local mode = Config.Modes[id]
    return (mode and mode.scoreLimit) or Config.Rules.scoreLimit.default
end

function Modes.List()
    local out = {}
    for _, id in ipairs(ORDER) do
        local mode = Config.Modes[id]
        if mode and mode.enabled then
            out[#out + 1] = {
                id          = id,
                label       = mode.label,
                description = mode.description,
                teams       = mode.teams or 0,
                scoreLimit  = Modes.DefaultScoreLimit(id),
                requires    = REQUIREMENTS[id] or {},
            }
        end
    end
    return out
end

function Modes.Enabled(id)
    local mode = Config.Modes[id]
    return mode ~= nil and mode.enabled == true
end

function Modes.ScoreLabel(id)
    if id == 'domination' then return 'Points' end
    if id == 'ctf' then return 'Captures' end
    if id == 'gungame' then return 'Tier' end
    if id == 'hyo' then return 'Lives' end
    return 'Score'
end
