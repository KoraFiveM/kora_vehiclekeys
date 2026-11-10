local GIVE_DISTANCE = 1.5

local function modelHash(model)
    if type(model) == 'string' and model ~= '' then return joaat(model) end
    if type(model) == 'number' then return model end
end

Kora.compat.provideExport('qb-vehiclekeys', 'addNoLockVehicles', function(model)
    local hash = modelHash(model)
    if hash then VehicleKeys.noLockModels[hash] = true end
end)

Kora.compat.provideExport('qb-vehiclekeys', 'removeNoLockVehicles', function(model)
    local hash = modelHash(model)
    if hash then VehicleKeys.noLockModels[hash] = nil end
end)

RegisterCommand('togglelocks', function() VehicleKeys.toggleLocks() end, false)
RegisterCommand('engine', function() VehicleKeys.toggleEngine() end, false)

local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
end

local function otherOccupants(vehicle)
    local ped, ids = PlayerPedId(), {}
    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant ~= 0 and occupant ~= ped and IsPedAPlayer(occupant) then
            ids[#ids + 1] = GetPlayerServerId(NetworkGetPlayerIndexFromPed(occupant))
        end
    end
    return ids
end

local function closestPlayerId()
    local self, coords = PlayerId(), GetEntityCoords(PlayerPedId())
    local best, bestDistance = nil, GIVE_DISTANCE
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= self then
            local distance = #(GetEntityCoords(GetPlayerPed(player)) - coords)
            if distance < bestDistance then best, bestDistance = GetPlayerServerId(player), distance end
        end
    end
    return best
end

-- Stock: give keys to the given id, else to everyone else in the vehicle, else
-- to the closest player. Only asks the server, which re-checks that the giver
-- holds the key and that every receiver is within reach.
RegisterNetEvent('qb-vehiclekeys:client:GiveKeys')
AddEventHandler('qb-vehiclekeys:client:GiveKeys', function(id)
    local vehicle = VehicleKeys.currentOrClosestVehicle(Config.InteractionDistance)
    if not vehicle then return end
    local plate = plateOf(vehicle)
    if plate == '' or Kora.callback.trigger('kora_vehiclekeys:server:legacyHasKeys', plate) ~= true then
        return VehicleKeys.notify("You don't have keys to this vehicle.", 'error')
    end

    local receivers
    if type(id) == 'number' then
        receivers = { id }
    elseif IsPedSittingInVehicle(PlayerPedId(), vehicle) then
        receivers = otherOccupants(vehicle)
    else
        local closest = closestPlayerId()
        receivers = closest and { closest } or {}
    end
    if #receivers == 0 then return VehicleKeys.notify('There is nobody nearby to hand keys to', 'error') end
    TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', receivers, plate)
end)
