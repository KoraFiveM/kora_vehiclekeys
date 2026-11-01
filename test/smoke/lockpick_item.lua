-- Using lockpick / advancedlockpick registers a usable that starts the
-- lockpick flow on the client; the server still validates and breaks the pick.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local usables, pushes, callbacks, events, removed, notices = {}, {}, {}, {}, {}, {}
local held = { advancedlockpick = { slot = 4, name = 'advancedlockpick' } }

_G.Kora = {
    callback = { register = function(name, handler) callbacks[name] = handler end },
    events = {
        register = function(name, handler) events[name] = handler end,
        push = function(target, name) pushes[#pushes + 1] = { target = target, name = name } end,
    },
    notify = { send = function(_, o) notices[#notices + 1] = o end },
    minigames = {
        authorizeProof = function() return 'auth' end,
        consumeProof = function() return false end,
    },
    world = { resolveNetworkEntity = function() return 70 end },
    vehicle = { normalizePlate = function(v) return v end },
}
_G.exports = setmetatable({
    kora_core = {
        getItemsByName = function() return {} end,
        getItemByName = function(_, _, name) return held[name] end,
        removeItem = function(_, _, name, amount, slot) removed[#removed + 1] = { name = name, slot = slot } return true end,
        createUseable = function(_, name, fn) usables[name] = fn end,
        getPlayerData = function() return {} end,
    },
}, { __call = function() end })
_G.GetVehicleNumberPlateText = function() return 'ABC 123' end
_G.GetEntityModel = function() return 1 end
_G.joaat = function() return 0 end
_G.Entity = function() return { state = { set = function() end } } end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end
_G.GetGameTimer = function() return 0 end
_G.GetPlayerPed = function() return 10 end
Kora.compat = dofile(resourceDir .. '../kora_lib/compat/provider.lua')()
dofile(resourceDir .. 'config.lua')
math.random = function() return 1 end
dofile(resourceDir .. 'server/main.lua')

harness.test('both default lockpick items are usable and ask the client to start the flow', function()
    harness.assertTrue(usables.lockpick ~= nil)
    harness.assertTrue(usables.advancedlockpick ~= nil)
    usables.advancedlockpick(1, { name = 'advancedlockpick', slot = 4 })
    harness.assertEqual(pushes[#pushes].name, 'qbvehiclekeys:client:lockpickUsed')
    harness.assertEqual(#removed, 0)
end)

harness.test('the held advanced lockpick starts the minigame and is the one that breaks', function()
    harness.assertEqual(callbacks['qbvehiclekeys:server:hotwireStarted'](1, 7), 'auth')
    events['qbvehiclekeys:server:hotwireFinished'](1, 'auth', 'bad')
    harness.assertEqual(removed[1].name, 'advancedlockpick')
    harness.assertEqual(removed[1].slot, 4)
end)

harness.test('registerUsable = false leaves the items to other resources', function()
    usables = {}
    Config.Lockpick.registerUsable = false
    dofile(resourceDir .. 'server/main.lua')
    harness.assertEqual(next(usables), nil)
end)

harness.report('vehiclekeys lockpick usable')
