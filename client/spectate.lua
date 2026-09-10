Spectate = { active = false, target = nil, free = false }

local cam = nil
local map = nil
local targets = {}
local index = 1

local function candidates()
    local out = {}
    local self = GetPlayerServerId(PlayerId())

    for _, entry in ipairs((PB.match and PB.match.roster) or (PB.spectateRoster or {})) do
        if entry.source ~= self and not entry.spectator then
            local player = GetPlayerFromServerId(entry.source)
            if player ~= -1 and NetworkIsPlayerActive(player) then
                out[#out + 1] = { source = entry.source, name = entry.name, team = entry.team, player = player }
            end
        end
    end

    return out
end

local function centreOf()
    -- A camera the map author placed beats a guess from above the middle.
    local placed = map and map.spectate and map.spectate[1]
    if placed then
        return vector3(placed.x, placed.y, placed.z)
    end

    if map and map.bounds and map.bounds.center then
        local c = map.bounds.center
        return vector3(c.x, c.y, (c.z or 0.0) + 60.0)
    end

    return GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 40.0)
end

local function ensureCam()
    if cam then return end

    local start = centreOf()

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, start.x, start.y, start.z)
    SetCamRot(cam, -55.0, 0.0, 0.0, 2)
    SetCamFov(cam, 60.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function destroyCam()
    RenderScriptCams(false, true, 400, true, true)

    if cam then
        SetCamActive(cam, false)
        DestroyCam(cam, true)
        cam = nil
    end

    ClearFocus()
end

function Spectate.Start(mapData)
    if Spectate.active then return end

    map = mapData
    Spectate.active = true
    Spectate.free = false
    index = 1

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)

    ensureCam()
    Hud.SetSpectating(true)

    CreateThread(function()
        while Spectate.active do
            targets = candidates()

            if #targets == 0 then
                Spectate.free = true
            end

            if not Spectate.free and #targets > 0 then
                if index > #targets then index = 1 end

                local target = targets[index]
                local targetPed = GetPlayerPed(target.player)

                if DoesEntityExist(targetPed) then
                    local coords = GetEntityCoords(targetPed)
                    local heading = GetEntityHeading(targetPed)
                    local behind = coords - vector3(
                        math.sin(math.rad(heading)) * -3.2,
                        math.cos(math.rad(heading)) * -3.2, -1.4)

                    SetCamCoord(cam, behind.x, behind.y, behind.z)
                    PointCamAtEntity(cam, targetPed, 0.0, 0.0, 0.5, true)
                    SetFocusEntity(targetPed)

                    Hud.SetSpectateTarget(target.name, target.team)
                end
            else
                StopCamPointing(cam)
                Hud.SetSpectateTarget(nil)
            end

            Wait(50)
        end
    end)

    CreateThread(function()
        local speed = 18.0

        while Spectate.active do
            DisableAllControlActions(0)
            EnableControlAction(0, 200, true)

            if IsDisabledControlJustPressed(0, 194) then
                TriggerServerEvent('XS-Paintball:server:leave')
            end

            if IsDisabledControlJustPressed(0, 175) then
                index = index + 1
                Spectate.free = false
            elseif IsDisabledControlJustPressed(0, 174) then
                index = index - 1
                if index < 1 then index = math.max(1, #targets) end
                Spectate.free = false
            end

            if IsDisabledControlJustPressed(0, 22) then
                Spectate.free = not Spectate.free
                if Spectate.free then
                    StopCamPointing(cam)
                    ClearFocus()
                end
            end

            if Spectate.free then
                local rot = GetCamRot(cam, 2)
                local dx = GetDisabledControlNormal(0, 1) * 5.0
                local dy = GetDisabledControlNormal(0, 2) * 5.0

                SetCamRot(cam, math.max(-89.0, math.min(89.0, rot.x - dy)), 0.0, rot.z - dx, 2)

                local pos = GetCamCoord(cam)
                local yaw = math.rad(rot.z)
                local pitch = math.rad(rot.x)
                local fwd = vector3(-math.sin(yaw) * math.abs(math.cos(pitch)),
                    math.cos(yaw) * math.abs(math.cos(pitch)), math.sin(pitch))
                local right = vector3(-fwd.y, fwd.x, 0.0)
                local move = vector3(0.0, 0.0, 0.0)

                if IsDisabledControlPressed(0, 32) then move = move + fwd end
                if IsDisabledControlPressed(0, 33) then move = move - fwd end
                if IsDisabledControlPressed(0, 35) then move = move + right end
                if IsDisabledControlPressed(0, 34) then move = move - right end
                if IsDisabledControlPressed(0, 44) then move = move + vector3(0.0, 0.0, 1.0) end
                if IsDisabledControlPressed(0, 38) then move = move - vector3(0.0, 0.0, 1.0) end

                local boost = IsDisabledControlPressed(0, 21) and 3.0 or 1.0

                if #move > 0.0 then
                    pos = pos + move * (speed * boost * GetFrameTime())
                    SetCamCoord(cam, pos.x, pos.y, pos.z)
                end

                SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
            end

            Wait(0)
        end
    end)
end

function Spectate.Stop()
    if not Spectate.active then return end

    Spectate.active = false
    Spectate.free = false

    destroyCam()

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)

    Hud.SetSpectating(false)
    map = nil
end

RegisterNetEvent('XS-Paintball:client:spectateStart', function(data)
    PB.spectating = true
    PB.spectateRoster = {}

    Props.Build(data.map)
    Objectives.Configure(data.mode, data.map, nil)
    Hud.StartSpectator(data)
    Spectate.Start(data.map)

    local centre = data.map.bounds.center
    if centre then
        SetEntityCoordsNoOffset(PlayerPedId(), centre.x, centre.y, centre.z + 2.0, false, false, false)
    end
end)

RegisterNetEvent('XS-Paintball:client:spectateStop', function()
    PB.spectating = false
    PB.spectateRoster = nil

    Spectate.Stop()
    Props.ClearAll()
    Objectives.Clear()
    Hud.Stop()
end)
