Builder = { active = false, working = nil }

local function emptyMap()
    return {
        name = 'New Map',
        description = '',
        author = '',
        weather = 'EXTRASUNNY',
        time = 12,
        bounds = { kind = 'circle', center = nil, radius = 80.0, points = {}, minZ = -20.0, maxZ = 60.0 },
        lobby = nil,
        spawns = { red = {}, blue = {}, green = {}, yellow = {}, ffa = {} },
        flags = {},
        capturePoints = {},
        props = {},
        spectate = {},
    }
end

local function normalise(map)
    map = type(map) == 'table' and map or {}

    local out = emptyMap()

    out.name        = map.name or out.name
    out.description = map.description or ''
    out.author      = map.author or ''
    out.weather     = map.weather or 'EXTRASUNNY'
    out.time        = map.time or 12
    out.id          = map.id

    if type(map.bounds) == 'table' then
        out.bounds.kind   = map.bounds.kind == 'poly' and 'poly' or 'circle'
        out.bounds.center = map.bounds.center
        out.bounds.radius = map.bounds.radius or 80.0
        out.bounds.points = map.bounds.points or {}
        out.bounds.minZ   = map.bounds.minZ or -20.0
        out.bounds.maxZ   = map.bounds.maxZ or 60.0
    end

    out.lobby = map.lobby

    if type(map.spawns) == 'table' then
        for _, team in ipairs(Config.TeamOrder) do
            out.spawns[team] = map.spawns[team] or {}
        end
        out.spawns.ffa = map.spawns.ffa or {}
    end

    out.flags         = map.flags or {}
    out.capturePoints = map.capturePoints or {}
    out.props         = map.props or {}
    out.spectate      = map.spectate or {}

    return out
end

function Builder.Start(map)
    Builder.working = normalise(map)
    Builder.active = true

    Props.RenderBuilder(Builder.working.props)
end

function Builder.Stop()
    Builder.active = false
    Builder.working = nil

    Placement.Abort()
    Props.ClearBuilder()
    Props.ClearGhost()
end

local function centreOfWork()
    local map = Builder.working
    if not map then return nil end

    if map.bounds.center then return map.bounds.center end
    if map.lobby then return map.lobby end

    for _, team in ipairs(Config.TeamOrder) do
        local first = (map.spawns[team] or {})[1]
        if first then return first end
    end

    return (map.spawns.ffa or {})[1]
end

local function nextPointId(map)
    local used = {}
    for _, point in ipairs(map.capturePoints) do used[point.id] = true end

    for letter in ('ABCDE'):gmatch('.') do
        if not used[letter] then return letter end
    end

    return 'A'
end

local function place(kind, payload)
    local map = Builder.working
    if not map then return false, 'The builder is not open.' end

    local limits = Config.Builder.limits
    local origin = payload.origin

    if kind == 'spawn' then
        local team = payload.team or 'ffa'
        local list = map.spawns[team]
        if not list then return false, 'Unknown team.' end
        if #list >= (team == 'ffa' and limits.spawnsPerTeam * 4 or limits.spawnsPerTeam) then
            return false, 'That is the spawn limit for this team.'
        end

        local colour = team == 'ffa' and { 235, 235, 235 } or Config.Teams[team].colour
        local result = Placement.Start({
            mode = 'point', label = ('%s spawn'):format(team == 'ffa' and 'Free for all' or Config.Teams[team].label),
            colour = colour, origin = origin,
        })

        if not result then return false end
        list[#list + 1] = { x = result.x, y = result.y, z = result.z, h = result.h }
        return true
    end

    if kind == 'flag' then
        local team = payload.team
        if not Config.Teams[team] then return false, 'Unknown team.' end

        local result = Placement.Start({
            mode = 'point', label = ('%s flag'):format(Config.Teams[team].label),
            colour = Config.Teams[team].colour, origin = map.flags[team],
        })

        if not result then return false end
        map.flags[team] = { x = result.x, y = result.y, z = result.z, h = result.h }
        return true
    end

    if kind == 'capture' then
        if #map.capturePoints >= limits.capturePoints then
            return false, ('You can only have %d capture points.'):format(limits.capturePoints)
        end

        local result = Placement.Start({
            mode = 'zone', label = 'Capture point', radius = payload.radius or 8.0, origin = origin,
        })

        if not result then return false end

        map.capturePoints[#map.capturePoints + 1] = {
            id = nextPointId(map),
            x = result.x, y = result.y, z = result.z,
            radius = result.radius or 8.0,
        }
        return true
    end

    if kind == 'lobby' then
        local result = Placement.Start({
            mode = 'point', label = 'Staging point', colour = { 245, 200, 36 }, origin = map.lobby,
        })

        if not result then return false end
        map.lobby = { x = result.x, y = result.y, z = result.z, h = result.h }
        return true
    end

    if kind == 'spectate' then
        if #map.spectate >= 8 then return false, 'Eight cameras is the limit.' end

        local result = Placement.Start({
            mode = 'point', label = 'Spectator camera', colour = { 150, 200, 255 }, origin = origin,
        })

        if not result then return false end
        map.spectate[#map.spectate + 1] = { x = result.x, y = result.y, z = result.z, h = result.h }
        return true
    end

    if kind == 'boundary' then
        local placed = 0
        local last = origin

        while true do
            if #map.bounds.points >= limits.boundaryPoints then
                Framework.Notify('That is the boundary point limit.', 'warning')
                break
            end

            local result = Placement.Start({
                mode = 'boundary', label = ('Boundary corner %d'):format(#map.bounds.points + 1),
                colour = Config.Builder.accent, origin = last,
            })

            if not result then break end
            last = result

            map.bounds.kind = 'poly'
            map.bounds.points[#map.bounds.points + 1] = { x = result.x, y = result.y, z = result.z }
            placed = placed + 1

            if not payload.multi then break end
        end

        if placed > 0 then
            local lowest, highest
            for _, point in ipairs(map.bounds.points) do
                lowest = math.min(lowest or point.z, point.z)
                highest = math.max(highest or point.z, point.z)
            end

            if lowest then
                map.bounds.minZ = Util.round(lowest - 15.0, 2)
                map.bounds.maxZ = Util.round(highest + 45.0, 2)
            end
        end

        return placed > 0
    end

    if kind == 'centre' then
        local result = Placement.Start({
            mode = 'zone', label = 'Arena centre', radius = map.bounds.radius or 80.0,
            origin = map.bounds.center,
        })

        if not result then return false end

        map.bounds.kind   = 'circle'
        map.bounds.center = { x = result.x, y = result.y, z = result.z }
        map.bounds.radius = result.radius or 80.0
        map.bounds.minZ   = Util.round(result.z - 25.0, 2)
        map.bounds.maxZ   = Util.round(result.z + 60.0, 2)
        return true
    end

    if kind == 'prop' then
        local model = payload.model
        if type(model) ~= 'string' or model == '' then return false, 'Pick a prop first.' end

        local placed = 0
        local last = origin

        while true do
            if #map.props >= limits.props then
                Framework.Notify('That is the prop limit for one map.', 'warning')
                break
            end

            local result = Placement.Start({
                mode = 'prop', label = model, model = model, origin = last,
            })

            if not result then break end
            last = result

            map.props[#map.props + 1] = {
                model = model,
                x = result.x, y = result.y, z = result.z,
                rx = result.rx, ry = result.ry, rz = result.rz,
                ground = result.ground == true,
            }

            placed = placed + 1
            Props.RenderBuilder(map.props)

            if not payload.multi then break end
        end

        return placed > 0
    end

    return false, 'Nothing to place.'
end

local function remove(kind, payload)
    local map = Builder.working
    if not map then return false end

    if kind == 'spawn' then
        local list = map.spawns[payload.team or 'ffa']
        if list and list[payload.index] then table.remove(list, payload.index) return true end
        return false
    end

    if kind == 'flag' then
        map.flags[payload.team] = nil
        return true
    end

    if kind == 'capture' then
        if map.capturePoints[payload.index] then
            table.remove(map.capturePoints, payload.index)
            return true
        end
        return false
    end

    if kind == 'prop' then
        if map.props[payload.index] then
            table.remove(map.props, payload.index)
            Props.RenderBuilder(map.props)
            return true
        end
        return false
    end

    if kind == 'spectate' then
        if map.spectate[payload.index] then table.remove(map.spectate, payload.index) return true end
        return false
    end

    if kind == 'boundary' then
        if map.bounds.points[payload.index] then
            table.remove(map.bounds.points, payload.index)
            return true
        end
        return false
    end

    if kind == 'lobby' then
        map.lobby = nil
        return true
    end

    return false
end

RegisterNUICallback('builderOpen', function(data, cb)
    Builder.Start((data or {}).map)
    cb({ ok = true, map = Builder.working })
end)

RegisterNUICallback('builderClose', function(_, cb)
    Builder.Stop()
    cb({ ok = true })
end)

RegisterNUICallback('builderSync', function(data, cb)
    if Builder.working and type(data) == 'table' and type(data.map) == 'table' then
        local props = Builder.working.props
        Builder.working = normalise(data.map)

        if #Builder.working.props ~= #props then
            Props.RenderBuilder(Builder.working.props)
        end
    end

    cb({ ok = true, map = Builder.working })
end)

RegisterNUICallback('builderPlace', function(data, cb)
    data = data or {}

    if not Builder.working then
        cb({ ok = false, error = 'Open a map in the builder first.' })
        return
    end

    PB.Suspend(true)

    CreateThread(function()
        local success, err = place(data.kind, data)

        PB.Suspend(false)
        cb({ ok = success ~= false, cancelled = success == false and err == nil, error = err, map = Builder.working })
    end)
end)

RegisterNUICallback('builderRemove', function(data, cb)
    data = data or {}
    local success = remove(data.kind, data)
    cb({ ok = success, map = Builder.working })
end)

RegisterNUICallback('builderTeleport', function(data, cb)
    data = data or {}

    local point = data.point or centreOfWork()
    if not point then
        cb({ ok = false, error = 'Nothing placed yet.' })
        return
    end

    PB.Suspend(true)

    CreateThread(function()
        Match.Teleport({ x = point.x, y = point.y, z = point.z + 1.0, h = point.h or 0.0 })
        Wait(200)
        PB.Suspend(false)
        cb({ ok = true })
    end)
end)

RegisterNUICallback('builderPreview', function(_, cb)
    if not Builder.working then
        cb({ ok = false, error = 'Open a map first.' })
        return
    end

    Props.RenderBuilder(Builder.working.props)
    cb({ ok = true })
end)

RegisterNUICallback('builderLook', function(_, cb)
    PB.Close()
    Framework.Notify(('Press %s again to reopen the builder.'):format(
        Config.Commands.builder and ('/' .. Config.Commands.builder) or 'the panel key'), 'inform')
    cb({ ok = true })
end)

if Config.Commands.builder then
    RegisterCommand(Config.Commands.builder, function()
        PB.Open('maps')
    end, false)
end

CreateThread(function()
    while true do
        local sleep = 500

        if Builder.active and Builder.working and not Placement.active and not PB.open then
            sleep = 0
            Markers.DrawEditorPoints(nil)
        end

        Wait(sleep)
    end
end)
