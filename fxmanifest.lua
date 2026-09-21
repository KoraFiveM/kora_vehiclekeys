fx_version 'cerulean'
game 'gta5'
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

client_script 'client/main.lua'
server_script 'server/main.lua'
