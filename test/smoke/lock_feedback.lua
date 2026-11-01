local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local log, pushHandlers, keybinds = {}, {}, {}
local hidden, shown, timeouts = {}, 0, {}
local toggleResult, toggleErr = true, nil
local inVehicle, vehicle, myServerId = false, 70, 5
local distance = 3.0

local function vec(d) return setmetatable({ d = d }, { __len = function(a) return a.d end, __sub = function(a, b) return vec(math.abs(a.d - b.d)) end }) end
local function rec(name) return function(...) log[#log + 1] = { name, ... } end end
local function count(name) local n = 0 for _, e in ipairs(log) do if e[1] == name then n = n + 1 end end return n end
local function reset() log = {} end

_G.PlaySoundFrontend = rec('frontend')
_G.PlaySoundFromEntity = rec('entitysound')
_G.SetVehicleLights = rec('lights')
_G.SetVehicleIndicatorLights = rec('indicators')
_G.TaskPlayAnim = rec('anim')
_G.RequestAnimDict = function() end
_G.RemoveAnimDict = function() end
_G.HasAnimDictLoaded = function() return true end
_G.IsPedInAnyVehicle = function() return inVehicle end
_G.IsEntityDead = function() return false end
_G.PlayerPedId = function() return 10 end
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return myServerId end
_G.GetVehiclePedIsIn = function() return inVehicle and vehicle or 0 end
_G.GetClosestVehicle = function() return vehicle end
_G.GetEntityCoords = function(e) return e == 10 and vec(0) or vec(distance) end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return true end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.NetworkGetEntityFromNetworkId = function() return vehicle end
_G.SetVehicleDoorsLocked = function() end
_G.GetEntityModel = function() return 1 end
_G.IsThisModelABike = function() return false end
_G.IsThisModelABicycle = function() return false end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.ClearPedTasks = function() end
_G.Entity = function() return { state = {} } end
_G.GetGameTimer = function() return 0 end
_G.Wait = function() end
_G.CreateThread = function(fn) fn() end
_G.SetTimeout = function(_, fn) timeouts[#timeouts + 1] = fn end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end

local notifications = {}
_G.Kora = {
    notify = { send = function(o) notifications[#notifications + 1] = o end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function() return toggleResult, toggleErr end },
    events = { onPush = function(name, fn) pushHandlers[name] = fn end, trigger = function() end },
    state = { onChange = function() end },
    keybind = { add = function(o) keybinds[#keybinds + 1] = o end },
    cache = { onChange = function() end },
    minigames = {},
    textui = {
        show = function(text, opts) shown = shown + 1; log[#log + 1] = { 'textui', text, opts.position }; return shown end,
        hide = function(id) hidden[#hidden + 1] = id end,
    },
}

dofile(resourceDir .. 'config.lua')
dofile(resourceDir .. 'client/feedback.lua')
dofile(resourceDir .. 'client/main.lua')
local function press() for _, k in ipairs(keybinds) do if k.name == Config.Keybind.name then k.onPressed() end end end
local function allOff()
    Config.lockFeedback = { sound = false, soundNearby = false, soundRange = 10.0, lights = false, animation = false, notify = false, textUI = false }
end

harness.test('defaults: sound, lights, notify on; nearby sound and textUI off', function()
    local c = Config.lockFeedback
    harness.assertTrue(c.sound); harness.assertTrue(c.lights); harness.assertTrue(c.notify)
    harness.assertFalse(c.soundNearby); harness.assertFalse(c.textUI)
end)

harness.test('sound toggle', function()
    allOff(); reset(); press()
    harness.assertEqual(count('frontend'), 0)
    Config.lockFeedback.sound = true; reset(); press()
    harness.assertEqual(count('frontend'), 1)
    harness.assertEqual(log[1][3], 'Remote_Control_Close')
    toggleResult = false; reset(); press()
    harness.assertEqual(log[1][3], 'Remote_Control_Open')
    toggleResult = true
end)

harness.test('animation toggle, skipped while in the vehicle', function()
    allOff(); reset(); press(); harness.assertEqual(count('anim'), 0)
    Config.lockFeedback.animation = true; reset(); press(); harness.assertEqual(count('anim'), 1)
    inVehicle = true; reset(); press(); harness.assertEqual(count('anim'), 0)
    inVehicle = false
end)

harness.test('notify toggle', function()
    allOff(); notifications = {}; press(); harness.assertEqual(#notifications, 0)
    Config.lockFeedback.notify = true; press()
    harness.assertEqual(#notifications, 1); harness.assertEqual(notifications[1].message, 'Vehicle locked.')
end)

harness.test('textUI toggle shows bottom-centre status then hides', function()
    allOff(); reset(); press(); harness.assertEqual(count('textui'), 0)
    Config.lockFeedback.textUI = true; reset(); press()
    harness.assertEqual(count('textui'), 1); harness.assertEqual(log[1][2], 'Locked'); harness.assertEqual(log[1][3], 'bottom-center')
    hidden = {}; timeouts[#timeouts]()
    harness.assertEqual(#hidden, 1)
end)

harness.test('lights toggle via broadcast, works for any vehicle type', function()
    allOff(); reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, 9)
    harness.assertEqual(count('lights'), 0)
    Config.lockFeedback.lights = true; reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, 9)
    harness.assertTrue(count('indicators') > 0 and count('lights') > 0)
    distance = 500.0; reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, 9)
    harness.assertEqual(count('lights'), 0, 'too far to see')
    distance = 3.0
end)

harness.test('soundNearby plays for others in range only', function()
    allOff(); Config.lockFeedback.soundNearby = true
    reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, 9)
    harness.assertEqual(count('entitysound'), 1)
    reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, myServerId)
    harness.assertEqual(count('entitysound'), 0, 'source uses its own local sound')
    distance = 30.0; reset(); pushHandlers['qbvehiclekeys:client:lockFeedback'](7, true, 9)
    harness.assertEqual(count('entitysound'), 0, 'outside soundRange')
    distance = 3.0
end)

harness.test('failed lock action gives no feedback', function()
    Config.lockFeedback = { sound = true, soundNearby = true, lights = true, animation = true, notify = false, textUI = true, soundRange = 10.0 }
    toggleResult, toggleErr = nil, 'You do not have the keys for this vehicle.'
    reset(); notifications = {}; press()
    harness.assertEqual(#log, 0, 'no sound/anim/lights/textUI')
    harness.assertEqual(notifications[1].type, 'error')
    toggleResult, toggleErr = true, nil
end)

harness.report('qbvehiclekeys lock feedback')
