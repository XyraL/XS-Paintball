Inventory = { name = 'none' }

local IS_SERVER = IsDuplicityVersion()

local CANDIDATES = {
    { id = 'ox',    resource = 'ox_inventory' },
    { id = 'qs',    resource = 'qs-inventory' },
    { id = 'codem', resource = 'codem-inventory' },
    { id = 'core',  resource = 'core_inventory' },
    { id = 'ps',    resource = 'ps-inventory' },
    { id = 'qb',    resource = 'qb-inventory' },
}

local forced = Config.Bridges and Config.Bridges.inventory or 'auto'

if forced ~= 'auto' then
    Inventory.name = forced
else
    for _, candidate in ipairs(CANDIDATES) do
        if GetResourceState(candidate.resource) == 'started' then
            Inventory.name = candidate.id
            break
        end
    end
end

if IS_SERVER then
    function Inventory.Count(src, item)
        if not item then return 0 end

        if Inventory.name == 'ox' then
            return exports.ox_inventory:GetItemCount(src, item) or 0
        end

        if Inventory.name == 'qs' then
            local list = exports['qs-inventory']:GetInventory(src) or {}
            local total = 0
            for _, slot in pairs(list) do
                if slot and slot.name == item then total = total + (slot.amount or slot.count or 0) end
            end
            return total
        end

        local player = Framework.GetPlayer(src)
        if not player then return 0 end

        local found = player.Functions.GetItemByName and player.Functions.GetItemByName(item)
        if found then return found.amount or found.count or 0 end
        return 0
    end

    function Inventory.Has(src, item, amount)
        if not item then return true end
        return Inventory.Count(src, item) >= (amount or 1)
    end

    function Inventory.Remove(src, item, amount)
        if not item then return true end
        amount = amount or 1

        if Inventory.name == 'ox' then
            return exports.ox_inventory:RemoveItem(src, item, amount) and true or false
        end

        if Inventory.name == 'qs' then
            return exports['qs-inventory']:RemoveItem(src, item, amount) and true or false
        end

        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveItem(item, amount) and true or false
    end

    function Inventory.Add(src, item, amount)
        if not item then return true end
        amount = amount or 1

        if Inventory.name == 'ox' then
            return exports.ox_inventory:AddItem(src, item, amount) and true or false
        end

        if Inventory.name == 'qs' then
            return exports['qs-inventory']:AddItem(src, item, amount) and true or false
        end

        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, amount) and true or false
    end
end

if Config.Debug then
    print(('^2[XS-Paintball]^0 inventory bridge: %s'):format(Inventory.name))
end

--[[ Snapshot, wipe and restore, for swapping a player into a match loadout.

     The order matters and is not negotiable: snapshot first, verify it came
     back, and only then wipe. A snapshot that fails must never be followed by
     a wipe, or the player loses everything they own. ]]

if IS_SERVER then
    function Inventory.Snapshot(src)
        if Inventory.name == 'ox' then
            local items
            local caught = pcall(function()
                items = exports.ox_inventory:GetInventoryItems(src)
            end)

            if not caught or type(items) ~= 'table' then return nil end

            local out = {}
            for _, item in pairs(items) do
                if item and item.name then
                    out[#out + 1] = {
                        name = item.name,
                        count = item.count or item.amount or 1,
                        slot = item.slot,
                        metadata = item.metadata,
                    }
                end
            end

            return out
        end

        local player = Framework.GetPlayer(src)
        if not player then return nil end

        local items = player.PlayerData and player.PlayerData.items
        if type(items) ~= 'table' then return nil end

        local out = {}
        for _, item in pairs(items) do
            if item and item.name then
                out[#out + 1] = {
                    name = item.name,
                    count = item.amount or item.count or 1,
                    slot = item.slot,
                    metadata = item.info,
                }
            end
        end

        return out
    end

    function Inventory.Wipe(src)
        if Inventory.name == 'ox' then
            return pcall(function() exports.ox_inventory:ClearInventory(src) end)
        end

        local player = Framework.GetPlayer(src)
        if not player or not player.Functions.ClearInventory then return false end

        return pcall(function() player.Functions.ClearInventory() end)
    end

    function Inventory.Restore(src, snapshot)
        if type(snapshot) ~= 'table' then return false end

        if Inventory.name == 'ox' then
            for _, item in ipairs(snapshot) do
                pcall(function()
                    exports.ox_inventory:AddItem(src, item.name, item.count, item.metadata, item.slot)
                end)
            end
            return true
        end

        local player = Framework.GetPlayer(src)
        if not player then return false end

        for _, item in ipairs(snapshot) do
            pcall(function()
                player.Functions.AddItem(item.name, item.count, item.slot, item.metadata)
            end)
        end

        return true
    end

    -- Weapon item names follow the spawn name in lower case on every inventory
    -- this bridge supports.
    function Inventory.GiveWeapon(src, weaponName, ammo)
        local item = weaponName:lower()

        if Inventory.name == 'ox' then
            return pcall(function()
                exports.ox_inventory:AddItem(src, item, 1, ammo and { ammo = ammo } or nil)
            end)
        end

        local player = Framework.GetPlayer(src)
        if not player then return false end

        return pcall(function()
            player.Functions.AddItem(item, 1, nil, ammo and { ammo = ammo } or nil)
        end)
    end
end
