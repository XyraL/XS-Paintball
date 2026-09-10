Framework = { name = nil, core = nil }

if not Config then
    print(('^1[XS-Paintball]^0 config.lua did not load, so this resource cannot start.\n'
        .. '  Almost always start order. In server.cfg, these must come first:\n'
        .. '    ensure ox_lib\n'
        .. '    ensure oxmysql\n'
        .. '    ensure %s'):format(GetCurrentResourceName()))
    return
end

local forced = Config.Bridges and Config.Bridges.framework or 'auto'

if forced == 'qbox' or (forced == 'auto' and GetResourceState('qbx_core') == 'started') then
    Framework.name = 'qbox'
elseif forced == 'qbcore' or (forced == 'auto' and GetResourceState('qb-core') == 'started') then
    Framework.name = 'qbcore'
    Framework.core = exports['qb-core']:GetCoreObject()
else
    print('^1[XS-Paintball]^0 No supported framework found. Start qbx_core or qb-core before XS-Paintball.')
end

local IS_SERVER = IsDuplicityVersion()

local blockedJobs = {}
for _, j in ipairs(Config.BlockedJobs or {}) do blockedJobs[j] = true end

if IS_SERVER then
    function Framework.GetPlayer(src)
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayer(src)
        elseif Framework.core then
            return Framework.core.Functions.GetPlayer(src)
        end
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        if not player then return GetPlayerName(src) or ('Player %s'):format(src) end
        local ci = player.PlayerData.charinfo
        return ('%s %s'):format(ci.firstname, ci.lastname)
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        local j = player.PlayerData.job
        return {
            name   = j.name,
            grade  = (type(j.grade) == 'table') and j.grade.level or j.grade,
            onDuty = j.onduty,
            label  = j.label,
        }
    end

    function Framework.IsBlockedJob(src)
        local job = Framework.GetJob(src)
        if not job or not blockedJobs[job.name] then return false end
        if Config.BlockedJobsRespectDuty and job.onDuty == false then return false end
        return true
    end

    function Framework.GetMoney(src, account)
        local player = Framework.GetPlayer(src)
        if not player then return 0 end
        if Framework.name == 'qbox' then
            return player.PlayerData.money[account] or 0
        end
        return player.Functions.GetMoney(account) or 0
    end

    function Framework.AddMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player or amount <= 0 then return false end
        return player.Functions.AddMoney(account, amount, reason or 'XS-Paintball')
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player or amount <= 0 then return false end
        return player.Functions.RemoveMoney(account, amount, reason or 'XS-Paintball')
    end

    function Framework.IsAdmin(src)
        local A = Config.Admin or {}
        if A.acePermission and IsPlayerAceAllowed(src, A.acePermission) then return true end

        for _, lic in ipairs(A.licenses or {}) do
            if GetPlayerIdentifierByType(src, 'license') == lic then return true end
        end

        local groups = A.groups or {}
        if Framework.name == 'qbox' then
            for _, g in ipairs(groups) do
                if exports.qbx_core:HasPermission(src, g) then return true end
            end
        elseif Framework.core then
            for _, g in ipairs(groups) do
                if Framework.core.Functions.HasPermission(src, g) then return true end
            end
        end
        return false
    end

    function Framework.Notify(src, msg, type, title)
        local NS = Config.NotifyStyle or {}
        local ico = (NS.icons or {})[type or 'inform'] or {}
        TriggerClientEvent('ox_lib:notify', src, {
            title = title or (NS.title ~= false and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = ico.icon,
            iconColor = ico.color,
        })
    end
else
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayerData()
        elseif Framework.core then
            return Framework.core.Functions.GetPlayerData()
        end
    end

    function Framework.GetJob()
        local data = Framework.GetPlayerData()
        if not data or not data.job then return nil end
        local j = data.job
        return {
            name   = j.name,
            grade  = (type(j.grade) == 'table') and j.grade.level or j.grade,
            onDuty = j.onduty,
            label  = j.label,
        }
    end

    function Framework.IsBlockedJob()
        local job = Framework.GetJob()
        if not job or not blockedJobs[job.name] then return false end
        if Config.BlockedJobsRespectDuty and job.onDuty == false then return false end
        return true
    end

    function Framework.Notify(msg, type, title)
        local NS = Config.NotifyStyle or {}
        local ico = (NS.icons or {})[type or 'inform'] or {}
        lib.notify({
            title = title or (NS.title ~= false and NS.title or nil),
            description = msg,
            type = type or 'inform',
            position = NS.position,
            duration = NS.duration,
            icon = ico.icon,
            iconColor = ico.color,
        })
    end
end

if Config.Debug then
    print(('^2[XS-Paintball]^0 framework bridge loaded (%s) on %s'):format(
        Framework.name or 'none', IS_SERVER and 'server' or 'client'))
end
