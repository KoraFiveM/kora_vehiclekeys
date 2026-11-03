local accessCache, busyHotwiring = {}, false

local function notify(message, notificationType, title)
    Kora.notify.send({ title = title or Config.Text.titleKeys, message = message, type = notificationType or 'info' })
end

local function currentOrClosestVehicle(distance)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end
    local coords = GetEntityCoords(ped)
    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, distance, 0, 70)
    return vehicle ~= 0 and vehicle or nil
end

local function isBike(vehicle)
    local model = GetEntityModel(vehicle)
    return IsThisModelABike(model) or IsThisModelABicycle(model)
end

-- takeControl is only set for the player who toggled the lock. Everyone else
-- applies the replicated state locally without asking for network control, so a
-- lock toggle never makes nearby clients fight over (and migrate) an occupied or
-- moving vehicle (F#50).
local function applyLockState(vehicle, locked, takeControl)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if takeControl and not Kora.entities.requestControl(vehicle, 250) then return end
    -- Bikes have no doors, but a locked door status also cancels the enter task
    -- that lifts a fallen bike. Their lock is enforced by BikeGuard (below) and
    -- the ignition check instead, so keep the native status unlocked.
    if isBike(vehicle) then locked = false end
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

    -- A raised callback (timeout, rate limit) counts as "no access" and is not
    -- cached; it must never abort the calling thread (the hotwire busy flag).
    local ok, result = pcall(Kora.callback.trigger, 'qbvehiclekeys:server:accessRequested', networkId)
    if not ok then return false end
    local allowed = result == true
    accessCache[networkId] = { allowed = allowed, expiresAt = GetGameTimer() + Config.AccessCacheMs }
    return allowed
end

-- Starts a hotwire/lockpick session on the server. A callback that errors,
-- times out or is rate limited raises inside kora_lib, so it is caught here:
-- the busy flag must always be released and the player only sees the generic
-- Config.Text.hotwireFailed. The technical detail goes to the debug log.
local function requestHotwireSession(callbackName, networkId)
    local ok, authorization, err = pcall(Kora.callback.trigger, callbackName, networkId)
    if not ok then
        if Config.Hotwire.debug == true then
            print(("[kora_vehiclekeys] %s: no response from the server (%s)"):format(callbackName, tostring(authorization)))
        end
        return nil
    end
    if not authorization and not err and Config.Hotwire.debug == true then
        print(("[kora_vehiclekeys] %s: server returned no authorization and no reason"):format(callbackName))
    end
    return authorization, err
end

-- Runs one server-authorised lockpick/hotwire session end to end. Every step is
-- guarded so the caller's busy flag is always released: a raised callback
-- (timeout, rate limit) or a minigame error just ends the attempt with the
-- generic failure notice.
local function runLockpickSession(callbackName, networkId)
    local authorization, err = requestHotwireSession(callbackName, networkId)
    if not authorization then
        return notify(err or Config.Text.hotwireFailed, 'error', Config.Text.titleHotwireFailed)
    end
    local ok, result = pcall(Kora.minigames.play, 'lockpick', nil, authorization)
    if not ok and Config.Hotwire.debug == true then
        print(("[kora_vehiclekeys] lockpick minigame errored (%s)"):format(tostring(result)))
    end
    Kora.events.trigger('qbvehiclekeys:server:hotwireFinished', authorization, ok and result and result.proof or nil)
end

local lastBikeNotice = 0

-- Keeps a locked bike blocked for players without access, with feedback. People
-- with a key (or an unlocked bike) get the normal enter task, which is how a
-- fallen or crashed bike is lifted. Config.allowPickupLockedBikes is read here,
-- every tick, so it applies live.
BikeGuard = {}

function BikeGuard.check()
    if Config.allowPickupLockedBikes == true then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local vehicle = GetVehiclePedIsTryingToEnter(ped)
    if not vehicle or vehicle == 0 or not isBike(vehicle) then return end
    if Entity(vehicle).state['qbvehiclekeys:locked'] ~= true then return end
    if hasIgnitionAccess(vehicle) then return end

    ClearPedTasks(ped)
    local now = GetGameTimer()
    if now - lastBikeNotice >= 2000 then
        lastBikeNotice = now
        notify('This bike is locked.', 'error')
    end
end

-- Only relevant during an entry attempt: kora_lib's cache 'enteringVehicle'
-- edge starts the 150 ms guard (first check immediately) when a bike is the
-- target, and the guard ends once neither the native nor the cache reports an
-- entry attempt. Keeping it alive while the cache still says "entering" covers
-- a retry made before the cache sampled the cancelled attempt, which would not
-- produce a new change event.
local cachedEntering = false
local bikeGuardRunning = false

local function startBikeGuard()
    if bikeGuardRunning then return end
    bikeGuardRunning = true
    CreateThread(function()
        while true do
            local ok, err = pcall(BikeGuard.check)
            if not ok then print(('[kora_vehiclekeys] BikeGuard.check errored: %s'):format(tostring(err))) end
            local trying = GetVehiclePedIsTryingToEnter(PlayerPedId())
            if not cachedEntering and (not trying or trying == 0) then break end
            Wait(150)
        end
        bikeGuardRunning = false
    end)
end

local function enteringVehicleChanged(vehicle)
    cachedEntering = vehicle ~= nil and vehicle ~= false and vehicle ~= 0
    if cachedEntering and isBike(vehicle) then startBikeGuard() end
end

-- kora_lib drops onChange listeners when it restarts: re-register and seed from
-- the current value (onChange never reports it), at load and on every restart.
local function watchBikeGuard()
    Kora.cache.onChange('enteringVehicle', enteringVehicleChanged)
    enteringVehicleChanged(Kora.cache.enteringVehicle())
end

watchBikeGuard()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_lib' then watchBikeGuard() end
end)

-- Models registered through the stock addNoLockVehicles export. Client-local
-- and advisory: it only stops this client initiating lock toggles for them; the
-- server never reads it, so it cannot unlock or exempt any vehicle.
local noLockModels = {}

local function isNoLockVehicle(vehicle)
    return next(noLockModels) ~= nil and noLockModels[GetEntityModel(vehicle)] == true
end

local function toggleNearestVehicle()
    local vehicle = currentOrClosestVehicle(Config.RemoteDistance)
    if vehicle and isNoLockVehicle(vehicle) then return end
    local networkId = vehicleNetworkId(vehicle)
    if not networkId then return notify('No nearby networked vehicle.', 'error') end
    local locked, err = Kora.callback.trigger('qbvehiclekeys:server:toggleRequested', networkId)
    if locked == nil then return notify(err or 'Could not change the vehicle lock.', 'error') end
    applyLockState(vehicle, locked, true)
    LockFeedback.localToggle(vehicle, locked)
    if (Config.lockFeedback or {}).notify ~= false then
        notify(locked and 'Vehicle locked.' or 'Vehicle unlocked.', 'success')
    end
end

-- Stock engine toggle (qb-vehiclekeys:client:ToggleEngine and the `engine` key).
-- Driver only, and the server must confirm keys or job access.
local function toggleEngine()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    CreateThread(function()
        if not hasIgnitionAccess(vehicle) then return end
        SetVehicleEngineOn(vehicle, not GetIsVehicleEngineRunning(vehicle), false, true)
    end)
end

RegisterNetEvent('qb-vehiclekeys:client:ToggleEngine')
AddEventHandler('qb-vehiclekeys:client:ToggleEngine', toggleEngine)

-- Item-driven lockpick (lockpick / advancedlockpick use): works on foot next to
-- a vehicle or from inside one, and always explains why it did nothing.
local function lockpickFromItem()
    if busyHotwiring then return end
    local vehicle = currentOrClosestVehicle(Config.InteractionDistance)
    local networkId = vehicle and vehicleNetworkId(vehicle)
    if not networkId then return notify(Config.Text.lockpickNoVehicle, 'error', Config.Text.titleHotwireFailed) end
    local ped = PlayerPedId()
    local inVehicle = GetVehiclePedIsIn(ped, false) == vehicle
    if inVehicle and GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return notify('You must be in the driver seat.', 'error', Config.Text.titleHotwireFailed)
    end

    busyHotwiring = true
    CreateThread(function()
        if inVehicle and (GetIsVehicleEngineRunning(vehicle) or hasIgnitionAccess(vehicle)) then
            busyHotwiring = false
            return notify(Config.Text.lockpickNotNeeded, 'info', Config.Text.titleHotwire)
        end
        runLockpickSession(inVehicle and 'qbvehiclekeys:server:hotwireStarted' or 'qbvehiclekeys:server:lockpickStarted', networkId)
        busyHotwiring = false
    end)
end

VehicleKeys = {
    notify = notify,
    noLockModels = noLockModels,
    vehicleNetworkId = vehicleNetworkId,
    currentOrClosestVehicle = currentOrClosestVehicle,
    toggleLocks = toggleNearestVehicle,
    toggleEngine = toggleEngine,
}

local function hotwireCurrentVehicle()
    if busyHotwiring then return end
    -- The hotwire key can share a physical key with other controls (H is also
    -- the headlight toggle), so every precondition fails silently unless the
    -- server opted into Config.Hotwire.notifyUnavailable.
    local function unavailable(message)
        if (Config.Hotwire or {}).notifyUnavailable == true then notify(message, 'error', Config.Text.titleHotwireFailed) end
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return unavailable('You must be in the driver seat.')
    end
    local networkId = vehicleNetworkId(vehicle)
    if not networkId then return unavailable('This vehicle cannot be hotwired.') end

    busyHotwiring = true
    CreateThread(function()
        -- Key holders and running engines never need hotwiring: do nothing.
        if GetIsVehicleEngineRunning(vehicle) or hasIgnitionAccess(vehicle) then
            busyHotwiring = false
            return
        end
        runLockpickSession('qbvehiclekeys:server:hotwireStarted', networkId)
        busyHotwiring = false
    end)
end

-- The server now replicates locks only through the state bag below; this push is
-- kept for integrations that still send it.
Kora.events.onPush('qbvehiclekeys:client:lockStateChanged', function(networkId, locked)
    if type(networkId) ~= 'number' or type(locked) ~= 'boolean' then return end
    applyLockState(NetworkGetEntityFromNetworkId(networkId), locked)
end)

Kora.events.onPush('qbvehiclekeys:client:lockFeedback', function(networkId, locked, source)
    if type(networkId) ~= 'number' or type(locked) ~= 'boolean' then return end
    LockFeedback.remote(NetworkGetEntityFromNetworkId(networkId), locked, source)
end)

Kora.events.onPush('qbvehiclekeys:client:keysChanged', function()
    accessCache = {}
end)

Kora.events.onPush('qbvehiclekeys:client:lockpickUsed', lockpickFromItem)

-- Stock qb-inventory / qb-vehiclekeys event for a lockpick use.
RegisterNetEvent('lockpicks:UseLockpick')
AddEventHandler('lockpicks:UseLockpick', function() lockpickFromItem() end)

Kora.events.onPush('qbvehiclekeys:client:physicalKeyUsed', function(metadata)
    if type(metadata) ~= 'table' then return end
    toggleNearestVehicle()
end)

Kora.state.onChange('qbvehiclekeys:locked', nil, function(change)
    if change.entity ~= 0 then applyLockState(change.entity, change.value == true) end
end)

Kora.keybind.add({
    name = Config.Keybind.name,
    description = Config.Keybind.description,
    defaultKey = Config.Keybind.defaultKey,
    onPressed = toggleNearestVehicle,
})

Kora.keybind.add({
    name = Config.EngineKeybind.name,
    description = Config.EngineKeybind.description,
    defaultKey = Config.EngineKeybind.defaultKey,
    onPressed = toggleEngine,
})

if Config.Hotwire.enabled then
    Kora.keybind.add({
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
        Kora.cache.onChange('vehicle', startIgnitionMonitor)
        Kora.cache.onChange('seat', startIgnitionMonitor)
        startIgnitionMonitor()
    end

    watchIgnition()
    AddEventHandler('onClientResourceStart', function(resource)
        if resource == 'kora_lib' then watchIgnition() end
    end)
end
