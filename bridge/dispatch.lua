-- Paintball shots must not reach your dispatch or MDT resource. There is no
-- NPC police in FiveM, so there is no wanted level involved — the only thing
-- that reports gunfire is another resource watching for it client side, and
-- nothing here can reach inside that. So this does three things: it tells the
-- resources you have named that a player is in a match, it fires an event any
-- resource can listen for, and it answers the question on demand through an
-- export.

Dispatch = { inMatch = false }

local function callMuteExports(inMatch)
    for _, entry in ipairs(Config.Dispatch.mute or {}) do
        if entry.resource and entry.export and GetResourceState(entry.resource) == 'started' then
            local ok = pcall(function()
                exports[entry.resource][entry.export](nil, inMatch)
            end)

            if not ok and Config.Debug then
                print(('^3[XS-Paintball]^0 mute export %s:%s failed'):format(entry.resource, entry.export))
            end
        end
    end
end

function Dispatch.SetInMatch(inMatch)
    inMatch = inMatch == true
    if Dispatch.inMatch == inMatch then return end

    Dispatch.inMatch = inMatch

    -- Anything running on this client can listen for this instead of polling
    -- the export.
    TriggerEvent('XS-Paintball:client:matchStateChanged', inMatch)

    callMuteExports(inMatch)
end

exports('IsPlayerInMatch', function()
    return Dispatch.inMatch
end)

CreateThread(function()
    while true do
        local sleep = 500

        if Dispatch.inMatch and Config.Dispatch.suppressShockingEvents then
            sleep = 0
            SuppressShockingEventsNextFrame()
        end

        Wait(sleep)
    end
end)
