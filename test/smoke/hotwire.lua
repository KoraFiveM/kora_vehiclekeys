local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local keybinds, notifications, triggers = {}, {}, {}
local inVehicle, isDriver, engineOn, networked, hasKeys = true, true, false, true, false
local ped, vehicle = 10, 70

_G.PlayerPedId = function() return ped end
_G.GetVehiclePedIsIn = function() return inVehicle and vehicle or 0 end
_G.GetPedInVehicleSeat = function() return isDriver and ped or 0 end
_G.GetIsVehicleEngineRunning = function() return engineOn end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return networked end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.NetworkGetEntityFromNetworkId = function() return vehicle end
local clock = 0
_G.GetGameTimer = function() clock = clock + 5000; return clock end
_G.IsPedInAnyVehicle = function() return inVehicle end
_G.CreateThread = function(fn) fn() end
_G.SetTimeout = function() end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.GetEntityModel = function() return 1 end
_G.IsThisModelABike = function() return false end
_G.IsThisModelABicycle = function() return false end
_G.Entity = function() return { state = {} } end

local api = {
    notify = { send = function(o) notifications[#notifications + 1] = o end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function(name)
        triggers[#triggers + 1] = name
        if name == 'qbvehiclekeys:server:accessRequested' then return hasKeys end
        if name == 'qbvehiclekeys:server:hotwireStarted' then return 'auth' end
    end },
    events = { onPush = function() end, trigger = function(name) triggers[#triggers + 1] = name end },
    state = { onChange = function() end },
    keybind = { add = function(o) keybinds[#keybinds + 1] = o end },
    cache = { onChange = function() end },
    minigames = { play = function() return { proof = 'p' } end },
    textui = { show = function() return 1 end, hide = function() end },
}
_G.Kora, _G.QB = api, api

dofile(resourceDir .. 'config.lua')
Config.RequireKeyToStart = false -- ignition monitor is not under test
dofile(resourceDir .. 'client/feedback.lua')
dofile(resourceDir .. 'client/main.lua')

local function hotwireKey() for _, k in ipairs(keybinds) do if k.name == Config.Hotwire.keybind.name then return k end end end
local function press()
    notifications, triggers = {}, {}
    hotwireKey().onPressed()
end
local function started()
    for _, t in ipairs(triggers) do if t == 'qbvehiclekeys:server:hotwireStarted' then return true end end
    return false
end
local function reset() inVehicle, isDriver, engineOn, networked, hasKeys = true, true, false, true, false end

harness.test('default hotwire key does not collide with the headlight key', function()
    harness.assertTrue(Config.Hotwire.keybind.defaultKey ~= 'H')
    harness.assertFalse(Config.Hotwire.notifyUnavailable)
end)

harness.test('driver with keys pressing the hotwire key: no notify, no hotwire', function()
    reset(); hasKeys = true; press()
    harness.assertEqual(#notifications, 0); harness.assertFalse(started())
end)

harness.test('driver without keys: hotwire starts', function()
    reset(); hasKeys = false; press()
    harness.assertTrue(started()); harness.assertEqual(#notifications, 0)
end)

harness.test('engine already running: nothing happens', function()
    reset(); engineOn = true; press()
    harness.assertEqual(#notifications, 0); harness.assertFalse(started())
end)

harness.test('passenger / on foot / non-networked: silent by default', function()
    reset(); isDriver = false; press(); harness.assertEqual(#notifications, 0); harness.assertFalse(started())
    reset(); inVehicle = false; press(); harness.assertEqual(#notifications, 0)
    reset(); networked = false; press(); harness.assertEqual(#notifications, 0); harness.assertFalse(started())
end)

harness.test('notifyUnavailable restores the error messages', function()
    Config.Hotwire.notifyUnavailable = true
    reset(); isDriver = false; press()
    harness.assertEqual(#notifications, 1); harness.assertEqual(notifications[1].message, 'You must be in the driver seat.')
    harness.assertEqual(notifications[1].title, Config.Text.titleHotwireFailed)
    Config.Hotwire.notifyUnavailable = false
end)

harness.report('qbvehiclekeys hotwire key')
