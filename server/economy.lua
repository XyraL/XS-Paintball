Economy = {}

local E = Config.Economy

function Economy.WagerEnabled()
    return E.enabled and Settings.Get('wagersEnabled') == true
end

function Economy.ClampWager(amount)
    if not Economy.WagerEnabled() then return 0 end
    return math.floor(Util.clamp(tonumber(amount) or 0, E.wager.min, E.wager.max))
end

function Economy.CanPay(src, amount)
    if amount <= 0 then return true end
    if not E.enabled then return true end
    return Framework.GetMoney(src, E.account) >= amount
end

function Economy.HasTicket(src)
    if not E.ticketItem then return true end
    return Inventory.Has(src, E.ticketItem, E.ticketAmount)
end

function Economy.TakeStake(src, amount)
    if not E.enabled then return true end

    if E.ticketItem then
        if not Inventory.Remove(src, E.ticketItem, E.ticketAmount) then
            return false, 'You need a paintball ticket.'
        end
    end

    if amount > 0 then
        if not Framework.RemoveMoney(src, E.account, amount, 'paintball-wager') then
            if E.ticketItem then Inventory.Add(src, E.ticketItem, E.ticketAmount) end
            return false, 'You cannot cover that wager.'
        end
    end

    return true
end

function Economy.Refund(src, amount)
    if not E.enabled then return end
    if E.ticketItem then Inventory.Add(src, E.ticketItem, E.ticketAmount) end
    if amount > 0 then Framework.AddMoney(src, E.account, amount, 'paintball-refund') end
end

local function payHouse(amount)
    if amount <= 0 then return end

    local B = E.business
    if not B.enabled or B.resource == '' or B.exportName == '' then return end
    if GetResourceState(B.resource) ~= 'started' then return end

    local ok = pcall(function()
        exports[B.resource][B.exportName](nil, B.account, amount)
    end)

    if not ok and Config.Debug then
        print(('^3[XS-Paintball]^0 business payout export %s:%s failed'):format(B.resource, B.exportName))
    end
end

function Economy.Settle(lobby, results)
    if not E.enabled then return {} end

    local pot = 0
    local stakers = 0

    for _, entry in pairs(results) do
        if entry.staked and entry.staked > 0 then
            pot = pot + entry.staked
            stakers = stakers + 1
        end
    end

    local payouts = {}
    local winners = {}

    for citizenid, entry in pairs(results) do
        if entry.won then winners[#winners + 1] = citizenid end
    end

    local cut = 0
    local share = 0

    if pot > 0 then
        if #winners == 0 then
            for citizenid, entry in pairs(results) do
                payouts[citizenid] = (payouts[citizenid] or 0) + (entry.staked or 0)
            end
        else
            cut = math.floor(pot * Util.clamp(Settings.Get('houseCut'), 0, 0.5))
            share = math.floor((pot - cut) / #winners)

            for _, citizenid in ipairs(winners) do
                payouts[citizenid] = (payouts[citizenid] or 0) + share
            end
        end
    end

    for citizenid, amount in pairs(payouts) do
        local entry = results[citizenid]
        if entry and entry.source and amount > 0 then
            Framework.AddMoney(entry.source, E.account, amount, 'paintball-payout')
            entry.payout = amount
        end
    end

    payHouse(cut)

    return { pot = pot, cut = cut, share = share, winners = #winners, stakers = stakers }
end
