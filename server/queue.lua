Queue = { waiting = {} }

local Q = Config.Queue

local function count()
    return Util.count(Queue.waiting)
end

local function broadcast()
    local size = count()
    local needed = math.max(2, Q.minPlayers)

    for src in pairs(Queue.waiting) do
        TriggerClientEvent('XS-Paintball:client:queue', src, { size = size, needed = needed })
    end
end

function Queue.Size()
    return count()
end

function Queue.Has(src)
    return Queue.waiting[src] ~= nil
end

function Queue.Join(src)
    if not Q.enabled then return false, 'Quick play is off.' end
    if Lobbies.ForSource(src) then return false, 'Leave your lobby first.' end
    if Queue.waiting[src] then return false, 'You are already queued.' end

    local allowed, why = Lobbies.CanJoin(src)
    if not allowed then return false, why end

    Queue.waiting[src] = os.time()
    broadcast()

    Queue.Tick()
    return true
end

function Queue.Leave(src)
    if not Queue.waiting[src] then return false end

    Queue.waiting[src] = nil
    TriggerClientEvent('XS-Paintball:client:queue', src, false)
    broadcast()

    return true
end

-- A mode that is enabled and has at least one map that can run it.
local function pickMode()
    if Q.mode ~= 'random' and Modes.Enabled(Q.mode) and #Store.Playable(Q.mode) > 0 then
        return Q.mode
    end

    local pool = {}
    for _, mode in ipairs(Modes.List()) do
        if #Store.Playable(mode.id) > 0 then pool[#pool + 1] = mode.id end
    end

    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

function Queue.Tick()
    if not Q.enabled then return end

    local needed = math.max(2, Q.minPlayers)
    if count() < needed then return end

    -- Anyone who wandered off or joined a lobby by hand loses their place.
    local ready = {}
    for src in pairs(Queue.waiting) do
        if not Lobbies.ForSource(src) and Lobbies.CanJoin(src) then
            ready[#ready + 1] = src
        else
            Queue.Leave(src)
        end
    end

    if #ready < needed then return end

    local mode = pickMode()
    if not mode then return end

    local host = ready[1]
    local lobby, err = Lobbies.Create(host, {
        name = 'Quick play',
        mode = mode,
    })

    if not lobby then
        for _, src in ipairs(ready) do
            Framework.Notify(src, err or 'Could not open a quick play lobby.', 'error')
        end
        return
    end

    Queue.waiting[host] = nil
    TriggerClientEvent('XS-Paintball:client:queue', host, false)

    for index = 2, #ready do
        local src = ready[index]
        local joined = Lobbies.Join(src, lobby.id, nil, false)

        Queue.waiting[src] = nil
        TriggerClientEvent('XS-Paintball:client:queue', src, false)

        if not joined then
            Framework.Notify(src, 'Quick play lobby filled up before you got in.', 'error')
        end
    end

    for src in pairs(lobby.players) do
        Framework.Notify(src, 'Quick play match found. Ready up.', 'success')
    end

    broadcast()
end

AddEventHandler('playerDropped', function()
    Queue.waiting[source] = nil
end)

CreateThread(function()
    while true do
        Wait(5000)

        if Q.enabled then
            local now = os.time()

            for src, since in pairs(Queue.waiting) do
                if now - since > Q.timeout then
                    Framework.Notify(src, 'Quick play timed out. Nobody else queued.', 'inform')
                    Queue.Leave(src)
                end
            end

            Queue.Tick()
        end
    end
end)
