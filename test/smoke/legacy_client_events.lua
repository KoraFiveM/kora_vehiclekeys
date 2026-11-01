local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local handlers, sent = {}, {}
function RegisterNetEvent() end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerServerEvent(name, ...) sent[#sent + 1] = { name, ... } end
Kora = { callback = { trigger = function() return false end } }
Kora.compat = dofile(root .. '../kora_lib/compat/provider.lua')()
dofile(root .. 'client/compat.lua')

local function expect(cond, msg) if not cond then error(msg, 2) end end

handlers['qb-vehiclekeys:client:AddKeys']('QB 123')
handlers['vehiclekeys:client:SetOwner']('QB 456')
expect(#sent == 2 and sent[1][1] == 'qb-vehiclekeys:server:AcquireVehicleKeys' and sent[1][2] == 'QB 123'
    and sent[2][2] == 'QB 456', 'AddKeys/SetOwner only ask the server')
handlers['qb-vehiclekeys:client:AddKeys'](nil); handlers['qb-vehiclekeys:client:AddKeys']({}); handlers['vehiclekeys:client:SetOwner'](('x'):rep(40))
expect(#sent == 2, 'invalid plates are not forwarded')
handlers['qb-vehiclekeys:client:RemoveKeys']('QB 123')
expect(#sent == 3 and sent[3][1] == 'qb-vehiclekeys:server:RemoveOwnKeys', 'RemoveKeys asks the server to drop own key')
print('qbvehiclekeys legacy client events: 4 checks passed')
