Store = { maps = {}, order = {} }

local function decode(row)
    local data = json.decode(row.data or '{}') or {}
    local map = Maps.Sanitise(data)

    map.id      = row.id
    map.name    = row.name or map.name
    map.author  = row.author or map.author
    map.preset  = row.preset
    map.enabled = Util.truthy(row.enabled)

    return map
end

local function reindex()
    Store.order = {}
    for id in pairs(Store.maps) do Store.order[#Store.order + 1] = id end

    table.sort(Store.order, function(a, b)
        return (Store.maps[a].name or ''):lower() < (Store.maps[b].name or ''):lower()
    end)
end

function Store.Load()
    Store.maps = {}

    local rows = MySQL.query.await('SELECT * FROM xs_paintball_maps') or {}
    for _, row in ipairs(rows) do
        Store.maps[row.id] = decode(row)
    end

    reindex()
    return #Store.order
end

function Store.Get(id)
    return Store.maps[tonumber(id) or -1]
end

function Store.List(includeDisabled)
    local out = {}

    for _, id in ipairs(Store.order) do
        local map = Store.maps[id]
        if includeDisabled or map.enabled then
            local summary = Maps.Summary(map)
            out[#out + 1] = {
                id          = map.id,
                name        = map.name,
                author      = map.author,
                description = map.description,
                enabled     = map.enabled,
                preset      = map.preset ~= nil,
                spawns      = summary.spawns,
                props       = summary.props,
                points      = summary.points,
                boundary    = summary.boundary,
                radius      = summary.radius,
                modes       = summary.modes,
                centre      = map.bounds.center,
            }
        end
    end

    return out
end

function Store.Playable(modeId)
    local out = {}

    for _, id in ipairs(Store.order) do
        local map = Store.maps[id]
        if map.enabled then
            local supported = Maps.SupportedModes(map)
            if not modeId or supported[modeId] then
                out[#out + 1] = { id = map.id, name = map.name, modes = supported }
            end
        end
    end

    return out
end

function Store.Save(data, author)
    local map = Maps.Sanitise(data)
    local check = Maps.Validate(map)
    if not check.ok then
        return nil, check.errors[1]
    end

    local payload = json.encode(map)
    local id = tonumber(data.id)

    if id and Store.maps[id] then
        MySQL.prepare.await(
            'UPDATE xs_paintball_maps SET name = ?, author = ?, data = ? WHERE id = ?',
            { map.name, map.author ~= '' and map.author or author, payload, id })
    else
        id = MySQL.insert.await(
            'INSERT INTO xs_paintball_maps (name, author, enabled, data) VALUES (?, ?, 1, ?)',
            { map.name, map.author ~= '' and map.author or author, payload })

        if not id then return nil, 'The database refused the new map.' end
    end

    map.id      = id
    map.enabled = Store.maps[id] and Store.maps[id].enabled or true
    map.preset  = Store.maps[id] and Store.maps[id].preset or nil

    Store.maps[id] = map
    reindex()

    return map
end

function Store.SetEnabled(id, enabled)
    id = tonumber(id)
    local map = Store.maps[id]
    if not map then return false end

    map.enabled = enabled == true
    MySQL.prepare.await('UPDATE xs_paintball_maps SET enabled = ? WHERE id = ?',
        { map.enabled and 1 or 0, id })

    return true
end

function Store.Rename(id, name)
    id = tonumber(id)
    local map = Store.maps[id]
    if not map then return false end

    map.name = Util.trim(name):sub(1, 48)
    if map.name == '' then return false end

    MySQL.prepare.await('UPDATE xs_paintball_maps SET name = ? WHERE id = ?', { map.name, id })
    reindex()
    return true
end

function Store.Duplicate(id, author)
    local source = Store.Get(id)
    if not source then return nil, 'That map is gone.' end

    local copy = Util.copy(source)
    copy.id     = nil
    copy.preset = nil
    copy.name   = (source.name .. ' Copy'):sub(1, 48)

    return Store.Save(copy, author)
end

function Store.Delete(id)
    id = tonumber(id)
    if not Store.maps[id] then return false end

    MySQL.prepare.await('DELETE FROM xs_paintball_maps WHERE id = ?', { id })
    Store.maps[id] = nil
    reindex()

    return true
end

function Store.Export(id)
    local map = Store.Get(id)
    if not map then return nil end

    local copy = Util.copy(map)
    copy.id      = nil
    copy.enabled = nil
    copy.preset  = nil

    return copy
end

function Store.Import(data, author)
    if type(data) ~= 'table' then return nil, 'That is not a map file.' end

    data.id     = nil
    data.preset = nil

    return Store.Save(data, author)
end

--[[ Overwrite the stored copy of every shipped preset with what is on disk.

     LoadPresets deliberately imports a preset once and never touches it again,
     so a corrected map file has no effect on a server that already imported the
     old one. This is the way to push a fix through.

     It replaces the map data, so anything edited in the builder on a preset map
     is lost. That is why it is a command somebody has to run rather than
     something that happens on restart. ]]
function Store.RefreshPresets()
    local index = LoadResourceFile(GetCurrentResourceName(), 'presets/index.json')
    if not index then return 0, 0 end

    local files = json.decode(index)
    if type(files) ~= 'table' then return 0, 0 end

    local byPreset = {}
    for _, id in ipairs(Store.order) do
        local preset = Store.maps[id].preset
        if preset then byPreset[preset] = id end
    end

    local updated, added = 0, 0

    for _, file in ipairs(files) do
        local raw = LoadResourceFile(GetCurrentResourceName(), 'presets/' .. file)
        local decoded = raw and json.decode(raw)

        if decoded then
            local map = Maps.Sanitise(decoded)
            local check = Maps.Validate(map)

            if check.ok then
                local id = byPreset[file]

                if id then
                    MySQL.prepare.await('UPDATE xs_paintball_maps SET name = ?, data = ? WHERE id = ?',
                        { map.name, json.encode(map), id })

                    map.id      = id
                    map.preset  = file
                    map.enabled = Store.maps[id].enabled
                    Store.maps[id] = map
                    updated = updated + 1
                else
                    local newId = MySQL.insert.await(
                        'INSERT INTO xs_paintball_maps (name, author, preset, enabled, data) VALUES (?, ?, ?, 1, ?)',
                        { map.name, map.author ~= '' and map.author or 'XyraL', file, json.encode(map) })

                    if newId then
                        map.id      = newId
                        map.preset  = file
                        map.enabled = true
                        Store.maps[newId] = map
                        added = added + 1
                    end
                end
            end
        end
    end

    if updated + added > 0 then Store.Load() end

    return updated, added
end

function Store.LoadPresets()
    if not Config.LoadPresetMaps then return 0 end

    local index = LoadResourceFile(GetCurrentResourceName(), 'presets/index.json')
    if not index then return 0 end

    local files = json.decode(index)
    if type(files) ~= 'table' then return 0 end

    local existing = {}
    for _, id in ipairs(Store.order) do
        local preset = Store.maps[id].preset
        if preset then existing[preset] = true end
    end

    local added = 0

    for _, file in ipairs(files) do
        if not existing[file] then
            local raw = LoadResourceFile(GetCurrentResourceName(), 'presets/' .. file)
            local decoded = raw and json.decode(raw)

            if decoded then
                local map = Maps.Sanitise(decoded)
                local check = Maps.Validate(map)

                if check.ok then
                    local id = MySQL.insert.await(
                        'INSERT INTO xs_paintball_maps (name, author, preset, enabled, data) VALUES (?, ?, ?, 1, ?)',
                        { map.name, map.author ~= '' and map.author or 'XyraL', file, json.encode(map) })

                    if id then
                        map.id      = id
                        map.preset  = file
                        map.enabled = true
                        Store.maps[id] = map
                        added = added + 1
                    end
                elseif Config.Debug then
                    print(('^3[XS-Paintball]^0 preset %s skipped: %s'):format(file, check.errors[1]))
                end
            end
        end
    end

    if added > 0 then reindex() end
    return added
end
