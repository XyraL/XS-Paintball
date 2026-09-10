Objectives = {}

local function near(a, b, distance)
    if not a or not b then return false end
    return Util.dist3(a, b) <= distance
end

local function syncObjectives(lobby)
    Match.Broadcast(lobby, 'XS-Paintball:client:objectives', lobby.objectives)
end

Objectives.Sync = syncObjectives

function Objectives.DropFlag(lobby, flag, coords)
    flag.carrier = nil
    flag.state   = coords and 'dropped' or 'home'
    flag.coords  = coords or flag.home
    flag.droppedAt = coords and os.time() or nil

    syncObjectives(lobby)
end

function Objectives.ResetFlag(lobby, flag)
    flag.carrier   = nil
    flag.state     = 'home'
    flag.coords    = flag.home
    flag.droppedAt = nil

    syncObjectives(lobby)
end

function Objectives.TouchFlag(src, team)
    local lobby = Lobbies.ForSource(src)
    if not lobby or lobby.state ~= 'live' or lobby.mode ~= 'ctf' then return false end

    local player = lobby.players[src]
    if not player or player.spectator or not player.alive or not player.team then return false end

    local flags = lobby.objectives.flags or {}
    local flag = flags[team]
    if not flag then return false end

    if not near(player.position, flag.coords, 4.0) then return false end

    if team ~= player.team then
        if flag.state == 'carried' then return false end

        flag.carrier = src
        flag.state   = 'carried'
        flag.coords  = player.position
        flag.droppedAt = nil

        Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
            text = ('%s took the %s flag'):format(player.name, Config.Teams[team].label),
            tone = 'warning',
        })

        syncObjectives(lobby)
        return true
    end

    if flag.state == 'dropped' then
        Objectives.ResetFlag(lobby, flag)

        Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
            text = ('%s returned the %s flag'):format(player.name, Config.Teams[team].label),
            tone = 'inform',
        })
        return true
    end

    if flag.state ~= 'home' then return false end

    local scored = false

    for otherTeam, other in pairs(flags) do
        if otherTeam ~= player.team and other.carrier == src then
            Objectives.ResetFlag(lobby, other)

            Match.AddTeamScore(lobby, player.team, 1)
            player.captures = (player.captures or 0) + 1
            player.score = (player.score or 0) + 1
            scored = true

            Match.Broadcast(lobby, 'XS-Paintball:client:sound', 'capture')
            Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
                text = ('%s captured for %s'):format(player.name, Config.Teams[player.team].label),
                tone = 'success',
            })
        end
    end

    if scored then
        Match.Push(lobby)
        Match.CheckEnd(lobby)
    end

    return scored
end

function Objectives.TickFlags(lobby)
    local flags = lobby.objectives.flags
    if not flags then return end

    local mode = Config.Modes.ctf
    local changed = false

    for _, flag in pairs(flags) do
        if flag.state == 'carried' then
            local carrier = flag.carrier and lobby.players[flag.carrier]

            if not carrier or not carrier.alive then
                Objectives.DropFlag(lobby, flag, carrier and carrier.position or nil)
                changed = true
            elseif carrier.position then
                flag.coords = carrier.position
                changed = true
            end
        elseif flag.state == 'dropped' and flag.droppedAt then
            if os.time() - flag.droppedAt >= mode.flagReturnTime then
                Objectives.ResetFlag(lobby, flag)

                Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
                    text = ('The %s flag returned'):format(Config.Teams[flag.team].label),
                    tone = 'inform',
                })
                changed = true
            end
        end
    end

    if changed then syncObjectives(lobby) end
end

function Objectives.TickDomination(lobby)
    local points = lobby.objectives.points
    if not points then return end

    local mode = Config.Modes.domination
    local changed = false

    for _, point in pairs(points) do
        local present = {}

        for _, player in pairs(lobby.players) do
            if not player.spectator and player.alive and player.team and player.position then
                local dx = player.position.x - point.x
                local dy = player.position.y - point.y
                local dz = (player.position.z or point.z) - point.z

                if (dx * dx + dy * dy) <= point.radius * point.radius and math.abs(dz) <= 6.0 then
                    present[player.team] = (present[player.team] or 0) + 1
                end
            end
        end

        local teams = Util.keys(present)

        if #teams == 1 then
            local team = teams[1]

            if point.owner == team then
                if point.capturing or point.progress ~= 1 then
                    point.capturing = nil
                    point.progress = 1
                    changed = true
                end
            else
                local rate = (1 / math.max(1, mode.captureTime)) * math.min(3, present[team])

                if point.capturing ~= team then
                    point.capturing = team
                    point.progress = 0
                end

                point.progress = math.min(1, point.progress + rate)
                changed = true

                if point.progress >= 1 then
                    point.owner = team
                    point.capturing = nil

                    Match.Broadcast(lobby, 'XS-Paintball:client:sound', 'capture')
                    Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
                        text = ('%s captured point %s'):format(Config.Teams[team].label, point.id),
                        tone = 'success',
                    })
                end
            end
        elseif #teams == 0 and point.capturing then
            local rate = (1 / math.max(1, mode.captureTime)) * 0.5
            point.progress = point.progress - rate
            changed = true

            if point.progress <= 0 then
                point.capturing = nil
                point.progress = point.owner and 1 or 0
            end
        end
    end

    if os.time() >= (lobby.objectives.nextTick or 0) then
        lobby.objectives.nextTick = os.time() + mode.tickInterval

        local gains = {}
        for _, point in pairs(points) do
            if point.owner then gains[point.owner] = (gains[point.owner] or 0) + mode.pointsPerTick end
        end

        for team, amount in pairs(gains) do
            Match.AddTeamScore(lobby, team, amount)
        end

        if Util.count(gains) > 0 then
            Match.Push(lobby)
            Match.CheckEnd(lobby)
        end

        changed = true
    end

    if changed then syncObjectives(lobby) end
end

function Objectives.DropTag(lobby, victim, victimSrc)
    if not victim.position then return end

    local tags = lobby.objectives.tags
    if not tags then return end

    local id = lobby.objectives.nextTag or 1
    lobby.objectives.nextTag = id + 1

    tags[tostring(id)] = {
        id      = id,
        team    = victim.team,
        x       = victim.position.x,
        y       = victim.position.y,
        z       = victim.position.z,
        expires = os.time() + Config.Modes.confirmed.tagLifetime,
    }

    syncObjectives(lobby)
end

function Objectives.TakeTag(src, tagId)
    local lobby = Lobbies.ForSource(src)
    if not lobby or lobby.state ~= 'live' or lobby.mode ~= 'confirmed' then return false end

    local player = lobby.players[src]
    if not player or player.spectator or not player.alive or not player.team then return false end

    local tags = lobby.objectives.tags or {}
    local tag = tags[tostring(tagId)]
    if not tag then return false end

    if not near(player.position, tag, 3.0) then return false end

    tags[tostring(tagId)] = nil

    if tag.team ~= player.team then
        Match.AddTeamScore(lobby, player.team, 1)
        player.captures = (player.captures or 0) + 1

        Match.Broadcast(lobby, 'XS-Paintball:client:sound', 'capture')
        Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
            text = ('%s confirmed a kill'):format(player.name),
            tone = 'success',
        })
    else
        local deny = Config.Modes.confirmed.denyScore or 0
        if deny > 0 then Match.AddTeamScore(lobby, player.team, deny) end

        Match.Broadcast(lobby, 'XS-Paintball:client:announce', {
            text = ('%s denied a tag'):format(player.name),
            tone = 'warning',
        })
    end

    syncObjectives(lobby)
    Match.Push(lobby)
    Match.CheckEnd(lobby)

    return true
end

function Objectives.TickTags(lobby)
    local tags = lobby.objectives.tags
    if not tags then return end

    local now = os.time()
    local changed = false

    for key, tag in pairs(tags) do
        if now >= tag.expires then
            tags[key] = nil
            changed = true
        end
    end

    if changed then syncObjectives(lobby) end
end
