Objectives = { state = {}, mode = nil, map = nil, team = nil }

local blips = {}
local lastTouch = 0

local function clearBlips()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

function Objectives.Configure(mode, map, team)
    Objectives.mode = mode
    Objectives.map  = map
    Objectives.team = team
end

function Objectives.Set(state)
    Objectives.state = type(state) == 'table' and state or {}
    Hud.SetObjectives(Objectives.state)
end

function Objectives.Clear()
    Objectives.state = {}
    Objectives.mode  = nil
    Objectives.map   = nil
    Objectives.team  = nil
    clearBlips()
end

local function ensureBlip(key, coords, sprite, colour, label)
    local blip = blips[key]

    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, sprite)
        SetBlipColour(blip, colour)
        SetBlipScale(blip, 0.9)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)
        blips[key] = blip
    else
        SetBlipCoords(blip, coords.x, coords.y, coords.z)
        SetBlipColour(blip, colour)
    end

    return blip
end

local function drawFlags()
    local flags = Objectives.state.flags
    if not flags then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for team, flag in pairs(flags) do
        local rgb = Match.TeamColour(team)
        local at = flag.coords or flag.home
        if at then
            local alpha = flag.state == 'carried' and 120 or 200

            DrawMarker(27, at.x, at.y, at.z - 0.9, 0, 0, 0, 0, 0, 0,
                1.4, 1.4, 1.0, rgb[1], rgb[2], rgb[3], alpha,
                false, false, 2, false, nil, nil, false)

            DrawMarker(0, at.x, at.y, at.z + 1.4, 0, 0, 0, 0, 0, 0,
                0.6, 0.6, 0.6, rgb[1], rgb[2], rgb[3], alpha,
                true, false, 2, false, nil, nil, false)

            ensureBlip('flag_' .. team, at,
                flag.state == 'carried' and 303 or 38,
                Config.Teams[team].blip,
                ('%s flag'):format(Config.Teams[team].label))

            if PB.match and PB.match.alive and #(coords - vector3(at.x, at.y, at.z)) < 2.6 then
                if GetGameTimer() - lastTouch > 800 then
                    lastTouch = GetGameTimer()
                    TriggerServerEvent('XS-Paintball:server:touchFlag', team)
                end
            end
        end
    end
end

local function drawPoints()
    local points = Objectives.state.points
    if not points then return end

    for _, point in pairs(points) do
        local rgb = point.owner and Match.TeamColour(point.owner) or { 190, 190, 190 }
        local alpha = point.capturing and 150 or 90

        DrawMarker(1, point.x, point.y, point.z - 1.0, 0, 0, 0, 0, 0, 0,
            point.radius * 2, point.radius * 2, 2.5, rgb[1], rgb[2], rgb[3], alpha,
            false, false, 2, false, nil, nil, false)

        DrawMarker(27, point.x, point.y, point.z + 2.2, 0, 0, 0, 0, 0, 0,
            1.6, 1.6, 1.0, rgb[1], rgb[2], rgb[3], 200,
            false, false, 2, false, nil, nil, false)

        ensureBlip('point_' .. point.id, point, 487,
            point.owner and Config.Teams[point.owner].blip or 0,
            ('Point %s'):format(point.id))

        local dist = #(GetEntityCoords(PlayerPedId()) - vector3(point.x, point.y, point.z))
        if dist < 45.0 then
            Markers.Draw3dText(point.x, point.y, point.z + 1.6, point.id, rgb)
        end
    end
end

local function drawTags()
    local tags = Objectives.state.tags
    if not tags then return end

    local coords = GetEntityCoords(PlayerPedId())

    for key, tag in pairs(tags) do
        local rgb = tag.team and Match.TeamColour(tag.team) or { 230, 230, 230 }
        local mine = tag.team == Objectives.team

        DrawMarker(28, tag.x, tag.y, tag.z + 0.35, 0, 0, 0, 0, 0, 0,
            0.28, 0.28, 0.28, rgb[1], rgb[2], rgb[3], 220,
            false, false, 2, false, nil, nil, false)

        DrawMarker(21, tag.x, tag.y, tag.z + 0.9, 0, 0, 0, 0, 0, 0,
            0.4, 0.4, 0.4, mine and 235 or rgb[1], mine and 64 or rgb[2], mine and 64 or rgb[3], 120,
            true, false, 2, false, nil, nil, false)

        if PB.match and PB.match.alive and #(coords - vector3(tag.x, tag.y, tag.z)) < 2.0 then
            if GetGameTimer() - lastTouch > 400 then
                lastTouch = GetGameTimer()
                TriggerServerEvent('XS-Paintball:server:takeTag', tag.id)
            end
        end
    end
end

CreateThread(function()
    while true do
        local sleep = 750

        if PB.match and not PB.match.ended and Objectives.mode then
            sleep = 0

            if Objectives.mode == 'ctf' then
                drawFlags()
            elseif Objectives.mode == 'domination' then
                drawPoints()
            elseif Objectives.mode == 'confirmed' then
                drawTags()
            else
                sleep = 750
            end
        elseif next(blips) then
            clearBlips()
        end

        Wait(sleep)
    end
end)
