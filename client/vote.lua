MapVote = { active = false, options = {}, choice = nil }

-- 1, 2 and 3 on the number row.
local KEYS = { 157, 158, 160 }

local function close()
    MapVote.active = false
    MapVote.options = {}
    MapVote.choice = nil
    Hud.HideVote()
end

RegisterNetEvent('XS-Paintball:client:voteOpen', function(data)
    if type(data) ~= 'table' or type(data.options) ~= 'table' then return end

    MapVote.active = true
    MapVote.options = data.options
    MapVote.choice = nil

    Hud.ShowVote({ options = data.options, seconds = data.seconds })
end)

RegisterNetEvent('XS-Paintball:client:voteTally', function(tally)
    if not MapVote.active then return end
    Hud.VoteTally(tally or {})
end)

RegisterNetEvent('XS-Paintball:client:voteResult', function(data)
    if type(data) ~= 'table' then return end

    Hud.VoteResult(data)
    Hud.Announce(('Next up: %s'):format(data.name or 'unknown'), 'success')

    SetTimeout(2500, close)
end)

CreateThread(function()
    while true do
        local sleep = 300

        if MapVote.active then
            sleep = 0

            -- 1, 2 and 3 are the game's own weapon select. Without disabling
            -- them the vote key just swaps your gun and never registers.
            for _, key in ipairs(KEYS) do
                DisableControlAction(0, key, true)
            end

            for index, key in ipairs(KEYS) do
                if MapVote.options[index] and IsDisabledControlJustPressed(0, key) then
                    MapVote.choice = index
                    Hud.VoteChoice(index)
                    TriggerServerEvent('XS-Paintball:server:vote', index)
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('XS-Paintball:client:matchStop', function()
    if MapVote.active then close() end
end)
