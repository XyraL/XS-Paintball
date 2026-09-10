Lobbies = { list = {}, bySource = {}, nextId = 1 }

local L = Config.Lobbies

--[[ Who was in a fight recently.

     weaponDamageEvent is fired by the server itself for every hit, so this
     counts real damage and cannot be faked by a client. The shooter is free to
     record; resolving who got hit means walking the player list, so that part
     is throttled — a burst of fire from one person only costs one lookup a
     second. ]]

local lastCombat = {}
local lastResolve = {}

local function markCombat(src)
    if src and src > 0 then lastCombat[src] = os.time() end
end

local function resolveVictims(data)
    local ids = data and data.hitGlobalIds
    if type(ids) ~= 'table' or #ids == 0 then return end

    local wanted = {}
    for _, netId in ipairs(ids) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 then wanted[entity] = true end
    end

    if not next(wanted) then return end

    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        if wanted[GetPlayerPed(src)] then markCombat(src) end
    end
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    markCombat(src)

    local now = os.time()
    if src and (lastResolve[src] or 0) == now then return end
    if src then lastResolve[src] = now end

    resolveVictims(data)
end)

function Lobbies.SecondsSinceCombat(src)
    local last = lastCombat[src]
    if not last then return nil end
    return os.time() - last
end

-- Everything here is read on the server, so none of it can be spoofed.
function Lobbies.CanJoin(src)
    local R = Config.JoinRules or {}
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then return false, 'Could not find your character.' end

    if R.blockWhenDead and GetEntityHealth(ped) <= 0 then
        return false, 'Not while you are down.'
    end

    if R.blockInVehicle and GetVehiclePedIsIn(ped) ~= 0 then
        return false, 'Get out of the vehicle first.'
    end

    local cooldown = R.combatCooldown or 0
    if cooldown > 0 then
        local since = Lobbies.SecondsSinceCombat(src)
        if since and since < cooldown then
            return false, ('You were in a fight. Wait %d more second%s.')
                :format(cooldown - since, (cooldown - since) == 1 and '' or 's')
        end
    end

    if Config.Staging.enabled and R.requireStaging then
        local here = GetEntityCoords(ped)
        local c = Config.Staging.coords
        local dx, dy, dz = here.x - c.x, here.y - c.y, here.z - c.z

        if (dx * dx + dy * dy + dz * dz) > (Config.Staging.radius * Config.Staging.radius) then
            return false, 'Head to the paintball staging area to join a match.'
        end
    end

    return true
end

local function bucketFor(id)
    return L.bucketBase + (id % 200)
end

local function defaultRules(mode)
    return {
        scoreLimit   = Modes.DefaultScoreLimit(mode),
        timeLimit    = Config.Rules.timeLimit.default,
        respawnTime  = Config.Rules.respawnTime.default,
        spawnProtect = Config.Rules.spawnProtect.default,
        friendlyFire = Settings.Get('friendlyFire') == true,
        rounds       = Config.Rounds.enabled and Config.Rounds.default or 1,
    }
end

function Lobbies.Get(id)
    return Lobbies.list[tonumber(id) or -1]
end

function Lobbies.ForSource(src)
    local id = Lobbies.bySource[src]
    return id and Lobbies.list[id] or nil
end

function Lobbies.Count()
    return Util.count(Lobbies.list)
end

local function teamSizes(lobby)
    local sizes = {}
    for _, team in ipairs(Modes.TeamsFor(lobby.mode)) do sizes[team] = 0 end

    for _, player in pairs(lobby.players) do
        if not player.spectator and player.team and sizes[player.team] then
            sizes[player.team] = sizes[player.team] + 1
        end
    end

    return sizes
end

local function smallestTeam(lobby)
    local sizes = teamSizes(lobby)
    local best, bestCount

    for _, team in ipairs(Modes.TeamsFor(lobby.mode)) do
        local count = sizes[team] or 0
        if not bestCount or count < bestCount then
            best, bestCount = team, count
        end
    end

    return best
end

function Lobbies.PlayerCount(lobby, includeSpectators)
    local n = 0
    for _, player in pairs(lobby.players) do
        if includeSpectators or not player.spectator then n = n + 1 end
    end
    return n
end

function Lobbies.Roster(lobby)
    local out = {}

    for src, player in pairs(lobby.players) do
        out[#out + 1] = {
            source     = src,
            citizenid  = player.citizenid,
            name       = player.name,
            team       = player.team,
            ready      = player.ready,
            host       = player.citizenid == lobby.host,
            spectator  = player.spectator,
            level      = player.level,
            alive      = player.alive,
            kills      = player.kills,
            deaths     = player.deaths,
            assists    = player.assists,
            streak     = player.streak,
            score      = player.score,
            tier       = player.tier,
            lives      = player.lives,
            loadout    = player.loadout,
            ping       = GetPlayerPing(src),
        }
    end

    table.sort(out, function(a, b)
        if a.score ~= b.score then return (a.score or 0) > (b.score or 0) end
        return (a.name or '') < (b.name or '')
    end)

    return out
end

function Lobbies.Public(lobby)
    local map = Store.Get(lobby.mapId)
    local mode = Config.Modes[lobby.mode]

    return {
        id        = lobby.id,
        code      = lobby.code,
        name      = lobby.name,
        state     = lobby.state,
        mode      = lobby.mode,
        modeLabel = mode and mode.label or lobby.mode,
        map       = map and map.name or 'Unknown',
        mapId     = lobby.mapId,
        players   = Lobbies.PlayerCount(lobby),
        max       = lobby.maxPlayers,
        locked    = lobby.passcode ~= nil,
        wager     = lobby.wager,
        host      = lobby.hostName,
        teams     = Modes.TeamCount(lobby.mode),
        spectators = Lobbies.PlayerCount(lobby, true) - Lobbies.PlayerCount(lobby),
        timeLeft  = lobby.endsAt and math.max(0, lobby.endsAt - os.time()) or lobby.rules.timeLimit,
    }
end

function Lobbies.State(lobby)
    local map = Store.Get(lobby.mapId)

    return {
        id        = lobby.id,
        code      = lobby.code,
        name      = lobby.name,
        state     = lobby.state,
        mode      = lobby.mode,
        modeLabel = (Config.Modes[lobby.mode] or {}).label,
        scoreLabel = Modes.ScoreLabel(lobby.mode),
        mapId     = lobby.mapId,
        mapName   = map and map.name or 'Unknown',
        host      = lobby.host,
        hostName  = lobby.hostName,
        rules     = lobby.rules,
        wager     = lobby.wager,
        maxPlayers = lobby.maxPlayers,
        locked    = lobby.passcode ~= nil,
        roster    = Lobbies.Roster(lobby),
        scores    = lobby.scores,
        teams     = Modes.TeamsFor(lobby.mode),
        countdown = lobby.countdown,
        round     = lobby.round or 1,
        roundWins = lobby.roundWins or {},
        timeLeft  = lobby.endsAt and math.max(0, lobby.endsAt - os.time()) or lobby.rules.timeLimit,
        objectives = lobby.objectives,
        result    = lobby.result,
    }
end

function Lobbies.Sync(lobby)
    if not lobby then return end

    local state = Lobbies.State(lobby)
    for src in pairs(lobby.players) do
        TriggerClientEvent('XS-Paintball:client:lobbyState', src, state)
    end
end

function Lobbies.SyncBrowser()
    TriggerClientEvent('XS-Paintball:client:lobbyList', -1, Lobbies.List())
end

function Lobbies.List()
    local out = {}
    for _, lobby in pairs(Lobbies.list) do
        out[#out + 1] = Lobbies.Public(lobby)
    end

    table.sort(out, function(a, b)
        if a.state ~= b.state then return a.state == 'waiting' end
        return a.id < b.id
    end)

    return out
end

local function newPlayer(src, spectator)
    local citizenid = Framework.GetCitizenId(src)
    local name = Framework.GetName(src)
    local stats = Stats.Load(citizenid, name)

    return {
        source     = src,
        citizenid  = citizenid,
        name       = name,
        level      = stats.level or 1,
        team       = nil,
        ready      = false,
        spectator  = spectator == true,
        alive      = false,
        loadout    = Weapons.Sanitise(nil, stats.level),
        cosmetics  = Cosmetics.Sanitise({ tint = stats.tint, kit = stats.kit },
            { level = stats.level or 1, wins = stats.wins or 0 }),
        kills = 0, deaths = 0, assists = 0, headshots = 0, captures = 0,
        streak = 0, bestStreak = 0, score = 0,
        staked = 0,
        tier = 1,
        lives = nil,
        joinedAt = os.time(),
    }
end

function Lobbies.Create(src, opts)
    if Lobbies.ForSource(src) then return nil, 'You are already in a lobby.' end
    if Lobbies.Count() >= Settings.Get('maxLobbies') then return nil, 'Every lobby slot is in use.' end
    if Framework.IsBlockedJob(src) then return nil, 'You cannot play paintball on duty.' end

    opts = type(opts) == 'table' and opts or {}

    local mode = Modes.Enabled(opts.mode) and opts.mode or 'tdm'
    if not Modes.Enabled(mode) then
        local list = Modes.List()
        if #list == 0 then return nil, 'No game modes are enabled.' end
        mode = list[1].id
    end

    local playable = Store.Playable(mode)
    if #playable == 0 then return nil, 'No map supports that mode yet.' end

    local mapId = tonumber(opts.mapId)
    local found = false
    for _, entry in ipairs(playable) do
        if entry.id == mapId then found = true break end
    end
    if not found then mapId = playable[1].id end

    local id = Lobbies.nextId
    Lobbies.nextId = Lobbies.nextId + 1

    local hostName = Framework.GetName(src)
    local rules = defaultRules(mode)

    local lobby = {
        id         = id,
        code       = Util.code(5),
        name       = Util.trim(opts.name):sub(1, 32),
        host       = Framework.GetCitizenId(src),
        hostName   = hostName,
        passcode   = nil,
        bucket     = bucketFor(id),
        mapId      = mapId,
        mode       = mode,
        rules      = rules,
        wager      = Economy.ClampWager(opts.wager),
        maxPlayers = math.floor(Util.clamp(tonumber(opts.maxPlayers) or L.maxPlayers, 2, L.maxPlayers)),
        state      = 'waiting',
        createdAt  = os.time(),
        players    = {},
        scores     = {},
        objectives = {},
    }

    if lobby.name == '' then lobby.name = ('%s lobby'):format(hostName) end

    if L.allowPasscodes and type(opts.passcode) == 'string' then
        local code = Util.trim(opts.passcode)
        if code ~= '' then lobby.passcode = code:sub(1, 12) end
    end

    Lobbies.list[id] = lobby

    local ok, err = Lobbies.Join(src, id, lobby.passcode, false)
    if not ok then
        Lobbies.list[id] = nil
        return nil, err
    end

    Lobbies.SyncBrowser()
    return lobby
end

function Lobbies.Join(src, id, passcode, asSpectator)
    local lobby = Lobbies.Get(id)
    if not lobby then return false, 'That lobby is gone.' end
    if Lobbies.ForSource(src) then return false, 'Leave your current lobby first.' end
    if Framework.IsBlockedJob(src) then return false, 'You cannot play paintball on duty.' end

    if lobby.passcode and lobby.passcode ~= passcode then
        return false, 'Wrong passcode.'
    end

    if asSpectator then
        if not Settings.Get('allowSpectators') then return false, 'Spectating is off.' end
    else
        if lobby.state ~= 'waiting' and lobby.state ~= 'starting' then
            return false, 'That match has already started. You can spectate instead.'
        end
        if Lobbies.PlayerCount(lobby) >= lobby.maxPlayers then
            return false, 'That lobby is full.'
        end

        local allowed, why = Lobbies.CanJoin(src)
        if not allowed then return false, why end
    end

    local player = newPlayer(src, asSpectator)

    -- Into the waiting room, in its own bucket, remembering where they came
    -- from so leaving puts them back.
    if not asSpectator and Config.Staging.enabled then
        player.worldBucket = GetPlayerRoutingBucket(src)
        SetPlayerRoutingBucket(src, Config.Staging.bucket)
        TriggerClientEvent('XS-Paintball:client:staging', src, true)
    end

    if not asSpectator and Modes.IsTeamMode(lobby.mode) then
        player.team = smallestTeam(lobby)
    end

    lobby.players[src] = player
    Lobbies.bySource[src] = lobby.id

    if asSpectator and lobby.state == 'live' then
        Match.SendSpectator(lobby, src)
    end

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()

    return true
end

local function removePlayer(lobby, src, reason)
    local player = lobby.players[src]
    if not player then return end

    local inArena = lobby.state == 'live' or lobby.state == 'ended' or lobby.state == 'break'

    if inArena and not player.spectator then
        Match.ReleasePlayer(lobby, src, reason or 'left')
    elseif player.spectator then
        Match.ReleaseSpectator(src)
    end

    Voice.Leave(src)

    if player.worldBucket ~= nil then
        SetPlayerRoutingBucket(src, player.worldBucket)
        TriggerClientEvent('XS-Paintball:client:staging', src, false)
        player.worldBucket = nil
    end

    if player.staked and player.staked > 0 and lobby.state ~= 'ended' then
        Economy.Refund(src, player.staked)
        player.staked = 0
    end

    lobby.players[src] = nil
    Lobbies.bySource[src] = nil

    TriggerClientEvent('XS-Paintball:client:lobbyState', src, false)
end

function Lobbies.Destroy(lobby, reason)
    if not lobby then return end

    for src in pairs(lobby.players) do
        removePlayer(lobby, src, reason)
    end

    Lobbies.list[lobby.id] = nil
    Lobbies.SyncBrowser()
end

function Lobbies.Leave(src, reason)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false end

    local wasHost = lobby.players[src] and lobby.players[src].citizenid == lobby.host
    removePlayer(lobby, src, reason)

    if Lobbies.PlayerCount(lobby, true) == 0 then
        Lobbies.Destroy(lobby, 'empty')
        return true
    end

    if wasHost then
        for otherSrc, player in pairs(lobby.players) do
            if not player.spectator then
                lobby.host = player.citizenid
                lobby.hostName = player.name
                Framework.Notify(otherSrc, 'You are the host now.', 'inform')
                break
            end
        end
    end

    if lobby.state == 'live' then
        Match.CheckEnd(lobby)
    end

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()
    return true
end

function Lobbies.SetTeam(src, team)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false, 'You are not in a lobby.' end
    if lobby.state ~= 'waiting' then return false, 'Teams are locked once the match starts.' end

    local player = lobby.players[src]
    if not player or player.spectator then return false, 'Spectators have no team.' end
    if not Modes.IsTeamMode(lobby.mode) then return false, 'This mode has no teams.' end
    if not Util.contains(Modes.TeamsFor(lobby.mode), team) then return false, 'That team is not in play.' end

    local sizes = teamSizes(lobby)
    local target = sizes[team] or 0
    local smallest = math.huge

    for _, other in ipairs(Modes.TeamsFor(lobby.mode)) do
        smallest = math.min(smallest, sizes[other] or 0)
    end

    if target > smallest then return false, 'That team is already the bigger one.' end

    player.team = team
    player.ready = false
    Lobbies.Sync(lobby)
    return true
end

function Lobbies.SetReady(src, ready)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false end

    local player = lobby.players[src]
    if not player or player.spectator then return false end

    player.ready = ready == true
    Lobbies.Sync(lobby)

    Lobbies.MaybeAutoStart(lobby)
    return true
end

function Lobbies.SetLoadout(src, loadout)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false end

    local player = lobby.players[src]
    if not player then return false end

    player.loadout = Weapons.Sanitise(loadout, player.level)
    Lobbies.Sync(lobby)
    return true, player.loadout
end

function Lobbies.IsHost(lobby, src)
    local player = lobby.players[src]
    return player ~= nil and player.citizenid == lobby.host
end

function Lobbies.UpdateSettings(src, patch)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false, 'You are not in a lobby.' end
    if not Lobbies.IsHost(lobby, src) then return false, 'Only the host can change that.' end
    if lobby.state ~= 'waiting' then return false, 'The match has already started.' end
    if not L.liveSettings then return false, 'Lobby settings are locked on this server.' end

    patch = type(patch) == 'table' and patch or {}

    if patch.mode and Modes.Enabled(patch.mode) and patch.mode ~= lobby.mode then
        local playable = Store.Playable(patch.mode)
        if #playable == 0 then return false, 'No map supports that mode.' end

        lobby.mode = patch.mode
        lobby.rules.scoreLimit = Modes.DefaultScoreLimit(patch.mode)

        local ok = false
        for _, entry in ipairs(playable) do
            if entry.id == lobby.mapId then ok = true break end
        end
        if not ok then lobby.mapId = playable[1].id end

        for _, player in pairs(lobby.players) do
            player.ready = false
            if Modes.IsTeamMode(lobby.mode) then
                if not Util.contains(Modes.TeamsFor(lobby.mode), player.team) then
                    player.team = nil
                end
                if not player.spectator and not player.team then
                    player.team = smallestTeam(lobby)
                end
            else
                player.team = nil
            end
        end
    end

    if patch.mapId then
        local mapId = tonumber(patch.mapId)
        for _, entry in ipairs(Store.Playable(lobby.mode)) do
            if entry.id == mapId then
                lobby.mapId = mapId
                break
            end
        end
    end

    if patch.name then
        local name = Util.trim(patch.name):sub(1, 32)
        if name ~= '' then lobby.name = name end
    end

    if patch.passcode ~= nil and L.allowPasscodes then
        local code = Util.trim(tostring(patch.passcode))
        lobby.passcode = code ~= '' and code:sub(1, 12) or nil
    end

    if patch.wager ~= nil then
        lobby.wager = Economy.ClampWager(patch.wager)
    end

    if patch.maxPlayers then
        lobby.maxPlayers = math.floor(Util.clamp(tonumber(patch.maxPlayers) or L.maxPlayers,
            math.max(2, Lobbies.PlayerCount(lobby)), L.maxPlayers))
    end

    local R = Config.Rules
    local rules = type(patch.rules) == 'table' and patch.rules or {}

    if rules.scoreLimit then
        lobby.rules.scoreLimit = math.floor(Util.clamp(tonumber(rules.scoreLimit) or lobby.rules.scoreLimit,
            R.scoreLimit.min, R.scoreLimit.max))
    end
    if rules.timeLimit then
        lobby.rules.timeLimit = math.floor(Util.clamp(tonumber(rules.timeLimit) or lobby.rules.timeLimit,
            R.timeLimit.min, R.timeLimit.max))
    end
    if rules.respawnTime then
        lobby.rules.respawnTime = math.floor(Util.clamp(tonumber(rules.respawnTime) or lobby.rules.respawnTime,
            R.respawnTime.min, R.respawnTime.max))
    end
    if rules.spawnProtect then
        lobby.rules.spawnProtect = math.floor(Util.clamp(tonumber(rules.spawnProtect) or lobby.rules.spawnProtect,
            R.spawnProtect.min, R.spawnProtect.max))
    end
    if rules.friendlyFire ~= nil then
        lobby.rules.friendlyFire = rules.friendlyFire == true
    end
    if rules.rounds and Config.Rounds.enabled then
        if Util.contains(Config.Rounds.options, tonumber(rules.rounds)) then
            lobby.rules.rounds = tonumber(rules.rounds)
        end
    end

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()
    return true
end

function Lobbies.Kick(src, targetSource)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return false, 'You are not in a lobby.' end
    if not Lobbies.IsHost(lobby, src) then return false, 'Only the host can kick.' end

    targetSource = tonumber(targetSource)
    if targetSource == src then return false, 'Use leave instead.' end
    if not lobby.players[targetSource] then return false, 'They are not in this lobby.' end

    Framework.Notify(targetSource, 'The host removed you from the lobby.', 'error')
    Lobbies.Leave(targetSource, 'kicked')
    return true
end

function Lobbies.Balance(lobby)
    if not Settings.Get('autoBalance') then return end
    if not Modes.IsTeamMode(lobby.mode) then return end

    local teams = Modes.TeamsFor(lobby.mode)
    local pool = {}

    for src, player in pairs(lobby.players) do
        if not player.spectator then pool[#pool + 1] = src end
    end

    Util.shuffle(pool)

    for index, src in ipairs(pool) do
        lobby.players[src].team = teams[((index - 1) % #teams) + 1]
    end
end

function Lobbies.MaybeAutoStart(lobby)
    if lobby.state ~= 'waiting' then return end

    local count = Lobbies.PlayerCount(lobby)
    if count < math.max(2, L.minToStart) then return end

    for _, player in pairs(lobby.players) do
        if not player.spectator and not player.ready then return end
    end

    Lobbies.Start(nil, lobby)
end

-- force skips both the host check and the minimum player count. Only an admin
-- ever gets to pass it, which is what makes a one-player test match possible.
function Lobbies.Start(src, lobby, force)
    lobby = lobby or Lobbies.ForSource(src)
    if not lobby then return false, 'You are not in a lobby.' end
    if src and not force and not Lobbies.IsHost(lobby, src) then return false, 'Only the host can start.' end
    if lobby.state ~= 'waiting' then return false, 'It is already starting.' end

    local minimum = force and 1 or math.max(2, L.minToStart)
    local count = Lobbies.PlayerCount(lobby)

    if count < minimum then
        return false, ('You need at least %d player%s.'):format(minimum, minimum == 1 and '' or 's')
    end

    local map = Store.Get(lobby.mapId)
    if not map or not map.enabled then return false, 'That map is not available any more.' end
    if not Maps.SupportedModes(map)[lobby.mode] then return false, 'That map cannot run this mode.' end

    if lobby.wager > 0 or Config.Economy.ticketItem then
        for playerSrc in pairs(lobby.players) do
            local player = lobby.players[playerSrc]
            if not player.spectator then
                if not Economy.CanPay(playerSrc, lobby.wager) then
                    return false, ('%s cannot cover the wager.'):format(player.name)
                end
                if not Economy.HasTicket(playerSrc) then
                    return false, ('%s has no ticket.'):format(player.name)
                end
            end
        end

        for playerSrc, player in pairs(lobby.players) do
            if not player.spectator then
                local ok = Economy.TakeStake(playerSrc, lobby.wager)
                if ok then player.staked = lobby.wager end
            end
        end
    end

    Lobbies.Balance(lobby)

    lobby.state = 'starting'
    lobby.countdown = L.startCountdown

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()

    CreateThread(function()
        local lobbyId = lobby.id

        while lobby.countdown > 0 do
            Wait(1000)

            local current = Lobbies.list[lobbyId]
            if not current or current.state ~= 'starting' then return end

            current.countdown = current.countdown - 1
            Lobbies.Sync(current)
        end

        local current = Lobbies.list[lobbyId]
        if current and current.state == 'starting' then
            Match.Begin(current)
        end
    end)

    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    if Lobbies.bySource[src] then Lobbies.Leave(src, 'disconnected') end

    lastCombat[src] = nil
    lastResolve[src] = nil
end)

CreateThread(function()
    if not Config.Staging.enabled or not Config.Staging.clearPopulation then return end

    SetRoutingBucketPopulationEnabled(Config.Staging.bucket, false)
    SetRoutingBucketEntityLockdownMode(Config.Staging.bucket, 'relaxed')
end)

CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()
        for _, lobby in pairs(Lobbies.list) do
            if lobby.state == 'waiting'
                and Lobbies.PlayerCount(lobby, true) == 0
                and now - lobby.createdAt > L.idleTimeout then
                Lobbies.Destroy(lobby, 'idle')
            end
        end
    end
end)
