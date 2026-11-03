-- The ignition monitor confirms access once and stops; key and job changes
-- re-run it, and drivers without access keep having the engine held off.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local handlers, pushes, engineOff, accessCalls = {}, {}, 0, 0
local driving, allowed, now = true, true, 10000
local car = 70

_G.PlayerPedId = function() return 10 end
_G.GetVehiclePedIsIn = function() return driving and car or 0 end
_G.GetPedInVehicleSeat = function() return 10 end
_G.GetIsVehicleEngineRunning = function() return false end
_G.IsPedInAnyVehicle = function() return true end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.SetVehicleEngineOn = function(_, on) if not on then engineOff = engineOff + 1 end end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return true end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.GetGameTimer = function() return now end
local threads = {}
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; coroutine.resume(co) end
_G.Wait = function() coroutine.yield() end
local function alive()
    local n = 0
    for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then n = n + 1 end end
    return n
end
local function step(times)
    for _ = 1, times or 1 do
        now = now + 2000 -- also expires the access cache
        for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end
    end
end
_G.SetTimeout = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function() end
_G.Kora = {
    notify = { send = function() end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function(name)
        if name == 'qbvehiclekeys:server:accessRequested' then accessCalls = accessCalls + 1 end
        return allowed
    end },
    events = { onPush = function(name, fn) pushes[name] = fn end, trigger = function() end },
    state = { onChange = function() end },
    keybind = { add = function() end },
    cache = { onChange = function() end, enteringVehicle = function() return false end },
    minigames = {},
}
_G.LockFeedback = { localToggle = function() end, remote = function() end }
dofile(resourceDir .. 'config.lua')
Config.RequireKeyToStart = true
dofile(resourceDir .. 'client/main.lua')

harness.test('a key holder is checked once, then the monitor stops', function()
    harness.assertEqual(Config.IgnitionRecheckMs, 0)
    step(10)
    harness.assertEqual(accessCalls, 1, 'one server check for the whole drive')
    harness.assertEqual(alive(), 0, 'no loop left running')
    harness.assertEqual(engineOff, 0)
end)

harness.test('losing the key re-checks and holds the engine off', function()
    allowed = false; accessCalls = 0
    pushes['qbvehiclekeys:client:keysChanged']('QB 123', false)
    harness.assertEqual(engineOff, 1)
    step(3)
    harness.assertTrue(engineOff >= 3, 'engine kept off while there is no access')
    harness.assertEqual(alive(), 1)
    allowed = true
    pushes['qbvehiclekeys:client:keysChanged']('QB 123', true)
    step(2)
    harness.assertEqual(alive(), 0, 'stops again once access returns')
end)

harness.test('a job update re-runs the check', function()
    allowed = false; engineOff = 0
    handlers['QBCore:Client:OnJobUpdate']({ name = 'unemployed' })
    harness.assertEqual(engineOff, 1)
    driving = false; step(2)
    harness.assertEqual(alive(), 0, 'leaving the driver seat ends the monitor')
    driving, allowed = true, true
end)

harness.test('IgnitionRecheckMs keeps a slow recheck when set', function()
    Config.IgnitionRecheckMs = 5000; accessCalls = 0
    pushes['qbvehiclekeys:client:keysChanged']('QB 123', true)
    step(3)
    harness.assertEqual(accessCalls, 4)
    harness.assertEqual(alive(), 1)
    Config.IgnitionRecheckMs = 0; step(1)
    harness.assertEqual(alive(), 0)
end)

harness.report('qbvehiclekeys ignition monitor')
