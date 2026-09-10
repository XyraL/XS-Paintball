Hud = { active = false, scoreboard = false }

local function send(action, data)
    SendNUIMessage({ action = 'hud:' .. action, data = data })
end

function Hud.Start(match)
    Hud.active = true

    send('self', GetPlayerServerId(PlayerId()))
    send('start', {
        mode      = match.mode,
        modeLabel = match.modeLabel,
        map       = match.map.name,
        team      = match.team,
        teams     = match.teams,
        teamData  = Config.Teams,
        scoreLimit = match.rules.scoreLimit,
        scoreLabel = Modes.ScoreLabel(match.mode),
        timeLeft  = match.timeLeft or 0,
        paint     = match.paint,
        paintMax  = match.paintMax,
        wager     = match.wager,
        goggles   = Config.Rules.goggles ~= false,
        round     = match.round or 1,
        rounds    = match.rounds or 1,
        roundWins = match.roundWins or {},
        spectator = false,
    })
end

function Hud.StartSpectator(data)
    Hud.active = true

    send('self', GetPlayerServerId(PlayerId()))
    send('start', {
        mode      = data.mode,
        modeLabel = (Config.Modes[data.mode] or {}).label,
        map       = data.map.name,
        team      = nil,
        teams     = Modes.TeamsFor(data.mode),
        teamData  = Config.Teams,
        scoreLabel = Modes.ScoreLabel(data.mode),
        timeLeft  = data.timeLeft or 0,
        spectator = true,
    })
end

function Hud.Stop()
    Hud.active = false
    Hud.scoreboard = false

    send('stop')

    DisplayRadar(true)
end

function Hud.Update(payload)
    if not Hud.active then return end

    send('update', {
        scores   = payload.scores,
        roster   = payload.roster,
        timeLeft = payload.timeLeft,
    })
end

function Hud.SetPaint(current, max)
    send('paint', { current = math.max(0, math.floor(current or 0)), max = max or 100 })
end

function Hud.SetState(state, delay)
    send('state', { state = state, delay = delay })
end

function Hud.SetRespawn(seconds)
    send('respawn', seconds)
end

function Hud.SetProtection(seconds)
    send('protection', seconds)
end

function Hud.SetBounds(seconds)
    send('bounds', seconds)
end


function Hud.ShowRound(data)
    send('round', data)
end

function Hud.ShowVote(data)
    send('vote', data)
end

function Hud.VoteTally(tally)
    send('voteTally', tally)
end

function Hud.VoteChoice(index)
    send('voteChoice', index)
end

function Hud.VoteResult(data)
    send('voteResult', data)
end

function Hud.HideVote()
    send('vote', false)
end

function Hud.SetQueue(state)
    send('queue', state or false)
end

function Hud.SetRound(round, rounds, roundWins)
    send('rounds', { round = round, rounds = rounds, roundWins = roundWins or {} })
end

function Hud.SetObjectives(state)
    if not Hud.active then return end
    send('objectives', state or {})
end

function Hud.SetTier(tier, total, label)
    send('tier', { tier = tier, total = total, label = label })
end

function Hud.SetStreak(info)
    send('streak', info and { label = info.label, remaining = math.max(0, math.floor((info.until_ - GetGameTimer()) / 1000)) } or nil)
end

function Hud.Killfeed(entry)
    if not Hud.active then return end

    send('killfeed', {
        killer     = entry.killer,
        killerTeam = entry.killerTeam,
        victim     = entry.victim,
        victimTeam = entry.victimTeam,
        weapon     = entry.weapon and Weapons.Label(entry.weapon) or nil,
        headshot   = entry.headshot,
        streak     = entry.streak,
    })
end

function Hud.Announce(text, tone)
    if not text then return end
    send('announce', { text = text, tone = tone or 'inform' })
end

function Hud.Splat()
    send('splat')
end

function Hud.HitMarker()
    send('hitmarker')
end

function Hud.ShowResult(result)
    send('result', result)
end

function Hud.SetLobby(state)
    send('lobby', state and {
        name  = state.name,
        state = state.state,
        countdown = state.countdown,
        players = state.roster and #state.roster or 0,
    } or nil)
end

function Hud.SetSpectating(active)
    send('spectating', active == true)
end

function Hud.SetSpectateTarget(name, team)
    send('spectateTarget', name and { name = name, team = team } or nil)
end

CreateThread(function()
    while true do
        local sleep = 1000

        if Hud.active and PB.match and not PB.match.ended then
            PB.match.timeLeft = math.max(0, (PB.match.timeLeft or 0) - 1)
            send('time', PB.match.timeLeft)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 300

        if Hud.active then
            sleep = 0

            local held = IsControlPressed(0, 47)

            if held ~= Hud.scoreboard then
                Hud.scoreboard = held
                send('scoreboard', held)
            end

            if Config.Rules.hideRadar and PB.match and not PB.match.ended then
                DisplayRadar(false)
            end
        elseif Hud.scoreboard then
            Hud.scoreboard = false
            send('scoreboard', false)
        end

        Wait(sleep)
    end
end)

--[[ The loadout bar.

     Reads the ped rather than trusting what the server handed out, so if
     another resource takes a gun away the bar shows that. The keys are the
     number row, and they only do anything while alive — the map vote uses the
     same three keys on the end screen, and the two can never be up at once. ]]

local ALL_SLOTS = { { 'primary', 157 }, { 'secondary', 158 }, { 'melee', 160 } }

local SLOT_KEYS, SLOT_ORDER = {}, {}

for _, entry in ipairs(ALL_SLOTS) do
    if Config.Loadout[entry[1]] then
        SLOT_KEYS[entry[1]] = entry[2]
        SLOT_ORDER[#SLOT_ORDER + 1] = entry[1]
    end
end

local function loadoutSlots()
    local match = PB.match
    if not match or not match.loadout then return {} end

    local ped = PlayerPedId()
    local held = GetSelectedPedWeapon(ped)
    local out = {}

    for index, slot in ipairs(SLOT_ORDER) do
        local name = match.loadout[slot]
        if name then
            local hash = joaat(name)
            local carrying = HasPedGotWeapon(ped, hash, false)

            out[#out + 1] = {
                key    = tostring(index),
                slot   = slot,
                label  = Weapons.Label(name),
                active = held == hash,
                missing = not carrying,
                ammo   = (slot ~= 'melee' and carrying) and GetAmmoInPedWeapon(ped, hash) or nil,
            }
        end
    end

    return out
end

CreateThread(function()
    local signature = nil

    while true do
        local sleep = 500

        if Hud.active and PB.match and not PB.match.ended then
            sleep = 200

            local slots = loadoutSlots()
            local key = ''

            for _, slot in ipairs(slots) do
                key = ('%s|%s%s%s'):format(key, slot.label, slot.active and '*' or '', slot.ammo or '')
            end

            if key ~= signature then
                signature = key
                send('loadout', slots)
            end
        elseif signature ~= nil then
            signature = nil
            send('loadout', false)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 300

        if PB.match and PB.match.alive and not PB.match.ended then
            sleep = 0

            for slot, control in pairs(SLOT_KEYS) do
                if IsControlJustPressed(0, control) then
                    local name = PB.match.loadout and PB.match.loadout[slot]
                    local hash = name and joaat(name)

                    if hash and HasPedGotWeapon(PlayerPedId(), hash, false) then
                        SetCurrentPedWeapon(PlayerPedId(), hash, true)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

--[[ Your side, down the edge of the screen.

     Alive or out, and who is talking. Talking comes from the game rather than
     the voice resource, so it works whatever you run — pma-voice, mumble, or
     nothing at all. ]]

CreateThread(function()
    local signature = nil

    while true do
        local sleep = 700

        if Config.TeamPanel and Hud.active and PB.match and PB.match.team
            and not PB.match.ended and PB.match.roster then

            sleep = 400

            local self = GetPlayerServerId(PlayerId())
            local rows = {}
            local key = ''

            for _, entry in ipairs(PB.match.roster) do
                if entry.team == PB.match.team and not entry.spectator then
                    local player = GetPlayerFromServerId(entry.source)
                    local talking = false

                    if player ~= -1 and NetworkIsPlayerActive(player) then
                        talking = NetworkIsPlayerTalking(player)
                    end

                    rows[#rows + 1] = {
                        name    = entry.name,
                        alive   = entry.alive,
                        talking = talking,
                        you     = entry.source == self,
                        kills   = entry.kills or 0,
                    }

                    key = ('%s|%s%s%s'):format(key, entry.name,
                        entry.alive and 'a' or 'd', talking and 't' or '')
                end
            end

            if key ~= signature then
                signature = key
                send('team', { team = PB.match.team, rows = rows })
            end
        elseif signature ~= nil then
            signature = nil
            send('team', false)
        end

        Wait(sleep)
    end
end)
