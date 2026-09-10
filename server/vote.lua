Vote = { open = {} }

local V = Config.MapVote

local function shuffled(list)
    local copy = {}
    for index, value in ipairs(list) do copy[index] = value end
    return Util.shuffle(copy)
end

local function pickOptions(lobby)
    local playable = Store.Playable(lobby.mode)
    if #playable < 2 then return nil end

    local pool = {}
    for _, entry in ipairs(playable) do
        if not (V.excludeCurrent and entry.id == lobby.mapId) or #playable <= V.options then
            pool[#pool + 1] = entry
        end
    end

    if #pool < 2 then pool = playable end

    pool = shuffled(pool)

    local out = {}
    for index = 1, math.min(V.options, #pool) do
        out[index] = { id = pool[index].id, name = pool[index].name }
    end

    return #out >= 2 and out or nil
end

-- Returns how long the caller should wait before tearing the lobby down, so a
-- vote is never cut off half way.
function Vote.Open(lobby)
    if not V.enabled then return 0 end

    local options = pickOptions(lobby)
    if not options then return 0 end

    Vote.open[lobby.id] = { options = options, votes = {}, closesAt = os.time() + V.seconds }

    Match.Broadcast(lobby, 'XS-Paintball:client:voteOpen', {
        options = options,
        seconds = V.seconds,
    })

    Match.Broadcast(lobby, 'XS-Paintball:client:sound', 'voteOpen')

    SetTimeout(V.seconds * 1000, function()
        Vote.Close(Lobbies.list[lobby.id])
    end)

    return V.seconds
end

function Vote.Cast(src, index)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false end

    local state = Vote.open[lobby.id]
    if not state then return false end

    index = tonumber(index)
    if not index or not state.options[index] then return false end

    state.votes[src] = index

    local tally = {}
    for _, choice in pairs(state.votes) do
        tally[choice] = (tally[choice] or 0) + 1
    end

    Match.Broadcast(lobby, 'XS-Paintball:client:voteTally', tally)
    TriggerClientEvent('XS-Paintball:client:sound', src, 'voteCast')

    return true
end

function Vote.Close(lobby)
    if not lobby then return end

    local state = Vote.open[lobby.id]
    if not state then return end

    Vote.open[lobby.id] = nil

    local tally = {}
    for _, choice in pairs(state.votes) do
        tally[choice] = (tally[choice] or 0) + 1
    end

    -- Highest count wins, and a tie is broken at random between the tied
    -- options rather than always falling to the first one.
    local best, bestCount = {}, 0
    for index in ipairs(state.options) do
        local count = tally[index] or 0
        if count > bestCount then
            best, bestCount = { index }, count
        elseif count == bestCount and count > 0 then
            best[#best + 1] = index
        end
    end

    if bestCount == 0 then
        best = {}
        for index in ipairs(state.options) do best[#best + 1] = index end
    end

    local winner = state.options[best[math.random(#best)]]
    if not winner then return end

    lobby.mapId = winner.id

    Match.Broadcast(lobby, 'XS-Paintball:client:voteResult', {
        name  = winner.name,
        votes = bestCount,
    })

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()
end

function Vote.Clear(lobbyId)
    Vote.open[lobbyId] = nil
end
