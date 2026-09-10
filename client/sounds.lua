Sounds = {}

local S = Config.Sounds

local function playCustom(entry)
    if not S.resource then return false end
    if not entry.file then return false end

    if S.resource == 'interact-sound' then
        if GetResourceState('interact-sound') ~= 'started' then return false end
        TriggerEvent('InteractSound_CL:PlayOnOne', entry.file, entry.volume or S.volume)
        return true
    end

    if S.exportResource ~= '' and S.exportName ~= '' then
        if GetResourceState(S.exportResource) ~= 'started' then return false end

        local ok = pcall(function()
            exports[S.exportResource][S.exportName](nil, entry.file, entry.volume or S.volume)
        end)

        return ok
    end

    return false
end

-- A frontend sound name that does not exist is a no-op rather than an error,
-- so a bad config entry costs silence and nothing else.
function Sounds.Play(id)
    if not S.enabled then return end

    local entry = (S.events or {})[id]
    if not entry then return end

    if playCustom(entry) then return end
    if not entry.set or not entry.name then return end

    PlaySoundFrontend(-1, entry.name, entry.set, true)
end

RegisterNetEvent('XS-Paintball:client:sound', function(id)
    Sounds.Play(id)
end)
