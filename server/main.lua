local temporaryKeys, hotwireSessions = {}, {}
local jobVehicleModels = {}
local VEHICLE_VALIDATION_MESSAGES = {
    invalid_network_id = 'Invalid vehicle.',
    routing_bucket_mismatch = 'Vehicle is in another instance.',
    too_far = 'Move closer to the vehicle.',
    driver_required = 'You must be in the driver seat.',
}

for jobName, models in pairs(Config.JobVehicles or {}) do
    assert(type(jobName) == 'string', 'Config.JobVehicles job names must be strings')
    assert(type(models) == 'table', ('Config.JobVehicles.%s must be a model list'):format(jobName))

    local modelHashes = {}
    for index = 1, #models do
        local model = models[index]
        assert(type(model) == 'string' or type(model) == 'number',
            ('Config.JobVehicles.%s[%d] must be a model name or hash'):format(jobName, index))
        modelHashes[type(model) == 'string' and joaat(model) or model] = true
    end
    jobVehicleModels[jobName] = modelHashes
end

local function normalisePlate(value)
    return Kora.vehicle.normalizePlate(value, {
        maxLength = 32,
        characters = 'any',
    })
end

---@param src integer
---@param networkId integer
---@param maximumDistance number
---@param requireDriver boolean
---@return integer|nil vehicle
---@return string|nil errorMessage
local function validateVehicle(src, networkId, maximumDistance, requireDriver)
    local vehicle, reason = Kora.world.resolveNetworkEntity(src, networkId, {
        entityType = 'vehicle',
        maxDistance = maximumDistance,
        requireDriver = requireDriver,
    })
    if vehicle then return vehicle end

    return nil, VEHICLE_VALIDATION_MESSAGES[reason] or 'Vehicle is no longer available.'
end

local function playerKeys(src)
    local keys = temporaryKeys[src]
    if not keys then
        keys = {}
        temporaryKeys[src] = keys
    end
    return keys
end

local function metadataMatches(item, plate)
    local expected = Config.PhysicalKey.metadata or {}
    local info = item and item.info
    if type(info) ~= 'table' then return false end

    for field, value in pairs(expected) do
        local required = value == true and plate or value
        if required == '{plate}' then required = plate end
        if required == plate then
            if normalisePlate(info[field]) ~= plate then return false end
        elseif info[field] ~= required then
            return false
        end
    end
    return true
end

---@param src integer
---@param plate string
---@return boolean hasKey
---@return integer|nil slot
local function hasPhysicalKey(src, plate)
    if not Config.PhysicalKey.enabled then return false end
    local items = exports.kora_core:getItemsByName(src, Config.PhysicalKey.item)
    for index = 1, #items do
        local item = items[index]
        if metadataMatches(item, plate) then return true, item.slot end
    end
    return false
end

---@param src integer
---@param plate string
---@return boolean hasAccess
local function hasAccess(src, plate)
    local temporary = playerKeys(src)[plate]
    if temporary == 'hotwired' or (Config.AllowTemporaryKeys and temporary == true) then return true end
    return hasPhysicalKey(src, plate)
end

---@param src integer
---@param vehicle integer
---@return boolean hasAccess
local function hasJobVehicleAccess(src, vehicle)
    local job = exports.kora_core:getPlayerData(src, { 'job' })
    local allowedModels = job and jobVehicleModels[job.name]
    return allowedModels ~= nil and allowedModels[GetEntityModel(vehicle)] == true
end

---@param src integer
---@param vehicle integer
---@param plate string
---@return boolean hasAccess
local function hasVehicleAccess(src, vehicle, plate)
    return hasAccess(src, plate) or hasJobVehicleAccess(src, vehicle)
end

local function setLocked(vehicle, networkId, locked)
    Entity(vehicle).state:set('qbvehiclekeys:locked', locked == true, true)
    Kora.events.push(-1, 'qbvehiclekeys:client:lockStateChanged', networkId, locked == true)
end

local function lockpickItem(src)
    local item = exports.kora_core:getItemByName(src, Config.Lockpick.item)
    return item and item.slot or nil
end

local function maybeBreakLockpick(src, slot, successful)
    local chances = Config.Lockpick.breakChance or {}
    local chance = tonumber(successful and chances.success or chances.failure) or 0
    if chance <= 0 or math.random(100) > chance then return end
    exports.kora_core:removeItem(src, Config.Lockpick.item, 1, slot, 'vehicle-lockpick-broke')
    Kora.notify.send(src, { title = Config.Text.titleHotwireFailed, message = 'Your lockpick broke.', type = 'error' })
end

---@param src integer
---@param plate string
---@return boolean
local function giveKeys(src, plate, allowWhenDisabled)
    plate = normalisePlate(plate)
    if not plate or (not Config.AllowTemporaryKeys and not allowWhenDisabled) then return false end
    playerKeys(src)[plate] = allowWhenDisabled and 'hotwired' or true
    Kora.events.push(src, 'qbvehiclekeys:client:keysChanged', plate, true)
    return true
end

---@param src integer
---@param plate string
---@return boolean
local function removeKeys(src, plate)
    plate = normalisePlate(plate)
    if not plate or not temporaryKeys[src] then return false end
    temporaryKeys[src][plate] = nil
    Kora.events.push(src, 'qbvehiclekeys:client:keysChanged', plate, false)
    return true
end

exports('giveKeys', giveKeys)
exports('removeKeys', removeKeys)
local function hasKeys(src, plate)
    plate = normalisePlate(plate)
    return plate ~= nil and hasAccess(src, plate) or false
end
exports('hasKeys', hasKeys)
Kora.compat.provideExport('qb-vehiclekeys', 'HasKeys', function(src, plate)
    if type(src) ~= 'number' or src < 1 or src % 1 ~= 0 then return false end
    return hasKeys(src, plate)
end)

-- Read only: clients can query only their own physical/temporary keys.
Kora.callback.register('qbvehiclekeys:server:legacyHasKeys', function(src, plate)
    return hasKeys(src, plate)
end, { rateLimit = Config.RateLimits.access })

if Config.PhysicalKey.enabled then
    exports.kora_core:createUseable(Config.PhysicalKey.item, function(src, item)
        Kora.events.push(src, 'qbvehiclekeys:client:physicalKeyUsed', item.info or {})
    end)
end

Kora.callback.register('qbvehiclekeys:server:accessRequested', function(src, networkId)
    local vehicle = validateVehicle(src, networkId, Config.InteractionDistance, true)
    if not vehicle then return false end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    return plate ~= nil and hasVehicleAccess(src, vehicle, plate)
end, { rateLimit = Config.RateLimits.access })

Kora.callback.register('qbvehiclekeys:server:toggleRequested', function(src, networkId)
    local vehicle, vehicleErr = validateVehicle(src, networkId, Config.RemoteDistance, false)
    if not vehicle then return nil, vehicleErr end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate or not hasVehicleAccess(src, vehicle, plate) then
        return nil, 'You do not have the keys for this vehicle.'
    end

    local locked = Entity(vehicle).state['qbvehiclekeys:locked'] == true
    locked = not locked
    setLocked(vehicle, networkId, locked)
    local feedback = Config.lockFeedback or {}
    if feedback.lights == true or feedback.soundNearby == true then
        Kora.events.push(-1, 'qbvehiclekeys:client:lockFeedback', networkId, locked, src)
    end
    return locked
end, { rateLimit = Config.RateLimits.toggle })

Kora.callback.register('qbvehiclekeys:server:hotwireStarted', function(src, networkId)
    if not Config.Hotwire.enabled then return nil, 'Hotwiring is disabled.' end
    local vehicle, vehicleErr = validateVehicle(src, networkId, Config.InteractionDistance, true)
    if not vehicle then return nil, vehicleErr end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return nil, 'Vehicle has no usable plate.' end
    if hasVehicleAccess(src, vehicle, plate) then return nil, 'You already have the keys.' end

    local slot = lockpickItem(src)
    if not slot then return nil, 'You need a lockpick.' end
    local authorization = Kora.minigames.authorizeProof(src, 'lockpick', Config.Lockpick.difficulty)
    if not authorization then return nil, 'Could not start the lockpick challenge.' end

    hotwireSessions[src] = { authorization = authorization, networkId = networkId, plate = plate, slot = slot }
    return authorization
end, { rateLimit = Config.RateLimits.hotwire })

Kora.events.register('qbvehiclekeys:server:hotwireFinished', function(src, authorization, proof)
    local session = hotwireSessions[src]
    hotwireSessions[src] = nil
    if not session or type(authorization) ~= 'string' or session.authorization ~= authorization then return end

    local vehicle = validateVehicle(src, session.networkId, Config.InteractionDistance, true)
    if not vehicle or normalisePlate(GetVehicleNumberPlateText(vehicle)) ~= session.plate then return end
    local successful = type(proof) == 'string'
        and Kora.minigames.consumeProof(src, proof, 'lockpick', authorization) == true
    maybeBreakLockpick(src, session.slot, successful)
    if not successful then
        return Kora.notify.send(src, { title = Config.Text.titleHotwireFailed, message = 'The ignition resisted your lockpick.', type = 'error' })
    end

    if Config.Hotwire.grantTemporaryKey then giveKeys(src, session.plate, true) end
    setLocked(vehicle, session.networkId, false)
    Kora.notify.send(src, { title = Config.Text.titleHotwire, message = 'Vehicle hotwired.', type = 'success' })
end, { rateLimit = Config.RateLimits.hotwire })

-- --- Legacy qb-vehiclekeys surface -----------------------------------------
-- Server exports are trusted callers (other server scripts) and map straight
-- onto giveKeys/removeKeys, so Config.AllowTemporaryKeys still applies. Net
-- events below are UNTRUSTED client input: each one re-derives authority on the
-- server (key ownership, driver seat, distance) exactly like the callbacks
-- above and never accepts a client's claim about who or what it may affect.
local function isOnline(src)
    return type(src) == 'number' and src >= 1 and src % 1 == 0 and GetPlayerPed(src) ~= 0
end

-- Stock servers call (id, plate); tolerate swapped arguments.
local function legacyArgs(a, b)
    if type(a) == 'string' and type(b) == 'number' then a, b = b, a end
    return a, b
end

Kora.compat.provideExport('qb-vehiclekeys', 'GiveKeys', function(a, b)
    local src, plate = legacyArgs(a, b)
    if not isOnline(src) then return false end
    return giveKeys(src, plate)
end)

Kora.compat.provideExport('qb-vehiclekeys', 'RemoveKeys', function(a, b)
    local src, plate = legacyArgs(a, b)
    if not isOnline(src) then return false end
    return removeKeys(src, plate)
end)

local legacyLastCall = {}
local function legacyThrottled(src, name)
    local now = GetGameTimer()
    local bySource = legacyLastCall[src]
    if not bySource then bySource = {}; legacyLastCall[src] = bySource end
    if bySource[name] and now - bySource[name] < 500 then return true end
    bySource[name] = now
    return false
end

local function legacyEvent(name, handler)
    RegisterNetEvent(name)
    AddEventHandler(name, function(...)
        local src = source
        if not isOnline(src) or legacyThrottled(src, name) then return end
        handler(src, ...)
    end)
end

-- Stock: the client claims a plate and the server hands it keys. Honoured only
-- when Config.LegacyClientGrants is on, and then only for the vehicle the
-- player is actually driving, with a matching plate.
legacyEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(src, plate)
    if Config.LegacyClientGrants ~= true then return end
    plate = type(plate) == 'string' and normalisePlate(plate) or nil
    if not plate then return end
    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if normalisePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return end
    giveKeys(src, plate)
end)

-- Stock: set a vehicle's lock state (1 unlocked, 2+ locked). Requires access.
legacyEvent('qb-vehiclekeys:server:setVehLockState', function(src, networkId, state)
    if type(networkId) ~= 'number' or type(state) ~= 'number' then return end
    local vehicle = validateVehicle(src, networkId, Config.RemoteDistance, false)
    if not vehicle then return end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate or not hasVehicleAccess(src, vehicle, plate) then return end
    setLocked(vehicle, networkId, state >= 2)
end)

-- Stock: hand a copy of a key to a nearby player. The giver must hold the key.
legacyEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(src, receiver, plate)
    plate = type(plate) == 'string' and normalisePlate(plate) or nil
    if not plate or not isOnline(receiver) or receiver == src then return end
    if not hasAccess(src, plate) then return end
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(receiver)))
    if distance > Config.InteractionDistance then return end
    giveKeys(receiver, plate)
end)

-- A client dropping its OWN temporary key (from qb-vehiclekeys:client:RemoveKeys).
legacyEvent('qb-vehiclekeys:server:RemoveOwnKeys', function(src, plate)
    if type(plate) == 'string' then removeKeys(src, plate) end
end)

AddEventHandler('playerDropped', function()
    temporaryKeys[source] = nil
    hotwireSessions[source] = nil
    legacyLastCall[source] = nil
end)
