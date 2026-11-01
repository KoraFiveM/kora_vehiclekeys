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

local function lockpickNames()
    local names = Config.Lockpick.items
    if type(names) ~= 'table' or #names == 0 then return { Config.Lockpick.item } end
    return names
end

---@return integer|nil slot
---@return string|nil itemName
local function lockpickItem(src)
    for _, name in ipairs(lockpickNames()) do
        local item = exports.kora_core:getItemByName(src, name)
        if item then return item.slot, name end
    end
    return nil
end

local function maybeBreakLockpick(src, session, successful)
    local chances = Config.Lockpick.breakChance or {}
    local chance = tonumber(successful and chances.success or chances.failure) or 0
    if chance <= 0 or math.random(100) > chance then return end
    exports.kora_core:removeItem(src, session.item or Config.Lockpick.item, 1, session.slot, 'vehicle-lockpick-broke')
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

-- Using a lockpick item only asks the client to start the lockpick flow; the
-- server still validates the vehicle, keys and the item in hotwireStarted.
-- Nothing is consumed here: breaking stays with maybeBreakLockpick.
if Config.Lockpick.registerUsable ~= false then
    for _, name in ipairs(lockpickNames()) do
        exports.kora_core:createUseable(name, function(src)
            Kora.events.push(src, 'qbvehiclekeys:client:lockpickUsed')
        end)
    end
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

    local slot, itemName = lockpickItem(src)
    if not slot then return nil, 'You need a lockpick.' end
    local authorization = Kora.minigames.authorizeProof(src, 'lockpick', Config.Lockpick.difficulty)
    if not authorization then return nil, 'Could not start the lockpick challenge.' end

    hotwireSessions[src] = {
        authorization = authorization, networkId = networkId, plate = plate, slot = slot, item = itemName,
        distance = Config.InteractionDistance, requireDriver = true, grantKey = Config.Hotwire.grantTemporaryKey == true,
    }
    return authorization
end, { rateLimit = Config.RateLimits.hotwire })

Kora.callback.register('qbvehiclekeys:server:lockpickStarted', function(src, networkId)
    if not Config.Hotwire.enabled then return nil, 'Lockpicking is disabled.' end
    local vehicle, vehicleErr = validateVehicle(src, networkId, Config.InteractionDistance, false)
    if not vehicle then return nil, vehicleErr end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return nil, 'Vehicle has no usable plate.' end
    if hasVehicleAccess(src, vehicle, plate) then return nil, 'You already have the keys.' end
    local locked = Entity(vehicle).state['qbvehiclekeys:locked'] == true or (GetVehicleDoorLockStatus(vehicle) or 0) > 1
    if not locked then return nil, 'This vehicle is not locked.' end

    local slot, itemName = lockpickItem(src)
    if not slot then return nil, 'You need a lockpick.' end
    local authorization = Kora.minigames.authorizeProof(src, 'lockpick', Config.Lockpick.difficulty)
    if not authorization then return nil, 'Could not start the lockpick challenge.' end

    hotwireSessions[src] = {
        authorization = authorization, networkId = networkId, plate = plate, slot = slot, item = itemName,
        distance = Config.InteractionDistance, requireDriver = false, grantKey = false,
    }
    return authorization
end, { rateLimit = Config.RateLimits.hotwire })

Kora.events.register('qbvehiclekeys:server:hotwireFinished', function(src, authorization, proof)
    local session = hotwireSessions[src]
    hotwireSessions[src] = nil
    if not session or type(authorization) ~= 'string' or session.authorization ~= authorization then return end

    local vehicle = validateVehicle(src, session.networkId, session.distance, session.requireDriver)
    if not vehicle or normalisePlate(GetVehicleNumberPlateText(vehicle)) ~= session.plate then return end
    local successful = type(proof) == 'string'
        and Kora.minigames.consumeProof(src, proof, 'lockpick', authorization) == true
    maybeBreakLockpick(src, session, successful)
    if not successful then
        return Kora.notify.send(src, { title = Config.Text.titleHotwireFailed, message = 'The ignition resisted your lockpick.', type = 'error' })
    end

    if session.grantKey then giveKeys(src, session.plate, true) end
    setLocked(vehicle, session.networkId, false)
    Kora.notify.send(src, {
        title = Config.Text.titleHotwire,
        message = session.requireDriver and 'Vehicle hotwired.' or 'You picked the door lock open.',
        type = 'success',
    })
end, { rateLimit = Config.RateLimits.hotwire })

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

-- Stock GiveKeys(id[, plate]): without a plate the vehicle the player is in is used.
local function currentPlate(src)
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if not vehicle or vehicle == 0 then return nil end
    return GetVehicleNumberPlateText(vehicle)
end

Kora.compat.provideExport('qb-vehiclekeys', 'GiveKeys', function(a, b)
    local src, plate = legacyArgs(a, b)
    if not isOnline(src) then return false end
    if plate == nil then plate = currentPlate(src) end
    return giveKeys(src, plate)
end)

Kora.compat.provideExport('qb-vehiclekeys', 'RemoveKeys', function(a, b)
    local src, plate = legacyArgs(a, b)
    if not isOnline(src) then return false end
    return removeKeys(src, plate)
end)

local legacyLastCall = {}
local function legacyThrottled(src, name, minInterval)
    local now = GetGameTimer()
    local bySource = legacyLastCall[src]
    if not bySource then bySource = {}; legacyLastCall[src] = bySource end
    if bySource[name] and now - bySource[name] < (minInterval or 500) then return true end
    bySource[name] = now
    return false
end

local function legacyEvent(name, handler, minInterval)
    RegisterNetEvent(name)
    AddEventHandler(name, function(...)
        local src = source
        if not isOnline(src) or legacyThrottled(src, name, minInterval) then return end
        handler(src, ...)
    end)
end

-- Recently created vehicle entities (entityCreated), used to recognise vehicles
-- that just spawned for the requester (stock /car, QBCore SpawnVehicle).
local spawned = {}
AddEventHandler('entityCreated', function(entity)
    if type(entity) ~= 'number' or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    -- Ambient traffic/parked population is owned by a nearby client too; only
    -- script-created (mission) entities count as spawns.
    if GetEntityPopulationType(entity) ~= 7 then return end
    local creator = NetworkGetFirstEntityOwner(entity)
    spawned[entity] = { at = GetGameTimer(), creator = (creator and creator > 0) and creator or nil }
end)
AddEventHandler('entityRemoved', function(entity) spawned[entity] = nil end)

local grantLog = {}
local function grantAllowed(src)
    local limit = Config.TrustedSetOwner.rateLimit or {}
    local now = GetGameTimer()
    local entry = grantLog[src]
    if not entry or now - entry.since >= (limit.window or 60000) then
        entry = { since = now, count = 0 }
        grantLog[src] = entry
    end
    if entry.count >= (limit.max or 5) then return false end
    entry.count = entry.count + 1
    return true
end

local function heldByAnother(src, plate)
    for other, keys in pairs(temporaryKeys) do
        if other ~= src and keys[plate] then return true end
    end
    return false
end

local function isOwnedVehicle(vehicle, plate)
    if Entity(vehicle).state.vehicleid ~= nil then return true end
    -- Look the plate up as written (trimmed/upper-cased) and normalised, since
    -- player_vehicles may store either form.
    local raw = (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$'):upper()
    local forms = { plate }
    if raw ~= plate then forms[2] = raw end
    for index = 1, #forms do
        local ok, row = pcall(function() return exports.kora_core:getByPlate(forms[index]) end)
        if not ok or row ~= nil then return true end -- fail closed when ownership cannot be checked
    end
    return false
end

-- True when a different live vehicle carries the plate (a duplicate plate must
-- never inherit a key), or a physical key item for it is held by any online player.
local function plateContested(vehicle, plate)
    for _, other in ipairs(GetAllVehicles()) do
        if other ~= vehicle and normalisePlate(GetVehicleNumberPlateText(other)) == plate then return true end
    end
    if Config.PhysicalKey.enabled then
        for _, player in ipairs(GetPlayers()) do
            if hasPhysicalKey(tonumber(player), plate) then return true end
        end
    end
    return false
end

---@param src integer
---@param vehicle integer
---@param plate string
---@return string|nil basis 'spawn' | 'job', nil when untrusted
local function trustedBasis(src, vehicle, plate)
    local cfg = Config.TrustedSetOwner
    if isOwnedVehicle(vehicle, plate) then return nil end
    if Entity(vehicle).state['qbvehiclekeys:locked'] == true then return nil end
    if (GetVehicleDoorLockStatus(vehicle) or 0) > 1 then return nil end
    if heldByAnother(src, plate) or plateContested(vehicle, plate) then return nil end

    local job = exports.kora_core:getPlayerData(src, { 'job' })
    local models = job and job.onduty == true and jobVehicleModels[job.name]
    if models and models[GetEntityModel(vehicle)] == true then return 'job' end

    local record = spawned[vehicle]
    if not record or GetGameTimer() - record.at > (cfg.spawnWindowMs or 15000) then return nil end
    if record.creator then
        if record.creator == src then return 'spawn' end
    elseif GetPedInVehicleSeat(vehicle, -1) == GetPlayerPed(src) then
        return 'spawn'
    end
    return nil
end

-- Stock sends a vehicle network id; older callers send a plate. A plate is only
-- resolved against the vehicle the player is currently inside.
local function resolveAcquireTarget(src, target)
    local cfg = Config.TrustedSetOwner or {}
    if type(target) == 'number' then
        return validateVehicle(src, target, cfg.maxDistance or 7.5, false)
    end
    local plate = type(target) == 'string' and normalisePlate(target) or nil
    if not plate then return nil end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if vehicle and vehicle ~= 0 and normalisePlate(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    return nil
end

-- Stock: the client asks for keys to a vehicle (netId; a plate is tolerated).
-- With Config.LegacyClientGrants the old rule applies: the driven vehicle only.
-- Otherwise Config.TrustedSetOwner decides (see config.lua). Either way the
-- server re-derives everything; the client's claim is never trusted.
legacyEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(src, target)
    if Config.LegacyClientGrants == true then
        local ped = GetPlayerPed(src)
        local driven = GetVehiclePedIsIn(ped, false)
        if not driven or driven == 0 or GetPedInVehicleSeat(driven, -1) ~= ped then return end
        local vehicle = resolveAcquireTarget(src, target)
        if vehicle ~= driven then return end
        return giveKeys(src, GetVehicleNumberPlateText(vehicle))
    end

    local cfg = Config.TrustedSetOwner
    if not cfg or cfg.enabled ~= true then return end
    local vehicle = resolveAcquireTarget(src, target)
    if not vehicle then return end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate or hasAccess(src, plate) then return end
    local basis = trustedBasis(src, vehicle, plate)
    if not basis or not grantAllowed(src) then return end
    if giveKeys(src, plate) and cfg.log ~= false then
        print(('[kora_vehiclekeys] granted keys to player %d for plate %s (%s)'):format(src, plate, basis))
    end
end, 300) -- the client retries every 400 ms while the server learns of a fresh entity

-- Stock: set a vehicle's lock state (1 unlocked, 2+ locked). Requires access.
legacyEvent('qb-vehiclekeys:server:setVehLockState', function(src, networkId, state)
    if type(networkId) ~= 'number' or type(state) ~= 'number' then return end
    local vehicle = validateVehicle(src, networkId, Config.RemoteDistance, false)
    if not vehicle then return end
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate or not hasVehicleAccess(src, vehicle, plate) then return end
    setLocked(vehicle, networkId, state >= 2)
end)

-- Stock: hand a copy of a key to a nearby player (receiver is an id or a list
-- of ids). The giver must hold the key; each receiver must be within reach.
local MAX_RECEIVERS = 8
legacyEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(src, receiver, plate)
    plate = type(plate) == 'string' and normalisePlate(plate) or nil
    if not plate or not hasAccess(src, plate) then return end
    local receivers = type(receiver) == 'table' and receiver or { receiver }
    local giverCoords = GetEntityCoords(GetPlayerPed(src))
    local seen, given = {}, false
    for index = 1, math.min(#receivers, MAX_RECEIVERS) do
        local target = receivers[index]
        if isOnline(target) and target ~= src and not seen[target]
            and #(giverCoords - GetEntityCoords(GetPlayerPed(target))) <= Config.InteractionDistance
            and giveKeys(target, plate) then
            seen[target] = true
            given = true
            Kora.notify.send(target, { title = Config.Text.titleKeys, message = 'You get keys to the vehicle!', type = 'success' })
        end
    end
    if given then
        Kora.notify.send(src, { title = Config.Text.titleKeys, message = 'You hand over the keys.', type = 'success' })
    end
end)

-- A client dropping its OWN temporary key. Never touches anyone else's keys.
local function dropOwnKeys(src, plate)
    if type(plate) == 'string' then removeKeys(src, plate) end
end
legacyEvent('qb-vehiclekeys:server:RemoveOwnKeys', dropOwnKeys)
legacyEvent('qb-vehiclekeys:server:RemoveVehicleKeys', dropOwnKeys)

-- Stock breakLockpick lets the client name an item to remove. Kora rolls the
-- break chance itself when it resolves a lockpick attempt (Config.Lockpick.breakChance), so this is a validated no-op: nothing is removed.
legacyEvent('qb-vehiclekeys:server:breakLockpick', function() end)

-- Stock callbacks, answering only about the calling player. Stock returns a
-- { [plate] = true } table; keys are the session keys plus matching key items.
local function keyList(src)
    local list = {}
    for plate, held in pairs(playerKeys(src)) do
        if held == 'hotwired' or (Config.AllowTemporaryKeys and held == true) then list[plate] = true end
    end
    if Config.PhysicalKey.enabled then
        local items = exports.kora_core:getItemsByName(src, Config.PhysicalKey.item)
        for index = 1, #items do
            local plate = type(items[index].info) == 'table' and normalisePlate(items[index].info.plate)
            if plate and metadataMatches(items[index], plate) then list[plate] = true end
        end
    end
    return list
end

Kora.callback.register('qb-vehiclekeys:server:GetVehicleKeys', function(src)
    return keyList(src)
end, { rateLimit = Config.RateLimits.access })

-- Stock: whether a plate belongs to a player. True when the caller holds the
-- key or the plate is a player_vehicles row (unreadable ownership counts as owned).
Kora.callback.register('qb-vehiclekeys:server:checkPlayerOwned', function(src, plate)
    plate = type(plate) == 'string' and normalisePlate(plate) or nil
    if not plate then return false end
    if hasAccess(src, plate) then return true end
    local ok, row = pcall(function() return exports.kora_core:getByPlate(plate) end)
    return not ok or row ~= nil
end, { rateLimit = Config.RateLimits.access })

local function auditAdmin(src, action, target, plate)
    print(('[kora_vehiclekeys] %s by %s: player %s plate %s'):format(action, tostring(src), tostring(target), plate))
    Kora.logging.event('vehiclekeys:' .. action, src, { target = target, plate = plate })
end

local function adminTarget(src, args)
    local target, plate = tonumber(args[1]), normalisePlate(args[2])
    if not isOnline(target) or not plate then
        Kora.notify.send(src, { title = Config.Text.titleKeys, message = 'Fill out the player ID and Plate arguments', type = 'error' })
        return nil
    end
    return target, plate
end

local function checkPermission(src, permission)
    return exports.kora_core:hasPermission(src, permission) == true
end

Kora.commands.add('givekeys', 'Hand over the keys to someone. If no ID, gives to closest person or everyone in the vehicle.', {
    { name = 'id', help = 'Player ID' },
}, false, function(src, args)
    if src < 1 then return end
    TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', src, tonumber(args[1]))
end)

Kora.commands.add('addkeys', 'Adds keys to a vehicle for someone.', {
    { name = 'id', help = 'Player ID' },
    { name = 'plate', help = 'Plate' },
}, true, function(src, args)
    local target, plate = adminTarget(src, args)
    if not target then return end
    if not giveKeys(target, plate) then
        return Kora.notify.send(src, { title = Config.Text.titleKeys, message = 'Temporary keys are disabled.', type = 'error' })
    end
    auditAdmin(src, 'addkeys', target, plate)
end, { permission = 'admin', checkPermission = checkPermission })

Kora.commands.add('removekeys', 'Remove keys to a vehicle for someone.', {
    { name = 'id', help = 'Player ID' },
    { name = 'plate', help = 'Plate' },
}, true, function(src, args)
    local target, plate = adminTarget(src, args)
    if not target then return end
    removeKeys(target, plate)
    auditAdmin(src, 'removekeys', target, plate)
end, { permission = 'admin', checkPermission = checkPermission })

AddEventHandler('playerDropped', function()
    temporaryKeys[source] = nil
    hotwireSessions[source] = nil
    legacyLastCall[source] = nil
    grantLog[source] = nil
end)
