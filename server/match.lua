Match = { live = {} }

local L = Config.Lobbies

local function playersOf(lobby, includeSpectators)
    local out = {}
    for src, player in pairs(lobby.players) do
        if includeSpectators or not player.spectator then out[#out + 1] = src end
    end
    return out
end

local function broadcast(lobby, event, ...)
    for src in pairs(lobby.players) do
        TriggerClientEvent(event, src, ...)
    end
end

Match.Broadcast = broadcast

local function spawnPool(lobby, player)
    local map = Store.Get(lobby.mapId)
    if not map then return {} end

    if Modes.IsTeamMode(lobby.mode) and player.team then
        local list = map.spawns[player.team]
        if list and #list > 0 then return list end
    end

    if #(map.spawns.ffa or {}) > 0 then return map.spawns.ffa end

    for _, team in ipairs(Config.TeamOrder) do
        if #(map.spawns[team] or {}) > 0 then return map.spawns[team] end
    end

    return {}
end

function Match.PickSpawn(lobby, src)
    local player = lobby.players[src]
    if not player then return nil end

    local pool = spawnPool(lobby, player)
    if #pool == 0 then
        -- Nothing placed for this mode. The map's own staging point is the
        -- author's "put people here" answer, so prefer it over the centre.
        local map = Store.Get(lobby.mapId)
        if not map then return nil end
        return map.lobby or map.bounds.center
    end

    local enemies = {}
    for otherSrc, other in pairs(lobby.players) do
        if otherSrc ~= src and not other.spectator and other.alive and other.position then
            if not Modes.IsTeamMode(lobby.mode) or other.team ~= player.team then
                enemies[#enemies + 1] = other.position
            end
        end
    end

    if #enemies == 0 then
        return pool[math.random(#pool)]
    end

    local best, bestScore
    for _, point in ipairs(pool) do
        local nearest = math.huge
        for _, enemy in ipairs(enemies) do
            nearest = math.min(nearest, Util.dist2(point, enemy))
        end

        local jitter = nearest * (0.85 + math.random() * 0.3)
        if not bestScore or jitter > bestScore then
            best, bestScore = point, jitter
        end
    end

    return best or pool[1]
end

local function modeLoadout(lobby, player)
    if lobby.mode == 'gungame' then
        local ladder = Config.GunGameLadder
        local tier = math.min(player.tier or 1, #ladder)
        return { primary = ladder[tier], secondary = nil }
    end

    if lobby.mode == 'oitc' then
        return { primary = nil, secondary = Config.OitcWeapon }
    end

    return player.loadout
end

Match.Loadout = modeLoadout

local function ammoFor(lobby, player)
    if lobby.mode == 'oitc' then
        local mode = Config.Modes.oitc
        return { primary = 0, secondary = player.ammo or mode.startAmmo }
    end
    return Config.Loadout.ammo
end

Match.Ammo = ammoFor

local function initObjectives(lobby)
    local map = Store.Get(lobby.mapId)
    lobby.objectives = {}

    if lobby.mode == 'ctf' then
        lobby.objectives.flags = {}
        for _, team in ipairs(Modes.TeamsFor(lobby.mode)) do
            local stand = map and map.flags[team]
            if stand then
                lobby.objectives.flags[team] = {
                    team    = team,
                    home    = stand,
                    state   = 'home',
                    carrier = nil,
                    coords  = stand,
                    droppedAt = nil,
                }
            end
        end
    elseif lobby.mode == 'domination' then
        lobby.objectives.points = {}
        for _, point in ipairs((map and map.capturePoints) or {}) do
            lobby.objectives.points[point.id] = {
                id       = point.id,
                x = point.x, y = point.y, z = point.z, radius = point.radius,
                owner    = nil,
                progress = 0,
                capturing = nil,
            }
        end
        lobby.objectives.nextTick = os.time() + Config.Modes.domination.tickInterval
    elseif lobby.mode == 'confirmed' then
        lobby.objectives.tags = {}
        lobby.objectives.nextTag = 1
    end
end

local function initScores(lobby)
    lobby.scores = {}

    if Modes.IsTeamMode(lobby.mode) then
        for _, team in ipairs(Modes.TeamsFor(lobby.mode)) do
            lobby.scores[team] = 0
        end

        if lobby.mode == 'hyo' then
            local sizes = {}
            for _, player in pairs(lobby.players) do
                if not player.spectator and player.team then
                    sizes[player.team] = (sizes[player.team] or 0) + 1
                end
            end
            for _, team in ipairs(Modes.TeamsFor(lobby.mode)) do
                lobby.scores[team] = (sizes[team] or 0) * Config.Modes.hyo.livesPerPlayer
            end
        end
    end
end

function Match.Begin(lobby, continuing)
    local map = Store.Get(lobby.mapId)
    if not map then
        print(('^1[XS-Paintball]^0 lobby %d tried to start on a map that no longer exists.'):format(lobby.id))

        for src in pairs(lobby.players) do
            Framework.Notify(src, 'That map is gone. Pick another one.', 'error')
        end

        lobby.state = 'waiting'
        lobby.countdown = nil
        Lobbies.Sync(lobby)
        return
    end

    lobby.state     = 'live'
    lobby.countdown = nil
    lobby.startedAt = os.time()
    lobby.endsAt    = os.time() + lobby.rules.timeLimit
    lobby.result    = nil

    initScores(lobby)
    initObjectives(lobby)

    local mode = Config.Modes[lobby.mode]

    if not continuing then
        lobby.round = 1
        lobby.roundWins = {}
    end

    for src, player in pairs(lobby.players) do
        -- Kills and deaths run across the whole match. Everything else is
        -- per round.
        if not continuing then
            player.kills, player.deaths, player.assists = 0, 0, 0
            player.headshots, player.captures = 0, 0
            player.bestStreak = 0
        end

        player.streak, player.score = 0, 0
        player.tier = 1
        player.damagedBy = {}
        player.alive = not player.spectator

        if lobby.mode == 'oitc' then
            player.lives = mode.lives
            player.ammo  = mode.startAmmo
        else
            player.lives = nil
        end
    end

    for _, src in ipairs(playersOf(lobby)) do
        local player = lobby.players[src]
        -- On round two onwards they are already in the arena bucket, and
        -- capturing that would strand them there at the end.
        if GetPlayerRoutingBucket(src) ~= lobby.bucket then
            player.previousBucket = GetPlayerRoutingBucket(src)
        end

        SetPlayerRoutingBucket(src, lobby.bucket)

        if not continuing then Stash.Take(src, modeLoadout(lobby, player)) end

        TriggerClientEvent('XS-Paintball:client:matchStart', src, {
            lobbyId  = lobby.id,
            map      = map,
            mode     = lobby.mode,
            modeLabel = mode.label,
            rules    = lobby.rules,
            team     = player.team,
            teams    = Modes.TeamsFor(lobby.mode),
            spawn    = Match.PickSpawn(lobby, src),
            loadout  = modeLoadout(lobby, player),
            ammo     = ammoFor(lobby, player),
            timeLeft = lobby.rules.timeLimit,
            scores   = lobby.scores,
            objectives = lobby.objectives,
            wager    = lobby.wager,
            lives    = player.lives,
            tier     = player.tier,
            cosmetics = player.cosmetics,
            continuing = continuing == true,
            round    = lobby.round or 1,
            rounds   = lobby.rules.rounds or 1,
            roundWins = lobby.roundWins or {},
            -- Sent up front so friendly fire and teammate blips work from the
            -- first second, not from the first score push.
            roster   = Lobbies.Roster(lobby),
        })
    end

    for src, player in pairs(lobby.players) do
        if player.spectator then Match.SendSpectator(lobby, src) end
    end

    if L.clearPopulation then
        SetRoutingBucketPopulationEnabled(lobby.bucket, false)
        SetRoutingBucketEntityLockdownMode(lobby.bucket, 'relaxed')
    end

    Match.live[lobby.id] = true

    Voice.Apply(lobby, true)
    broadcast(lobby, 'XS-Paintball:client:sound', 'matchStart')

    TriggerEvent('XS-Paintball:matchStarted', {
        lobby   = lobby.id,
        mode    = lobby.mode,
        map     = map.name,
        wager   = lobby.wager,
        players = playersOf(lobby),
    })

    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()
end

function Match.SendSpectator(lobby, src)
    local map = Store.Get(lobby.mapId)
    if not map then return end

    local player = lobby.players[src]
    if player then
        player.previousBucket = GetPlayerRoutingBucket(src)
    end

    SetPlayerRoutingBucket(src, lobby.bucket)

    TriggerClientEvent('XS-Paintball:client:spectateStart', src, {
        lobbyId = lobby.id,
        map     = map,
        mode    = lobby.mode,
        timeLeft = math.max(0, lobby.endsAt - os.time()),
        scores  = lobby.scores,
    })
end

function Match.ReleaseSpectator(src)
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('XS-Paintball:client:spectateStop', src)
end

function Match.ReleasePlayer(lobby, src, reason)
    local player = lobby.players[src]

    Stash.Return(src)

    SetPlayerRoutingBucket(src, (player and player.previousBucket) or 0)
    TriggerClientEvent('XS-Paintball:client:matchStop', src, reason)

    if lobby.mode == 'ctf' and lobby.objectives.flags then
        for _, flag in pairs(lobby.objectives.flags) do
            if flag.carrier == src then Objectives.DropFlag(lobby, flag, nil) end
        end
    end
end

function Match.Position(src, coords)
    local lobby = Lobbies.ForSource(src)
    if not lobby or lobby.state ~= 'live' then return end

    local player = lobby.players[src]
    if not player then return end

    player.position = coords
end

local function addScore(lobby, player, amount)
    player.score = (player.score or 0) + amount

    if Modes.IsTeamMode(lobby.mode) and player.team and lobby.mode ~= 'hyo' then
        lobby.scores[player.team] = (lobby.scores[player.team] or 0) + amount
    end
end

Match.AddScore = addScore

function Match.AddTeamScore(lobby, team, amount)
    if not team then return end
    lobby.scores[team] = (lobby.scores[team] or 0) + amount
end

local function killstreakRewards(lobby, src, player)
    if not Config.Killstreaks.enabled or Settings.Get('killstreaks') ~= true then return end
    if lobby.mode == 'gungame' or lobby.mode == 'oitc' then return end

    local earned = {}
    for _, reward in ipairs(Config.Killstreaks.rewards) do
        if reward.kills == player.streak then earned[#earned + 1] = reward end
    end

    if #earned == 0 then return end

    if Config.Killstreaks.oneAtATime then
        earned = { earned[#earned] }
    end

    for _, reward in ipairs(earned) do
        TriggerClientEvent('XS-Paintball:client:killstreak', src, reward)

        if reward.id == 'uav' and Modes.IsTeamMode(lobby.mode) then
            for otherSrc, other in pairs(lobby.players) do
                if otherSrc ~= src and not other.spectator and other.team == player.team then
                    TriggerClientEvent('XS-Paintball:client:uav', otherSrc, reward.duration)
                end
            end
        end
    end
end

function Match.Eliminate(lobby, victimSrc, killerSrc, weapon, headshot)
    local victim = lobby.players[victimSrc]
    if not victim or victim.spectator or not victim.alive then return end

    local mode = Config.Modes[lobby.mode]
    local killer = killerSrc and lobby.players[killerSrc] or nil
    local ladderWinner = nil

    if killer and (killer.spectator or killerSrc == victimSrc) then killer = nil end
    if killer and Modes.IsTeamMode(lobby.mode) and killer.team == victim.team and not lobby.rules.friendlyFire then
        killer = nil
    end

    victim.alive = false
    victim.deaths = victim.deaths + 1
    victim.streak = 0
    victim.lastDeath = os.time()

    if lobby.mode == 'hyo' and victim.team then
        lobby.scores[victim.team] = math.max(0, (lobby.scores[victim.team] or 0) - 1)
    elseif lobby.mode == 'oitc' then
        victim.lives = math.max(0, (victim.lives or 0) - 1)
    end

    local assists = {}
    for otherSrc, at in pairs(victim.damagedBy or {}) do
        if otherSrc ~= killerSrc and os.time() - at <= 12 and lobby.players[otherSrc] then
            local other = lobby.players[otherSrc]
            if not Modes.IsTeamMode(lobby.mode) or other.team ~= victim.team then
                other.assists = other.assists + 1
                assists[#assists + 1] = other.name
            end
        end
    end
    victim.damagedBy = {}

    if killer then
        killer.kills = killer.kills + 1
        killer.streak = killer.streak + 1
        killer.bestStreak = math.max(killer.bestStreak, killer.streak)

        if headshot then killer.headshots = killer.headshots + 1 end

        if lobby.mode == 'gungame' then
            local ladder = Config.GunGameLadder

            killer.tier = (killer.tier or 1) + 1
            killer.score = killer.tier - 1
            TriggerClientEvent('XS-Paintball:client:tier', killerSrc, killer.tier)

            if killer.tier > #ladder then ladderWinner = killer end
        elseif lobby.mode == 'oitc' then
            killer.ammo = (killer.ammo or 0) + mode.ammoPerKill
            addScore(lobby, killer, 1)
            TriggerClientEvent('XS-Paintball:client:ammo', killerSrc, killer.ammo)
        elseif lobby.mode == 'confirmed' then
            killer.score = (killer.score or 0) + 1
        elseif lobby.mode ~= 'ctf' and lobby.mode ~= 'domination' and lobby.mode ~= 'hyo' then
            addScore(lobby, killer, 1)
        else
            killer.score = (killer.score or 0) + 1
        end

        TriggerClientEvent('XS-Paintball:client:sound', killerSrc, headshot and 'headshot' or 'kill')

        killstreakRewards(lobby, killerSrc, killer)
    end

    TriggerClientEvent('XS-Paintball:client:sound', victimSrc, 'eliminated')

    TriggerEvent('XS-Paintball:playerEliminated', {
        lobby     = lobby.id,
        mode      = lobby.mode,
        victim    = victim.citizenid,
        victimSource = victimSrc,
        killer    = killer and killer.citizenid or nil,
        killerSource = killer and killerSrc or nil,
        headshot  = headshot == true,
        streak    = killer and killer.streak or 0,
    })

    broadcast(lobby, 'XS-Paintball:client:killfeed', {
        killer   = killer and killer.name or nil,
        killerTeam = killer and killer.team or nil,
        victim   = victim.name,
        victimTeam = victim.team,
        weapon   = weapon,
        headshot = headshot == true,
        streak   = killer and killer.streak or nil,
        assists  = assists,
    })

    if lobby.mode == 'ctf' and lobby.objectives.flags then
        for _, flag in pairs(lobby.objectives.flags) do
            if flag.carrier == victimSrc then Objectives.DropFlag(lobby, flag, victim.position) end
        end
    end

    if lobby.mode == 'confirmed' then
        Objectives.DropTag(lobby, victim, victimSrc)
    end

    if ladderWinner then
        Match.Push(lobby)
        Match.Finish(lobby, nil, ladderWinner)
        return
    end

    local eliminated = false

    if lobby.mode == 'oitc' and (victim.lives or 0) <= 0 then
        eliminated = true
    elseif lobby.mode == 'hyo' and (lobby.scores[victim.team] or 0) <= 0 then
        eliminated = true
    end

    if eliminated then
        TriggerClientEvent('XS-Paintball:client:eliminated', victimSrc)
    else
        local delay = lobby.rules.respawnTime
        TriggerClientEvent('XS-Paintball:client:respawn', victimSrc, {
            delay   = delay,
            spawn   = Match.PickSpawn(lobby, victimSrc),
            loadout = modeLoadout(lobby, victim),
            ammo    = ammoFor(lobby, victim),
            protect = lobby.rules.spawnProtect,
            lives   = victim.lives,
        })

        SetTimeout((delay + 1) * 1000, function()
            local current = Lobbies.list[lobby.id]
            if current and current.state == 'live' and current.players[victimSrc] then
                current.players[victimSrc].alive = true
            end
        end)
    end

    Match.Push(lobby)
    Match.CheckEnd(lobby)
end

function Match.Damage(lobby, victimSrc, attackerSrc)
    local victim = lobby.players[victimSrc]
    if not victim then return end

    victim.damagedBy = victim.damagedBy or {}
    victim.damagedBy[attackerSrc] = os.time()
end

function Match.Push(lobby)
    local payload = {
        scores     = lobby.scores,
        objectives = lobby.objectives,
        roster     = Lobbies.Roster(lobby),
        timeLeft   = lobby.endsAt and math.max(0, lobby.endsAt - os.time()) or 0,
    }

    broadcast(lobby, 'XS-Paintball:client:matchUpdate', payload)
end

local function leader(lobby)
    if Modes.IsTeamMode(lobby.mode) then
        local best, bestScore, tie = nil, nil, false

        for team, score in pairs(lobby.scores) do
            if not bestScore or score > bestScore then
                best, bestScore, tie = team, score, false
            elseif score == bestScore then
                tie = true
            end
        end

        return best, bestScore, tie
    end

    local best, bestScore, tie = nil, nil, false
    for src, player in pairs(lobby.players) do
        if not player.spectator then
            local score = player.score or 0
            if not bestScore or score > bestScore then
                best, bestScore, tie = src, score, false
            elseif score == bestScore then
                tie = true
            end
        end
    end

    return best, bestScore, tie
end

function Match.CheckEnd(lobby)
    if lobby.state ~= 'live' then return end

    local limit = lobby.rules.scoreLimit

    if lobby.mode == 'hyo' then
        local alive = {}
        for team, lives in pairs(lobby.scores) do
            if lives > 0 then alive[#alive + 1] = team end
        end

        if #alive == 1 then
            Match.Finish(lobby, alive[1])
            return
        elseif #alive == 0 then
            Match.Finish(lobby, nil)
            return
        end
    elseif Modes.IsTeamMode(lobby.mode) then
        for team, score in pairs(lobby.scores) do
            if score >= limit then
                Match.Finish(lobby, team)
                return
            end
        end
    else
        for src, player in pairs(lobby.players) do
            if not player.spectator and (player.score or 0) >= limit then
                Match.Finish(lobby, nil, player)
                return
            end
        end
    end

    if lobby.mode == 'oitc' then
        local standing = {}
        for src, player in pairs(lobby.players) do
            if not player.spectator and (player.lives or 0) > 0 then standing[#standing + 1] = src end
        end

        if #standing <= 1 then
            local winner = standing[1] and lobby.players[standing[1]] or nil
            Match.Finish(lobby, nil, winner)
            return
        end
    end

    if Lobbies.PlayerCount(lobby) == 0 then
        Match.Finish(lobby, nil)
    end
end

local function totalRounds(lobby)
    if not Config.Rounds.enabled then return 1 end
    return math.max(1, lobby.rules.rounds or 1)
end

local function majority(rounds)
    return math.floor(rounds / 2) + 1
end

local function roundWinner(lobby)
    local best, _, tie = leader(lobby)
    if tie or not best then return nil, nil end

    if Modes.IsTeamMode(lobby.mode) then return best, nil end
    return nil, lobby.players[best]
end

local function mostRoundWins(lobby)
    local bestKey, bestCount, tie = nil, nil, false

    for key, count in pairs(lobby.roundWins or {}) do
        if not bestCount or count > bestCount then
            bestKey, bestCount, tie = key, count, false
        elseif count == bestCount then
            tie = true
        end
    end

    return (not tie) and bestKey or nil
end

-- Round wins follow the players, not the colour, so they swap with the sides.
function Match.SwapSides(lobby)
    local teams = Modes.TeamsFor(lobby.mode)
    if #teams < 2 then return end

    local a, b = teams[1], teams[2]

    for _, player in pairs(lobby.players) do
        if not player.spectator then
            if player.team == a then
                player.team = b
            elseif player.team == b then
                player.team = a
            end
        end
    end

    local wins = lobby.roundWins or {}
    wins[a], wins[b] = wins[b], wins[a]
    lobby.roundWins = wins

    broadcast(lobby, 'XS-Paintball:client:announce', { text = 'Sides swapped', tone = 'warning' })
end

function Match.EndRound(lobby, winningTeam, winningPlayer)
    lobby.state = 'break'
    Match.live[lobby.id] = nil

    local rounds = totalRounds(lobby)
    local pause = math.max(3, Config.Rounds.breakSeconds or 12)

    broadcast(lobby, 'XS-Paintball:client:roundEnd', {
        round        = lobby.round or 1,
        rounds       = rounds,
        winnerTeam   = winningTeam,
        winnerName   = winningPlayer and winningPlayer.name or nil,
        roundWins    = lobby.roundWins or {},
        scores       = lobby.scores,
        scoreboard   = Lobbies.Roster(lobby),
        breakSeconds = pause,
        teams        = Modes.TeamsFor(lobby.mode),
    })

    broadcast(lobby, 'XS-Paintball:client:sound', 'roundEnd')
    Lobbies.Sync(lobby)

    SetTimeout(pause * 1000, function()
        local current = Lobbies.list[lobby.id]
        if not current or current.state ~= 'break' then return end

        current.round = (current.round or 1) + 1

        if Config.Rounds.swapSides and Modes.IsTeamMode(current.mode) then
            if current.round == math.ceil(rounds / 2) + 1 then Match.SwapSides(current) end
        end

        Match.Begin(current, true)
    end)
end

-- The end of a round, which may or may not be the end of the match.
function Match.Finish(lobby, winningTeam, winningPlayer)
    if lobby.state ~= 'live' then return end

    if not winningTeam and not winningPlayer then
        winningTeam, winningPlayer = roundWinner(lobby)
    end

    local rounds = totalRounds(lobby)
    local round = lobby.round or 1

    lobby.roundWins = lobby.roundWins or {}

    local key = winningTeam or (winningPlayer and winningPlayer.citizenid) or nil
    if key then lobby.roundWins[key] = (lobby.roundWins[key] or 0) + 1 end

    local decided = key ~= nil and lobby.roundWins[key] >= majority(rounds)

    if rounds > 1 and round < rounds and not decided then
        Match.EndRound(lobby, winningTeam, winningPlayer)
        return
    end

    -- In a best-of the match winner is whoever took the most rounds, not
    -- whoever took the last one.
    if rounds > 1 then
        local overall = mostRoundWins(lobby)

        if Modes.IsTeamMode(lobby.mode) then
            winningTeam, winningPlayer = overall, nil
        else
            winningTeam, winningPlayer = nil, nil

            if overall then
                for _, player in pairs(lobby.players) do
                    if player.citizenid == overall then
                        winningPlayer = player
                        break
                    end
                end
            end
        end
    end

    Match.EndMatch(lobby, winningTeam, winningPlayer)
end

-- Ending it early, from the host panel or an admin command. Whoever is ahead
-- when the plug is pulled takes it.
function Match.ForceEnd(lobby)
    if lobby.state ~= 'live' and lobby.state ~= 'break' then return false end

    Match.live[lobby.id] = nil
    lobby.state = 'live'

    local winningTeam, winningPlayer = roundWinner(lobby)

    -- Somebody pulled the plug deliberately. Asking the room to vote on the
    -- next map straight afterwards is not what they meant.
    Match.EndMatch(lobby, winningTeam, winningPlayer, true)

    return true
end

function Match.EndMatch(lobby, winningTeam, winningPlayer, skipVote)
    lobby.state = 'ended'
    Match.live[lobby.id] = nil

    local duration = os.time() - (lobby.startedAt or os.time())
    local results = {}
    local historyPlayers = {}

    if not winningTeam and not winningPlayer then
        local best, _, tie = leader(lobby)
        if not tie then
            if Modes.IsTeamMode(lobby.mode) then
                winningTeam = best
            elseif best then
                winningPlayer = lobby.players[best]
            end
        end
    end

    for src, player in pairs(lobby.players) do
        if not player.spectator then
            local won = false

            if winningTeam and player.team == winningTeam then won = true end
            if winningPlayer and winningPlayer.citizenid == player.citizenid then won = true end

            results[player.citizenid] = {
                source = src,
                name   = player.name,
                kills  = player.kills,
                deaths = player.deaths,
                staked = player.staked or 0,
                won    = won,
            }

            historyPlayers[#historyPlayers + 1] = {
                name   = player.name,
                team   = player.team,
                kills  = player.kills,
                deaths = player.deaths,
                score  = player.score,
                won    = won,
            }
        end
    end

    local settlement = Economy.Settle(lobby, results)

    if Config.Progression.enabled and Settings.Get('progression') then
        local XP = Config.Progression.xp

        for src, player in pairs(lobby.players) do
            if not player.spectator then
                local entry = results[player.citizenid]
                local won = entry and entry.won

                local xp = player.kills * XP.kill
                    + player.headshots * XP.headshot
                    + player.assists * XP.assist
                    + player.captures * XP.capture
                    + player.bestStreak * XP.streak
                    + (won and XP.win or XP.loss)

                local _, levelUp = Stats.Apply(player.citizenid, player.name, {
                    kills = player.kills, deaths = player.deaths, assists = player.assists,
                    headshots = player.headshots, captures = player.captures,
                    wins = won and 1 or 0, losses = won and 0 or 1, matches = 1,
                    streak = player.bestStreak, xp = xp,
                })

                if levelUp then
                    TriggerClientEvent('XS-Paintball:client:levelUp', src, levelUp)
                end
            end
        end
    end

    local map = Store.Get(lobby.mapId)

    Stats.RecordMatch({
        map      = map and map.name or 'Unknown',
        mode     = lobby.mode,
        winner   = winningTeam or (winningPlayer and winningPlayer.name) or 'Draw',
        duration = duration,
        pot      = settlement.pot or 0,
        players  = historyPlayers,
    })

    lobby.result = {
        winnerTeam   = winningTeam,
        winnerName   = winningPlayer and winningPlayer.name or nil,
        draw         = not winningTeam and not winningPlayer,
        duration     = duration,
        pot          = settlement.pot or 0,
        share        = settlement.share or 0,
        scoreboard   = Lobbies.Roster(lobby),
        scores       = lobby.scores,
        payouts      = {},
    }

    for citizenid, entry in pairs(results) do
        lobby.result.payouts[citizenid] = entry.payout or 0
    end

    TriggerEvent('XS-Paintball:matchEnded', {
        lobby    = lobby.id,
        mode     = lobby.mode,
        map      = map and map.name or nil,
        winner   = winningTeam or (winningPlayer and winningPlayer.citizenid) or nil,
        duration = duration,
        pot      = settlement.pot or 0,
        players  = historyPlayers,
    })

    Voice.Apply(lobby, false)

    for src, player in pairs(lobby.players) do
        if not player.spectator then
            local entry = results[player.citizenid]
            TriggerClientEvent('XS-Paintball:client:sound', src,
                (entry and entry.won) and 'matchWin' or 'matchLoss')
        end
    end

    broadcast(lobby, 'XS-Paintball:client:matchEnd', lobby.result)
    Lobbies.Sync(lobby)
    Lobbies.SyncBrowser()

    local voteSeconds = skipVote and 0 or Vote.Open(lobby)
    local hold = math.max(L.endScreen, voteSeconds + 3)

    SetTimeout(hold * 1000, function()
        local current = Lobbies.list[lobby.id]
        if not current then return end

        for src, player in pairs(current.players) do
            if player.spectator then
                Match.ReleaseSpectator(src)
            else
                Match.ReleasePlayer(current, src, 'ended')
            end

            player.staked = 0
            player.ready  = false
            player.alive  = false
        end

        current.state   = 'waiting'
        current.endsAt  = nil
        current.startedAt = nil
        current.scores  = {}
        current.objectives = {}
        current.result  = nil
        current.createdAt = os.time()

        Lobbies.Sync(current)
        Lobbies.SyncBrowser()
    end)
end

CreateThread(function()
    while true do
        Wait(1000)

        for id in pairs(Match.live) do
            local lobby = Lobbies.list[id]

            if not lobby or lobby.state ~= 'live' then
                Match.live[id] = nil
            else
                if lobby.mode == 'domination' then
                    Objectives.TickDomination(lobby)
                elseif lobby.mode == 'ctf' then
                    Objectives.TickFlags(lobby)
                elseif lobby.mode == 'confirmed' then
                    Objectives.TickTags(lobby)
                end

                if os.time() >= lobby.endsAt then
                    Match.Finish(lobby, nil)
                else
                    local left = lobby.endsAt - os.time()
                    if left % 5 == 0 or left <= 10 then
                        Match.Push(lobby)
                    end
                end
            end
        end
    end
end)
