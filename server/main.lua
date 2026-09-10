--[[ Optional modules.

     This file loads last, so by now every other server file has had its turn.
     If one of them did not load — nearly always because it was missed when the
     folder was uploaded — the feature it carries should switch itself off and
     the console should say which file is missing. Before this, one absent file
     meant every panel request died on a nil index with a stack trace that
     pointed at the caller rather than the cause. ]]

local MISSING = {}

local function optional(name, file, stub)
    if _G[name] ~= nil then return end

    MISSING[#MISSING + 1] = file
    _G[name] = stub
end

optional('Queue', 'server/queue.lua', {
    Size = function() return 0 end,
    Has  = function() return false end,
    Join = function() return false, 'Quick play is not loaded on this server.' end,
    Leave = function() return false end,
    Tick = function() end,
})

optional('Vote', 'server/vote.lua', {
    Open  = function() return 0 end,
    Cast  = function() return false end,
    Close = function() end,
    Clear = function() end,
})

optional('Diagnose', 'server/diagnose.lua', {
    Run = function() return { '^1[XS-Paintball]^0 server/diagnose.lua did not load.' }, 1 end,
})

optional('Stash', 'server/loadout.lua', {
    Holding = function() return false end,
    Take    = function() return false end,
    Return  = function() return false end,
    Recover = function() end,
})

optional('Cosmetics', 'shared/cosmetics.lua', {
    Enabled     = function() return false end,
    Sanitise    = function() return { tint = 0, kit = 'none' } end,
    Catalogue   = function() return { tints = {}, kits = {} } end,
    GetKit      = function() return nil end,
    IsUnlocked  = function() return false end,
    DefaultTint = function() return 0 end,
    DefaultKit  = function() return 'none' end,
})

optional('Voice', 'bridge/voice.lua', {
    provider = 'none',
    Channel = function() return nil end,
    Join    = function() end,
    Leave   = function() end,
    Apply   = function() end,
})

if #MISSING > 0 then
    print(('^1[XS-Paintball]^0 %d file(s) did not load: %s'):format(#MISSING, table.concat(MISSING, ', ')))
    print('^3[XS-Paintball]^0 Those features are switched off for now. Re-upload the resource folder, including every file in fxmanifest.lua, then restart it.')
end

local function admin(src)
    return Framework.IsAdmin(src)
end

local function deny(reason)
    return { ok = false, error = reason }
end

local function ok(payload)
    payload = payload or {}
    payload.ok = true
    return payload
end

local function profileFor(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end

    Stats.Load(citizenid, Framework.GetName(src))
    return Stats.Profile(citizenid)
end

lib.callback.register('XS-Paintball:bootstrap', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return deny('No character loaded.') end

    local profile = profileFor(src)

    return ok({
        isAdmin   = admin(src),
        profile   = profile,
        loadouts  = Stats.LoadLoadouts(citizenid),
        lobbies   = Lobbies.List(),
        lobby     = (function()
            local lobby = Lobbies.ForSource(src)
            return lobby and Lobbies.State(lobby) or nil
        end)(),
        modes     = Modes.List(),
        maps      = Store.List(false),
        weapons   = Weapons.Catalogue(),
        ladder    = Weapons.GunGameLadder(),
        teams     = Config.Teams,
        teamOrder = Config.TeamOrder,
        rules     = Config.Rules,
        loadout   = {
            slots   = { primary = Config.Loadout.primary, secondary = Config.Loadout.secondary, melee = Config.Loadout.melee },
            presets = Config.Loadout.presets,
        },
        wager = {
            enabled = Economy.WagerEnabled(),
            min     = Config.Economy.wager.min,
            max     = Config.Economy.wager.max,
            default = Config.Economy.wager.default,
            account = Config.Economy.account,
        },
        cosmetics = Cosmetics.Enabled() and Cosmetics.Catalogue(profile) or nil,
        rounds = Config.Rounds.enabled and Config.Rounds.options or nil,
        queue = Config.Queue.enabled and {
            size   = Queue.Size(),
            needed = math.max(2, Config.Queue.minPlayers),
            queued = Queue.Has(src),
        } or nil,
        killstreaks = Config.Killstreaks.enabled and Config.Killstreaks.rewards or {},
        progression = {
            enabled  = Config.Progression.enabled,
            maxLevel = Config.Progression.maxLevel,
        },
        lobbyLimits = {
            maxPlayers = Config.Lobbies.maxPlayers,
            minToStart = Config.Lobbies.minToStart,
            passcodes  = Config.Lobbies.allowPasscodes,
            spectators = Settings.Get('allowSpectators'),
        },
        builder = {
            enabled    = Config.Builder.enabled,
            props      = Config.Builder.props,
            categories = Config.Builder.propCategories,
            limits     = Config.Builder.limits,
            weathers   = Maps.Weathers,
        },
    })
end)

lib.callback.register('XS-Paintball:lobbies', function(src)
    return ok({ lobbies = Lobbies.List() })
end)

lib.callback.register('XS-Paintball:createLobby', function(src, payload)
    local lobby, err = Lobbies.Create(src, payload)
    if not lobby then return deny(err) end
    return ok({ lobby = Lobbies.State(lobby) })
end)

lib.callback.register('XS-Paintball:joinLobby', function(src, payload)
    payload = payload or {}

    local id = tonumber(payload.id)
    if not id and type(payload.code) == 'string' then
        local wanted = payload.code:upper()
        for lobbyId, lobby in pairs(Lobbies.list) do
            if lobby.code == wanted then id = lobbyId break end
        end
        if not id then return deny('No lobby with that code.') end
    end

    local success, err = Lobbies.Join(src, id, payload.passcode, payload.spectate == true)
    if not success then return deny(err) end

    local lobby = Lobbies.ForSource(src)
    return ok({ lobby = lobby and Lobbies.State(lobby) or nil })
end)

lib.callback.register('XS-Paintball:leaveLobby', function(src)
    Lobbies.Leave(src, 'left')
    return ok()
end)

lib.callback.register('XS-Paintball:setTeam', function(src, payload)
    local success, err = Lobbies.SetTeam(src, (payload or {}).team)
    if not success then return deny(err) end
    return ok()
end)

lib.callback.register('XS-Paintball:setReady', function(src, payload)
    Lobbies.SetReady(src, (payload or {}).ready == true)
    return ok()
end)

lib.callback.register('XS-Paintball:setLoadout', function(src, payload)
    local success, loadout = Lobbies.SetLoadout(src, (payload or {}).loadout)
    if not success then
        local citizenid = Framework.GetCitizenId(src)
        local stats = citizenid and Stats.Get(citizenid)
        loadout = Weapons.Sanitise((payload or {}).loadout, stats and stats.level or 1)
    end
    return ok({ loadout = loadout })
end)

lib.callback.register('XS-Paintball:saveLoadoutPreset', function(src, payload)
    payload = payload or {}

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return deny('No character loaded.') end

    local stats = Stats.Load(citizenid, Framework.GetName(src))
    local clean = Weapons.Sanitise(payload.loadout, stats.level)

    Stats.SaveLoadout(citizenid, payload.slot, payload.label, clean)
    return ok({ loadouts = Stats.LoadLoadouts(citizenid) })
end)

lib.callback.register('XS-Paintball:setCosmetics', function(src, payload)
    if not Cosmetics.Enabled() then return deny('Cosmetics are off on this server.') end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return deny('No character loaded.') end

    Stats.Load(citizenid, Framework.GetName(src))

    local clean = Stats.SaveCosmetics(citizenid, (payload or {}).cosmetics)
    if not clean then return deny('Could not save that.') end

    -- Keep the copy the match will read in step with the saved one.
    local lobby = Lobbies.ForSource(src)
    if lobby and lobby.players[src] then
        lobby.players[src].cosmetics = clean
        Lobbies.Sync(lobby)
    end

    return ok({ cosmetics = clean, profile = profileFor(src) })
end)

lib.callback.register('XS-Paintball:updateLobby', function(src, payload)
    local success, err = Lobbies.UpdateSettings(src, payload)
    if not success then return deny(err) end
    return ok()
end)

lib.callback.register('XS-Paintball:kickPlayer', function(src, payload)
    local success, err = Lobbies.Kick(src, (payload or {}).source)
    if not success then return deny(err) end
    return ok()
end)

lib.callback.register('XS-Paintball:startMatch', function(src, payload)
    -- Force skips the host check and the minimum player count, so it is admin
    -- only. Without it this is the ordinary host start.
    local force = (payload or {}).force == true and admin(src)

    local success, err = Lobbies.Start(src, nil, force)
    if not success then return deny(err) end
    return ok()
end)

lib.callback.register('XS-Paintball:hostPanel', function(src)
    local lobby = Lobbies.ForSource(src)
    if not lobby then return deny('You are not in a lobby.') end

    local isHost = Lobbies.IsHost(lobby, src)
    if not isHost and not admin(src) then return deny('Only the host can do that.') end

    local map = Store.Get(lobby.mapId)

    return ok({
        roster = Lobbies.Roster(lobby),
        self   = src,
        mode   = (Config.Modes[lobby.mode] or {}).label,
        map    = map and map.name or nil,
        maps   = Store.Playable(lobby.mode),
        teams  = Modes.TeamsFor(lobby.mode),
        state  = lobby.state,
        round  = lobby.round or 1,
        rounds = lobby.rules.rounds or 1,
        admin  = admin(src),
    })
end)

lib.callback.register('XS-Paintball:hostAction', function(src, payload)
    payload = payload or {}

    local lobby = Lobbies.ForSource(src)
    if not lobby then return deny('You are not in a lobby.') end

    if not Lobbies.IsHost(lobby, src) and not admin(src) then
        return deny('Only the host can do that.')
    end

    local action = payload.action

    if action == 'end' then
        if not Match.ForceEnd(lobby) then return deny('No match running.') end
        Match.Broadcast(lobby, 'XS-Paintball:client:announce', { text = 'Host ended the match', tone = 'warning' })
        return ok()
    end

    if action == 'swap' then
        if lobby.state ~= 'live' and lobby.state ~= 'break' then return deny('No match running.') end
        Match.SwapSides(lobby)
        Lobbies.Sync(lobby)
        return ok()
    end

    if action == 'kick' then
        local success, err = Lobbies.Kick(src, payload.source)
        if not success then return deny(err) end
        return ok()
    end

    if action == 'restart' then
        if lobby.state ~= 'live' and lobby.state ~= 'break' then return deny('No match running.') end

        Match.Broadcast(lobby, 'XS-Paintball:client:announce', { text = 'Round restarting', tone = 'warning' })
        Match.Begin(lobby, true)
        return ok()
    end

    if action == 'map' then
        local mapId = tonumber(payload.mapId)
        local map = mapId and Store.Get(mapId)

        if not map or not Maps.SupportedModes(map)[lobby.mode] then
            return deny('That map cannot run this mode.')
        end

        lobby.mapId = mapId
        Lobbies.Sync(lobby)
        Lobbies.SyncBrowser()

        -- Takes effect next round, or next match if this is the last one.
        Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
            text = ('Next map: %s'):format(map.name), tone = 'inform',
        })

        return ok()
    end

    if action == 'balance' then
        if lobby.state ~= 'waiting' then return deny('Only between matches.') end
        Lobbies.Balance(lobby)
        Lobbies.Sync(lobby)
        return ok()
    end

    return deny('Unknown action.')
end)

lib.callback.register('XS-Paintball:mapsFor', function(src, payload)
    return ok({ maps = Store.Playable((payload or {}).mode) })
end)

lib.callback.register('XS-Paintball:stats', function(src, payload)
    payload = payload or {}

    return ok({
        profile     = profileFor(src),
        leaderboard = Stats.Leaderboard(payload.scope, payload.sortBy),
        history     = Stats.History(payload.limit or 20),
        scope       = payload.scope or 'all',
        weekly      = Config.Leaderboard.weekly,
    })
end)

lib.callback.register('XS-Paintball:leaderboardTop', function(src, payload)
    if not Config.Leaderboard.enabled then return ok({ rows = {} }) end

    local wanted = math.min(tonumber((payload or {}).limit) or 8, 15)
    local rows = Stats.Leaderboard('all', 'kills')
    local out = {}

    for index = 1, math.min(wanted, #rows) do
        out[index] = {
            name   = rows[index].name or rows[index].citizenid,
            kills  = rows[index].kills or 0,
            deaths = rows[index].deaths or 0,
            kd     = rows[index].kd,
        }
    end

    return ok({ rows = out })
end)

lib.callback.register('XS-Paintball:adminMaps', function(src)
    if not admin(src) then return deny('You are not allowed to do that.') end
    return ok({ maps = Store.List(true) })
end)

lib.callback.register('XS-Paintball:mapData', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local map = Store.Get((payload or {}).id)
    if not map then return deny('That map is gone.') end

    return ok({ map = map, check = Maps.Validate(map) })
end)

lib.callback.register('XS-Paintball:saveMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local map, err = Store.Save((payload or {}).map, Framework.GetName(src))
    if not map then return deny(err) end

    Lobbies.SyncBrowser()
    return ok({ map = map, check = Maps.Validate(map) })
end)

lib.callback.register('XS-Paintball:validateMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local map = Maps.Sanitise((payload or {}).map)
    return ok({ check = Maps.Validate(map), summary = Maps.Summary(map) })
end)

lib.callback.register('XS-Paintball:toggleMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    payload = payload or {}
    if not Store.SetEnabled(payload.id, payload.enabled == true) then return deny('That map is gone.') end

    Lobbies.SyncBrowser()
    return ok({ maps = Store.List(true) })
end)

lib.callback.register('XS-Paintball:renameMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    payload = payload or {}
    if not Store.Rename(payload.id, payload.name) then return deny('That name will not do.') end

    return ok({ maps = Store.List(true) })
end)

lib.callback.register('XS-Paintball:duplicateMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local map, err = Store.Duplicate((payload or {}).id, Framework.GetName(src))
    if not map then return deny(err) end

    return ok({ maps = Store.List(true), map = map })
end)

lib.callback.register('XS-Paintball:deleteMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local id = tonumber((payload or {}).id)

    for _, lobby in pairs(Lobbies.list) do
        if lobby.mapId == id and lobby.state ~= 'waiting' then
            return deny('A match is running on that map.')
        end
    end

    if not Store.Delete(id) then return deny('That map is gone already.') end

    for _, lobby in pairs(Lobbies.list) do
        if lobby.mapId == id then
            local playable = Store.Playable(lobby.mode)
            lobby.mapId = playable[1] and playable[1].id or nil
            Lobbies.Sync(lobby)
        end
    end

    Lobbies.SyncBrowser()
    return ok({ maps = Store.List(true) })
end)

lib.callback.register('XS-Paintball:exportMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local map = Store.Export((payload or {}).id)
    if not map then return deny('That map is gone.') end

    return ok({ map = map, json = json.encode(map) })
end)

lib.callback.register('XS-Paintball:importMap', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    local raw = (payload or {}).json
    local decoded = type(raw) == 'string' and json.decode(raw) or (payload or {}).map

    if type(decoded) ~= 'table' then return deny('That is not a map file.') end

    local map, err = Store.Import(decoded, Framework.GetName(src))
    if not map then return deny(err) end

    return ok({ maps = Store.List(true), map = map })
end)

lib.callback.register('XS-Paintball:settings', function(src, payload)
    if not admin(src) then return deny('You are not allowed to do that.') end

    payload = payload or {}

    if payload.set then
        for key, value in pairs(payload.set) do
            Settings.Set(key, value)
        end
    end

    return ok({ settings = Settings.All(), defaults = Settings.Defaults() })
end)


lib.callback.register('XS-Paintball:queue', function(src, payload)
    payload = payload or {}

    if payload.leave then
        Queue.Leave(src)
        return ok({ queued = false, size = Queue.Size() })
    end

    local success, why = Queue.Join(src)
    if not success then return deny(why) end

    return ok({ queued = true, size = Queue.Size(), needed = math.max(2, Config.Queue.minPlayers) })
end)

RegisterNetEvent('XS-Paintball:server:vote', function(index)
    Vote.Cast(source, index)
end)

RegisterNetEvent('XS-Paintball:server:position', function(coords)
    if type(coords) ~= 'table' then return end
    Match.Position(source, {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
    })
end)

RegisterNetEvent('XS-Paintball:server:damaged', function(attacker)
    local src = source
    local lobby = Lobbies.ForSource(src)
    if not lobby or lobby.state ~= 'live' then return end

    attacker = tonumber(attacker)
    if not attacker or not lobby.players[attacker] then return end

    Match.Damage(lobby, src, attacker)
    TriggerClientEvent('XS-Paintball:client:hitmarker', attacker)
end)

RegisterNetEvent('XS-Paintball:server:eliminated', function(payload)
    local src = source
    local lobby = Lobbies.ForSource(src)
    if not lobby or lobby.state ~= 'live' then return end

    payload = type(payload) == 'table' and payload or {}

    local killerSrc = tonumber(payload.killer)
    if killerSrc and not lobby.players[killerSrc] then killerSrc = nil end

    if killerSrc then
        local killer = lobby.players[killerSrc]
        local victim = lobby.players[src]

        if killer.position and victim.position and Util.dist3(killer.position, victim.position) > 500.0 then
            killerSrc = nil
        end
    end

    Match.Eliminate(lobby, src, killerSrc, payload.weapon, payload.headshot == true)
end)

RegisterNetEvent('XS-Paintball:server:touchFlag', function(team)
    if type(team) ~= 'string' then return end
    Objectives.TouchFlag(source, team)
end)

RegisterNetEvent('XS-Paintball:server:takeTag', function(tagId)
    Objectives.TakeTag(source, tagId)
end)

RegisterNetEvent('XS-Paintball:server:leave', function()
    Lobbies.Leave(source, 'left')
end)

RegisterNetEvent('XS-Paintball:server:saveOutfit', function(team, data)
    local src = source
    if not Config.TeamOutfits then return end
    if type(team) ~= 'string' or not Config.Teams[team] then return end
    if type(data) ~= 'table' then return end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return end

    Stats.SaveOutfit(citizenid, team, data)
    Framework.Notify(src, ('Saved your %s kit.'):format(Config.Teams[team].label), 'success')
end)

lib.callback.register('XS-Paintball:outfit', function(src, team)
    if not Config.TeamOutfits then return nil end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end

    return Stats.GetOutfit(citizenid, team)
end)

AddEventHandler('playerDropped', function()
    local citizenid = Framework.GetCitizenId(source)
    if citizenid then Stats.Drop(citizenid) end
end)

-- Routing buckets outlive the resource. Without this everyone in a match is
-- left in an empty world after a restart.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, lobby in pairs(Lobbies.list) do
        for src, player in pairs(lobby.players) do
            SetPlayerRoutingBucket(src, player.previousBucket or 0)

            if player.staked and player.staked > 0 and lobby.state ~= 'ended' then
                Economy.Refund(src, player.staked)
            end

            TriggerClientEvent('XS-Paintball:client:matchStop', src, 'resource stopped')
        end
    end
end)

exports('GetLobbies', function()
    return Lobbies.List()
end)

exports('IsInMatch', function(src)
    local lobby = Lobbies.ForSource(tonumber(src) or -1)
    return lobby ~= nil and lobby.state == 'live'
end)

exports('GetLobbyFor', function(src)
    local lobby = Lobbies.ForSource(tonumber(src) or -1)
    return lobby and Lobbies.Public(lobby) or nil
end)

exports('GetProfile', function(citizenid)
    if not citizenid then return nil end
    Stats.Load(citizenid, nil)
    return Stats.Profile(citizenid)
end)

exports('GetLeaderboard', function(scope, sortBy)
    return Stats.Leaderboard(scope, sortBy)
end)

exports('GetMaps', function()
    return Store.List(true)
end)

CreateThread(function()
    Wait(500)

    Settings.Load()

    local count = Store.Load()
    local added = Store.LoadPresets()

    print(('^5[XS-Paintball]^0 %d map(s) loaded%s'):format(
        count + added, added > 0 and (', %d from presets'):format(added) or ''))
end)
