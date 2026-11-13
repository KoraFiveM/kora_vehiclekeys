fx_version 'cerulean'
game 'gta5'
provide 'qb-vehiclekeys'
lua54 'yes'

name 'kora_vehiclekeys'
author 'Kora'
version '0.1.0'
description 'Server-authoritative vehicle keys, locks, and hotwiring for kora_lib/kora_core'

dependencies {
    'kora_lib',
    'kora_core',
}

shared_scripts {
    '@kora_lib/init.lua',
    'shared/config.lua',
}

client_scripts { 'client/feedback.lua', 'client/main.lua', 'client/compat.lua', 'client/stock.lua' }
server_script 'server/main.lua'

files {
    'locales/*.lua',
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
