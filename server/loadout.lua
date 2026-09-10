--[[ Swapping a player's inventory for a match loadout, and giving it back.

     Everything a player owns passes through here, so the rules are strict:

       1. Snapshot first. If the snapshot does not come back, stop — never wipe
          an inventory we could not read.
       2. Write the snapshot to the database before wiping, not after. A crash
          between the two would otherwise take the inventory with it.
       3. Restore on every exit: match end, leaving, disconnecting, the resource
          stopping, and again when the player next loads if a stash is still
          sitting there from a crash.
       4. Only delete the stash once the items are actually back. ]]

Stash = { held = {} }

local L = Config.Loadout

local function enabled()
    return L.manageInventory == true and Inventory.name ~= 'none'
end

--[[ Saves the snapshot and proves it landed.

     The write's return value is no use here: oxmysql hands back nil for a
     prepare INSERT whether it worked or not. So the row gets read back and
     compared. This is the one place in the resource where "probably saved" is
     not good enough — everything the player owns is about to be deleted on the
     strength of it. ]]
local function persist(citizenid, snapshot)
    local payload = json.encode(snapshot)

    local wrote = pcall(function()
        MySQL.prepare.await([[
            INSERT INTO xs_paintball_stashes (citizenid, data) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE data = VALUES(data), created = CURRENT_TIMESTAMP
        ]], { citizenid, payload })
    end)

    if not wrote then return false end

    local row = MySQL.single.await('SELECT data FROM xs_paintball_stashes WHERE citizenid = ?', { citizenid })

    return row ~= nil and row.data == payload
end

local function forget(citizenid)
    MySQL.prepare.await('DELETE FROM xs_paintball_stashes WHERE citizenid = ?', { citizenid })
end

local function stored(citizenid)
    local row = MySQL.single.await('SELECT data FROM xs_paintball_stashes WHERE citizenid = ?', { citizenid })
    if not row then return nil end
    return json.decode(row.data or 'null')
end

function Stash.Holding(citizenid)
    return Stash.held[citizenid] ~= nil
end

-- Returns true when the swap happened. False means nothing was touched and the
-- caller should carry on with ped weapons only.
function Stash.Take(src, loadout)
    if not enabled() then return false end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false end

    if Stash.held[citizenid] then return true end

    local snapshot = Inventory.Snapshot(src)

    if type(snapshot) ~= 'table' then
        print(('^1[XS-Paintball]^0 could not read %s inventory for %s, so it was left alone. No loadout items were given.')
            :format(Inventory.name, citizenid))
        Framework.Notify(src, 'Could not swap your inventory, so it was left alone.', 'error')
        return false
    end

    if not persist(citizenid, snapshot) then
        print(('^1[XS-Paintball]^0 could not save the inventory stash for %s. Nothing was wiped.'):format(citizenid))
        Framework.Notify(src, 'Could not stash your inventory, so it was left alone.', 'error')
        return false
    end

    Stash.held[citizenid] = snapshot

    if not Inventory.Wipe(src) then
        print(('^1[XS-Paintball]^0 could not clear the inventory for %s. Putting it straight back.'):format(citizenid))
        Stash.Return(src)
        return false
    end

    for _, slot in ipairs({ 'primary', 'secondary', 'melee' }) do
        local weapon = loadout and loadout[slot]
        if weapon then
            Inventory.GiveWeapon(src, weapon, slot ~= 'melee' and ((L.ammo or {})[slot] or 100) or nil)
        end
    end

    if L.ammoItem then
        Inventory.GiveWeapon(src, L.ammoItem, nil)
    end

    return true
end

function Stash.Return(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false end

    local snapshot = Stash.held[citizenid] or stored(citizenid)
    if type(snapshot) ~= 'table' then return false end

    Inventory.Wipe(src)

    if not Inventory.Restore(src, snapshot) then
        print(('^1[XS-Paintball]^0 failed to give %s their inventory back. The stash is being kept — use /pbrestore %s once it is sorted.')
            :format(citizenid, src))
        return false
    end

    Stash.held[citizenid] = nil
    forget(citizenid)

    return true
end

-- A stash still in the table when somebody logs in means the server went down
-- mid match. Give it back before they notice.
function Stash.Recover(src)
    if not enabled() then return end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return end

    local snapshot = stored(citizenid)
    if type(snapshot) ~= 'table' then return end

    Stash.held[citizenid] = snapshot

    if Stash.Return(src) then
        Framework.Notify(src, 'Your inventory is back after the paintball match was cut short.', 'inform')
        print(('^2[XS-Paintball]^0 recovered a leftover inventory stash for %s'):format(citizenid))
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    if Stash.held[Framework.GetCitizenId(src) or ''] then Stash.Return(src) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local citizenid = Framework.GetCitizenId(src)
        if citizenid and Stash.held[citizenid] then Stash.Return(src) end
    end
end)

-- Frameworks name their load event differently, so listen for both.
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    Stash.Recover(source)
end)

RegisterNetEvent('qbx_core:playerLoaded', function()
    Stash.Recover(source)
end)

--[[ The stash table has to exist before anybody's inventory is touched.

     Without this the first player into a match gets a failed save, keeps their
     items, and gets no loadout — which reads like a script bug rather than a
     missing table. Better to say so once at startup and switch the feature off
     than to fail quietly every match. ]]

CreateThread(function()
    Wait(1200)

    if L.manageInventory ~= true then return end

    if Inventory.name == 'none' then
        print('^3[XS-Paintball]^0 Config.Loadout.manageInventory is on but no inventory resource was detected. Falling back to ped weapons.')
        L.manageInventory = false
        return
    end

    local found = MySQL.query.await("SHOW TABLES LIKE 'xs_paintball_stashes'")

    if type(found) ~= 'table' or #found == 0 then
        print('^1[XS-Paintball]^0 Table xs_paintball_stashes is missing, so inventories cannot be stashed safely.')
        print('^3[XS-Paintball]^0 Import sql/xs_paintball.sql again — it gained that table — then restart. Inventory swapping is off until you do.')
        L.manageInventory = false
        return
    end

    local leftover = MySQL.query.await('SELECT citizenid FROM xs_paintball_stashes') or {}

    if #leftover > 0 then
        print(('^3[XS-Paintball]^0 %d inventory stash(es) still held from a previous run. They go back automatically when those players next load.')
            :format(#leftover))
    end
end)
