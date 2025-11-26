fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'AXStudio'
description 'Sistema de Territorios para Bandas - NEW ESX 1.13.4'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib'
}