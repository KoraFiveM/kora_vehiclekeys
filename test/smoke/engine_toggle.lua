local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local handlers, keybinds, engineCalls = {}, {}, {}
local driving, driver, allowed, running, now = true, true, true, false, 10000
local car = 70

_G.PlayerPedId = function() return 10 end
_G.GetVehiclePedIsIn = function() return driving and car or 0 end
_G.GetPedInVehicleSeat = function() return driver and 10 or 0 end
_G.GetIsVehicleEngineRunning = function() return running end
_G.IsPedInAnyVehicle = function() return true end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.SetVehicleEngineOn = function(_, on) engineCalls[#engineCalls + 1] = on end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return true end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.GetGameTimer = function() return now end
_G.Wait = function() end
_G.CreateThread = function(fn) fn() end
_G.SetTimeout = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function() end
_G.Kora = {
    notify = { send = function() end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function() return allowed end },
    events = { onPush = function() end, trigger = function() end },
    state = { onChange = function() end },
    keybind = { add = function(o) keybinds[o.name] = o end },
    cache = { onChange = function() end, enteringVehicle = function() return false end },
    minigames = {},
}
_G.LockFeedback = { localToggle = function() end, remote = function() end }
dofile(resourceDir .. 'config.lua')
Config.RequireKeyToStart = false -- the ignition monitor loops forever under the synchronous CreateThread stub
dofile(resourceDir .. 'client/main.lua')

local function press()
    engineCalls = {}
    now = now + 10000 -- expire the access cache
    handlers['qb-vehiclekeys:client:ToggleEngine']()
end

harness.test('engine keybind uses the stock G default and shares the event handler', function()
    harness.assertEqual(keybinds['vehiclekeys:toggle-engine'].defaultKey, 'G')
    harness.assertTrue(keybinds['vehiclekeys:toggle-engine'].onPressed ~= nil)
end)

harness.test('driver with server-confirmed access toggles the engine', function()
    press()
    harness.assertEqual(engineCalls[1], true)
    running = true; press()
    harness.assertEqual(engineCalls[1], false)
    running = false
end)

harness.test('no keys, passenger or on foot: nothing happens', function()
    allowed = false; press(); harness.assertEqual(#engineCalls, 0)
    allowed, driver = true, false; press(); harness.assertEqual(#engineCalls, 0)
    driver, driving = true, false; press(); harness.assertEqual(#engineCalls, 0)
    driving = true
end)

harness.report('kora_vehiclekeys engine toggle')
