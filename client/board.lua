--[[ The leaderboard board.

     Walk up to it and read it. The rows are fetched once and kept for a minute,
     so standing in front of it does not hammer the database. ]]

local rows = {}
local fetchedAt = 0
local fetching = false

local function refresh()
    if fetching then return end

    fetching = true

    CreateThread(function()
        local result = lib.callback.await('XS-Paintball:leaderboardTop', false,
            { limit = Config.Leaderboard.board.entries })

        if result and result.ok then
            rows = result.rows or {}
            fetchedAt = GetGameTimer()
        end

        fetching = false
    end)
end

CreateThread(function()
    -- Read the config inside the loop. Bailing out once at start means a
    -- config that arrived late, or an older one without the board block, kills
    -- the board for the whole session with nothing said about it.
    local warned = false

    while true do
        local sleep = 1000
        local B = Config.Leaderboard and Config.Leaderboard.board

        if not B or not B.enabled or not Config.Leaderboard.enabled then
            if not warned and Config.Leaderboard and not Config.Leaderboard.board then
                warned = true
                print('^3[XS-Paintball]^0 Config.Leaderboard.board is missing, so the in-world board is off. Update config.lua.')
            end

            Wait(5000)
            goto continue
        end

        local here = GetEntityCoords(PlayerPedId())
        local distance = #(here - B.coords)

        if distance < B.distance and not PB.match then
            sleep = 0

            if GetGameTimer() - fetchedAt > 60000 then refresh() end

            local x, y, z = B.coords.x, B.coords.y, B.coords.z

            Markers.Draw3dText(x, y, z + 0.30, 'PAINTBALL', { 224, 22, 95 }, 0.62)
            Markers.Draw3dText(x, y, z + 0.16, 'TOP OF THE BOARD', { 240, 238, 228 }, 0.30)

            if #rows == 0 then
                Markers.Draw3dText(x, y, z - 0.06, 'Nobody has played yet', { 170, 165, 155 }, 0.32)
            else
                for index, row in ipairs(rows) do
                    local line = ('%d.  %s   %d kills   %s K/D'):format(index, row.name, row.kills, row.kd)
                    local tint = index == 1 and { 234, 169, 0 } or { 240, 238, 228 }

                    Markers.Draw3dText(x, y, z - 0.04 - (index * 0.115), line, tint, 0.34)
                end
            end
        end

        ::continue::
        Wait(sleep)
    end
end)
