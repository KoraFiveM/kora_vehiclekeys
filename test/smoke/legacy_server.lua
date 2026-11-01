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
local playerJob = { name = 'unemployed' }
local vehicleModel = 100

local vectorMeta
vectorMeta = {
    __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
}
local function vector(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMeta) end

_G.Kora = {
    callback = { register = function(name, handler) callbacks[name] = handler end },
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
dofile(resourceDir .. 'server/main.lua')


-- Two players: 1 (ped 10) and 2 (ped 11), 2 is nearby; 3 is far away.
local peds = { [1] = 10, [2] = 11, [3] = 12 }
local coords = { [10] = vector(0, 0, 0), [11] = vector(2, 0, 0), [12] = vector(500, 0, 0), [70] = vector(1, 0, 0) }
_G.GetPlayerPed = function(src) return peds[src] or 0 end
_G.GetEntityCoords = function(entity) return coords[entity] or vector(1, 0, 0) end
local inVehicle = vehicle
_G.GetVehiclePedIsIn = function(ped) return ped == playerPed and inVehicle or 0 end
local exp = {}
local function export(name)
    if not exp[name] then legacyEvents['__cfx_export_qb-vehiclekeys_' .. name](function(fn) exp[name] = fn end) end
    return exp[name]
end
local function fire(name, src, ...)
    now = now + 1000
    _G.source = src
    legacyEvents[name](...)
end

harness.test('GiveKeys / RemoveKeys exports mirror giveKeys/removeKeys', function()
    harness.assertFalse(exports.kora_vehiclekeys and false or export('HasKeys')(1, 'QB 123'))
    harness.assertTrue(export('GiveKeys')(1, ' qb 123 '))
    harness.assertTrue(export('HasKeys')(1, 'QB 123'))
    harness.assertFalse(export('HasKeys')(2, 'QB 123'))
    harness.assertTrue(export('RemoveKeys')(1, 'QB 123'))
    harness.assertFalse(export('HasKeys')(1, 'QB 123'))
    harness.assertTrue(export('GiveKeys')('QB 123', 1), 'swapped args tolerated')
    harness.assertTrue(export('RemoveKeys')(1, 'QB 123'))
end)

harness.test('GiveKeys rejects offline players, bad plates and disabled temporary keys', function()
    harness.assertFalse(export('GiveKeys')(99, 'QB 123'))
    harness.assertFalse(export('GiveKeys')(nil, 'QB 123'))
    harness.assertFalse(export('GiveKeys')(1, {}))
    Config.AllowTemporaryKeys = false
    harness.assertFalse(export('GiveKeys')(1, 'QB 123'))
    Config.AllowTemporaryKeys = true
end)

harness.test('client AcquireVehicleKeys cannot self-grant by default', function()
    Config.TrustedSetOwner.enabled = false
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 1, 'QB 123')
    harness.assertFalse(export('HasKeys')(1, 'QB 123'))
    Config.TrustedSetOwner.enabled = true
end)

harness.test('AcquireVehicleKeys with opt-in requires driving a vehicle with that plate', function()
    Config.LegacyClientGrants = true
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 1, 'OTHER 1')
    harness.assertFalse(export('HasKeys')(1, 'OTHER 1'), 'plate must match the driven vehicle')
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 2, 'QB 123')
    harness.assertFalse(export('HasKeys')(2, 'QB 123'), 'not in a vehicle')
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 1, {})
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 1, 'QB 123')
    harness.assertTrue(export('HasKeys')(1, 'QB 123'))
    export('RemoveKeys')(1, 'QB 123')
    fire('qb-vehiclekeys:server:AcquireVehicleKeys', 1, 7)
    harness.assertTrue(export('HasKeys')(1, 'QB 123'), 'network id accepted')
    export('RemoveKeys')(1, 'QB 123')
    Config.LegacyClientGrants = false
end)

local function lockedState() return (states[vehicle] or {})['qbvehiclekeys:locked'] end
harness.test('setVehLockState needs access and a valid vehicle', function()
    fire('qb-vehiclekeys:server:setVehLockState', 1, 7, 2)
    harness.assertEqual(lockedState(), nil, 'no key, no change')
    export('GiveKeys')(1, 'QB 123')
    fire('qb-vehiclekeys:server:setVehLockState', 1, 7, 2)
    harness.assertTrue(lockedState())
    fire('qb-vehiclekeys:server:setVehLockState', 1, 7, 1)
    harness.assertFalse(lockedState())
    fire('qb-vehiclekeys:server:setVehLockState', 1, 999, 2)
    fire('qb-vehiclekeys:server:setVehLockState', 1, 7, 'x')
    harness.assertFalse(lockedState())
    fire('qb-vehiclekeys:server:setVehLockState', 2, 7, 2)
    harness.assertFalse(lockedState(), 'other player has no key')
end)

harness.test('GiveVehicleKeys requires the giver to hold the key and a nearby receiver', function()
    export('RemoveKeys')(1, 'QB 123')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, 2, 'QB 123')
    harness.assertFalse(export('HasKeys')(2, 'QB 123'), 'giver has no key')
    export('GiveKeys')(1, 'QB 123')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, 3, 'QB 123')
    harness.assertFalse(export('HasKeys')(3, 'QB 123'), 'receiver too far')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, 99, 'QB 123')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, 1, 'QB 123')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, 2, 'QB 123')
    harness.assertTrue(export('HasKeys')(2, 'QB 123'))
    harness.assertFalse(export('HasKeys')(3, 'QB 123'))
end)

harness.test('events are throttled and RemoveOwnKeys only affects the caller', function()
    export('GiveKeys')(2, 'AA 1')
    _G.source = 3
    legacyEvents['qb-vehiclekeys:server:RemoveOwnKeys']('AA 1')
    harness.assertTrue(export('HasKeys')(2, 'AA 1'))
    now = now + 1000
    _G.source = 2
    legacyEvents['qb-vehiclekeys:server:RemoveOwnKeys']('AA 1')
    harness.assertFalse(export('HasKeys')(2, 'AA 1'))
    export('GiveKeys')(2, 'AA 1')
    legacyEvents['qb-vehiclekeys:server:RemoveOwnKeys']('AA 1')  -- same tick: throttled
    harness.assertTrue(export('HasKeys')(2, 'AA 1'))
end)

harness.report('qbvehiclekeys legacy server')
