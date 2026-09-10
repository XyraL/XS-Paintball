Target = { name = 'none' }

local forced = Config.Bridges and Config.Bridges.target or 'auto'

if forced ~= 'auto' then
    Target.name = forced
elseif GetResourceState('ox_target') == 'started' then
    Target.name = 'ox_target'
elseif GetResourceState('qb-target') == 'started' then
    Target.name = 'qb-target'
end

local zones = {}

function Target.AddEntity(entity, label, icon, onSelect)
    if Target.name == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, {
            {
                name     = ('xs_paintball_%s'):format(entity),
                label    = label,
                icon     = icon or 'fa-solid fa-crosshairs',
                distance = Config.Interaction.distance + 0.5,
                onSelect = onSelect,
            },
        })
        return true
    end

    if Target.name == 'qb-target' then
        exports['qb-target']:AddTargetEntity(entity, {
            options = {
                { label = label, icon = icon or 'fa-solid fa-crosshairs', action = onSelect },
            },
            distance = Config.Interaction.distance + 0.5,
        })
        return true
    end

    return false
end

function Target.AddSphere(id, coords, radius, label, icon, onSelect)
    if Target.name == 'ox_target' then
        zones[id] = exports.ox_target:addSphereZone({
            coords  = vec3(coords.x, coords.y, coords.z),
            radius  = radius,
            options = {
                {
                    name     = id,
                    label    = label,
                    icon     = icon or 'fa-solid fa-crosshairs',
                    onSelect = onSelect,
                },
            },
        })
        return true
    end

    if Target.name == 'qb-target' then
        exports['qb-target']:AddCircleZone(id, vec3(coords.x, coords.y, coords.z), radius, {
            name = id,
            useZ = true,
        }, {
            options = {
                { label = label, icon = icon or 'fa-solid fa-crosshairs', action = onSelect },
            },
            distance = Config.Interaction.distance + 0.5,
        })
        zones[id] = id
        return true
    end

    return false
end

function Target.Remove(id)
    local handle = zones[id]
    if not handle then return end

    if Target.name == 'ox_target' then
        exports.ox_target:removeZone(handle)
    elseif Target.name == 'qb-target' then
        exports['qb-target']:RemoveZone(handle)
    end

    zones[id] = nil
end

function Target.RemoveEntity(entity)
    if Target.name == 'ox_target' then
        exports.ox_target:removeLocalEntity(entity)
    elseif Target.name == 'qb-target' then
        exports['qb-target']:RemoveTargetEntity(entity)
    end
end

if Config.Debug then
    print(('^2[XS-Paintball]^0 target bridge: %s'):format(Target.name))
end
