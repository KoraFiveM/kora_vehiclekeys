Kora.compat.provideExport('qb-vehiclekeys', 'HasKeys', function(plate)
    if type(plate) ~= 'string' or plate == '' or #plate > 32 then return false end
    return Kora.callback.trigger('qbvehiclekeys:server:legacyHasKeys', plate) == true
end)
