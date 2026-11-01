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

AddEventHandler('playerDropped', function()
    temporaryKeys[source] = nil
    hotwireSessions[source] = nil
end)
