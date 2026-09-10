-- Team voice for the duration of a match. Each team gets its own radio
-- channel, so a side can talk across the arena; proximity carries on working
-- underneath it, unchanged.
--
-- Only pma-voice is wired directly, because it is the one with a stable
-- server-side call for this. Every call is wrapped, so if an update changes
-- the signature the match still runs and only team voice goes quiet.

Voice = { provider = 'none' }

local V = Config.Voice
local forced = V.provider or 'auto'

if not V.enabled then
    Voice.provider = 'none'
elseif forced == 'none' then
    Voice.provider = 'none'
elseif forced == 'pma' or (forced == 'auto' and GetResourceState('pma-voice') == 'started') then
    Voice.provider = 'pma'
elseif forced == 'generic' or (forced == 'auto' and V.generic.resource ~= '') then
    if V.generic.resource ~= '' and V.generic.join ~= '' then
        Voice.provider = 'generic'
    end
end

local teamIndex = {}
for index, team in ipairs(Config.TeamOrder) do teamIndex[team] = index end

function Voice.Channel(lobbyId, team)
    local slot = teamIndex[team]
    if not slot then return nil end

    return V.channelBase + ((lobbyId % 400) * 8) + slot
end

function Voice.Join(src, channel)
    if Voice.provider == 'none' or not channel then return end

    if Voice.provider == 'pma' then
        pcall(function() exports['pma-voice']:setPlayerRadio(src, channel) end)
        return
    end

    pcall(function()
        exports[V.generic.resource][V.generic.join](nil, src, channel)
    end)
end

function Voice.Leave(src)
    if Voice.provider == 'none' then return end

    if Voice.provider == 'pma' then
        pcall(function() exports['pma-voice']:setPlayerRadio(src, 0) end)
        return
    end

    if V.generic.leave == '' then return end

    pcall(function()
        exports[V.generic.resource][V.generic.leave](nil, src)
    end)
end

-- Puts everyone on their team's channel, or takes them all off it.
function Voice.Apply(lobby, on)
    if Voice.provider == 'none' then return end
    if not Modes.IsTeamMode(lobby.mode) then return end

    for src, player in pairs(lobby.players) do
        if player.spectator then
            Voice.Leave(src)
        elseif on then
            Voice.Join(src, Voice.Channel(lobby.id, player.team))
        else
            Voice.Leave(src)
        end
    end
end

if Config.Debug then
    print(('^2[XS-Paintball]^0 voice bridge: %s'):format(Voice.provider))
end
