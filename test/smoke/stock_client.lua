local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceDir = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

local handlers, commands, exportsProvided, serverEvents, callbacks, notes = {}, {}, {}, {}, {}, {}
local triggered, minigames = {}, 0
local hasKey, now = true, 'auth', 10000
local vecMeta
vecMeta = { __sub = function(a, b) return setmetatable({ d = math.abs(a.d - b.d) }, vecMeta) end, __len = function(a) return a.d end }
local function vec(d) return setmetatable({ d = d }, vecMeta) end
local positions = { [10] = 0, [70] = 1, [21] = 1.0, [22] = 9.0 }
local car, driving, networked, model = 70, false, true, 500
local occupants = { [-1] = 10, [0] = 31, [1] = 32 }

_G.PlayerPedId = function() return 10 end
_G.PlayerId = function() return 1 end
_G.GetVehiclePedIsIn = function() return driving and car or 0 end
_G.GetClosestVehicle = function() return car end
_G.GetPedInVehicleSeat = function(_, seat) return occupants[seat] or 0 end
_G.GetVehicleModelNumberOfSeats = function() return 4 end
_G.IsPedAPlayer = function(ped) return ped ~= 0 end
_G.IsPedSittingInVehicle = function() return driving end
_G.NetworkGetPlayerIndexFromPed = function(ped) return ped end
_G.GetPlayerServerId = function(player) return player + 100 end
_G.GetActivePlayers = function() return { 1, 21, 22 } end
_G.GetPlayerPed = function(player) return player end
_G.GetEntityCoords = function(e) return vec(positions[e] or 0) end
_G.GetEntityModel = function() return model end
_G.GetVehicleNumberPlateText = function() return ' qb 123 ' end
_G.DoesEntityExist = function() return true end
_G.NetworkGetEntityIsNetworked = function() return networked end
_G.NetworkGetNetworkIdFromEntity = function() return 7 end
_G.GetGameTimer = function() return now end
_G.GetIsVehicleEngineRunning = function() return false end
_G.SetVehicleEngineOn = function() end
_G.SetVehicleDoorsLocked = function() end
_G.IsThisModelABike = function() return false end
_G.IsThisModelABicycle = function() return false end
_G.GetVehiclePedIsTryingToEnter = function() return 0 end
_G.IsPedInAnyVehicle = function() return driving end
_G.Entity = function() return { state = {} } end
_G.CreateThread = function(fn) fn() end
_G.SetTimeout = function() end
_G.joaat = function(name) return name == 'sultan' and 500 or 1 end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.RegisterNetEvent = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.TriggerServerEvent = function(name, ...) serverEvents[#serverEvents + 1] = { name, ... } end
_G.Kora = {
    notify = { send = function(o) notes[#notes + 1] = o.message end },
    entities = { requestControl = function() return true end },
    callback = { trigger = function(name, ...)
        callbacks[#callbacks + 1] = { name, ... }
        if name == 'kora_vehiclekeys:server:legacyHasKeys' then return hasKey end
        if name == 'kora_vehiclekeys:server:toggleRequested' then return true end
    end },
    events = { onPush = function() end, trigger = function(name, ...) triggered[#triggered + 1] = { name, ... } end },
    state = { onChange = function() end },
    keybind = { add = function() end },
    cache = { onChange = function() end, enteringVehicle = function() return false end },
    minigames = { play = function() minigames = minigames + 1 return { proof = 'proof' } end },
}
Kora.compat = dofile(resourceDir .. '../kora_lib/compat/provider.lua')()
_G.LockFeedback = { localToggle = function() end, remote = function() end }
dofile(resourceDir .. 'config.lua')
Config.RequireKeyToStart = false
dofile(resourceDir .. 'client/main.lua')
dofile(resourceDir .. 'client/stock.lua')

local function provided(name)
    local fn
    handlers['__cfx_export_qb-vehiclekeys_' .. name](function(f) fn = f end)
    return fn
end

harness.test('togglelocks and engine are registered commands', function()
    harness.assertTrue(type(commands.togglelocks) == 'function' and type(commands.engine) == 'function')
    callbacks = {}
    commands.togglelocks()
    harness.assertEqual(callbacks[1][1], 'kora_vehiclekeys:server:toggleRequested')
end)

harness.test('addNoLockVehicles stops lock toggling client-side only; removeNoLockVehicles restores it', function()
    provided('addNoLockVehicles')('sultan')
    callbacks = {}
    commands.togglelocks()
    harness.assertEqual(#callbacks, 0)
    provided('removeNoLockVehicles')('sultan')
    commands.togglelocks()
    harness.assertEqual(#callbacks, 1)
    provided('addNoLockVehicles')(500); provided('addNoLockVehicles')({}); provided('addNoLockVehicles')(nil)
    callbacks = {}
    commands.togglelocks()
    harness.assertEqual(#callbacks, 0)
    provided('removeNoLockVehicles')(500)
    for _, call in ipairs(serverEvents) do harness.assertTrue(call[1] ~= 'qb-vehiclekeys:server:setVehLockState') end
end)

harness.test('GiveKeys event with an id asks the server with a one-element list', function()
    serverEvents = {}
    handlers['qb-vehiclekeys:client:GiveKeys'](5)
    harness.assertEqual(serverEvents[1][1], 'qb-vehiclekeys:server:GiveVehicleKeys')
    harness.assertEqual(serverEvents[1][2][1], 5)
    harness.assertEqual(serverEvents[1][3], 'QB 123')
end)

harness.test('GiveKeys event without an id uses the closest player on foot', function()
    serverEvents = {}
    handlers['qb-vehiclekeys:client:GiveKeys']()
    harness.assertEqual(serverEvents[1][2][1], 121)
    harness.assertEqual(#serverEvents[1][2], 1)
end)

harness.test('GiveKeys event inside a vehicle sends every other player occupant', function()
    driving = true
    serverEvents = {}
    handlers['qb-vehiclekeys:client:GiveKeys']()
    harness.assertEqual(#serverEvents[1][2], 2)
    harness.assertEqual(serverEvents[1][2][1], 131)
    harness.assertEqual(serverEvents[1][2][2], 132)
    driving = false
end)

harness.test('GiveKeys event refuses without keys or without anybody close', function()
    hasKey = false; serverEvents = {}; notes = {}
    handlers['qb-vehiclekeys:client:GiveKeys'](5)
    harness.assertEqual(#serverEvents, 0)
    harness.assertEqual(#notes, 1)
    hasKey = true
    positions[21] = 5.0
    handlers['qb-vehiclekeys:client:GiveKeys']()
    harness.assertEqual(#serverEvents, 0, 'only players within 1.5 m')
    positions[21] = 1.0
end)

harness.test('VehicleKeys table is exposed to the stock handlers', function()
    harness.assertTrue(VehicleKeys ~= nil and VehicleKeys.toggleLocks ~= nil)
end)

harness.report('kora_vehiclekeys stock parity client')
