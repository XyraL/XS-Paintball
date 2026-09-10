Match = {}

local origin = nil

-- Sound and dispatch are optional files. Guard them here as well as in
-- client/fallbacks.lua, so a half-uploaded resource still runs a match.
local function playSound(id)
    if Sounds then Sounds.Play(id) end
end

local function setDispatchState(inMatch)
    if Dispatch then Dispatch.SetInMatch(inMatch) end
end

local function teamColour(team)
    local data = Config.Teams[team]
    return data and data.colour or { 235, 235, 235 }
end

Match.TeamColour = teamColour

local function giveLoadout(loadout, ammo)
    local ped = PlayerPedId()

    RemoveAllPedWeapons(ped, true)

    local slots = { 'primary', 'secondary', 'melee' }
    local first = nil

    for _, slot in ipairs(slots) do
        local name = loadout and loadout[slot]
        if name then
            local hash = joaat(name)
            local rounds = slot == 'melee' and 0 or ((ammo and ammo[slot]) or 100)

            GiveWeaponToPed(ped, hash, rounds, false, false)
            SetPedAmmo(ped, hash, rounds)

            for _, component in ipairs(Config.Loadout.components or {}) do
                if DoesWeaponTakeWeaponComponent(hash, joaat(component)) then
                    GiveWeaponComponentToPed(ped, hash, joaat(component))
                end
            end

            local tint = PB.match and PB.match.cosmetics and PB.match.cosmetics.tint
            if tint and tint > 0 then SetPedWeaponTintIndex(ped, hash, tint) end

            if not first and slot ~= 'melee' then first = hash end
        end
    end

    if first then SetCurrentPedWeapon(ped, first, true) end
end

Match.GiveLoadout = giveLoadout

local appearance = nil

local function captureAppearance()
    local ped = PlayerPedId()
    local out = { components = {}, props = {} }

    for slot = 0, 11 do
        out.components[#out.components + 1] = {
            slot = slot,
            drawable = GetPedDrawableVariation(ped, slot),
            texture  = GetPedTextureVariation(ped, slot),
        }
    end

    for slot = 0, 7 do
        out.props[#out.props + 1] = {
            slot = slot,
            drawable = GetPedPropIndex(ped, slot),
            texture  = GetPedPropTextureIndex(ped, slot),
        }
    end

    return out
end

local function wearAppearance(outfit)
    if type(outfit) ~= 'table' then return end

    local ped = PlayerPedId()

    for _, item in ipairs(outfit.components or {}) do
        SetPedComponentVariation(ped, item.slot, item.drawable, item.texture, 0)
    end

    for _, item in ipairs(outfit.props or {}) do
        if item.drawable == -1 then
            ClearPedProp(ped, item.slot)
        else
            SetPedPropIndex(ped, item.slot, item.drawable, item.texture, true)
        end
    end
end

-- An unlocked kit wins over the personal team outfit, because the player had
-- to pick it. Neither touches the real character: whatever they walked in
-- wearing is captured first and put back at the end.
local function applyKit(kitId, team)
    if not Config.Cosmetics.enabled then return false end

    local kit = Cosmetics.GetKit(kitId)
    if not kit then return false end

    local ped = PlayerPedId()
    local female = GetEntityModel(ped) == joaat('mp_f_freemode_01')
    local set = (female and kit.female or kit.male) or {}

    if #(set.components or {}) == 0 and #(set.props or {}) == 0 then return false end

    local teamTexture = Config.Cosmetics.teamTexture
    local override = teamTexture and team and teamTexture[team] or nil

    for _, item in ipairs(set.components or {}) do
        local texture = item.texture
        if override and item.slot == 11 then texture = override end
        SetPedComponentVariation(ped, item.slot, item.drawable, texture, 0)
    end

    for _, item in ipairs(set.props or {}) do
        SetPedPropIndex(ped, item.slot, item.drawable, item.texture, true)
    end

    return true
end

local function applyOutfit(team)
    if not Config.TeamOutfits or not team then return end

    local outfit = lib.callback.await('XS-Paintball:outfit', false, team)
    if type(outfit) ~= 'table' then return end

    local ped = PlayerPedId()

    for _, item in ipairs(outfit.components or {}) do
        SetPedComponentVariation(ped, item.slot, item.drawable, item.texture, 0)
    end

    for _, item in ipairs(outfit.props or {}) do
        if item.drawable == -1 then
            ClearPedProp(ped, item.slot)
        else
            SetPedPropIndex(ped, item.slot, item.drawable, item.texture, true)
        end
    end
end

local function teleport(point)
    local ped = PlayerPedId()

    DoScreenFadeOut(300)
    local timeout = GetGameTimer() + 1500
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

    SetEntityCoordsNoOffset(ped, point.x, point.y, point.z, false, false, false)
    SetEntityHeading(ped, point.h or 0.0)

    local settle = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < settle do Wait(50) end

    Wait(150)
    DoScreenFadeIn(400)
end

Match.Teleport = teleport

function Match.Spawn(point, loadout, ammo, protect)
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(point.x, point.y, point.z, point.h or 0.0, true, false)
    end

    SetEntityInvincible(ped, false)

    teleport(point)

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedLastWeaponDamage(ped)
    SetPedArmour(ped, 0)

    giveLoadout(loadout, ammo)

    if PB.match then
        PB.match.paint = PB.match.rules.paintHealth or Config.Rules.paintHealth
        PB.match.paintMax = PB.match.paint
        PB.match.alive = true
        PB.match.protectedUntil = GetGameTimer() + ((protect or 0) * 1000)
        PB.match.lastHealth = GetEntityHealth(ped)
    end

    Hud.SetPaint(PB.match and PB.match.paint or 100, PB.match and PB.match.paintMax or 100)
    Hud.SetState('alive')
end

local function applyWorld(map)
    if map.weather then
        SetWeatherTypeNowPersist(map.weather)
        SetOverrideWeather(map.weather)
    end

    if map.time then
        NetworkOverrideClockTime(map.time, 0, 0)
    end
end

local function clearWorld()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    NetworkClearClockTimeOverride()
end

RegisterNetEvent('XS-Paintball:client:matchStart', function(data)
    -- Round two onwards keeps the props, the world override, the kit and the
    -- saved origin. Tearing all that down and rebuilding it between rounds
    -- would mean a second fade and a fresh 400-prop load for nothing.
    local continuing = data.continuing == true and PB.match ~= nil

    if PB.match and not continuing then Match.Teardown('restart') end

    local ped = PlayerPedId()

    if not continuing then
        origin = {
            coords  = GetEntityCoords(ped),
            heading = GetEntityHeading(ped),
            health  = GetEntityHealth(ped),
            armour  = GetPedArmour(ped),
        }
    end

    PB.match = {
        lobbyId   = data.lobbyId,
        map       = data.map,
        mode      = data.mode,
        modeLabel = data.modeLabel,
        rules     = data.rules,
        team      = data.team,
        teams     = data.teams,
        loadout   = data.loadout,
        ammoPlan  = data.ammo,
        timeLeft  = data.timeLeft or data.rules.timeLimit,
        scores    = data.scores or {},
        roster    = data.roster or {},
        objectives = data.objectives or {},
        alive     = true,
        paint     = data.rules.paintHealth or Config.Rules.paintHealth,
        paintMax  = data.rules.paintHealth or Config.Rules.paintHealth,
        tier      = data.tier or 1,
        lives     = data.lives,
        cosmetics = data.cosmetics,
        round     = data.round or 1,
        rounds    = data.rounds or 1,
        roundWins = data.roundWins or {},
        startedAt = GetGameTimer(),
    }

    PB.Close()

    Objectives.Set(data.objectives)
    Objectives.Configure(data.mode, data.map, data.team)

    if not continuing then
        applyWorld(data.map)
        Props.Build(data.map)

        -- Capture first, so whatever goes on next can always be undone.
        appearance = captureAppearance()

        local wearingKit = data.cosmetics and applyKit(data.cosmetics.kit, data.team)
        if not wearingKit and Config.TeamOutfits then applyOutfit(data.team) end

        setDispatchState(true)
        Gear.Wear()
    elseif data.cosmetics then
        -- Sides may have swapped, so the team texture on the kit has to follow.
        applyKit(data.cosmetics.kit, data.team)
    end

    SetCanAttackFriendly(ped, true, true)
    NetworkSetFriendlyFireOption(true)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    SetPedSuffersCriticalHits(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPlayerCanDoDriveBy(PlayerId(), false)

    Match.Spawn(data.spawn, data.loadout, data.ammo, data.rules.spawnProtect)

    Hud.Start(PB.match)
    Hud.SetObjectives(PB.match.objectives)
    Combat.Start()

    if continuing then
        Hud.Announce(('Round %d'):format(PB.match.round), 'inform')
    else
        Framework.Notify(('%s on %s. Good luck.'):format(data.modeLabel, data.map.name), 'success')
    end
end)

RegisterNetEvent('XS-Paintball:client:roundEnd', function(data)
    if not PB.match and not PB.spectating then return end

    if PB.match then
        PB.match.alive = false
        PB.match.roundWins = data.roundWins or PB.match.roundWins
    end

    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetEntityInvincible(ped, true)

    Hud.ShowRound(data)
end)

RegisterNetEvent('XS-Paintball:client:respawn', function(payload)
    if not PB.match then return end

    PB.match.alive = false
    PB.match.lives = payload.lives
    PB.match.loadout = payload.loadout

    if Config.Rules.handsUpWhenOut then
        TaskHandsUp(PlayerPedId(), math.max(1, payload.delay or 3) * 1000, -1, -1, true)
    end

    Hud.SetState('dead', payload.delay)
    Combat.OnDeath()

    CreateThread(function()
        local remaining = payload.delay or 0

        while remaining > 0 do
            Hud.SetRespawn(remaining)
            Wait(1000)
            remaining = remaining - 1

            if not PB.match then return end
        end

        Hud.SetRespawn(0)
        playSound('respawn')
        Match.Spawn(payload.spawn, payload.loadout, payload.ammo, payload.protect)
    end)
end)

RegisterNetEvent('XS-Paintball:client:eliminated', function()
    if not PB.match then return end

    PB.match.alive = false
    PB.match.spectating = true

    Hud.SetState('eliminated')
    Framework.Notify('You are out. Watching the rest.', 'warning')

    Spectate.Start(PB.match.map)
end)

RegisterNetEvent('XS-Paintball:client:matchUpdate', function(payload)
    if PB.spectating then
        PB.spectateRoster = payload.roster
        Objectives.Set(payload.objectives)
        Hud.Update(payload)
        return
    end

    if not PB.match then return end

    PB.match.scores = payload.scores or PB.match.scores
    PB.match.roster = payload.roster
    PB.match.timeLeft = payload.timeLeft

    Objectives.Set(payload.objectives)
    Hud.Update(payload)
end)

RegisterNetEvent('XS-Paintball:client:objectives', function(objectives)
    if PB.match then PB.match.objectives = objectives end
    if PB.match or PB.spectating then Objectives.Set(objectives) end
end)

RegisterNetEvent('XS-Paintball:client:killfeed', function(entry)
    Hud.Killfeed(entry)
end)

RegisterNetEvent('XS-Paintball:client:tier', function(tier)
    if not PB.match then return end

    PB.match.tier = tier
    local ladder = Config.GunGameLadder
    local weapon = ladder[math.min(tier, #ladder)]

    if weapon and PB.match.alive then
        giveLoadout({ primary = weapon }, Config.Loadout.ammo)
    end

    Hud.SetTier(tier, #ladder, Weapons.Label(weapon))
end)

RegisterNetEvent('XS-Paintball:client:ammo', function(rounds)
    if not PB.match then return end

    local ped = PlayerPedId()
    local hash = joaat(Config.OitcWeapon)
    SetPedAmmo(ped, hash, rounds)

    Hud.Announce(('%d round%s left'):format(rounds, rounds == 1 and '' or 's'), 'inform')
end)

RegisterNetEvent('XS-Paintball:client:matchEnd', function(result)
    if PB.spectating then
        Hud.ShowResult(result)
        return
    end

    if not PB.match then return end

    PB.match.ended = true
    PB.match.alive = false

    Hud.ShowResult(result)

    local ped = PlayerPedId()
    SetEntityInvincible(ped, true)
    RemoveAllPedWeapons(ped, true)
end)

RegisterNetEvent('XS-Paintball:client:matchStop', function(reason)
    Match.Teardown(reason)
end)

function Match.Teardown(reason)
    if not PB.match then return end

    local ped = PlayerPedId()

    Combat.Stop()
    Hud.Stop()
    Objectives.Clear()
    Killstreaks.Clear()
    Props.ClearAll()
    Spectate.Stop()
    Markers.ClearTeamBlips()
    clearWorld()

    RemoveAllPedWeapons(ped, true)
    SetEntityInvincible(ped, false)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 1.0)
    SetPedSuffersCriticalHits(ped, true)
    SetPedCanRagdoll(ped, true)
    SetEntityHealth(ped, origin and origin.health or GetEntityMaxHealth(ped))
    SetPedArmour(ped, origin and origin.armour or 0)
    ClearPedBloodDamage(ped)

    setDispatchState(false)
    Gear.Remove()

    -- Back into their own clothes, whatever the kit did.
    wearAppearance(appearance)
    appearance = nil

    if origin and origin.coords then
        teleport({ x = origin.coords.x, y = origin.coords.y, z = origin.coords.z, h = origin.heading })
    end

    PB.match = nil
    origin = nil

    if reason == 'left' or reason == 'kicked' then
        Framework.Notify('You left the arena.', 'inform')
    end
end

CreateThread(function()
    while true do
        local sleep = 1000

        if PB.match and not PB.match.ended then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            TriggerServerEvent('XS-Paintball:server:position', {
                x = coords.x, y = coords.y, z = coords.z,
            })

            Markers.UpdateTeamBlips(PB.match)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    local warnedAt = 0

    while true do
        local sleep = 500

        if PB.match and PB.match.alive and not PB.match.ended then
            sleep = 250

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if not Maps.InBounds(PB.match.map, coords.x, coords.y, coords.z) then
                if not PB.match.outSince then
                    PB.match.outSince = GetGameTimer()
                end

                local out = (GetGameTimer() - PB.match.outSince) / 1000
                local limit = Config.Rules.outOfBounds

                Hud.SetBounds(math.max(0, math.ceil(limit - out)))

                if GetGameTimer() - warnedAt > 1500 then
                    warnedAt = GetGameTimer()
                    playSound('outOfBounds')
                end

                if out >= limit then
                    PB.match.outSince = nil
                    Hud.SetBounds(nil)
                    Combat.SelfEliminate('out of bounds')
                end
            elseif PB.match.outSince then
                PB.match.outSince = nil
                Hud.SetBounds(nil)
            end

            if Config.Rules.forceThirdPerson and GetFollowPedCamViewMode() == 4 then
                SetFollowPedCamViewMode(1)
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if PB.match and not PB.match.ended and Config.DrawBoundary then
            sleep = 0
            Markers.DrawBoundary(PB.match.map)
        end

        Wait(sleep)
    end
end)
