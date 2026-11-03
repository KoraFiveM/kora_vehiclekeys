-- Client half: the lockpick use event on foot with no vehicle explains itself
-- instead of erroring, and near a locked vehicle starts the lockpick flow.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local pushHandlers, netHandlers, notifications, triggers = {}, {}, {}, {}
local nearby, hasKeys = 0, false
local ped = 10

_G.PlayerPedId = function() return ped end
local inCar = false
_G.GetVehiclePedIsIn = function() return inCar and nearby or 0 end
_G.GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end
_G.GetClosestVehicle = function() return nearby end
_G.GetPedInVehicleSeat = function() return ped end
_G.GetIsVehicleEngineRunning = function() return false end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return true end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
local clock = 0
_G.GetGameTimer = function() clock = clock + 5000 return clock end
_G.CreateThread = function(fn) fn() end
_G.SetTimeout = function() end
_G.AddEventHandler = function(name, fn) netHandlers[name] = fn end
_G.RegisterNetEvent = function() end
_G.IsPedInAnyVehicle = function() return false end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.GetEntityModel = function() return 1 end
_G.IsThisModelABike = function() return false end
_G.IsThisModelABicycle = function() return false end
_G.Entity = function() return { state = {} } end

_G.Kora = {
    notify = { send = function(o) notifications[#notifications + 1] = o end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function(name)
        triggers[#triggers + 1] = name
        if name == 'qbvehiclekeys:server:accessRequested' then return hasKeys end
        if name == 'qbvehiclekeys:server:hotwireStarted' or name == 'qbvehiclekeys:server:lockpickStarted' then return 'auth' end
    end },
    events = { onPush = function(name, fn) pushHandlers[name] = fn end, trigger = function(name) triggers[#triggers + 1] = name end },
    state = { onChange = function() end },
    keybind = { add = function() end },
    cache = { onChange = function() end, enteringVehicle = function() return false end },
    minigames = { play = function() return { proof = 'p' } end },
    textui = { show = function() return 1 end, hide = function() end },
}

dofile(resourceDir .. 'config.lua')
Config.RequireKeyToStart = false
dofile(resourceDir .. 'client/feedback.lua')
dofile(resourceDir .. 'client/main.lua')

harness.test('no vehicle in reach: friendly notice, no server call', function()
    nearby, notifications, triggers = 0, {}, {}
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(#notifications, 1)
    harness.assertEqual(notifications[1].message, Config.Text.lockpickNoVehicle)
    harness.assertEqual(#triggers, 0)
end)

harness.test('on foot next to a vehicle starts the door pick, not hotwiring', function()
    nearby, notifications, triggers, inCar = 70, {}, {}, false
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(triggers[#triggers - 1], 'qbvehiclekeys:server:lockpickStarted')
    harness.assertEqual(triggers[#triggers], 'qbvehiclekeys:server:hotwireFinished')
end)

harness.test('driver seat without keys starts the hotwire flow', function()
    nearby, notifications, triggers, inCar = 70, {}, {}, true
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(triggers[#triggers - 1], 'qbvehiclekeys:server:hotwireStarted')
    harness.assertEqual(triggers[#triggers], 'qbvehiclekeys:server:hotwireFinished')
end)

harness.test('key holders are told no lockpick is needed', function()
    nearby, hasKeys, notifications, triggers = 70, true, {}, {}
    Kora.callback.trigger = function(name) triggers[#triggers + 1] = name return true end
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(notifications[1].message, Config.Text.lockpickNotNeeded)
end)

harness.test('stock lockpicks:UseLockpick event is handled', function()
    harness.assertTrue(netHandlers['lockpicks:UseLockpick'] ~= nil)
end)

harness.test('a raised callback or minigame error never leaves the lockpick busy', function()
    nearby, hasKeys, notifications, triggers, inCar = 70, false, {}, {}, false
    local realTrigger, realPlay = Kora.callback.trigger, Kora.minigames.play
    Kora.callback.trigger = function(name)
        triggers[#triggers + 1] = name
        if name == 'qbvehiclekeys:server:lockpickStarted' then error('rate limited') end
    end
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(notifications[#notifications].message, Config.Text.hotwireFailed)
    Kora.callback.trigger = function(name) triggers[#triggers + 1] = name return 'auth' end
    Kora.minigames.play = function() error('minigame failed') end
    triggers = {}
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(triggers[#triggers], 'qbvehiclekeys:server:hotwireFinished', 'a failed minigame still closes the session')
    Kora.minigames.play = realPlay
    triggers = {}
    pushHandlers['qbvehiclekeys:client:lockpickUsed']()
    harness.assertEqual(triggers[1], 'qbvehiclekeys:server:lockpickStarted', 'still usable afterwards')
    Kora.callback.trigger = realTrigger
end)

harness.report('vehiclekeys lockpick item client')
