Kora.compat.provideExport('qb-vehiclekeys', 'HasKeys', function(plate)
    if type(plate) ~= 'string' or plate == '' or #plate > 32 then return false end
    return Kora.callback.trigger('qbvehiclekeys:server:legacyHasKeys', plate) == true
end)

-- Stock qb-vehiclekeys client events. A client can never grant itself keys:
-- these only ASK the server, which grants when Config.LegacyClientGrants is on
-- and the player is the driver of a vehicle with that plate (see server/main.lua).
-- Server scripts should prefer exports['qb-vehiclekeys']:GiveKeys(src, plate).
local function requestGrant(plate)
    if type(plate) == 'string' and plate ~= '' and #plate <= 32 then
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end
end

RegisterNetEvent('qb-vehiclekeys:client:AddKeys')
AddEventHandler('qb-vehiclekeys:client:AddKeys', requestGrant)
RegisterNetEvent('vehiclekeys:client:SetOwner')
AddEventHandler('vehiclekeys:client:SetOwner', requestGrant)
RegisterNetEvent('qb-vehiclekeys:client:RemoveKeys')
AddEventHandler('qb-vehiclekeys:client:RemoveKeys', function(plate)
    if type(plate) == 'string' and plate ~= '' and #plate <= 32 then
        TriggerServerEvent('qb-vehiclekeys:server:RemoveOwnKeys', plate)
    end
end)
