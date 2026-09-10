--[[ A tank on your back while you are on the field.

     Purely cosmetic, created locally, and deleted the moment the match ends or
     the resource stops — it must never be able to survive a match and follow
     somebody around the city. ]]

Gear = { prop = nil }

function Gear.Wear()
    if not Config.Gear.enabled or Gear.prop then return end

    local G = Config.Gear
    local hash = Props.LoadModel(G.prop)
    if not hash then return end

    local ped = PlayerPedId()
    local object = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    if not object or object == 0 then return end

    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, G.bone),
        G.offset.x, G.offset.y, G.offset.z,
        G.rotation.x, G.rotation.y, G.rotation.z,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(hash)
    Gear.prop = object
end

function Gear.Remove()
    if not Gear.prop then return end

    if DoesEntityExist(Gear.prop) then
        DetachEntity(Gear.prop, true, true)
        DeleteEntity(Gear.prop)
    end

    Gear.prop = nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Gear.Remove()
end)
