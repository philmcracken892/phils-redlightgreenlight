fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'phil mcracken'
description 'Red Light Green Light - Squid Games inspired mini-game for RSG-Core'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target'
}

lua54 'yes'