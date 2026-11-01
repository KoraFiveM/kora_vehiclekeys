local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local handlers, sent = {}, {}
function RegisterNetEvent() end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerServerEvent(name, ...) sent[#sent + 1] = { name, ... } end
local plates = { [70] = ' qb 123 ', [71] = 'FAR 1' }
local positions = { [10] = 0, [70] = 3, [71] = 100 }
local vecMeta
vecMeta = { __sub = function(a, b) return setmetatable({ d = math.abs(a.d - b.d) }, vecMeta) end, __len = function(a) return a.d end }
local function vec(d) return setmetatable({ d = d }, vecMeta) end
local current = 0
function PlayerPedId() return 10 end
function GetVehiclePedIsIn() return current end
function GetEntityCoords(e) return vec(positions[e]) end
function GetGamePool() return { 70, 71 } end
function GetVehicleNumberPlateText(v) return plates[v] end
function NetworkGetEntityIsNetworked() return true end
function NetworkGetNetworkIdFromEntity(v) return v + 1000 end
local hasKeysNow = false
Kora = { callback = { trigger = function() return hasKeysNow end } }
-- Threads run as coroutines the test steps by hand; Wait yields.
local threads = {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn); coroutine.resume(threads[#threads]) end
function Wait() coroutine.yield() end
local function step() for _, t in ipairs(threads) do if coroutine.status(t) == 'suspended' then coroutine.resume(t) end end end
local function drain() for _ = 1, 20 do step() end end
Kora.compat = dofile(root .. '../kora_lib/compat/provider.lua')()
dofile(root .. 'client/compat.lua')

local function expect(cond, msg) if not cond then error(msg, 2) end end

handlers['qb-vehiclekeys:client:AddKeys']('QB 123')
handlers['vehiclekeys:client:SetOwner']('qb 123')
hasKeysNow = true; drain(); hasKeysNow = false
expect(#sent == 2 and sent[1][1] == 'qb-vehiclekeys:server:AcquireVehicleKeys' and sent[1][2] == 1070
    and sent[2][2] == 1070, 'AddKeys/SetOwner send the vehicle network id')
handlers['vehiclekeys:client:SetOwner']('FAR 1')
handlers['vehiclekeys:client:SetOwner']('NOPE')
drain()
expect(#sent == 2, 'far or unknown plates are not forwarded')
handlers['qb-vehiclekeys:client:AddKeys'](nil); handlers['qb-vehiclekeys:client:AddKeys']({}); handlers['vehiclekeys:client:SetOwner'](('x'):rep(40))
expect(#sent == 2, 'invalid plates are not forwarded')
current = 71; handlers['vehiclekeys:client:SetOwner']('FAR 1')
hasKeysNow = true; drain(); hasKeysNow = false
expect(#sent == 3 and sent[3][2] == 1071, 'the vehicle the player is in is preferred at any distance')
-- Retries: ask again until the server confirms the key, at most 8 times, one loop per plate.
current = 0; sent = {}; threads = {}
handlers['vehiclekeys:client:SetOwner']('QB 123')
handlers['vehiclekeys:client:SetOwner']('QB 123')
expect(#sent == 1, 'first request goes out at once; a duplicate loop is not started')
step(); step()
expect(#sent == 3, 'unaccepted requests are retried')
hasKeysNow = true; drain()
expect(#sent == 3, 'retrying stops once the server grants the key')
hasKeysNow = false; sent = {}; threads = {}
handlers['vehiclekeys:client:SetOwner']('QB 123'); drain()
expect(#sent == 8, 'gives up after ~3 s')
sent = {}; handlers['vehiclekeys:client:SetOwner']('QB 123')
expect(#sent == 1, 'a new request after giving up starts again'); drain()
sent = { 1, 2, 3 }
handlers['qb-vehiclekeys:client:RemoveKeys']('QB 123')
expect(#sent == 4 and sent[4][1] == 'qb-vehiclekeys:server:RemoveOwnKeys', 'RemoveKeys asks the server to drop own key')
print('qbvehiclekeys legacy client events: 6 checks passed')
