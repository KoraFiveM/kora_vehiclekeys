local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local lockedStatus, cleared, notifications = {}, 0, {}
local timeouts, keybinds = {}, {}
local onFoot, enterTarget, isBikeModel, stateLocked, hasAccess, now = true, 0, true, true, false, 10000
local bike = 70

_G.PlayerPedId = function() return 10 end
_G.IsPedInAnyVehicle = function() return not onFoot end
_G.GetVehiclePedIsIn = function() return 0 end
_G.GetVehiclePedIsTryingToEnter = function() return enterTarget end
_G.ClearPedTasks = function() cleared = cleared + 1 end
_G.GetEntityModel = function() return 1 end
_G.IsThisModelABike = function() return isBikeModel end
_G.IsThisModelABicycle = function() return false end
_G.Entity = function() return { state = { ['qbvehiclekeys:locked'] = stateLocked } } end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return true end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.NetworkGetEntityFromNetworkId = function() return bike end
_G.SetVehicleDoorsLocked = function(_, status) lockedStatus[#lockedStatus + 1] = status end
_G.GetGameTimer = function() return now end
_G.Wait = function() end
_G.CreateThread = function() end
_G.SetTimeout = function(_, fn) timeouts[#timeouts + 1] = fn end
_G.AddEventHandler = function() end

local push = {}
_G.Kora = {
    notify = { send = function(o) notifications[#notifications + 1] = o end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function() return hasAccess end },
    events = { onPush = function(name, fn) push[name] = fn end, trigger = function() end },
    state = { onChange = function() end },
    keybind = { add = function(o) keybinds[#keybinds + 1] = o end },
    cache = { onChange = function() end },
    minigames = {},
}
_G.LockFeedback = { localToggle = function() end, remote = function() end }

dofile(resourceDir .. 'config.lua')
dofile(resourceDir .. 'client/main.lua')

local function reset()
    lockedStatus, cleared, notifications = {}, 0, {}
    onFoot, enterTarget, isBikeModel, stateLocked, hasAccess = true, bike, true, true, false
    Config.allowPickupLockedBikes = false
    now = now + 10000 -- also expires the access cache and notice throttle
end

harness.test('default keeps locked bikes blocked (option is false)', function()
    harness.assertFalse(Config.allowPickupLockedBikes)
end)

harness.test('a locked bike never gets the native locked-door status', function()
    reset()
    push['qbvehiclekeys:client:lockStateChanged'](7, true)
    harness.assertEqual(lockedStatus[1], 1, 'bike stays status 1')
    isBikeModel = false
    push['qbvehiclekeys:client:lockStateChanged'](7, true)
    harness.assertEqual(lockedStatus[2], 2, 'cars are still locked')
    push['qbvehiclekeys:client:lockStateChanged'](7, false)
    harness.assertEqual(lockedStatus[3], 1, 'cars unlock')
end)

harness.test('key holder can lift a locked fallen bike', function()
    reset(); hasAccess = true
    BikeGuard.check()
    harness.assertEqual(cleared, 0, 'enter task not cancelled')
    harness.assertEqual(#notifications, 0)
end)

harness.test('unlocked bike is always liftable', function()
    reset(); stateLocked = false
    BikeGuard.check()
    harness.assertEqual(cleared, 0)
end)

harness.test('no key + locked: blocked with a visible notice, throttled', function()
    reset()
    BikeGuard.check()
    harness.assertEqual(cleared, 1, 'enter task cancelled')
    harness.assertEqual(notifications[1].message, 'This bike is locked.')
    harness.assertEqual(notifications[1].type, 'error')
    BikeGuard.check()
    harness.assertEqual(cleared, 2, 'still blocked')
    harness.assertEqual(#notifications, 1, 'notice throttled')
end)

harness.test('allowPickupLockedBikes = true lets anyone lift it', function()
    reset(); Config.allowPickupLockedBikes = true
    BikeGuard.check()
    harness.assertEqual(cleared, 0)
end)

harness.test('cars and idle players are untouched by the guard', function()
    reset(); isBikeModel = false
    BikeGuard.check()
    harness.assertEqual(cleared, 0, 'not a bike')
    reset(); enterTarget = 0
    BikeGuard.check()
    harness.assertEqual(cleared, 0, 'not entering anything')
    reset(); onFoot = false
    BikeGuard.check()
    harness.assertEqual(cleared, 0, 'already in a vehicle')
end)

harness.report('qbvehiclekeys bike pickup')
