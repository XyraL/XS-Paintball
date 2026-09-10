Staging = { active = false }

local origin = nil
local blip = nil

local function point()
    local c = Config.Staging.coords
    return { x = c.x, y = c.y, z = c.z, h = c.w or 0.0 }
end

function Staging.Enter()
    if Staging.active or not Config.Staging.enabled then return end

    local ped = PlayerPedId()

    origin = {
        coords  = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
    }

    Staging.active = true
    Match.Teleport(point())

    Framework.Notify('Waiting room. You go back where you were when you leave.', 'inform')
end

function Staging.Leave()
    if not Staging.active then return end

    Staging.active = false

    if origin and origin.coords then
        Match.Teleport({
            x = origin.coords.x, y = origin.coords.y, z = origin.coords.z,
            h = origin.heading,
        })
    end

    origin = nil
end

-- Where the player would be put back to. The builder and the match both need
-- this so that leaving from inside an arena does not strand anyone.
function Staging.Origin()
    return origin
end

RegisterNetEvent('XS-Paintball:client:staging', function(state)
    if state then Staging.Enter() else Staging.Leave() end
end)

CreateThread(function()
    if not Config.Staging.enabled or not Config.Staging.blip.enabled then return end

    local c = Config.Staging.coords
    blip = AddBlipForCoord(c.x, c.y, c.z)

    SetBlipSprite(blip, Config.Staging.blip.sprite)
    SetBlipColour(blip, Config.Staging.blip.colour)
    SetBlipScale(blip, Config.Staging.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Staging.blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- Wandering out of the waiting room puts you back on the spot. Players in here
-- are in their own routing bucket, so there is nothing outside it to explore.
CreateThread(function()
    while true do
        local sleep = 1000

        if Staging.active and not PB.match and not PB.spectating then
            local c = Config.Staging.coords
            local here = GetEntityCoords(PlayerPedId())

            if #(here - vector3(c.x, c.y, c.z)) > Config.Staging.radius then
                Match.Teleport(point())
                Framework.Notify('Stay in the waiting room until the match starts.', 'warning')
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end)
