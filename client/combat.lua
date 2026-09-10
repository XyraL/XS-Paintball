Combat = { running = false }

local HEAD_BONE = 31086

local lastAttacker = nil
local reported = {}
local maxHealth = 200

local function damageModifier()
    local value = tonumber(Config.Rules.damageModifier) or 0.25
    if value <= 0.01 then return 0.01 end
    if value > 1.0 then return 1.0 end
    return value
end

local function attackerFromEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if not IsEntityAPed(entity) or not IsPedAPlayer(entity) then return nil end

    local index = NetworkGetPlayerIndexFromPed(entity)
    if index == -1 or index == PlayerId() then return nil end

    return GetPlayerServerId(index), GetSelectedPedWeapon(entity)
end

local function isTeammate(serverId)
    if not PB.match or not PB.match.team then return false end
    if not PB.match.roster then return false end

    for _, entry in ipairs(PB.match.roster) do
        if entry.source == serverId then
            return entry.team == PB.match.team
        end
    end

    return false
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if not PB.match or not PB.match.alive then return end

    local victim = args[1]
    if victim ~= PlayerPedId() then return end

    local serverId, weapon = attackerFromEntity(args[2])
    if not serverId then return end

    lastAttacker = { source = serverId, weapon = weapon, at = GetGameTimer() }

    if reported[serverId] and GetGameTimer() - reported[serverId] < 350 then return end
    reported[serverId] = GetGameTimer()

    TriggerServerEvent('XS-Paintball:server:damaged', serverId)
end)

local function currentAttacker()
    if lastAttacker and GetGameTimer() - lastAttacker.at <= 6000 then
        return lastAttacker
    end
    return nil
end

local function eliminate(headshot)
    if not PB.match or not PB.match.alive then return end

    PB.match.alive = false

    local attacker = currentAttacker()

    TriggerServerEvent('XS-Paintball:server:eliminated', {
        killer   = attacker and attacker.source or nil,
        weapon   = attacker and attacker.weapon or nil,
        headshot = headshot == true,
    })

    lastAttacker = nil
    Hud.SetPaint(0, PB.match.paintMax)
end

function Combat.SelfEliminate(reason)
    if not PB.match or not PB.match.alive then return end

    PB.match.alive = false
    lastAttacker = nil

    TriggerServerEvent('XS-Paintball:server:eliminated', { killer = nil, weapon = nil, headshot = false })
    Framework.Notify(reason == 'out of bounds' and 'You left the arena.' or 'Eliminated.', 'error')
end

local function takePaint(amount, headshot)
    if not PB.match or not PB.match.alive then return end

    if GetGameTimer() < (PB.match.protectedUntil or 0) then return end

    local attacker = currentAttacker()
    if attacker and isTeammate(attacker.source) and not PB.match.rules.friendlyFire then
        return
    end

    if headshot and Config.Rules.headshotKills then
        PB.match.paint = 0
    else
        -- Real damage was scaled down so nothing can kill outright. Scale it
        -- back up here so the paint pool drains at the rate the weapon deserves.
        local real = amount / damageModifier()
        PB.match.paint = PB.match.paint - (real * (Config.Rules.damageScale or 1.0))
    end

    Hud.SetPaint(math.max(0, PB.match.paint), PB.match.paintMax)

    if Config.PaintEffects.screenSplat then Hud.Splat() end

    if PB.match.paint <= 0 then
        eliminate(headshot)
    end
end

function Combat.AddPaint(amount)
    if not PB.match then return end

    PB.match.paintMax = PB.match.paintMax + amount
    PB.match.paint = PB.match.paint + amount
    Hud.SetPaint(PB.match.paint, PB.match.paintMax)
end

function Combat.OnDeath()
    lastAttacker = nil
    reported = {}
end

function Combat.Start()
    if Combat.running then return end
    Combat.running = true

    local ped = PlayerPedId()
    maxHealth = GetEntityMaxHealth(ped)

    SetEntityHealth(ped, maxHealth)

    -- Melee is scaled the same way, so every hit costs paint at the same rate
    -- whatever it came from.
    SetPlayerWeaponDamageModifier(PlayerId(), damageModifier())
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), damageModifier())

    CreateThread(function()
        local ped = PlayerPedId()
        local last = GetEntityHealth(ped)

        while Combat.running and PB.match do
            ped = PlayerPedId()

            if PB.match.alive and not PB.match.ended then
                local health = GetEntityHealth(ped)

                if IsEntityDead(ped) then
                    PB.match.paint = 0
                    Hud.SetPaint(0, PB.match.paintMax)
                    eliminate(false)
                    last = maxHealth
                elseif health < last then
                    local lost = last - health
                    local _, bone = GetPedLastDamageBone(ped)
                    local headshot = bone == HEAD_BONE

                    SetEntityHealth(ped, maxHealth)
                    ClearPedBloodDamage(ped)
                    ClearPedLastDamageBone(ped)

                    last = maxHealth
                    takePaint(lost, headshot)
                elseif health > last then
                    last = health
                end

                if Config.PaintEffects.noBlood then
                    ResetPedVisibleDamage(ped)
                end
            else
                last = GetEntityHealth(ped)
            end

            Wait(0)
        end
    end)

    CreateThread(function()
        while Combat.running and PB.match do
            if PB.match.alive and (PB.match.protectedUntil or 0) > GetGameTimer() then
                if IsPedShooting(PlayerPedId()) then
                    PB.match.protectedUntil = 0
                end

                Hud.SetProtection(math.max(0, math.ceil((PB.match.protectedUntil - GetGameTimer()) / 1000)))
            else
                Hud.SetProtection(0)
            end

            Wait(200)
        end
    end)
end

function Combat.Stop()
    if not Combat.running then return end
    Combat.running = false

    SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), 1.0)

    lastAttacker = nil
    reported = {}
end

RegisterNetEvent('XS-Paintball:client:hitmarker', function()
    if not PB.match then return end

    if Config.PaintEffects.hitMarker then Hud.HitMarker() end
    if Config.PaintEffects.hitSound then
        PlaySoundFrontend(-1, 'Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
    end
end)

--[[ Safe zone.

     No firing in the waiting room, and none while you are marked and waiting
     to come back on. Both are how a real field works, and the first one also
     stops the crowd shooting each other while they wait for a match. ]]

CreateThread(function()
    while true do
        local sleep = 300

        if Config.Rules.safeZone then
            local waiting = Staging and Staging.active and not PB.match
            local marked  = PB.match and (not PB.match.alive or PB.match.ended)

            if waiting or marked then
                sleep = 0

                local player = PlayerId()
                DisablePlayerFiring(player, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
        end

        Wait(sleep)
    end
end)
