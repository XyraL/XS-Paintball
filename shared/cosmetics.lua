Cosmetics = { tintById = {}, kitById = {} }

for _, tint in ipairs(Config.Cosmetics.tints or {}) do
    Cosmetics.tintById[tint.id] = tint
end

for _, kit in ipairs(Config.Cosmetics.kits or {}) do
    Cosmetics.kitById[kit.id] = kit
end

local function requirement(entry)
    local u = entry.unlock or {}
    if u.level and u.level > 1 then return ('Level %d'):format(u.level) end
    if u.wins then return ('%d wins'):format(u.wins) end
    return nil
end

function Cosmetics.IsUnlocked(entry, profile)
    if not entry then return false end

    local u = entry.unlock or {}
    profile = profile or {}

    if u.level and (profile.level or 1) < u.level then return false end
    if u.wins and (profile.wins or 0) < u.wins then return false end

    return true
end

function Cosmetics.Enabled()
    return Config.Cosmetics.enabled == true
end

function Cosmetics.DefaultTint()
    local first = (Config.Cosmetics.tints or {})[1]
    return first and first.id or 0
end

function Cosmetics.DefaultKit()
    local first = (Config.Cosmetics.kits or {})[1]
    return first and first.id or 'none'
end

function Cosmetics.GetKit(id)
    return Cosmetics.kitById[id]
end

-- Falls back to the defaults whenever the stored choice is unknown or the
-- player has not earned it, so a level reset or a config edit can never leave
-- somebody wearing something they should not have.
function Cosmetics.Sanitise(choice, profile)
    choice = type(choice) == 'table' and choice or {}

    local tintId = tonumber(choice.tint)
    local tint = tintId and Cosmetics.tintById[tintId]
    if not tint or not Cosmetics.IsUnlocked(tint, profile) then
        tintId = Cosmetics.DefaultTint()
    end

    local kitId = choice.kit
    local kit = type(kitId) == 'string' and Cosmetics.kitById[kitId]
    if not kit or not Cosmetics.IsUnlocked(kit, profile) then
        kitId = Cosmetics.DefaultKit()
    end

    return { tint = tintId, kit = kitId }
end

function Cosmetics.Catalogue(profile)
    local tints, kits = {}, {}

    for _, tint in ipairs(Config.Cosmetics.tints or {}) do
        tints[#tints + 1] = {
            id       = tint.id,
            label    = tint.label,
            unlocked = Cosmetics.IsUnlocked(tint, profile),
            requires = requirement(tint),
        }
    end

    for _, kit in ipairs(Config.Cosmetics.kits or {}) do
        kits[#kits + 1] = {
            id       = kit.id,
            label    = kit.label,
            unlocked = Cosmetics.IsUnlocked(kit, profile),
            requires = requirement(kit),
            pieces   = #((kit.male or {}).components or {}) + #((kit.male or {}).props or {}),
        }
    end

    return { tints = tints, kits = kits }
end
