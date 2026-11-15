-- Run from anywhere: lua test/smoke/00_logging.lua
-- A BikeGuard.check failure must reach Kora.logging.error (event + error in fields), never print.
-- Named 00_ so it runs first under test/run.sh.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local repoRoot = scriptDir .. '../../'
local calls = {}
local env = setmetatable({}, { __index = _G })
env._G = env
env.print = function() error('client/main.lua must log through Kora.logging, not print') end
env.Config = { Text = {}, RateLimits = {}, AccessCacheMs = 0, Hotwire = {} }
env.AddEventHandler = function() end
env.RegisterNetEvent = function() end
env.RegisterCommand = function() end
env.exports = setmetatable({}, { __call = function() end })
env.GetGameTimer = function() return 0 end
env.PlayerPedId = function() return 1 end
env.GetEntityModel = function() return 1 end
env.IsThisModelABike = function() return true end
env.IsThisModelABicycle = function() return false end
env.GetVehiclePedIsTryingToEnter = function() return 0 end
env.Wait = function() error('stop-loop') end
-- Run the guard thread inline; the loop's Wait aborts it after the first iteration.
env.CreateThread = function(fn) pcall(fn) end
env.Kora = {
    cache = { onChange = function() end, enteringVehicle = function() return 5 end },
    logging = { error = function(event, message, fields)
        calls[#calls + 1] = { level = 'error', event = event, message = message, fields = fields }
        return true
    end },
}
env.IsPedInAnyVehicle = function() error('guard boom') end
env.Kora.events = { onPush = function() end, trigger = function() end }
-- The guard runs during load; later top-level code needs host stubs we do not provide, so tolerate that.
pcall(assert(loadfile(repoRoot .. 'client/main.lua', 't', env)))
local call = assert(calls[1], 'a logger call was made')
assert(call.level == 'error' and call.event == 'bikeguard.check_failed', 'stable error event name')
assert(tostring(call.fields.error):find('guard boom', 1, true), 'logger fields carry the error')
print('kora_vehiclekeys: BikeGuard failure is logged through Kora.logging')
