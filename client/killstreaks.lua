Killstreaks = { uavUntil = 0, machineUntil = 0 }

local enemyBlips = {}

local function clearEnemyBlips()
    for _, blip in pairs(enemyBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    enemyBlips = {}
end

function Killstreaks.Clear()
    Killstreaks.uavUntil = 0
    Killstreaks.machineUntil = 0
    clearEnemyBlips()
    Hud.SetStreak(nil)
end

local function startUav(duration)
    Killstreaks.uavUntil = GetGameTimer() + (duration * 1000)
    Hud.SetStreak({ label = 'UAV', until_ = Killstreaks.uavUntil })
end

local function resupply()
    if not PB.match then return end
    Match.GiveLoadout(PB.match.loadout, Config.Loadout.ammo)
end

local function deathMachine(reward)
    if not PB.match then return end

    local ped = PlayerPedId()
    local hash = joaat(reward.weapon or 'WEAPON_MINIGUN')

    GiveWeaponToPed(ped, hash, reward.ammo or 200, false, true)
    SetPedAmmo(ped, hash, reward.ammo or 200)
    SetCurrentPedWeapon(ped, hash, true)

    Killstreaks.machineUntil = GetGameTimer() + ((reward.duration or 30) * 1000)
    Hud.SetStreak({ label = reward.label, until_ = Killstreaks.machineUntil })

    CreateThread(function()
        while PB.match and GetGameTimer() < Killstreaks.machineUntil do
            Hud.SetStreak({ label = reward.label, until_ = Killstreaks.machineUntil })
            Wait(500)
        end

        local current = PlayerPedId()
        if HasPedGotWeapon(current, hash, false) then
            RemoveWeaponFromPed(current, hash)
            if PB.match and PB.match.alive then
                Match.GiveLoadout(PB.match.loadout, Config.Loadout.ammo)
            end
        end

        Killstreaks.machineUntil = 0
        Hud.SetStreak(nil)
    end)
end

RegisterNetEvent('XS-Paintball:client:killstreak', function(reward)
    if not PB.match or type(reward) ~= 'table' then return end

    Hud.Announce(reward.label, 'success')
    if Sounds then Sounds.Play('killstreak') end
    Framework.Notify(reward.description or reward.label, 'success')

    if reward.id == 'uav' then
        startUav(reward.duration or 30)
    elseif reward.id == 'resupply' then
        resupply()
    elseif reward.id == 'armour' then
        Combat.AddPaint(reward.amount or 50)
    elseif reward.id == 'deathmachine' then
        deathMachine(reward)
    end
end)

RegisterNetEvent('XS-Paintball:client:uav', function(duration)
    if not PB.match then return end

    Hud.Announce('UAV overhead', 'inform')
    startUav(duration or 30)
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if PB.match and not PB.match.ended and GetGameTimer() < Killstreaks.uavUntil then
            sleep = 900

            if Killstreaks.machineUntil == 0 then
                Hud.SetStreak({ label = 'UAV', until_ = Killstreaks.uavUntil })
            end

            local seen = {}

            for _, entry in ipairs(PB.match.roster or {}) do
                local isEnemy = not PB.match.team or entry.team ~= PB.match.team

                if isEnemy and entry.alive and entry.source ~= GetPlayerServerId(PlayerId()) then
                    local player = GetPlayerFromServerId(entry.source)

                    if player ~= -1 and NetworkIsPlayerActive(player) then
                        local ped = GetPlayerPed(player)
                        local blip = enemyBlips[entry.source]

                        if not blip or not DoesBlipExist(blip) then
                            blip = AddBlipForEntity(ped)
                            SetBlipSprite(blip, 1)
                            SetBlipColour(blip, 76)
                            SetBlipScale(blip, 0.75)
                            SetBlipAsShortRange(blip, false)
                            enemyBlips[entry.source] = blip
                        end

                        seen[entry.source] = true
                    end
                end
            end

            for source, blip in pairs(enemyBlips) do
                if not seen[source] then
                    if DoesBlipExist(blip) then RemoveBlip(blip) end
                    enemyBlips[source] = nil
                end
            end
        elseif next(enemyBlips) then
            clearEnemyBlips()
            if Killstreaks.machineUntil == 0 then Hud.SetStreak(nil) end
        end

        Wait(sleep)
    end
end)
