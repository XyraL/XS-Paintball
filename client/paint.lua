--[[ Paint on the world.

     Every shot you land leaves a splat in your team's colour on whatever it
     hit. It is a base game decal tinted to the team, so it needs no assets,
     and it projects along the line you fired so it lies flat on the surface
     rather than being dropped from above. ]]

local function teamColour()
    if not PB.match then return { 224, 22, 95 } end
    return Match.TeamColour(PB.match.team)
end

CreateThread(function()
    local last = 0

    while true do
        local sleep = 250
        local D = Config.PaintEffects.decals

        if D and D.enabled and PB.match and PB.match.alive and not PB.match.ended then
            sleep = 0

            local ped = PlayerPedId()

            if IsPedShooting(ped) and GetGameTimer() - last > 45 then
                local hit, coords = GetPedLastWeaponImpactCoord(ped)

                if hit then
                    last = GetGameTimer()

                    local from = GetGameplayCamCoord()
                    local dir = coords - from
                    local length = #dir

                    if length > 0.1 then
                        dir = dir / length

                        local rgb = teamColour()

                        AddDecal(D.type, coords.x, coords.y, coords.z,
                            dir.x, dir.y, dir.z, 0.0, 0.0, 0.0,
                            D.size, D.size,
                            rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1.0,
                            D.timeout, true, false, false)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('XS-Paintball:client:matchStop', function()
    -- Nothing to undo: decals expire on their own timeout.
end)
