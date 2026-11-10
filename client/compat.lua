Kora.compat.provideExport('qb-vehiclekeys', 'HasKeys', function(plate)
    if type(plate) ~= 'string' or plate == '' or #plate > 32 then return false end
    return Kora.callback.trigger('kora_vehiclekeys:server:legacyHasKeys', plate) == true
end)

-- Stock qb-vehiclekeys client events. A client can never grant itself keys:
-- these only ASK the server (with the vehicle's network id, as stock does),
-- which decides under Config.LegacyClientGrants / Config.TrustedSetOwner (see
-- server/main.lua). Server scripts should prefer
-- exports['qb-vehiclekeys']:GiveKeys(src, plate).
local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
end

local function findVehicleByPlate(plate)
    local wanted = plate:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    local ped = PlayerPedId()
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 and plateOf(current) == wanted then return current end
    local coords = GetEntityCoords(ped)
    local best, bestDistance = nil, 15.0
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if plateOf(vehicle) == wanted then
            local distance = #(GetEntityCoords(vehicle) - coords)
            if distance < bestDistance then best, bestDistance = vehicle, distance end
        end
    end
    return best
end

-- A freshly spawned entity may not be known to the server yet (or the server
-- rejects the first request), so keep asking about every 400 ms for ~3 s until
-- the server reports we hold a key. One loop per plate.
local RETRY_INTERVAL, RETRY_ATTEMPTS = 400, 8
local pending = {}

local function requestGrant(plate)
    if type(plate) ~= 'string' or plate == '' or #plate > 32 or pending[plate] then return end
    pending[plate] = true
    CreateThread(function()
        for _ = 1, RETRY_ATTEMPTS do
            local vehicle = findVehicleByPlate(plate)
            if vehicle and NetworkGetEntityIsNetworked(vehicle) then
                TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', NetworkGetNetworkIdFromEntity(vehicle))
            end
            Wait(RETRY_INTERVAL)
            if Kora.callback.trigger('kora_vehiclekeys:server:legacyHasKeys', plate) == true then break end
        end
        pending[plate] = nil
    end)
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
