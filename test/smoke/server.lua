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

local vectorMeta = {
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
_G.GetGameTimer = function() return 0 end
Kora.compat = dofile(resourceDir .. '../kora_lib/compat/provider.lua')()

dofile(resourceDir .. 'config.lua')
Config.PhysicalKey.enabled = true
Config.PhysicalKey.metadata = { plate = '{plate}', keyType = 'standard' }
Config.AllowTemporaryKeys = false
Config.JobVehicles = { police = { 'police' } }
dofile(resourceDir .. 'server/main.lua')

harness.test('physical keys match normalised plate metadata before toggling', function()
    local locked = callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertTrue(locked)
    harness.assertTrue(states[vehicle]['qbvehiclekeys:locked'])
    for _, push in ipairs(pushes) do
        harness.assertTrue(push.name ~= 'qbvehiclekeys:client:lockStateChanged', 'the lock replicates through the state bag only')
    end
end)

harness.test('wrong physical metadata cannot unlock a vehicle', function()
    inventory[1].info.keyType = 'valet'
    local locked, reason = callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertEqual(locked, nil)
    harness.assertEqual(reason, 'You do not have the keys for this vehicle.')
    inventory[1].info.keyType = 'standard'
end)

harness.test('configured jobs can use configured vehicle models without keys', function()
    inventory = {}
    playerJob = { name = 'police' }
    vehicleModel = 200

    harness.assertTrue(callbacks['qbvehiclekeys:server:accessRequested'](1, 7))
    local locked = callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertEqual(locked, false)

    playerJob = { name = 'unemployed' }
    harness.assertFalse(callbacks['qbvehiclekeys:server:accessRequested'](1, 7))
end)

harness.test('a validated hotwire proof grants ignition access even in item-only mode', function()
    inventory = {}
    vehicleModel = 100
    local authorization = callbacks['qbvehiclekeys:server:hotwireStarted'](1, 7)
    harness.assertEqual(authorization, 'authorisation')
    events['qbvehiclekeys:server:hotwireFinished'](1, authorization, 'proof')
    harness.assertTrue(callbacks['qbvehiclekeys:server:accessRequested'](1, 7))
end)

harness.test('legacy HasKeys reads actual server keys and rejects invalid subjects', function()
    local legacy
    legacyEvents['__cfx_export_qb-vehiclekeys_HasKeys'](function(fn) legacy = fn end)
    harness.assertTrue(legacy(1, ' qb  123 '), 'validated hotwire key still applies')
    harness.assertFalse(legacy(2, 'QB 123'), 'cannot borrow another players temporary key')
    harness.assertFalse(legacy(nil, 'QB 123'))
    harness.assertFalse(legacy(1, {}))
    harness.assertTrue(callbacks['qbvehiclekeys:server:legacyHasKeys'](1, 'QB 123'))
    harness.assertFalse(callbacks['qbvehiclekeys:server:legacyHasKeys'](2, 'QB 123'))
end)

harness.test('lock feedback broadcast follows lights/soundNearby and skips failed toggles', function()
    local function feedbackPushes()
        local n = 0
        for _, push in ipairs(pushes) do if push.name == 'qbvehiclekeys:client:lockFeedback' then n = n + 1 end end
        return n
    end
    Config.lockFeedback = { lights = true, soundNearby = false }
    local before = feedbackPushes()
    local locked = callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertEqual(feedbackPushes(), before + 1)
    local push = pushes[#pushes]
    harness.assertEqual(push.values[1], 7)
    harness.assertEqual(push.values[2], locked)
    harness.assertEqual(push.values[3], 1)

    Config.lockFeedback = { lights = false, soundNearby = true }
    callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertEqual(feedbackPushes(), before + 2)

    Config.lockFeedback = { lights = false, soundNearby = false }
    callbacks['qbvehiclekeys:server:toggleRequested'](1, 7)
    harness.assertEqual(feedbackPushes(), before + 2, 'no broadcast when both disabled')

    Config.lockFeedback = { lights = true, soundNearby = true }
    local failed = callbacks['qbvehiclekeys:server:toggleRequested'](2, 7)
    harness.assertEqual(failed, nil)
    harness.assertEqual(feedbackPushes(), before + 2, 'no broadcast on failed toggle')
end)

harness.report('qbvehiclekeys server')
