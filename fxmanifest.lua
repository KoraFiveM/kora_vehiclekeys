fx_version 'cerulean'
game 'gta5'
provide 'qb-vehiclekeys'
lua54 'yes'

name 'kora_vehiclekeys'
-- Keep the legacy resource name resolvable for exports['qbvehiclekeys'] callers.
provide 'qbvehiclekeys'
author 'qbcore2'
version '1.0.0'
description 'Server-authoritative vehicle keys, locks, and hotwiring for kora_lib/qbcore'

dependencies {
    'kora_lib',
    'kora_core',
}

shared_scripts {
    '@kora_lib/init.lua',
    'config.lua',
}

client_scripts { 'client/main.lua', 'client/compat.lua' }
server_script 'server/main.lua'
