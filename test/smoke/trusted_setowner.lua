local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local callbacks, events, pushes, states = {}, {}, {}, {}
local inventory = {
    { slot = 3, name = 'vehiclekey', info = { plate = 'qb 123', keyType = 'standard' } },
}
local playerPed, vehicle = 10, 70
local playerJob = { name = 'unemployed', onduty = false }
local vehicleModel = 100

local vectorMeta
vectorMeta = {
    __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
}
local function vector(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMeta) end

_G.Kora = {
    callback = { register = function(name, handler) callbacks[name] = handler end },
    commands = { add = function() end },
    logging = { event = function() end },
    events = {
        register = function(name, handler) events[name] = handler end,
        push = function(target, name, ...) pushes[#pushes + 1] = { target = target, name = name, values = { ... } } end,
    },
    notify = { send = function() end },
    minigames = {
        authorizeProof = function() return 'authorisation' end,
        consumeProof = function(_, proof, gameType, authorisation)
            return proof == 'proof' and gameType == 'lockpick' and authorisation == 'authorisation'
        end,
    },
    world = {
        resolveNetworkEntity = function(src, networkId, options)
            local entity = NetworkGetEntityFromNetworkId(networkId)
            local ped = GetPlayerPed(src)
            if entity == 0 or not DoesEntityExist(entity) then return nil, 'entity_unavailable' end
            if GetEntityType(entity) ~= 2 then return nil, 'wrong_entity_type' end
            if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entity) then
                return nil, 'routing_bucket_mismatch'
            end
            if options.requireDriver and GetPedInVehicleSeat(entity, -1) ~= ped then return nil, 'driver_required' end
            return entity
        end,
    },
    vehicle = {
        normalizePlate = function(value)
            if type(value) ~= 'string' then return nil end
            local plate = value:match('^%s*(.-)%s*$'):upper():gsub('%s+', ' ')
            return plate ~= '' and #plate <= 32 and plate or nil
        end,
    },
}
_G.exports = setmetatable({
    kora_core = {
        getItemsByName = function() return inventory end,
        getItemByName = function() return { slot = 8, name = 'lockpick' } end,
        removeItem = function() return true end,
        createUseable = function() end,
        getPlayerData = function() return playerJob end,
    },
}, { __call = function(_, _, _) end })
_G.NetworkGetEntityFromNetworkId = function(networkId) return networkId == 7 and vehicle or 0 end
_G.GetPlayerPed = function(src) return src == 1 and playerPed or 0 end
_G.DoesEntityExist = function(entity) return entity == playerPed or entity == vehicle end
_G.GetEntityType = function(entity) return entity == vehicle and 2 or 1 end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.GetEntityRoutingBucket = function() return 0 end
_G.GetEntityCoords = function(entity) return entity == playerPed and vector(0, 0, 0) or vector(1, 0, 0) end
_G.GetPedInVehicleSeat = function() return playerPed end
_G.GetVehicleNumberPlateText = function() return ' QB  123 ' end
_G.GetEntityModel = function() return vehicleModel end
_G.joaat = function(model) return model == 'police' and 200 or 0 end
_G.Entity = function(entity)
    states[entity] = states[entity] or {}
    return { state = setmetatable(states[entity], { __index = { set = function(self, key, value) self[key] = value end } }) }
end
local legacyEvents = {}
_G.AddEventHandler = function(name, fn) legacyEvents[name] = fn end
_G.RegisterNetEvent = function() end
_G.now = 0
_G.GetGameTimer = function() return now end
Kora.compat = dofile(resourceDir .. '../kora_lib/compat/provider.lua')()

dofile(resourceDir .. 'config.lua')
Config.PhysicalKey.metadata = { plate = '{plate}', keyType = 'standard' }
Config.AllowTemporaryKeys = true
Config.PhysicalKey.enabled = false
Config.JobVehicles = { police = { 'police' } }
local owned, creator, lockStatus, popType = nil, nil, 0, 7
local rows, otherVehicles, onlinePlayers = nil, {}, {}
_G.GetEntityPopulationType = function() return popType end
_G.GetAllVehicles = function() local l = { vehicle }; for _, v in ipairs(otherVehicles) do l[#l + 1] = v end; return l end
_G.GetPlayers = function() return onlinePlayers end
_G.NetworkGetFirstEntityOwner = function() return creator end
_G.GetVehicleDoorLockStatus = function() return lockStatus end
exports.kora_core.getByPlate = function(_, plate) if rows then return rows[plate] end return owned end
dofile(resourceDir .. 'server/main.lua')



local peds = { [1] = 10, [2] = 11, [3] = 12 }
local coords = { [10] = vector(0, 0, 0), [11] = vector(2, 0, 0), [12] = vector(500, 0, 0) }
_G.GetPlayerPed = function(src) return peds[src] or 0 end
_G.GetEntityCoords = function(entity) return coords[entity] or vector(1, 0, 0) end
_G.GetVehiclePedIsIn = function() return 0 end
_G.GetPedInVehicleSeat = function() return 0 end
_G.GetEntityType = function(entity) return entity == vehicle and 2 or 1 end
local exp
local function hasKeys(src)
    if not exp then legacyEvents['__cfx_export_qb-vehiclekeys_HasKeys'](function(fn) exp = fn end) end
    return exp(src, 'QB 123')
end
local function fire(src, ...)
    now = now + 1000
    _G.source = src
    legacyEvents['qb-vehiclekeys:server:AcquireVehicleKeys'](...)
end
local function spawn(by)
    creator = by
    now = now + 1000
    legacyEvents['entityCreated'](vehicle)
end
local function reset()
    exports.kora_vehiclekeys = nil
    rows, otherVehicles, onlinePlayers, popType, inventory[1].info.plate = nil, {}, {}, 7, 'qb 123'
    Config.PhysicalKey.enabled = false
    owned, lockStatus, playerJob.onduty, playerJob.name = nil, 0, false, 'unemployed'
    states[vehicle] = nil
    legacyEvents['entityRemoved'](vehicle)
    for src = 1, 3 do _G.source = src; legacyEvents['playerDropped']() end
    Config.TrustedSetOwner.enabled = true
    Config.TrustedSetOwner.rateLimit = { max = 5, window = 60000 }
    Config.LegacyClientGrants = false
end

harness.test('no spawn record and no job: refused', function()
    reset()
    fire(1, 7)
    harness.assertFalse(hasKeys(1))
end)

harness.test('client-spawned vehicle (stock /car) grants the creator by network id', function()
    reset(); spawn(1)
    fire(1, 7)
    harness.assertTrue(hasKeys(1))
end)

harness.test('another player cannot claim a vehicle someone else spawned', function()
    reset(); spawn(1)
    fire(2, 7)
    harness.assertFalse(hasKeys(2))
end)

harness.test('server-spawned vehicle needs the requester in the driver seat', function()
    reset(); spawn(nil)
    fire(1, 7)
    _G.GetPedInVehicleSeat = function() return 0 end
    harness.assertFalse(hasKeys(1))
    _G.GetPedInVehicleSeat = function() return 10 end
    fire(1, 7)
    harness.assertTrue(hasKeys(1))
    _G.GetPedInVehicleSeat = function() return 0 end
end)

harness.test('spawn window expires', function()
    reset(); spawn(1)
    now = now + Config.TrustedSetOwner.spawnWindowMs + 1
    _G.source = 1
    legacyEvents['qb-vehiclekeys:server:AcquireVehicleKeys'](7)
    harness.assertFalse(hasKeys(1))
end)

harness.test('owned, locked, key-held or out-of-range vehicles are refused', function()
    reset(); spawn(1); owned = { plate = 'QB 123' }
    fire(1, 7); harness.assertFalse(hasKeys(1), 'player_vehicles row')
    owned = nil; spawn(1); states[vehicle] = { vehicleid = 4 }
    fire(1, 7); harness.assertFalse(hasKeys(1), 'tagged owned entity')
    states[vehicle] = { ['qbvehiclekeys:locked'] = true }
    fire(1, 7); harness.assertFalse(hasKeys(1), 'locked state')
    states[vehicle] = nil; lockStatus = 2
    fire(1, 7); harness.assertFalse(hasKeys(1), 'native lock')
    lockStatus = 0
    local give
    legacyEvents['__cfx_export_qb-vehiclekeys_GiveKeys'](function(fn) give = fn end)
    give(2, 'QB 123')
    fire(1, 7); harness.assertFalse(hasKeys(1), 'another player holds a key')
    reset(); spawn(1); coords[vehicle] = vector(50, 0, 0)
    local resolve = Kora.world.resolveNetworkEntity
    Kora.world.resolveNetworkEntity = function(src, id, o)
        if #(GetEntityCoords(vehicle) - GetEntityCoords(GetPlayerPed(src))) > o.maxDistance then return nil, 'too_far' end
        return resolve(src, id, o)
    end
    fire(1, 7); harness.assertFalse(hasKeys(1), 'too far')
    coords[vehicle] = nil
    Kora.world.resolveNetworkEntity = resolve
end)

harness.test('ambient population is never a spawn', function()
    reset(); popType = 1; spawn(1)
    fire(1, 7); harness.assertFalse(hasKeys(1), 'ambient traffic owned by the requester')
    popType = 7
end)

harness.test('ownership is looked up by raw and normalised plate', function()
    reset(); spawn(1)
    rows = { ['QB  123'] = { plate = 'QB  123' } } -- stored with its double space
    fire(1, 7); harness.assertFalse(hasKeys(1), 'raw plate row')
    rows = {}
    fire(1, 7); harness.assertTrue(hasKeys(1), 'no row under either form')
end)

harness.test('duplicate live plate or an existing physical key refuses the spawn basis', function()
    reset(); spawn(1)
    otherVehicles = { 99 }
    local plateOf = GetVehicleNumberPlateText
    fire(1, 7); harness.assertFalse(hasKeys(1), 'another live vehicle shares the plate')
    otherVehicles = {}
    Config.PhysicalKey.enabled = true
    onlinePlayers = { '2' }
    inventory[1].info.plate = 'qb 123'
    local items = exports.kora_core.getItemsByName
    exports.kora_core.getItemsByName = function(_, src) return src == 2 and inventory or {} end
    fire(1, 7); harness.assertFalse(hasKeys(1), 'a physical key exists for the plate')
    onlinePlayers = {}
    fire(1, 7); harness.assertTrue(hasKeys(1), 'no physical key held by anyone online')
    exports.kora_core.getItemsByName = items
end)

harness.test('job vehicles need the on-duty job and a matching model', function()
    reset()
    playerJob.name = 'police'
    fire(1, 7); harness.assertFalse(hasKeys(1), 'off duty')
    playerJob.onduty = true
    vehicleModel = 999
    fire(1, 7); harness.assertFalse(hasKeys(1), 'model not listed')
    vehicleModel = 200 -- joaat('police') in this harness
    fire(1, 7); harness.assertTrue(hasKeys(1), 'on-duty police in a police model')
    reset()
    playerJob.name, playerJob.onduty, vehicleModel = 'ambulance', true, 200
    fire(1, 7); harness.assertFalse(hasKeys(1), 'other job')
    vehicleModel = 100
end)

harness.test('grants are rate limited and the flag disables the path', function()
    reset(); spawn(1)
    Config.TrustedSetOwner.enabled = false
    fire(1, 7); harness.assertFalse(hasKeys(1), 'disabled')
    Config.TrustedSetOwner.enabled = true
    Config.TrustedSetOwner.rateLimit = { max = 1, window = 60000 }
    local remove
    legacyEvents['__cfx_export_qb-vehiclekeys_RemoveKeys'](function(fn) remove = fn end)
    fire(1, 7); harness.assertTrue(hasKeys(1))
    remove(1, 'QB 123')
    fire(1, 7); harness.assertFalse(hasKeys(1), 'second grant inside window refused')
end)

harness.test('LegacyClientGrants stays off by default', function()
    dofile(resourceDir .. 'config.lua')
    harness.assertFalse(Config.LegacyClientGrants)
    harness.assertTrue(Config.TrustedSetOwner.enabled)
end)

harness.report('qbvehiclekeys trusted SetOwner')
