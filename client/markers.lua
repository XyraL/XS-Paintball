Markers = {}

local teamBlips = {}

function Markers.Draw3dText(x, y, z, text, rgb, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    rgb = rgb or { 235, 240, 245 }
    scale = scale or 0.32

    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(rgb[1], rgb[2], rgb[3], 235)
    SetTextDropshadow(0, 0, 0, 0, 210)
    SetTextEdge(1, 0, 0, 0, 200)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(sx, sy)
end

local function wall(ax, ay, bx, by, baseZ, height, rgb, alpha)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.01 then return end

    local steps = math.max(1, math.floor(length / 2.5))

    for i = 0, steps do
        local t = i / steps
        local x, y = ax + dx * t, ay + dy * t

        DrawLine(x, y, baseZ, x, y, baseZ + height, rgb[1], rgb[2], rgb[3], alpha)
    end

    DrawLine(ax, ay, baseZ + height, bx, by, baseZ + height, rgb[1], rgb[2], rgb[3], alpha)
    DrawLine(ax, ay, baseZ, bx, by, baseZ, rgb[1], rgb[2], rgb[3], alpha)
end

Markers.Wall = wall

function Markers.DrawBoundary(map)
    if not map or not map.bounds then return end

    local rgb = Config.BoundaryColour
    local alpha = rgb[4] or 60
    local coords = GetEntityCoords(PlayerPedId())
    local b = map.bounds
    local height = 5.0

    if b.kind == 'poly' and #b.points >= 3 then
        for i = 1, #b.points do
            local a = b.points[i]
            local c = b.points[(i % #b.points) + 1]

            local midX, midY = (a.x + c.x) / 2, (a.y + c.y) / 2
            if #(coords - vector3(midX, midY, coords.z)) < 90.0 then
                wall(a.x, a.y, c.x, c.y, a.z, height, rgb, alpha)
            end
        end
        return
    end

    local centre = b.center
    if not centre then return end

    local radius = b.radius or 80.0
    local segments = 64

    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2

        local ax = centre.x + math.cos(a1) * radius
        local ay = centre.y + math.sin(a1) * radius
        local bx = centre.x + math.cos(a2) * radius
        local by = centre.y + math.sin(a2) * radius

        if #(coords - vector3(ax, ay, coords.z)) < 90.0 then
            wall(ax, ay, bx, by, centre.z, height, rgb, alpha)
        end
    end
end

function Markers.UpdateTeamBlips(match)
    if not match or not match.roster then return end

    local self = GetPlayerServerId(PlayerId())
    local seen = {}

    for _, entry in ipairs(match.roster) do
        local sameTeam = match.team and entry.team == match.team

        if sameTeam and entry.source ~= self and not entry.spectator then
            local player = GetPlayerFromServerId(entry.source)

            if player ~= -1 and NetworkIsPlayerActive(player) then
                local blip = teamBlips[entry.source]

                if not blip or not DoesBlipExist(blip) then
                    blip = AddBlipForEntity(GetPlayerPed(player))
                    SetBlipSprite(blip, 1)
                    SetBlipScale(blip, 0.8)
                    SetBlipAsShortRange(blip, false)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentSubstringPlayerName(entry.name or 'Teammate')
                    EndTextCommandSetBlipName(blip)
                    teamBlips[entry.source] = blip
                end

                SetBlipColour(blip, Config.Teams[entry.team] and Config.Teams[entry.team].blip or 0)
                SetBlipAlpha(blip, entry.alive and 255 or 90)
                seen[entry.source] = true
            end
        end
    end

    for source, blip in pairs(teamBlips) do
        if not seen[source] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            teamBlips[source] = nil
        end
    end
end

function Markers.ClearTeamBlips()
    for _, blip in pairs(teamBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    teamBlips = {}
end

local function spawnMarker(point, rgb, label)
    DrawMarker(28, point.x, point.y, point.z + 0.12, 0, 0, 0, 0, 0, 0,
        0.16, 0.16, 0.16, rgb[1], rgb[2], rgb[3], 200,
        false, false, 2, false, nil, nil, false)

    DrawLine(point.x, point.y, point.z, point.x, point.y, point.z + 1.9,
        rgb[1], rgb[2], rgb[3], 180)

    local hx = point.x + math.sin(math.rad(-(point.h or 0.0))) * 1.4
    local hy = point.y + math.cos(math.rad(-(point.h or 0.0))) * 1.4
    DrawLine(point.x, point.y, point.z + 0.1, hx, hy, point.z + 0.1, rgb[1], rgb[2], rgb[3], 220)

    if label then
        Markers.Draw3dText(point.x, point.y, point.z + 2.1, label, rgb)
    end
end

Markers.SpawnMarker = spawnMarker

function Markers.DrawEditorPoints(ghost)
    local map = Builder and Builder.working
    if not map then return end

    local coords = GetEntityCoords(PlayerPedId())
    local near = 120.0

    for _, team in ipairs(Config.TeamOrder) do
        local rgb = Config.Teams[team].colour

        for index, point in ipairs(map.spawns[team] or {}) do
            if #(coords - vector3(point.x, point.y, point.z)) < near then
                spawnMarker(point, rgb, ('%s %d'):format(Config.Teams[team].label, index))
            end
        end
    end

    for index, point in ipairs(map.spawns.ffa or {}) do
        if #(coords - vector3(point.x, point.y, point.z)) < near then
            spawnMarker(point, { 235, 235, 235 }, ('FFA %d'):format(index))
        end
    end

    for team, point in pairs(map.flags or {}) do
        local rgb = Config.Teams[team] and Config.Teams[team].colour or { 235, 235, 235 }

        DrawMarker(27, point.x, point.y, point.z - 0.9, 0, 0, 0, 0, 0, 0,
            1.5, 1.5, 1.0, rgb[1], rgb[2], rgb[3], 180,
            false, false, 2, false, nil, nil, false)

        Markers.Draw3dText(point.x, point.y, point.z + 1.6,
            ('%s flag'):format(Config.Teams[team] and Config.Teams[team].label or team), rgb)
    end

    for _, point in ipairs(map.capturePoints or {}) do
        local accent = Config.Builder.accent

        DrawMarker(1, point.x, point.y, point.z - 1.0, 0, 0, 0, 0, 0, 0,
            point.radius * 2, point.radius * 2, 2.0, accent[1], accent[2], accent[3], 70,
            false, false, 2, false, nil, nil, false)

        Markers.Draw3dText(point.x, point.y, point.z + 1.4,
            ('Point %s  %.1fm'):format(point.id, point.radius), accent)
    end

    if map.lobby then
        DrawMarker(27, map.lobby.x, map.lobby.y, map.lobby.z - 0.9, 0, 0, 0, 0, 0, 0,
            1.8, 1.8, 1.0, 245, 200, 36, 150, false, false, 2, false, nil, nil, false)
        Markers.Draw3dText(map.lobby.x, map.lobby.y, map.lobby.z + 1.6, 'Staging', { 245, 200, 36 })
    end

    for index, point in ipairs(map.spectate or {}) do
        Markers.Draw3dText(point.x, point.y, point.z + 0.4, ('Camera %d'):format(index), { 150, 200, 255 })
    end

    if map.bounds then
        Markers.DrawBoundary(map)
    end
end
