PB = {
    open       = false,
    boot       = nil,
    lobby      = nil,
    match      = nil,
    spectating = false,
    builder    = false,
    entryPeds  = {},
}

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

PB.Send = sendNui

function PB.Open(tab)
    if PB.open then return end

    if PB.match and not PB.match.ended then
        Framework.Notify(('Not in the middle of a match. Hold G for the scoreboard, or /%s to walk out.')
            :format(Config.Commands.leave or 'pbleave'), 'error')
        return
    end

    if PB.spectating then
        Framework.Notify('Press BACKSPACE to stop spectating first.', 'error')
        return
    end

    if Framework.IsBlockedJob() then
        Framework.Notify('You cannot play paintball on duty.', 'error')
        return
    end

    local boot = lib.callback.await('XS-Paintball:bootstrap', false)
    if not boot or not boot.ok then
        Framework.Notify((boot and boot.error) or 'The paintball server is not responding.', 'error')
        return
    end

    PB.boot = boot
    PB.open = true

    SetNuiFocus(true, true)
    sendNui('open', {
        boot    = boot,
        tab     = tab,
        lobby   = PB.lobby,
        inMatch = PB.match ~= nil,
        -- Reopening after Look around drops you back on the map you were
        -- building, not on a stale copy from the database.
        builder = Builder.active and Builder.working or nil,
    })
end

function PB.Close()
    if not PB.open then return end

    PB.open = false
    SetNuiFocus(false, false)
    sendNui('close')
end

function PB.Suspend(state)
    sendNui('suspend', state == true)
    SetNuiFocus(not state, not state)
end

RegisterNUICallback('close', function(_, cb)
    PB.Close()
    cb({ ok = true })
end)

local PASSTHROUGH = {
    'lobbies', 'createLobby', 'joinLobby', 'leaveLobby', 'setTeam', 'setReady',
    'setLoadout', 'saveLoadoutPreset', 'setCosmetics', 'queue', 'hostAction', 'updateLobby', 'kickPlayer', 'startMatch',
    'mapsFor', 'stats', 'adminMaps', 'mapData', 'saveMap', 'validateMap',
    'toggleMap', 'renameMap', 'duplicateMap', 'deleteMap', 'exportMap',
    'importMap', 'settings',
}

for _, endpoint in ipairs(PASSTHROUGH) do
    RegisterNUICallback(endpoint, function(data, cb)
        local result = lib.callback.await('XS-Paintball:' .. endpoint, false, data)
        cb(result or { ok = false, error = 'No answer from the server.' })
    end)
end

RegisterNUICallback('bootstrap', function(_, cb)
    local boot = lib.callback.await('XS-Paintball:bootstrap', false)
    PB.boot = boot
    cb(boot or { ok = false, error = 'No answer from the server.' })
end)

RegisterNetEvent('XS-Paintball:client:lobbyList', function(list)
    if PB.open then sendNui('lobbyList', list) end
end)

RegisterNetEvent('XS-Paintball:client:lobbyState', function(state)
    PB.lobby = state or nil

    if PB.open then sendNui('lobbyState', state) end
    if state and state.state then Hud.SetLobby(state) end

    if not state then Hud.SetLobby(nil) end
end)

local function nearestEntry()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist

    for index, entry in ipairs(Config.EntryPoints) do
        local dist = #(coords - vector3(entry.coords.x, entry.coords.y, entry.coords.z))
        if not bestDist or dist < bestDist then
            best, bestDist = index, dist
        end
    end

    return best, bestDist
end

local function setupEntryPoint(index, entry)
    if entry.blip and entry.blip.enabled then
        local blip = AddBlipForCoord(entry.coords.x, entry.coords.y, entry.coords.z)
        SetBlipSprite(blip, entry.blip.sprite)
        SetBlipColour(blip, entry.blip.colour)
        SetBlipScale(blip, entry.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(entry.blip.label or entry.label)
        EndTextCommandSetBlipName(blip)
    end

    if entry.ped then
        local model = joaat(entry.ped)
        RequestModel(model)

        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end

        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, entry.coords.x, entry.coords.y, entry.coords.z - 1.0, entry.coords.w, false, false)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            SetPedCanRagdoll(ped, false)
            SetModelAsNoLongerNeeded(model)

            if entry.scenario then TaskStartScenarioInPlace(ped, entry.scenario, 0, true) end

            PB.entryPeds[index] = ped

            Target.AddEntity(ped, entry.label, 'fa-solid fa-crosshairs', function()
                PB.Open()
            end)
        end
    end

    if not entry.ped or Target.name == 'none' then
        Target.AddSphere(('xs_paintball_entry_%d'):format(index),
            entry.coords, Config.Interaction.distance, entry.label, 'fa-solid fa-crosshairs',
            function() PB.Open() end)
    end
end

CreateThread(function()
    for index, entry in ipairs(Config.EntryPoints) do
        setupEntryPoint(index, entry)
    end
end)

CreateThread(function()
    if Target.name ~= 'none' then return end

    local I = Config.Interaction

    while true do
        local sleep = 1000
        local index, dist = nearestEntry()

        if index and dist and dist < 12.0 then
            sleep = 0
            local entry = Config.EntryPoints[index]

            DrawMarker(I.markerType, entry.coords.x, entry.coords.y, entry.coords.z - 0.9,
                0, 0, 0, 0, 0, 0, I.markerSize, I.markerSize, 0.4,
                I.markerRGB[1], I.markerRGB[2], I.markerRGB[3], 120,
                false, false, 2, false, nil, nil, false)

            if dist < I.distance then
                lib.showTextUI(('[E] %s'):format(entry.label))

                if IsControlJustReleased(0, I.key) then
                    lib.hideTextUI()
                    PB.Open()
                end
            else
                lib.hideTextUI()
            end
        end

        Wait(sleep)
    end
end)

if Config.Commands.open then
    RegisterCommand(Config.Commands.open, function()
        if not Config.OpenAnywhere then
            local _, dist = nearestEntry()
            if not dist or dist > 25.0 then
                if not PB.lobby and not PB.match then
                    Framework.Notify('Head to the paintball arena first.', 'error')
                    return
                end
            end
        end

        PB.Open()
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.open, 'Open the paintball panel')
end

if Config.Commands.leave then
    RegisterCommand(Config.Commands.leave, function()
        if not PB.lobby and not PB.match then
            Framework.Notify('You are not in a lobby.', 'error')
            return
        end

        TriggerServerEvent('XS-Paintball:server:leave')
    end, false)
end

if Config.TeamOutfits then
    for team, data in pairs(Config.Teams) do
        if data.outfitCommand then
            RegisterCommand(data.outfitCommand, function()
                local ped = PlayerPedId()
                local outfit = { components = {}, props = {} }

                for slot = 0, 11 do
                    outfit.components[#outfit.components + 1] = {
                        slot    = slot,
                        drawable = GetPedDrawableVariation(ped, slot),
                        texture  = GetPedTextureVariation(ped, slot),
                    }
                end

                for slot = 0, 7 do
                    outfit.props[#outfit.props + 1] = {
                        slot    = slot,
                        drawable = GetPedPropIndex(ped, slot),
                        texture  = GetPedPropTextureIndex(ped, slot),
                    }
                end

                TriggerServerEvent('XS-Paintball:server:saveOutfit', team, outfit)
            end, false)
        end
    end
end

RegisterNetEvent('XS-Paintball:client:queue', function(state)
    PB.queue = state or nil

    Hud.SetQueue(state)
    if PB.open then sendNui('queue', state) end
end)

RegisterNetEvent('XS-Paintball:client:levelUp', function(level)
    Hud.Announce(('Level %d'):format(level), 'success')
    Framework.Notify(('You reached paintball level %d.'):format(level), 'success')
end)

RegisterNetEvent('XS-Paintball:client:announce', function(payload)
    if type(payload) ~= 'table' then return end
    Hud.Announce(payload.text, payload.tone)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, ped in pairs(PB.entryPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end

    SetNuiFocus(false, false)
    lib.hideTextUI()

    if PB.match then Match.Teardown('resource stopped') end
    if PB.builder then Builder.Stop() end

    Props.ClearAll()
end)

--[[ Host controls, without leaving the arena.

     The full panel is blocked during a match on purpose, so the host gets this
     instead: a small overlay for the handful of things somebody running a match
     actually needs. The server checks host or admin again on every action. ]]

PB.host = false

local function myRow()
    if not PB.match or not PB.match.roster then return nil end

    local self = GetPlayerServerId(PlayerId())
    for _, entry in ipairs(PB.match.roster) do
        if entry.source == self then return entry end
    end

    return nil
end

function PB.OpenHost()
    if PB.host then return end

    if not PB.match or PB.match.ended then
        Framework.Notify('Only during a match.', 'error')
        return
    end

    local me = myRow()
    local isAdmin = PB.boot and PB.boot.isAdmin

    if not (me and me.host) and not isAdmin then
        Framework.Notify('Only the host can do that.', 'error')
        return
    end

    local data = lib.callback.await('XS-Paintball:hostPanel', false)

    if not data or not data.ok then
        Framework.Notify((data and data.error) or 'Could not open host controls.', 'error')
        return
    end

    PB.host = true
    SetNuiFocus(true, true)
    sendNui('host', data)
end

function PB.CloseHost()
    if not PB.host then return end

    PB.host = false
    SetNuiFocus(false, false)
    sendNui('host', false)
end

RegisterNUICallback('hostClose', function(_, cb)
    PB.CloseHost()
    cb({ ok = true })
end)

RegisterCommand('pbhost', function()
    if PB.host then PB.CloseHost() else PB.OpenHost() end
end, false)

RegisterKeyMapping('pbhost', 'Paintball: host controls', 'keyboard', 'F7')

RegisterNetEvent('XS-Paintball:client:matchStop', function()
    if PB.host then PB.CloseHost() end
end)
