local accessCache, busyHotwiring = {}, false

local function notify(message, notificationType)
    QB.notify.send({ title = 'Vehicle keys', message = message, type = notificationType or 'info' })
end

local function currentOrClosestVehicle(distance)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end
    local coords = GetEntityCoords(ped)
    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, distance, 0, 70)
    return vehicle ~= 0 and vehicle or nil
end

local function applyLockState(vehicle, locked)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not QB.entities.requestControl(vehicle, 250) then return end
    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
end

local function vehicleNetworkId(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) or not NetworkGetEntityIsNetworked(vehicle) then return nil end
    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    return networkId > 0 and networkId or nil
end

local function hasIgnitionAccess(vehicle)
    local networkId = vehicleNetworkId(vehicle)
    if not networkId then return false end
    local cached = accessCache[networkId]
    if cached and cached.expiresAt > GetGameTimer() then return cached.allowed end

    local allowed = QB.callback.trigger('qbvehiclekeys:server:accessRequested', networkId) == true
    accessCache[networkId] = { allowed = allowed, expiresAt = GetGameTimer() + Config.AccessCacheMs }
    return allowed
end

local function toggleNearestVehicle()
    local vehicle = currentOrClosestVehicle(Config.RemoteDistance)
    local networkId = vehicleNetworkId(vehicle)
    if not networkId then return notify('No nearby networked vehicle.', 'error') end
    local locked, err = QB.callback.trigger('qbvehiclekeys:server:toggleRequested', networkId)
    if locked == nil then return notify(err or 'Could not change the vehicle lock.', 'error') end
    applyLockState(vehicle, locked)
    notify(locked and 'Vehicle locked.' or 'Vehicle unlocked.', 'success')
end

local function hotwireCurrentVehicle()
    if busyHotwiring then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return notify('You must be in the driver seat.', 'error')
    end
    local networkId = vehicleNetworkId(vehicle)
    if not networkId then return notify('This vehicle cannot be hotwired.', 'error') end

    busyHotwiring = true
    CreateThread(function()
        local authorization, err = QB.callback.trigger('qbvehiclekeys:server:hotwireStarted', networkId)
        if not authorization then
            busyHotwiring = false
            return notify(err or 'Could not start hotwiring.', 'error')
        end
        local result = QB.minigames.play('lockpick', nil, authorization)
        QB.events.trigger('qbvehiclekeys:server:hotwireFinished', authorization, result and result.proof or nil)
        busyHotwiring = false
    end)
end

QB.events.onPush('qbvehiclekeys:client:lockStateChanged', function(networkId, locked)
    if type(networkId) ~= 'number' or type(locked) ~= 'boolean' then return end
    applyLockState(NetworkGetEntityFromNetworkId(networkId), locked)
end)

QB.events.onPush('qbvehiclekeys:client:keysChanged', function()
    accessCache = {}
end)

QB.events.onPush('qbvehiclekeys:client:physicalKeyUsed', function(metadata)
    if type(metadata) ~= 'table' then return end
    toggleNearestVehicle()
end)

QB.state.onChange('qbvehiclekeys:locked', nil, function(change)
    if change.entity ~= 0 then applyLockState(change.entity, change.value == true) end
end)

QB.keybind.add({
    name = Config.Keybind.name,
    description = Config.Keybind.description,
    defaultKey = Config.Keybind.defaultKey,
    onPressed = toggleNearestVehicle,
})

if Config.Hotwire.enabled then
    QB.keybind.add({
        name = Config.Hotwire.keybind.name,
        description = Config.Hotwire.keybind.description,
        defaultKey = Config.Hotwire.keybind.defaultKey,
        onPressed = hotwireCurrentVehicle,
    })
end

if Config.RequireKeyToStart then
    local ignitionMonitorRunning = false

    local function startIgnitionMonitor()
        if ignitionMonitorRunning then return end
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

        ignitionMonitorRunning = true
        CreateThread(function()
            while true do
                ped = PlayerPedId()
                vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then break end
                if not hasIgnitionAccess(vehicle) then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    Wait(250)
                else
                    Wait(750)
                end
            end
            ignitionMonitorRunning = false
        end)
    end

    local function watchIgnition()
        QB.cache.onChange('vehicle', startIgnitionMonitor)
        QB.cache.onChange('seat', startIgnitionMonitor)
        startIgnitionMonitor()
    end

    watchIgnition()
    AddEventHandler('onClientResourceStart', function(resource)
        if resource == 'kora_lib' then watchIgnition() end
    end)
end
