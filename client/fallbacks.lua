--[[ Loads last, once every other client file has had its turn.

     A file that did not load is nearly always one that was missed when the
     folder was uploaded. Without this, the first thing that touches it dies on
     a nil index and the stack trace points at the caller rather than the
     missing file. So: switch that feature off, keep the match running, and say
     plainly in the console which file to go and get. ]]

local MISSING = {}

local function optional(name, file, stub)
    if _G[name] ~= nil then return end

    MISSING[#MISSING + 1] = file
    _G[name] = stub
end

local function noop() end

optional('Sounds', 'client/sounds.lua', { Play = noop })

optional('Dispatch', 'bridge/dispatch.lua', { inMatch = false, SetInMatch = noop })

optional('Staging', 'client/staging.lua', { active = false, Enter = noop, Leave = noop, Origin = function() return nil end })

optional('MapVote', 'client/vote.lua', { active = false, options = {} })

optional('Gear', 'client/gear.lua', { prop = nil, Wear = noop, Remove = noop })

optional('Killstreaks', 'client/killstreaks.lua', { Clear = noop })

optional('Spectate', 'client/spectate.lua', { active = false, Start = noop, Stop = noop })

optional('Cosmetics', 'shared/cosmetics.lua', {
    Enabled     = function() return false end,
    Sanitise    = function() return { tint = 0, kit = 'none' } end,
    GetKit      = function() return nil end,
    DefaultTint = function() return 0 end,
    DefaultKit  = function() return 'none' end,
})

if #MISSING > 0 then
    print(('^1[XS-Paintball]^0 %d client file(s) did not load: %s'):format(#MISSING, table.concat(MISSING, ', ')))
    print('^3[XS-Paintball]^0 Those features are off. Re-upload the resource folder with every file listed in fxmanifest.lua, then restart it.')
end
