fx_version 'cerulean'
game 'gta5'
provide 'qb-vehiclekeys'
lua54 'yes'

name 'qbvehiclekeys'
author 'qbcore2'
version '1.0.0'
description 'Server-authoritative vehicle keys, locks, and hotwiring for qblib/qbcore'

dependencies {
    'qblib',
    'qbcore',
}

shared_scripts {
    '@qblib/init.lua',
    'config.lua',
}

client_scripts { 'client/main.lua', 'client/compat.lua' }
server_script 'server/main.lua'
