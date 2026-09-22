fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'spz-pausemenu'
description 'SPiceZ Racing — pause menu (replaces the GTA ESC menu)'
author 'SPiceZ-Core'
version '1.0.2'

ui_page 'ui/index.html'

files {
  'ui/index.html',
  'ui/style.css',
  'ui/app.js',
  'ui/fonts/*.ttf',
  'ui/ranks/*.svg',
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
}

client_scripts {
  'client/main.lua',
}

server_scripts {
  'server/main.lua',
}

dependencies {
  'ox_lib',
  'spz-core',
}
