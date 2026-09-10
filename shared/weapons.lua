Weapons = { byName = {}, bySlot = { primary = {}, secondary = {}, melee = {} } }

local CATEGORY_LABELS = {
    rifle   = 'Rifles',
    smg     = 'SMGs',
    shotgun = 'Shotguns',
    sniper  = 'Snipers',
    lmg     = 'Light Machine Guns',
    pistol  = 'Sidearms',
    melee   = 'Melee',
    special = 'Special',
}

for _, weapon in ipairs(Config.Weapons) do
    local entry = {
        name     = weapon.name,
        label    = weapon.label,
        slot     = weapon.slot,
        category = weapon.category,
        paint    = weapon.paint == true,
        hash     = joaat(weapon.name),
        unlock   = (Config.Progression.unlocks or {})[weapon.name] or 0,
    }

    Weapons.byName[weapon.name] = entry
    Weapons.byName[entry.hash]  = entry

    local slot = Weapons.bySlot[weapon.slot]
    if slot then slot[#slot + 1] = entry end
end

function Weapons.Get(nameOrHash)
    return Weapons.byName[nameOrHash]
end

function Weapons.Label(nameOrHash)
    local entry = Weapons.byName[nameOrHash]
    if entry then return entry.label end
    if type(nameOrHash) == 'string' then
        return (nameOrHash:gsub('^WEAPON_', ''):gsub('_', ' '):lower():gsub('^%l', string.upper))
    end
    return 'Unknown'
end

function Weapons.CategoryLabel(id)
    return CATEGORY_LABELS[id] or id
end

function Weapons.Unlocked(name, level)
    local entry = Weapons.byName[name]
    if not entry then return false end
    if not Config.Progression.enabled then return true end
    return (level or 1) >= entry.unlock
end

function Weapons.IsAllowed(name, slot)
    local entry = Weapons.byName[name]
    return entry ~= nil and entry.slot == slot
end

function Weapons.DefaultLoadout()
    return {
        primary   = Config.Loadout.primary   and (Weapons.bySlot.primary[2]   or Weapons.bySlot.primary[1]   or {}).name or nil,
        secondary = Config.Loadout.secondary and (Weapons.bySlot.secondary[1] or {}).name or nil,
        melee     = Config.Loadout.melee     and (Weapons.bySlot.melee[1]     or {}).name or nil,
    }
end

function Weapons.Sanitise(loadout, level)
    loadout = type(loadout) == 'table' and loadout or {}
    local out = {}

    for _, slot in ipairs({ 'primary', 'secondary', 'melee' }) do
        if Config.Loadout[slot] then
            local name = loadout[slot]
            if type(name) == 'string' and Weapons.IsAllowed(name, slot) and Weapons.Unlocked(name, level) then
                out[slot] = name
            end
        end
    end

    local fallback = Weapons.DefaultLoadout()
    for _, slot in ipairs({ 'primary', 'secondary', 'melee' }) do
        if Config.Loadout[slot] and not out[slot] then out[slot] = fallback[slot] end
    end

    return out
end

function Weapons.Catalogue()
    local out = {}
    for _, slot in ipairs({ 'primary', 'secondary', 'melee' }) do
        if Config.Loadout[slot] then
            for _, entry in ipairs(Weapons.bySlot[slot]) do
                out[#out + 1] = {
                    name     = entry.name,
                    label    = entry.label,
                    slot     = entry.slot,
                    category = entry.category,
                    categoryLabel = CATEGORY_LABELS[entry.category] or entry.category,
                    unlock   = entry.unlock,
                    paint    = entry.paint,
                }
            end
        end
    end
    return out
end

function Weapons.GunGameLadder()
    local out = {}
    for _, name in ipairs(Config.GunGameLadder) do
        out[#out + 1] = { name = name, label = Weapons.Label(name) }
    end
    return out
end
