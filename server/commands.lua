local function allowed(src)
    if src == 0 then return true end
    return Framework.IsAdmin(src)
end

local function reply(src, message)
    if src == 0 then
        print(('^5[XS-Paintball]^0 %s'):format(message))
    else
        Framework.Notify(src, message, 'inform')
    end
end

if Config.Commands.reload then
    RegisterCommand(Config.Commands.reload, function(source)
        if not allowed(source) then
            Framework.Notify(source, 'You are not allowed to do that.', 'error')
            return
        end

        Settings.Load()
        local count = Store.Load()
        local added = Store.LoadPresets()

        reply(source, ('Reloaded %d map(s)%s.'):format(count + added,
            added > 0 and (', %d new from presets'):format(added) or ''))

        Lobbies.SyncBrowser()
    end, false)
end

RegisterCommand('pbdebug', function(source)
    if not allowed(source) then return end

    local lines, problems = Diagnose.Run()

    for _, line in ipairs(lines) do
        if source == 0 then
            print(line)
        else
            -- Colour codes are console only, so strip them for chat.
            TriggerClientEvent('chat:addMessage', source, { args = { 'XS', (line:gsub('%^%d', '')) } })
        end
    end

    if source ~= 0 then
        Framework.Notify(source, problems == 0 and 'Nothing obviously wrong.'
            or ('%d thing(s) need attention — see chat.'):format(problems),
            problems == 0 and 'success' or 'error')
    end
end, false)

RegisterCommand('pblobbies', function(source)
    if not allowed(source) then return end

    local list = Lobbies.List()
    if #list == 0 then
        reply(source, 'No lobbies open.')
        return
    end

    for _, lobby in ipairs(list) do
        reply(source, ('#%d %s | %s on %s | %d/%d | %s'):format(
            lobby.id, lobby.name, lobby.modeLabel, lobby.map,
            lobby.players, lobby.max, lobby.state))
    end
end, false)

RegisterCommand('pbend', function(source, args)
    if not allowed(source) then return end

    local id = tonumber(args[1])
    local lobby = id and Lobbies.Get(id)

    if not lobby then
        reply(source, 'Usage: pbend <lobby id>')
        return
    end

    if lobby.state == 'live' then
        Match.Finish(lobby, nil)
        reply(source, ('Ended match in lobby %d.'):format(id))
    else
        Lobbies.Destroy(lobby, 'closed')
        reply(source, ('Closed lobby %d.'):format(id))
    end
end, false)

RegisterCommand('pbstart', function(source, args)
    if not allowed(source) then return end

    local id = tonumber(args[1])
    local lobby = id and Lobbies.Get(id)

    if not lobby then
        reply(source, 'Usage: pbstart <lobby id>. Run pblobbies for the list.')
        return
    end

    local success, err = Lobbies.Start(nil, lobby, true)
    reply(source, success and ('Starting lobby %d.'):format(id) or ('Could not start it: %s'):format(err))
end, false)

RegisterCommand('pbrestore', function(source, args)
    if not allowed(source) then return end

    local target = tonumber(args[1])
    if not target then
        reply(source, 'Usage: pbrestore <player id>. Puts a stashed inventory back.')
        return
    end

    reply(source, Stash.Return(target)
        and ('Gave %d their inventory back.'):format(target)
        or ('Nothing stashed for %d.'):format(target))
end, false)

RegisterCommand('pbpresets', function(source)
    if not allowed(source) then return end

    local updated, added = Store.RefreshPresets()

    reply(source, ('Refreshed the shipped maps: %d updated, %d added. Any builder edits to those maps are gone.')
        :format(updated, added))

    Lobbies.SyncBrowser()
end, false)

RegisterCommand('pbstats', function(source, args)
    if not allowed(source) then return end

    local rows = Stats.Leaderboard('all', args[1])
    for index, row in ipairs(rows) do
        reply(source, ('%2d. %-24s %d kills / %d deaths (%.2f)')
            :format(index, row.name or row.citizenid, row.kills, row.deaths, row.kd))
    end
end, false)
