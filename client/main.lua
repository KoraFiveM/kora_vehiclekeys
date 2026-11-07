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

local function applyLockState(vehicle, locked)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not Kora.entities.requestControl(vehicle, 250) then return end
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
--
-- Spamming the lockpick item / hotwire key is refused here, before the server,
-- by mirroring the server's per-callback Config.RateLimits.hotwire window. If a
-- rate-limit rejection still gets through (latency), further requests wait out
-- the server's "retry in" time instead of hitting the limiter again.
local hotwireRequests, hotwireBlockedUntil = {}, 0

local function hotwireRequestAllowed(callbackName)
    local now = GetGameTimer()
    if now < hotwireBlockedUntil then return false end
    local limit = (Config.RateLimits or {}).hotwire
    if type(limit) ~= 'table' or type(limit.max) ~= 'number' or type(limit.window) ~= 'number' then return true end
    local kept = {}
    for _, sentAt in ipairs(hotwireRequests[callbackName] or {}) do
        if now - sentAt < limit.window + 250 then kept[#kept + 1] = sentAt end
    end
    hotwireRequests[callbackName] = kept
    if #kept >= limit.max then return false end
    kept[#kept + 1] = now
    return true
end

local function requestHotwireSession(callbackName, networkId)
    if not hotwireRequestAllowed(callbackName) then return nil, 'Slow down before trying that again.' end
    local ok, authorization, err = pcall(Kora.callback.trigger, callbackName, networkId)
    if not ok then
        local retryMs = tonumber(tostring(authorization):match('retry in (%d+)ms'))
        if retryMs then hotwireBlockedUntil = GetGameTimer() + retryMs end
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

local lastBikeNotice = 0

-- Keeps a locked bike blocked for players without access, with feedback. People
-- with a key (or an unlocked bike) get the normal enter task, which is how a
-- fallen or crashed bike is lifted. Config.allowPickupLockedBikes is read here,
-- every tick, so it applies live.
BikeGuard = {}

local lastBikeTarget, lastBikeTargetAt = 0, 0

-- Pushes a ped that already got onto a locked bike back off it. True if it was seated.
local function ejectFromBike(ped, vehicle)
    if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= vehicle then return false end
    TaskLeaveVehicle(ped, vehicle, 16)
    return true
end

function BikeGuard.check()
    if Config.allowPickupLockedBikes == true then return end
    local ped = PlayerPedId()
    local vehicle, seated = nil, false
    if IsPedInAnyVehicle(ped, false) then
        seated = true
        -- The mount can finish before the guard samples it (a bike is mounted in
        -- an instant): treat a bike we just saw being entered as still pending.
        vehicle = GetVehiclePedIsIn(ped, false)
        if not vehicle or vehicle == 0 or vehicle ~= lastBikeTarget or GetGameTimer() - lastBikeTargetAt > 3000 then return end
    else
        vehicle = GetVehiclePedIsTryingToEnter(ped)
    end
    if not vehicle or vehicle == 0 or not isBike(vehicle) then return end
    if Entity(vehicle).state['qbvehiclekeys:locked'] ~= true then return end
    if not seated then lastBikeTarget, lastBikeTargetAt = vehicle, GetGameTimer() end
    -- The access check is a server round trip: the ped may be seated by the time
    -- it answers, and ClearPedTasks does nothing to a seated ped.
    if hasIgnitionAccess(vehicle) then return end

    if not ejectFromBike(ped, vehicle) then ClearPedTasks(ped) end
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
    applyLockState(vehicle, locked)
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
    local ownText = (Config.Lockpick or {}).lockpickFailureText == true
    if not networkId then
        -- On foot with no vehicle in reach: hand the pick to a nearby lockpickable door.
        if (Config.Lockpick or {}).doorFallback ~= false and GetResourceState('kora_doorlock') == 'started' then
            local ok, started = pcall(function() return exports.kora_doorlock:pickClosestDoor() end)
            if ok and started then return end
        end
        return notify(Config.Text.lockpickNoVehicle, 'error', ownText and Config.Text.titleLockpickFailed or Config.Text.titleHotwireFailed)
    end
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
        local authorization, err = requestHotwireSession(
            inVehicle and 'qbvehiclekeys:server:hotwireStarted' or 'qbvehiclekeys:server:lockpickStarted', networkId)
        if not authorization then
            busyHotwiring = false
            if ownText and not inVehicle then
                return notify(err or Config.Text.lockpickFailed, 'error', Config.Text.titleLockpickFailed)
            end
            return notify(err or Config.Text.hotwireFailed, 'error', Config.Text.titleHotwireFailed)
        end
        local result = Kora.minigames.play('lockpick', nil, authorization)
        Kora.events.trigger('qbvehiclekeys:server:hotwireFinished', authorization, result and result.proof or nil)
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
        local authorization, err = requestHotwireSession('qbvehiclekeys:server:hotwireStarted', networkId)
        if not authorization then
            busyHotwiring = false
            return notify(err or Config.Text.hotwireFailed, 'error', Config.Text.titleHotwireFailed)
        end
        local result = Kora.minigames.play('lockpick', nil, authorization)
        Kora.events.trigger('qbvehiclekeys:server:hotwireFinished', authorization, result and result.proof or nil)
        busyHotwiring = false
    end)
end

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
