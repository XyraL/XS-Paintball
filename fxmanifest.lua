fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-Paintball'
author 'XyraL'
description 'Lobbies, eight game modes, killstreaks, wagers and a full in-game map builder. Standalone for QBox/QBCore.'
version '1.4.0'

-- Works on QBox (qbx_core) OR QBCore (qb-core). The bridge auto-detects.
-- Inventory: ox_inventory / qb-inventory / qs-inventory / codem-inventory /
-- core_inventory / ps-inventory — auto-detected, force it via Config.Bridges.
-- Target: ox_target / qb-target, or a built-in marker and key prompt when the
-- server runs neither. See Config.Interaction.
-- Nothing else is required. No other XS script is a dependency.
dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/util.lua',
    'shared/modes.lua',
    'shared/weapons.lua',
    'shared/cosmetics.lua',
    'shared/maps.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/target.lua',
    'bridge/dispatch.lua',
    'client/main.lua',
    'client/match.lua',
    'client/staging.lua',
    'client/sounds.lua',
    'client/vote.lua',
    'client/combat.lua',
    'client/paint.lua',
    'client/gear.lua',
    'client/objectives.lua',
    'client/killstreaks.lua',
    'client/spectate.lua',
    'client/hud.lua',
    'client/builder.lua',
    'client/placement.lua',
    'client/props.lua',
    'client/markers.lua',
    'client/board.lua',
    'client/fallbacks.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/voice.lua',
    'server/settings.lua',
    'server/store.lua',
    'server/stats.lua',
    'server/economy.lua',
    'server/loadout.lua',
    'server/lobbies.lua',
    'server/vote.lua',
    'server/queue.lua',
    'server/match.lua',
    'server/objectives.lua',
    'server/main.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/core.js',
    'html/js/hud.js',
    'html/js/app.js',
    'html/js/mock.js',
    'html/js/panels/play.js',
    'html/js/panels/lobby.js',
    'html/js/panels/loadout.js',
    'html/js/panels/unlocks.js',
    'html/js/panels/maps.js',
    'html/js/panels/editor.js',
    'html/js/panels/stats.js',
    'html/js/panels/settings.js',
}
