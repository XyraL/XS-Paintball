Props = { spawned = {}, builder = {}, ghost = nil, building = false }

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model

    if not IsModelValid(hash) then return nil end
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

Props.LoadModel = loadModel

--[[ Sit a prop's base on whatever is underneath it.

     PlaceObjectOnGroundProperly is unreliable on a static, non-dynamic object,
     so this works it out instead: raycast down for the real surface, then use
     the model's own dimensions to place the base on it.

     GetGroundZFor_3dCoord is no use here — it returns terrain height and
     ignores concrete, kerbs and anything raised, which is most of an airfield
     apron. A prop's origin is not always its base either: a container's is its
     centre, which is exactly why they floated. min.z is how far the base sits
     below the origin. ]]
function Props.Settle(object, hash, x, y, z)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        x, y, z + 4.0, x, y, z - 12.0, 1, object, 4)

    local _, hit, endCoords = GetShapeTestResult(ray)

    if hit ~= 1 then
        PlaceObjectOnGroundProperly(object)
        return
    end

    local min = GetModelDimensions(hash)
    SetEntityCoordsNoOffset(object, x, y, endCoords.z - min.z, false, false, false)
end

local function create(entry, collision)
    local hash = loadModel(entry.model)
    if not hash then return nil end

    local object = CreateObjectNoOffset(hash, entry.x, entry.y, entry.z, false, false, false)
    if not object or object == 0 then return nil end

    SetEntityRotation(object, entry.rx or 0.0, entry.ry or 0.0, entry.rz or 0.0, 2, true)
    SetEntityCollision(object, collision ~= false, collision ~= false)

    -- Only when the map asked for it: a prop the builder deliberately placed
    -- in the air has to stay there.
    if entry.ground then Props.Settle(object, hash, entry.x, entry.y, entry.z) end

    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true, true)
    SetModelAsNoLongerNeeded(hash)

    return object
end

Props.Create = create

function Props.Build(map)
    Props.ClearSpawned()

    if not map or type(map.props) ~= 'table' then return end

    Props.building = true

    CreateThread(function()
        for index, entry in ipairs(map.props) do
            if not Props.building then break end

            local object = create(entry, true)
            if object then Props.spawned[#Props.spawned + 1] = object end

            if index % 12 == 0 then Wait(0) end
        end

        Props.building = false
    end)
end

function Props.ClearSpawned()
    Props.building = false

    for _, object in ipairs(Props.spawned) do
        if DoesEntityExist(object) then DeleteEntity(object) end
    end

    Props.spawned = {}
end

function Props.ClearBuilder()
    for _, object in pairs(Props.builder) do
        if DoesEntityExist(object) then DeleteEntity(object) end
    end

    Props.builder = {}
end

function Props.ClearAll()
    Props.ClearSpawned()
    Props.ClearBuilder()
    Props.ClearGhost()
end

function Props.RenderBuilder(list)
    Props.ClearBuilder()

    if type(list) ~= 'table' then return end

    CreateThread(function()
        for index, entry in ipairs(list) do
            local object = create(entry, false)

            if object then
                SetEntityAlpha(object, 210, false)
                Props.builder[index] = object
            end

            if index % 12 == 0 then Wait(0) end
        end
    end)
end

function Props.Ghost(model)
    Props.ClearGhost()

    local hash = loadModel(model)
    if not hash then return nil end

    local coords = GetEntityCoords(PlayerPedId())
    local object = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)

    if not object or object == 0 then return nil end

    SetEntityCollision(object, false, false)
    SetEntityAlpha(object, 150, false)
    FreezeEntityPosition(object, true)
    SetEntityInvincible(object, true)
    SetModelAsNoLongerNeeded(hash)

    Props.ghost = object
    return object
end

function Props.MoveGhost(x, y, z, rx, ry, rz)
    if not Props.ghost or not DoesEntityExist(Props.ghost) then return end

    SetEntityCoordsNoOffset(Props.ghost, x, y, z, false, false, false)
    SetEntityRotation(Props.ghost, rx or 0.0, ry or 0.0, rz or 0.0, 2, true)
end

function Props.ClearGhost()
    if Props.ghost and DoesEntityExist(Props.ghost) then DeleteEntity(Props.ghost) end
    Props.ghost = nil
end

function Props.GhostSize()
    if not Props.ghost or not DoesEntityExist(Props.ghost) then return 1.0 end

    local min, max = GetModelDimensions(GetEntityModel(Props.ghost))
    return math.max(max.x - min.x, max.y - min.y, max.z - min.z)
end
