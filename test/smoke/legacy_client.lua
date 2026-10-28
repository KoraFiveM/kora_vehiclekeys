local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local handler, response, requested, calls = nil, nil, nil, 0
function AddEventHandler(_, fn) fn(function(value) handler=value end) end
QB = { callback = {trigger=function(name, plate)
    calls=calls+1; requested={name,plate}; return response
end} }
QB.compat = dofile(root .. '../kora_lib/compat/provider.lua')()
dofile(root .. 'client/compat.lua')
response=true; assert(handler('PLATE')==true)
assert(requested[1]=='qbvehiclekeys:server:legacyHasKeys' and requested[2]=='PLATE')
response=false; assert(handler('PLATE')==false)
response=nil; assert(handler('PLATE')==false)
local before=calls; assert(handler({})==false and handler('')==false and calls==before)
print('qbvehiclekeys legacy client: 5 checks passed')
