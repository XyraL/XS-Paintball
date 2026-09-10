Config = {}

-- Prints extra detail to both consoles. Leave off on a live server.
Config.Debug = false

-- Force a bridge instead of letting it auto-detect.
-- framework: auto | qbox | qbcore
-- inventory: auto | ox | qb | qs | codem | core | ps
-- target:    auto | ox_target | qb-target | none
Config.Bridges = {
    framework = 'auto',
    inventory = 'auto',
    target    = 'auto',
}

-- Who can open the map builder and the admin settings tab.
Config.Admin = {
    acePermission = 'xs.paintball',
    groups        = { 'admin', 'god' },
    licenses      = {},
}

-- Jobs that cannot join a match at all. Useful for on-duty police and EMS.
Config.BlockedJobs = {}
Config.BlockedJobsRespectDuty = true

-- Notification styling, passed straight to ox_lib.
Config.NotifyStyle = {
    title    = 'Paintball',
    position = 'top',
    duration = 4000,
    -- These match the panel palette. Change them and the notifications stop
    -- matching the rest of the script.
    icons = {
        inform  = { icon = 'circle-info',          color = '#e0165f' },
        success = { icon = 'circle-check',         color = '#2c9c4a' },
        error   = { icon = 'circle-exclamation',   color = '#e0342a' },
        warning = { icon = 'triangle-exclamation', color = '#eaa900' },
    },
}

--[[ ---------------------------------------------------------------------
     ENTRY POINTS
     Where players walk up to join. Add as many as you like.
--------------------------------------------------------------------- ]]

Config.Interaction = {
    -- ox_target or qb-target when installed, otherwise a marker you press E in.
    distance   = 2.0,
    key        = 38,
    markerType = 27,
    markerSize = 1.2,
    markerRGB  = { 224, 22, 95 },
}

Config.EntryPoints = {
    {
        label  = 'Paintball Arena',
        coords = vec4(-257.71, -2022.7, 29.15, 315.21),

        -- Set ped to false for no ped, or change the model.
        ped      = 's_m_y_dealer_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',

        -- Off on purpose: Config.Staging carries the blip, and the entry
        -- point is standing in the same place, so two would be one too many.
        blip = {
            enabled = false,
            sprite  = 313,
            colour  = 27,
            scale   = 0.8,
            label   = 'Paintball',
        },
    },
}

-- Commands. Set any of them to false to remove it.
Config.Commands = {
    open    = 'paintball',
    leave   = 'pbleave',
    builder = 'pbbuild',
    reload  = 'pbreload',
}

-- Let players open the panel from anywhere, not just at an entry point.
Config.OpenAnywhere = false

--[[ ---------------------------------------------------------------------
     STAGING AREA
     Where the paintball crowd waits. Joining a lobby puts you here, and
     leaving puts you back exactly where you were.

     This is also what stops someone diving into a match to escape a chase:
     you have to physically be here to join, so you cannot do it from the
     other side of the map.
--------------------------------------------------------------------- ]]

Config.Staging = {
    enabled = true,

    -- Set this to wherever you want people to gather. Anywhere with room to
    -- stand around works — an arena, a warehouse, a car park.
    coords = vec4(-257.71, -2022.7, 29.15, 315.21),

    -- How far you can wander before you get put back on the spot. Big enough
    -- to stand around in and mess about.
    radius = 60.0,

    -- The waiting room gets its own routing bucket, so the crowd is invisible
    -- to the rest of the city and cannot be shot while they stand there.
    -- Nothing else on your server should use this one.
    bucket = 6399,

    -- Empty the waiting room of traffic and pedestrians.
    clearPopulation = true,

    -- A plain blip, no route. Nothing sets a GPS waypoint for it.
    blip = {
        enabled = true,
        sprite  = 313,
        colour  = 27,
        scale   = 0.8,
        label   = 'Paintball',
    },
}

--[[ ---------------------------------------------------------------------
     WHO CAN JOIN
     All of these are checked on the server, so they cannot be faked.
--------------------------------------------------------------------- ]]

Config.JoinRules = {
    -- You have to be standing in the staging area. This is the important one.
    -- Turn it off and people can join from anywhere they can open the panel.
    requireStaging = true,

    -- Seconds since you last shot someone or got shot. Stops people using a
    -- match as an escape hatch mid fight. Fed by the server's own damage
    -- event, so it counts real hits, not anything the client claims.
    combatCooldown = 45,

    -- Cannot join sitting in a vehicle.
    blockInVehicle = true,

    -- Cannot join while down.
    blockWhenDead = true,
}

--[[ ---------------------------------------------------------------------
     KEEPING PAINTBALL OFF THE DISPATCH BOARD
     There is no NPC police in FiveM, so there is no wanted level to clear.
     What matters is your dispatch and MDT resources, which watch for gunfire
     client side and report it. Nothing here can reach inside those, so this
     gives them a way to ask.
--------------------------------------------------------------------- ]]

Config.Dispatch = {
    -- Stops ambient peds reacting to gunfire. Harmless to leave on.
    suppressShockingEvents = true,

    -- If your dispatch resource has a way to mute a player, wire it up here
    -- and it gets called when a match starts and again when it ends.
    -- The boolean passed is "is this player in a match".
    --
    --   { resource = 'my-dispatch', export = 'SetPlayerMuted' }
    --
    -- Called client side as exports['my-dispatch']:SetPlayerMuted(inMatch).
    mute = {},
}

--[[ ---------------------------------------------------------------------
     LOBBIES
--------------------------------------------------------------------- ]]

Config.Lobbies = {
    -- How many matches can run at the same time. Each one gets its own
    -- routing bucket, so players in different matches never see each other.
    max = 8,

    -- Routing buckets used for matches. Nothing else on your server should
    -- use this range.
    bucketBase = 6400,

    -- Empty the arena of traffic and pedestrians while a match is running.
    clearPopulation = true,

    maxPlayers     = 24,
    minToStart     = 2,
    startCountdown = 10,
    endScreen      = 12,

    -- Close a lobby nobody has joined after this many seconds.
    idleTimeout = 600,

    allowPasscodes  = true,
    allowSpectators = true,

    -- Shuffle teams evenly when the match starts.
    autoBalance = true,

    -- Let the host change map, mode and rules while people are waiting.
    liveSettings = true,
}

-- Team colours are used for blips, markers, flags and capture points in the
-- world. These are the same values the panel uses, so the two match.
Config.Teams = {
    red    = { label = 'Red',    colour = { 224, 52, 42 },  blip = 1, outfitCommand = 'redoutfit' },
    blue   = { label = 'Blue',   colour = { 37, 96, 212 },  blip = 3, outfitCommand = 'blueoutfit' },
    green  = { label = 'Green',  colour = { 44, 156, 74 },  blip = 2, outfitCommand = 'greenoutfit' },
    yellow = { label = 'Yellow', colour = { 234, 169, 0 },  blip = 5, outfitCommand = 'yellowoutfit' },
}

-- Show your side down the edge of the screen during a match, with who is
-- alive and who is talking.
Config.TeamPanel = true

-- The team order used when a mode asks for 2, 3 or 4 teams.
Config.TeamOrder = { 'red', 'blue', 'green', 'yellow' }

-- Let players save the outfit they are wearing as their team kit, with the
-- commands named above. They get it back automatically at match start.
Config.TeamOutfits = true

--[[ ---------------------------------------------------------------------
     ROUNDS
     A match can be a single round or a best-of. Sides swap at the halfway
     point so nobody is stuck on the worse half of the map.
--------------------------------------------------------------------- ]]

Config.Rounds = {
    enabled = true,

    -- What a new lobby starts on, and what the host can pick from.
    default = 1,
    options = { 1, 3, 5, 7 },

    -- Swap red and blue when the rounds are halfway through.
    swapSides = true,

    -- Seconds between rounds, on the round scoreboard.
    breakSeconds = 12,
}

--[[ ---------------------------------------------------------------------
     MAP VOTE
     Runs on the end screen. Winner becomes the lobby's next map.
--------------------------------------------------------------------- ]]

Config.MapVote = {
    enabled = true,

    -- How many maps to offer. Players press 1, 2 or 3 to vote.
    options = 3,
    seconds = 20,

    -- Leave the map that was just played out of the choices when there are
    -- enough others to fill the list.
    excludeCurrent = true,
}

--[[ ---------------------------------------------------------------------
     QUICK PLAY QUEUE
     Instead of picking a lobby, join a queue and get put in one as soon as
     there are enough people. Same join rules apply, so you still have to be
     at the staging area.
--------------------------------------------------------------------- ]]

Config.Queue = {
    enabled = true,

    -- Players needed before a lobby is made.
    minPlayers = 4,

    -- Mode used for a queue match. 'random' picks from whatever is enabled
    -- and has a playable map.
    mode = 'random',

    -- Drop anyone who has been queued this long without a match starting.
    timeout = 600,
}

--[[ ---------------------------------------------------------------------
     TEAM VOICE
     Puts each team on its own radio channel for the match, so you can talk
     to your side across the arena. Proximity still works as normal on top.

     Only pma-voice is wired up out of the box, because it is the only one
     with a stable server-side API for this. Anything else can be driven
     through the generic hook.
--------------------------------------------------------------------- ]]

Config.Voice = {
    enabled = true,

    -- auto | pma | generic | none
    provider = 'auto',

    -- Radio channels get taken from this upwards. Pick a range nothing else
    -- on your server uses — every lobby and team takes one.
    channelBase = 4200,

    -- For provider = 'generic'. Called server side as
    --   exports[resource][join](source, channel)
    --   exports[resource][leave](source)
    generic = {
        resource = '',
        join     = '',
        leave    = '',
    },
}

--[[ ---------------------------------------------------------------------
     MATCH RULES
     Defaults a new lobby starts with. The host can change any of them in
     the lobby, within the limits set here.
--------------------------------------------------------------------- ]]

Config.Rules = {
    scoreLimit   = { default = 30,  min = 5,   max = 150 },
    timeLimit    = { default = 600, min = 120, max = 1800 },
    respawnTime  = { default = 4,   min = 0,   max = 15 },
    spawnProtect = { default = 4,   min = 0,   max = 10 },

    friendlyFire = false,

    -- Paint pool. This is not real health. A player never actually dies, they
    -- get eliminated and respawn, so ambulance scripts never fire.
    paintHealth = 100,

    -- Multiplies every hit against the paint pool. 1.0 means a rifle hit takes
    -- about as much paint as it would take health normally.
    damageScale = 1.0,

    -- Real weapon and melee damage is scaled down to this for everyone in a
    -- match, so no single hit can ever be lethal and the ped never actually
    -- dies. Paint damage is scaled back up, so this does not change how hard
    -- anything hits.
    -- Health stays under 200 the whole time, which keeps anticheats happy.
    -- Lower it if your server streams high damage addon weapons.
    damageModifier = 0.25,

    -- A headshot always eliminates, whatever the paint pool says.
    headshotKills = true,

    -- Seconds outside the arena boundary before you are eliminated.
    outOfBounds = 8,

    -- Third person only inside a match.
    forceThirdPerson = false,

    -- Hide the vanilla radar and use the paintball HUD on its own.
    hideRadar = false,

    -- Show where a player was killed from on the killfeed.
    killcam = false,

    -- Marked players put their hand up and walk off, the way they would on a
    -- real field, for as long as the respawn takes.
    handsUpWhenOut = true,

    -- The waiting room is a safe zone: no firing in it, and none while you are
    -- marked and waiting to come back on.
    safeZone = true,

    -- A soft goggle vignette while you are on the field.
    goggles = true,
}

--[[ ---------------------------------------------------------------------
     GAME MODES
     Turn any of them off with enabled = false. teams = 0 is free-for-all.
--------------------------------------------------------------------- ]]

Config.Modes = {
    tdm = {
        enabled = true, label = 'Team Deathmatch', teams = 2,
        description = 'First team to the score limit wins.',
        scoreLimit = 60,
    },
    ffa = {
        enabled = true, label = 'Free For All', teams = 0,
        description = 'Everyone for themselves.',
        scoreLimit = 25,
    },
    ctf = {
        enabled = true, label = 'Capture The Flag', teams = 2,
        description = 'Take the enemy flag back to your own. Yours has to be home to score.',
        scoreLimit = 3,
        flagReturnTime = 30,
        carrierSpeed = 0.9,
    },
    gungame = {
        enabled = true, label = 'Gun Game', teams = 0,
        description = 'Every kill moves you up the weapon ladder. Finish it to win.',
        -- Winning is finishing the ladder, so this only sets what the lobby
        -- shows. Keep it level with the number of rungs.
        scoreLimit = 15,
    },
    oitc = {
        enabled = true, label = 'One In The Chamber', teams = 0,
        description = 'One bullet, one hit kill. Every kill gives you another round.',
        scoreLimit = 15,
        lives = 5,
        startAmmo = 1,
        ammoPerKill = 1,
    },
    hyo = {
        enabled = true, label = 'Hold Your Own', teams = 2,
        description = 'Each team shares a pool of lives. Run it dry and you lose.',
        livesPerPlayer = 5,
    },
    confirmed = {
        enabled = true, label = 'Kill Confirmed', teams = 2,
        description = 'Kills only count once someone picks up the tag.',
        scoreLimit = 50,
        tagLifetime = 20,
        denyScore = 0,
    },
    domination = {
        enabled = true, label = 'Domination', teams = 2,
        description = 'Hold the capture points. Score ticks while you own them.',
        scoreLimit = 200,
        captureTime = 8,
        tickInterval = 5,
        pointsPerTick = 1,
    },
}

--[[ ---------------------------------------------------------------------
     WEAPONS
     Anything listed here can be picked in a loadout. Addon weapons work,
     just add the spawn name.
--------------------------------------------------------------------- ]]

Config.Loadout = {
    primary   = true,
    secondary = true,

    -- No melee. It is paintball — there is nothing to hit anybody with.
    -- Turning this back on needs melee entries adding to Config.Weapons again.
    melee     = false,

    -- Ammo given per life.
    ammo = { primary = 250, secondary = 120 },

    -- How many loadout presets a player can save.
    presets = 3,

    -- Take the real weapons away for the match and hand them back after.
    -- Strongly recommended.
    stripWeapons = true,

    --[[ Swap the whole inventory, not just the ped's weapons.

         On: the inventory is snapshotted, saved to the database, emptied, and
         the loadout weapons are handed over as items. Everything goes back at
         the end of the match, and also on leaving, disconnecting, the resource
         stopping, or the next time the player loads if the server went down
         mid match.

         The snapshot is always taken and saved before anything is emptied. If
         either step fails the inventory is left completely alone and the match
         runs on ped weapons instead, so a bad read can never cost anybody
         their items.

         Off: the ped's weapons are swapped and the inventory is untouched.
         Nothing is ever at risk, but players keep their own items on them. ]]
    manageInventory = true,

    -- Optional item handed out alongside the guns, e.g. an ammo box.
    ammoItem = false,

    -- Attachments granted with every gun that accepts them.
    components = {},
}

Config.Weapons = {
    { name = 'WEAPON_PETROLCAN',        label = 'Paint Sprayer',       slot = 'primary',   category = 'special', paint = true },
    { name = 'WEAPON_ASSAULTRIFLE',     label = 'Assault Rifle',       slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_ASSAULTRIFLE_MK2', label = 'Assault Rifle Mk II', slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_CARBINERIFLE',     label = 'Carbine',             slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_CARBINERIFLE_MK2', label = 'Carbine Mk II',       slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_SPECIALCARBINE',   label = 'Special Carbine',     slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_BULLPUPRIFLE',     label = 'Bullpup Rifle',       slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_COMPACTRIFLE',     label = 'Compact Rifle',       slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_MILITARYRIFLE',    label = 'Military Rifle',      slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_HEAVYRIFLE',       label = 'Heavy Rifle',         slot = 'primary',   category = 'rifle' },
    { name = 'WEAPON_ADVANCEDRIFLE',    label = 'Advanced Rifle',      slot = 'primary',   category = 'rifle' },

    { name = 'WEAPON_SMG',              label = 'SMG',                 slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_SMG_MK2',          label = 'SMG Mk II',           slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_MICROSMG',         label = 'Micro SMG',           slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_MINISMG',          label = 'Mini SMG',            slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_ASSAULTSMG',       label = 'Assault SMG',         slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_COMBATPDW',        label = 'Combat PDW',          slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_MACHINEPISTOL',    label = 'Machine Pistol',      slot = 'primary',   category = 'smg' },
    { name = 'WEAPON_GUSENBERG',        label = 'Gusenberg',           slot = 'primary',   category = 'smg' },

    { name = 'WEAPON_PUMPSHOTGUN',      label = 'Pump Shotgun',        slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_PUMPSHOTGUN_MK2',  label = 'Pump Shotgun Mk II',  slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_SAWNOFFSHOTGUN',   label = 'Sawn-Off',            slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_ASSAULTSHOTGUN',   label = 'Assault Shotgun',     slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_BULLPUPSHOTGUN',   label = 'Bullpup Shotgun',     slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_HEAVYSHOTGUN',     label = 'Heavy Shotgun',       slot = 'primary',   category = 'shotgun' },
    { name = 'WEAPON_COMBATSHOTGUN',    label = 'Combat Shotgun',      slot = 'primary',   category = 'shotgun' },

    { name = 'WEAPON_SNIPERRIFLE',      label = 'Sniper Rifle',        slot = 'primary',   category = 'sniper' },
    { name = 'WEAPON_HEAVYSNIPER',      label = 'Heavy Sniper',        slot = 'primary',   category = 'sniper' },
    { name = 'WEAPON_HEAVYSNIPER_MK2',  label = 'Heavy Sniper Mk II',  slot = 'primary',   category = 'sniper' },
    { name = 'WEAPON_MARKSMANRIFLE',    label = 'Marksman Rifle',      slot = 'primary',   category = 'sniper' },
    { name = 'WEAPON_MARKSMANRIFLE_MK2',label = 'Marksman Mk II',      slot = 'primary',   category = 'sniper' },

    { name = 'WEAPON_MG',               label = 'MG',                  slot = 'primary',   category = 'lmg' },
    { name = 'WEAPON_COMBATMG',         label = 'Combat MG',           slot = 'primary',   category = 'lmg' },
    { name = 'WEAPON_COMBATMG_MK2',     label = 'Combat MG Mk II',     slot = 'primary',   category = 'lmg' },

    { name = 'WEAPON_PISTOL',           label = 'Pistol',              slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_PISTOL_MK2',       label = 'Pistol Mk II',        slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_COMBATPISTOL',     label = 'Combat Pistol',       slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_APPISTOL',         label = 'AP Pistol',           slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_HEAVYPISTOL',      label = 'Heavy Pistol',        slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_VINTAGEPISTOL',    label = 'Vintage Pistol',      slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_SNSPISTOL',        label = 'SNS Pistol',          slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_PISTOL50',         label = 'Pistol .50',          slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_REVOLVER',         label = 'Revolver',            slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_REVOLVER_MK2',     label = 'Revolver Mk II',      slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_MARKSMANPISTOL',   label = 'Marksman Pistol',     slot = 'secondary', category = 'pistol' },
    { name = 'WEAPON_STUNGUN',          label = 'Stun Gun',            slot = 'secondary', category = 'pistol' },

}

-- The Gun Game ladder, in order. Everything here has to exist above.
Config.GunGameLadder = {
    'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW',
    'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_SPECIALCARBINE',
    'WEAPON_BULLPUPRIFLE', 'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN',
    'WEAPON_MARKSMANRIFLE', 'WEAPON_SNIPERRIFLE', 'WEAPON_COMBATMG',
    'WEAPON_PISTOL', 'WEAPON_REVOLVER',
}

-- One In The Chamber gives everyone this and nothing else.
Config.OitcWeapon = 'WEAPON_REVOLVER'

-- What a hit looks like. None of this changes how much damage is dealt.
Config.PaintEffects = {
    -- Wipe blood off everyone in the match and turn off critical hits, so it
    -- reads as paint rather than gunfire.
    noBlood = true,

    -- Paint splatter across the screen of whoever got hit.
    screenSplat = true,

    -- Hit marker and tick sound for whoever landed it.
    hitMarker = true,
    hitSound  = true,

    --[[ Paint splats on the world.

         Every shot you land leaves a splat in your team's colour on whatever
         it hit, and they build up over a match. No assets needed — this is a
         base game decal tinted to the team colour.

         type is the decal id. 9 is the generic splat and is what reads best as
         paint. size is metres across. ]]
    decals = {
        enabled = true,
        type    = 9,
        size    = 0.55,
        timeout = 45000,
    },

    -- A world particle at the impact point. Off by default because the base
    -- game has no paint splash. If your server streams a particle dictionary
    -- with one, put it here and set worldFx = true.
    worldFx    = false,
    worldDict  = '',
    worldAsset = '',
    worldScale = 0.6,
}

--[[ ---------------------------------------------------------------------
     GEAR
     A tank on your back for the length of a match. Cosmetic only, and it is
     removed the moment you leave the field.

     The offsets suit the default freemode models. If it clips on your peds,
     nudge them here — or set enabled = false and lose nothing.
--------------------------------------------------------------------- ]]

Config.Gear = {
    enabled = true,
    prop    = 'prop_fire_exting_1a',
    bone    = 24818,
    offset  = { x = -0.17, y = -0.21, z = 0.0 },
    rotation = { x = 0.0, y = 180.0, z = 0.0 },
}

--[[ ---------------------------------------------------------------------
     KILLSTREAKS
     Earned at a kill count in the current life. Set enabled = false to
     switch the whole system off.
--------------------------------------------------------------------- ]]

Config.Killstreaks = {
    enabled = true,

    -- Only the highest earned reward fires, instead of all of them.
    oneAtATime = false,

    rewards = {
        {
            id = 'uav', label = 'UAV', kills = 4, duration = 30,
            description = 'Every enemy shows on your team radar.',
            icon = 'satellite-dish',
        },
        {
            id = 'resupply', label = 'Resupply', kills = 6,
            description = 'Full ammo, instantly.',
            icon = 'boxes-stacked',
        },
        {
            id = 'armour', label = 'Paint Vest', kills = 7, amount = 50,
            description = 'Adds to your paint pool for this life.',
            icon = 'shield-halved',
        },
        {
            id = 'deathmachine', label = 'Death Machine', kills = 10, duration = 45,
            weapon = 'WEAPON_MINIGUN', ammo = 200,
            description = 'A minigun, for a little while.',
            icon = 'burst',
        },
    },
}

--[[ ---------------------------------------------------------------------
     WAGERS AND PAYOUTS
--------------------------------------------------------------------- ]]

-- Wagers only. There is no payout for winning, losing or getting kills — the
-- only money that moves is what players put up themselves, and a match with no
-- wager on it costs and pays nothing.
Config.Economy = {
    enabled = true,

    -- cash or bank
    account = 'cash',

    wager = {
        enabled = true,
        min     = 0,
        max     = 25000,
        default = 0,

        -- The pot is every player wager added up. Winners split what is left
        -- after the house cut. A draw refunds everyone.
        houseCut = 0.05,
    },

    -- Require an item to play, taken on match start. false skips it.
    ticketItem   = false,
    ticketAmount = 1,

    -- Where the house cut goes. Any resource with an add-money export works.
    business = {
        enabled    = false,
        resource   = '',
        exportName = '',
        account    = 'paintball',
    },
}

--[[ ---------------------------------------------------------------------
     PROGRESSION
--------------------------------------------------------------------- ]]

Config.Progression = {
    enabled = true,

    xp = { kill = 10, headshot = 5, assist = 4, capture = 25, win = 150, loss = 50, streak = 5 },

    -- XP for level n is levelBase * n ^ levelCurve.
    levelBase  = 400,
    levelCurve = 1.35,
    maxLevel   = 100,

    -- Lock weapons behind a level. Anything not listed is available at level 1.
    unlocks = {
        WEAPON_HEAVYSNIPER   = 15,
        WEAPON_COMBATMG      = 20,
        WEAPON_MARKSMANRIFLE = 10,
        WEAPON_HEAVYSHOTGUN  = 12,
    },
}

--[[ ---------------------------------------------------------------------
     COSMETIC UNLOCKS
     Earned by level or by wins, picked in the Unlocks tab, and worn only
     inside a match. Whatever the player was wearing goes back on when the
     match ends, so none of this touches their real character.
--------------------------------------------------------------------- ]]

Config.Cosmetics = {
    enabled = true,

    -- Weapon tints. These are the eight vanilla ones and need no assets.
    -- id is the GTA tint index.
    tints = {
        { id = 0, label = 'Standard', unlock = {} },
        { id = 1, label = 'Green',    unlock = { level = 5 } },
        { id = 2, label = 'Gold',     unlock = { level = 40 } },
        { id = 3, label = 'Pink',     unlock = { level = 10 } },
        { id = 4, label = 'Army',     unlock = { level = 15 } },
        { id = 5, label = 'Blue',     unlock = { level = 20 } },
        { id = 6, label = 'Orange',   unlock = { level = 30 } },
        { id = 7, label = 'Platinum', unlock = { wins = 50 } },
    },

    --[[ Kits.

         A kit is a set of clothing components put on at match start and taken
         off at the end. Slots are the standard GTA component ids:
           1 mask   3 arms   4 legs   6 shoes   8 undershirt   9 vest   11 top
         Props: 0 hat   1 glasses

         The drawable and texture numbers below are EXAMPLES. Take the real
         ones from your clothing menu and put them here — they are different
         on every server that streams custom clothing, and different between
         the male and female freemode models.

         The first kit is deliberately empty, which means "wear your own
         clothes". Leave it in as the default so nobody is forced into a kit
         you have not set up yet.
    ]]
    kits = {
        {
            id = 'none', label = 'Your own clothes', unlock = {},
            male = {}, female = {},
        },
        {
            id = 'recruit', label = 'Recruit', unlock = { level = 1 },
            male = {
                components = {
                    { slot = 11, drawable = 1,  texture = 0 },
                    { slot = 8,  drawable = 15, texture = 0 },
                    { slot = 4,  drawable = 1,  texture = 0 },
                    { slot = 6,  drawable = 1,  texture = 0 },
                },
                props = {},
            },
            female = {
                components = {
                    { slot = 11, drawable = 1,  texture = 0 },
                    { slot = 8,  drawable = 14, texture = 0 },
                    { slot = 4,  drawable = 1,  texture = 0 },
                    { slot = 6,  drawable = 1,  texture = 0 },
                },
                props = {},
            },
        },
        {
            id = 'skirmisher', label = 'Skirmisher', unlock = { level = 10 },
            male   = { components = { { slot = 11, drawable = 31, texture = 0 }, { slot = 9, drawable = 1, texture = 0 } }, props = {} },
            female = { components = { { slot = 11, drawable = 30, texture = 0 }, { slot = 9, drawable = 1, texture = 0 } }, props = {} },
        },
        {
            id = 'veteran', label = 'Veteran', unlock = { level = 25 },
            male   = { components = { { slot = 11, drawable = 55, texture = 0 }, { slot = 9, drawable = 2, texture = 0 } }, props = { { slot = 0, drawable = 8, texture = 0 } } },
            female = { components = { { slot = 11, drawable = 54, texture = 0 }, { slot = 9, drawable = 2, texture = 0 } }, props = { { slot = 0, drawable = 8, texture = 0 } } },
        },
        {
            id = 'paintdevil', label = 'Paint Devil', unlock = { wins = 50 },
            male   = { components = { { slot = 11, drawable = 63, texture = 0 }, { slot = 1, drawable = 52, texture = 0 } }, props = {} },
            female = { components = { { slot = 11, drawable = 62, texture = 0 }, { slot = 1, drawable = 52, texture = 0 } }, props = {} },
        },
    },

    -- Tint the kit's top by team, so sides stay readable. The number is the
    -- texture index used on slot 11. Set to false if your kits already carry
    -- their own colours.
    teamTexture = false,
}

--[[ ---------------------------------------------------------------------
     SOUND
     All of these are base game sounds, so nothing needs streaming. A name
     that does not exist simply does not play — no error — so if you swap one
     out and hear nothing, the name is wrong rather than the code.

     To use your own audio instead, set Config.Sounds.resource to a sound
     resource and give each entry a `file` (see the comment on resource).
--------------------------------------------------------------------- ]]

Config.Sounds = {
    enabled = true,

    -- Optional. A resource that can play a named file, for custom audio.
    -- interact-sound is supported directly. Anything else can be wired with
    -- exportResource/exportName, called as
    --   exports[resource][name](file, volume)
    resource       = false,
    exportResource = '',
    exportName     = '',

    volume = 0.5,

    events = {
        countdown   = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_NORMAL' },
        matchStart  = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_PERFECT' },
        roundEnd    = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'TIMER_STOP' },
        matchWin    = { set = 'HUD_AWARDS',                        name = 'RACE_PLACED' },
        matchLoss   = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_MISSED' },
        kill        = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_NORMAL' },
        headshot    = { set = 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', name = 'Hack_Success' },
        eliminated  = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_MISSED' },
        respawn     = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',     name = 'SELECT' },
        hitmarker   = { set = 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', name = 'Hack_Success' },
        killstreak  = { set = 'HUD_AWARDS',                        name = 'RACE_PLACED' },
        capture     = { set = 'HUD_MINI_GAME_SOUNDSET',            name = 'CHECKPOINT_PERFECT' },
        outOfBounds = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',     name = 'CANCEL' },
        voteOpen    = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',     name = 'NAV_UP_DOWN' },
        voteCast    = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET',     name = 'SELECT' },
    },
}

Config.Leaderboard = {
    enabled = true,
    size    = 25,
    -- kills | kd | wins | xp
    sortBy  = 'kills',
    weekly  = true,

    -- A board you can walk up to and read, instead of opening the panel. Put
    -- the coordinates on a wall near the staging area — the text is drawn
    -- facing you, so it works anywhere with a flat surface behind it.
    board = {
        enabled  = true,
        coords   = vec3(-257.71, -2027.5, 30.6),
        entries  = 8,
        distance = 14.0,
    },
}

Config.History = {
    enabled = true,
    keep    = 200,
}

--[[ ---------------------------------------------------------------------
     MAP BUILDER
     Maps are built in-game. Nothing below needs editing to make one, these
     are just the builder controls and the prop list it offers you.
--------------------------------------------------------------------- ]]

Config.Builder = {
    enabled = true,

    CameraSpeed    = { slow = 2.0, normal = 12.0, fast = 40.0 },
    NudgeStep      = 0.1,
    PlacementRange = 60.0,
    SnapToGround   = false,

    propCategories = {
        { id = 'barrier',  label = 'Barriers' },
        { id = 'cover',    label = 'Cover' },
        { id = 'crate',    label = 'Crates' },
        { id = 'industry', label = 'Industrial' },
        { id = 'nature',   label = 'Nature' },
        { id = 'decor',    label = 'Decor' },
    },

    -- Props you can drop to build cover. Add whatever your server streams.
    props = {
        { model = 'prop_barrier_work05',    label = 'Work Barrier',   category = 'barrier' },
        { model = 'prop_barrier_work06a',   label = 'Barrier Long',   category = 'barrier' },
        { model = 'prop_mp_barrier_02b',    label = 'MP Barrier',     category = 'barrier' },
        { model = 'prop_barier_conc_01a',   label = 'Concrete Block', category = 'barrier' },
        { model = 'prop_barier_conc_02a',   label = 'Concrete Long',  category = 'barrier' },
        { model = 'prop_fnclink_03gate5',   label = 'Fence Gate',     category = 'barrier' },
        { model = 'prop_fnclink_05crnr1',   label = 'Fence Corner',   category = 'barrier' },

        { model = 'prop_boxpile_07d',       label = 'Box Pile',       category = 'cover' },
        { model = 'prop_container_01mb',    label = 'Container',      category = 'cover' },
        { model = 'prop_container_05a',     label = 'Container Open', category = 'cover' },
        { model = 'prop_rub_carwreck_2',    label = 'Car Wreck',      category = 'cover' },
        { model = 'prop_dumpster_02a',      label = 'Dumpster',       category = 'cover' },
        { model = 'prop_bin_beach_01a',     label = 'Bin',            category = 'cover' },

        { model = 'prop_crate_02a',         label = 'Crate',          category = 'crate' },
        { model = 'prop_crate_11a',         label = 'Crate Tall',     category = 'crate' },
        { model = 'prop_boxpile_04a',       label = 'Crate Stack',    category = 'crate' },
        { model = 'prop_mil_crate_01',      label = 'Military Crate', category = 'crate' },

        { model = 'prop_pipes_conc_01',     label = 'Concrete Pipes', category = 'industry' },
        { model = 'prop_scaffold_pole_01a', label = 'Scaffold Pole',  category = 'industry' },
        { model = 'prop_worklight_03b',     label = 'Work Light',     category = 'industry' },
        { model = 'prop_metal_plates02',    label = 'Metal Plates',   category = 'industry' },
        { model = 'prop_water_tank_01',     label = 'Water Tank',     category = 'industry' },

        { model = 'prop_bush_med_02',       label = 'Bush',           category = 'nature' },
        { model = 'prop_tree_cedar_02',     label = 'Cedar Tree',     category = 'nature' },
        { model = 'prop_rock_4_a',          label = 'Rock',           category = 'nature' },
        { model = 'prop_haybale_01',        label = 'Hay Bale',       category = 'nature' },

        { model = 'prop_flagpole_1a',       label = 'Flag Pole',      category = 'decor' },
        { model = 'prop_offroad_tyres01',   label = 'Tyre Stack',     category = 'decor' },
        { model = 'prop_beachflag_le',      label = 'Beach Flag',     category = 'decor' },
    },

    -- Hard limits so one map cannot melt a client.
    limits = {
        props          = 400,
        spawnsPerTeam  = 32,
        capturePoints  = 5,
        boundaryPoints = 32,
    },

    -- Prop used for a flag stand in Capture The Flag.
    flagProp = 'prop_flag_ls',
    -- Prop used for a dropped tag in Kill Confirmed.
    tagProp  = 'prop_paper_bag_small',

    -- Colour of the builder's own markers and placement camera. Anything that
    -- is not a team, a flag or the staging point uses this.
    accent = { 224, 22, 95 },
}

-- Maps in presets/ are loaded into the database the first time the resource
-- starts. Set to false once you have your own.
Config.LoadPresetMaps = true

-- Draw the arena boundary as a wall while you are in a match.
Config.DrawBoundary   = true
Config.BoundaryColour = { 224, 22, 95, 60 }
