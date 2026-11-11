local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local callbacks, events, pushes, states = {}, {}, {}, {}
local commands, useables, logged, clientEvents, notified = {}, {}, {}, {}, {}
local inventory = {
    { slot = 3, name = 'vehiclekey', info = { plate = 'qb 123', keyType = 'standard' } },
}
local playerPed, vehicle = 10, 70
local heldPick = 'lockpick'
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
    commands = { add = function(name, help, args, required, handler, opts) commands[name] = { help = help, args = args, required = required, handler = handler, opts = opts or {} } end },
    logging = { event = function(category, src, data) logged[#logged + 1] = { category, src, data } end },
    events = {
        register = function(name, handler) events[name] = handler end,
        push = function(target, name, ...) pushes[#pushes + 1] = { target = target, name = name, values = { ... } } end,
    },
    notify = { send = function(target, o) notified[#notified + 1] = { target, o.message } end },
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
            if options.maxDistance and #(GetEntityCoords(ped) - GetEntityCoords(entity)) > options.maxDistance then
                return nil, 'too_far'
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
        getItemByName = function(_, _, name) if heldPick == name then return { slot = 8, name = name } end end,
        hasPermission = function(_, src, perm) return perm == 'admin' and src == 1 end,
        getByPlate = function(_, plate) return plate == 'OWNED 1' and { plate = plate } or nil end,
        removeItem = function() return true end,
        createUseable = function(_, name, fn) useables[name] = fn end,
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
local seatPed = playerPed
_G.GetPedInVehicleSeat = function() return seatPed end
_G.GetVehicleNumberPlateText = function() return ' QB  123 ' end
_G.GetEntityModel = function() return vehicleModel end
_G.joaat = function(model) return model == 'police' and 200 or 0 end
_G.Entity = function(entity)
    states[entity] = states[entity] or {}
    return { state = setmetatable(states[entity], { __index = { set = function(self, key, value) self[key] = value end } }) }
end
local legacyEvents = {}
_G.AddEventHandler = function(name, fn) legacyEvents[name] = fn end
_G.TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { name, target, ... } end
_G.GetVehicleDoorLockStatus = function() return 1 end
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


local function runCommand(name, src, ...)
    local def = commands[name]
    local args = { ... }
    if def.opts.permission and def.opts.permission ~= 'user' and not def.opts.checkPermission(src, def.opts.permission) then
        return false
    end
    def.handler(src, args, '')
    return true
end

harness.test('commands use stock names, help, args and permission levels', function()
    harness.assertEqual(commands.givekeys.opts.permission, nil)
    harness.assertEqual(commands.givekeys.required, false)
    harness.assertEqual(commands.addkeys.opts.permission, 'admin')
    harness.assertEqual(commands.removekeys.opts.permission, 'admin')
    harness.assertTrue(commands.addkeys.required)
    harness.assertEqual(commands.addkeys.args[1].name, 'id')
    harness.assertEqual(commands.addkeys.args[2].name, 'plate')
    harness.assertEqual(commands.removekeys.help, 'Remove keys to a vehicle for someone.')
end)

harness.test('addkeys / removekeys are admin only, validated and audit logged', function()
    harness.assertFalse(runCommand('addkeys', 2, '1', 'QB 123'))
    harness.assertFalse(export('HasKeys')(1, 'QB 123'))
    runCommand('addkeys', 1, '2', 'ZZ 9')
    harness.assertTrue(export('HasKeys')(2, 'ZZ 9'))
    harness.assertEqual(logged[#logged][1], 'vehiclekeys:addkeys')
    harness.assertEqual(logged[#logged][3].plate, 'ZZ 9')
    local count = #logged
    runCommand('addkeys', 1, '99', 'ZZ 9')
    runCommand('addkeys', 1, 'x', 'ZZ 9')
    runCommand('addkeys', 1, '2', '')
    harness.assertEqual(#logged, count)
    harness.assertFalse(runCommand('removekeys', 2, '2', 'ZZ 9'))
    harness.assertTrue(export('HasKeys')(2, 'ZZ 9'))
    runCommand('removekeys', 1, '2', 'ZZ 9')
    harness.assertFalse(export('HasKeys')(2, 'ZZ 9'))
    harness.assertEqual(logged[#logged][1], 'vehiclekeys:removekeys')
    Config.AllowTemporaryKeys = false
    count = #logged
    runCommand('addkeys', 1, '2', 'ZZ 9')
    harness.assertEqual(#logged, count)
    Config.AllowTemporaryKeys = true
end)

harness.test('givekeys forwards the id to the stock client event', function()
    clientEvents = {}
    runCommand('givekeys', 1, '2')
    harness.assertEqual(clientEvents[1][1], 'qb-vehiclekeys:client:GiveKeys')
    harness.assertEqual(clientEvents[1][2], 1)
    harness.assertEqual(clientEvents[1][3], 2)
    runCommand('givekeys', 1)
    harness.assertEqual(clientEvents[2][3], nil)
    runCommand('givekeys', 0)
    harness.assertEqual(#clientEvents, 2, 'console has no client')
end)

harness.test('GiveVehicleKeys accepts a receiver list, skips far or duplicate receivers', function()
    export('GiveKeys')(1, 'QB 123')
    notified = {}
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 1, { 2, 2, 3, 99, 1 }, 'QB 123')
    harness.assertTrue(export('HasKeys')(2, 'QB 123'))
    harness.assertFalse(export('HasKeys')(3, 'QB 123'))
    harness.assertEqual(#notified, 2, 'one notice per side')
    export('RemoveKeys')(2, 'QB 123'); export('RemoveKeys')(1, 'QB 123')
    fire('qb-vehiclekeys:server:GiveVehicleKeys', 2, { 1 }, 'QB 123')
    harness.assertFalse(export('HasKeys')(1, 'QB 123'), 'a giver without the key gives nothing')
end)

harness.test('RemoveVehicleKeys only drops the caller\'s own key', function()
    export('GiveKeys')(1, 'RM 1'); export('GiveKeys')(2, 'RM 1')
    fire('qb-vehiclekeys:server:RemoveVehicleKeys', 3, 'RM 1')
    harness.assertTrue(export('HasKeys')(1, 'RM 1'))
    harness.assertTrue(export('HasKeys')(2, 'RM 1'))
    fire('qb-vehiclekeys:server:RemoveVehicleKeys', 1, 'RM 1')
    harness.assertFalse(export('HasKeys')(1, 'RM 1'))
    harness.assertTrue(export('HasKeys')(2, 'RM 1'), 'other holders are untouched')
    fire('qb-vehiclekeys:server:RemoveVehicleKeys', 1, { 'RM 1' })
    harness.assertTrue(export('HasKeys')(2, 'RM 1'))
    export('RemoveKeys')(2, 'RM 1')
end)

harness.test('GetVehicleKeys returns only the caller\'s keys as { [plate] = true }', function()
    export('GiveKeys')(1, 'K 1'); export('GiveKeys')(2, 'K 2')
    local list = callbacks['qb-vehiclekeys:server:GetVehicleKeys'](1)
    harness.assertTrue(list['K 1'])
    harness.assertEqual(list['K 2'], nil)
    Config.PhysicalKey.enabled = true
    list = callbacks['qb-vehiclekeys:server:GetVehicleKeys'](3)
    harness.assertTrue(list['QB 123'], 'matching key items are included')
    Config.PhysicalKey.enabled = false
    harness.assertEqual(next(callbacks['qb-vehiclekeys:server:GetVehicleKeys'](3)), nil)
    export('RemoveKeys')(1, 'K 1'); export('RemoveKeys')(2, 'K 2')
end)

harness.test('checkPlayerOwned returns a boolean for the plate', function()
    local check = callbacks['qb-vehiclekeys:server:checkPlayerOwned']
    harness.assertTrue(check(1, 'owned 1'))
    harness.assertFalse(check(1, 'FREE 1'))
    export('GiveKeys')(1, 'FREE 1')
    harness.assertTrue(check(1, 'FREE 1'), 'the caller holds the key')
    harness.assertFalse(check(2, 'FREE 1'), 'other players\' keys are not revealed')
    harness.assertFalse(check(1, {}))
    export('RemoveKeys')(1, 'FREE 1')
end)

harness.test('GiveKeys export without a plate uses the vehicle the player is in', function()
    harness.assertTrue(export('GiveKeys')(1))
    harness.assertTrue(export('HasKeys')(1, 'QB 123'))
    export('RemoveKeys')(1, 'QB 123')
    inVehicle = 0
    harness.assertFalse(export('GiveKeys')(1))
    inVehicle = vehicle
end)

harness.test('breakLockpick is accepted but removes nothing', function()
    local removed = 0
    local original = exports.kora_core.removeItem
    exports.kora_core.removeItem = function() removed = removed + 1 return true end
    fire('qb-vehiclekeys:server:breakLockpick', 1, 'lockpick')
    fire('qb-vehiclekeys:server:breakLockpick', 1, 'phone')
    harness.assertEqual(removed, 0)
    exports.kora_core.removeItem = original
end)

harness.test('lockpick items are registered once, by the shared loop, and push the client event', function()
    harness.assertTrue(useables.lockpick ~= nil and useables.advancedlockpick ~= nil)
    harness.assertEqual(Config.LockpickItems, nil)
    pushes = {}
    useables.lockpick(1, {}); useables.advancedlockpick(1, {})
    harness.assertEqual(pushes[1].name, 'kora_vehiclekeys:client:lockpickUsed')
    harness.assertEqual(pushes[2].name, 'kora_vehiclekeys:client:lockpickUsed')
end)

local start = callbacks['kora_vehiclekeys:server:lockpickStarted']
local startHotwire = callbacks['kora_vehiclekeys:server:hotwireStarted']
local finish = events['kora_vehiclekeys:server:hotwireFinished']
harness.test('lockpickStarted validates item, keys, distance and lock state', function()
    seatPed = 0
    states[vehicle] = {}
    harness.assertEqual((start(1, 7)), nil, 'not locked')
    states[vehicle] = { ['kora_vehiclekeys:locked'] = true }
    heldPick = nil
    harness.assertEqual((start(1, 7)), nil, 'no lockpick item')
    heldPick = 'advancedlockpick'
    harness.assertEqual(start(1, 7), 'authorisation', 'any configured pick works')
    heldPick = 'lockpick'
    harness.assertEqual((start(1, 999)), nil, 'unknown vehicle')
    coords[70] = vector(50, 0, 0)
    harness.assertEqual((start(1, 7)), nil, 'too far')
    coords[70] = vector(1, 0, 0)
    export('GiveKeys')(1, 'QB 123')
    harness.assertEqual((start(1, 7)), nil, 'already has keys')
    export('RemoveKeys')(1, 'QB 123')
    harness.assertEqual(start(1, 7), 'authorisation', 'no driver seat needed')
end)

harness.test('a successful lockpick from outside unlocks without granting a key', function()
    seatPed = 0
    states[vehicle] = { ['kora_vehiclekeys:locked'] = true }
    start(1, 7)
    _G.source = 1
    finish(1, 'authorisation', 'proof')
    harness.assertEqual(states[vehicle]['kora_vehiclekeys:locked'], false)
    harness.assertFalse(export('HasKeys')(1, 'QB 123'))
end)

harness.test('hotwire from the driver seat grants a session key; failure changes nothing', function()
    seatPed = playerPed
    states[vehicle] = { ['kora_vehiclekeys:locked'] = true }
    startHotwire(1, 7)
    finish(1, 'authorisation', 'bad')
    harness.assertEqual(states[vehicle]['kora_vehiclekeys:locked'], true)
    harness.assertFalse(export('HasKeys')(1, 'QB 123'))
    startHotwire(1, 7)
    finish(1, 'authorisation', 'proof')
    harness.assertEqual(states[vehicle]['kora_vehiclekeys:locked'], false)
    harness.assertTrue(export('HasKeys')(1, 'QB 123'))
    export('RemoveKeys')(1, 'QB 123')
    startHotwire(1, 7)
    finish(1, 'wrong', 'proof')
    finish(1, 'authorisation', 'proof')
    harness.assertFalse(export('HasKeys')(1, 'QB 123'), 'the session is single use')
end)

harness.test('the broken pick is the session item and slot', function()
    local removedItems = {}
    local original = exports.kora_core.removeItem
    exports.kora_core.removeItem = function(_, _, name, _, slot) removedItems[#removedItems + 1] = { name, slot } return true end
    math.random = function() return 1 end
    seatPed = 0
    states[vehicle] = { ['kora_vehiclekeys:locked'] = true }
    start(1, 7)
    finish(1, 'authorisation', 'bad')
    harness.assertEqual(removedItems[1][1], 'lockpick')
    harness.assertEqual(removedItems[1][2], 8)
    exports.kora_core.removeItem = original
end)

harness.report('kora_vehiclekeys stock parity server')
