# XS-Paintball

Paintball arenas with eight game modes, killstreaks and wagers — and a map
builder that runs in game, so your arenas are yours.

No config coordinates to copy. Fly around, drop the boundary, place spawns, build
cover out of props, save it. That map is live for every lobby the moment you hit
save.

Standalone for QBox and QBCore.

## Install

1. Import `sql/xs_paintball.sql`.
2. Drop the folder in your resources and `ensure XS-Paintball` after
   `ox_lib` and `oxmysql`.
3. Set your entry point in `config.lua` — `Config.EntryPoints` — or set
   `Config.OpenAnywhere = true` and use `/paintball`.
4. Set `Config.Staging.coords` to wherever you want the paintball crowd to
   gather. Players have to be standing there to join a match.

Two maps ship with it and load on first start. They are built out of props on
open tarmac, so they work anywhere and are a decent starting point to pull apart
in the builder. Turn them off with `Config.LoadPresetMaps = false`.

## The builder

`/pbbuild`, or the Maps tab if you are an admin.

Every button drops you into a free camera. WASD flies, the mouse aims, ENTER
places, BACKSPACE cancels. SPACE pins the point where it is so you can fly around
and look at it, X drops it to whatever floor is underneath, Z cycles grid
snapping and CTRL nudges ten times finer.

What you place:

| Thing | What it does |
|---|---|
| Boundary | A circle, or a polygon you walk the corners of. Leave it and you get a countdown, then you are out. |
| Team spawns | Red, blue, green and yellow. The server picks the one furthest from the nearest enemy. |
| Free-for-all spawns | One shared pool for the solo modes. |
| Flags | A stand each for red and blue. Two of them switches Capture The Flag on. |
| Capture points | Up to five, each with its own radius. One or more switches Domination on. |
| Props | Anything your server streams. This is how you build an arena in an empty field. |
| Fallback point | Where anyone lands if they spawn into a mode with no spawns placed. Optional — this is per map, and is not the same thing as `Config.Staging`, which is the server-wide waiting room. |
| Spectator cameras | Where a spectator starts. Optional. |
| Weather and time | Forced inside the match, put back when it ends. |

The panel tells you which modes the map can run and why one is greyed out. A map
with no boundary or no spawns will not save.

Maps export to JSON and import back, so an arena travels between servers as a
block of text. Nothing about it is tied to our map or our items.

## Game modes

| Mode | Teams | How it ends |
|---|---|---|
| Team Deathmatch | 2 | First team to the score limit |
| Free For All | — | First player to the score limit |
| Capture The Flag | 2 | Three captures. Your own flag has to be home to score |
| Domination | 2 | Points tick while you hold a capture point |
| Kill Confirmed | 2 | Kills only count once somebody picks up the tag |
| Gun Game | — | Every kill moves you up the ladder. Finish it to win |
| One In The Chamber | — | One bullet, one hit kill, a fixed number of lives |
| Hold Your Own | 2 | Each team shares a pool of lives. Run it dry and you lose |

Any of them can be switched off in `config.lua`.

## Lobbies

Up to eight matches run at once and each gets its own routing bucket, so two
lobbies on the same map never see each other, and neither does the rest of the
city.

The host names the lobby, picks the mode and map, sets the score limit, time
limit, respawn delay, spawn shield, friendly fire, wager and player cap, and can
lock it with a passcode. Everyone else joins from the browser or with the
five-character code. Anyone can spectate a live match — free camera, or follow a
player with A and D.

## The staging area, and nobody escaping into a match

`Config.Staging` is where the paintball crowd gathers. Joining a lobby puts you
there, leaving puts you back exactly where you were, and the waiting room runs in
its own routing bucket — so the crowd is invisible to the rest of the city and
cannot be shot while they stand around.

That also closes the obvious hole. `Config.JoinRules` decides who gets in, and
every one of these is read on the server, so none of it can be faked:

| Rule | Default | What it stops |
|---|---|---|
| `requireStaging` | on | Joining from anywhere but the staging area. This is the one that stops someone diving into a match to lose a chase. |
| `combatCooldown` | 45s | Joining right after shooting someone or being shot. Counted from the server's own damage event, so it is real hits, not anything a client claims. |
| `blockInVehicle` | on | Joining from the driver's seat. |
| `blockWhenDead` | on | Joining while down. |

Set the staging coordinates to wherever you want people to gather — an arena, a
warehouse, a car park. Anywhere with room to stand.

## Keeping paintball off the dispatch board

There is no NPC police in FiveM, so there is no wanted level to clear and this
script never touches one. What actually reports gunfire is your dispatch or MDT
resource watching for it client side, and nothing in here can reach inside that.

So it gives them three ways to ask. Use whichever fits:

```lua
-- 1. Ask at the moment you are about to alert
if exports['XS-Paintball']:IsPlayerInMatch() then return end        -- client
if exports['XS-Paintball']:IsInMatch(source) then return end        -- server

-- 2. Or react to the change and mute yourself
AddEventHandler('XS-Paintball:client:matchStateChanged', function(inMatch)
    MyDispatch.muted = inMatch
end)
```

3. Or, if your dispatch already has a mute function, name it in
`Config.Dispatch.mute` and it gets called on match start and match end with a
single boolean. No patching either resource.

## Rounds, votes and quick play

**Rounds.** A match is a single round by default, or a best of three, five or
seven. Sides swap at the halfway point so nobody is stuck on the worse half of
the map, and round wins follow the players across the swap rather than staying
with the colour. Kills and deaths run across the whole match; scores and streaks
reset each round. Between rounds there is a short break on a round scoreboard.

**Map vote.** On the end screen everybody gets three maps and presses 1, 2 or 3.
Highest wins, a tie is broken at random between the tied maps, and the winner
becomes the lobby's next map. Nobody voting picks one at random.

**Quick play.** Instead of picking a lobby, hit Quick play and wait at the
staging area. As soon as there are enough people queued the server opens a lobby
and drops everyone into it. Same join rules apply, so you still have to be
standing at the staging area, and anyone who wanders off loses their place.

## Team voice

Each team gets its own radio channel for the length of the match, so a side can
talk across the arena. Proximity carries on working underneath it, unchanged.

Only **pma-voice** is wired directly, because it is the one with a stable
server-side call for this. Anything else goes through the generic hook:

```lua
Config.Voice.provider = 'generic'
Config.Voice.generic = {
    resource = 'my-voice',
    join     = 'AddPlayerToChannel',   -- exports[resource][join](source, channel)
    leave    = 'RemovePlayerFromChannel',
}
```

Every voice call is wrapped, so if an update changes a signature the match keeps
running and only team voice goes quiet. Set `Config.Voice.enabled = false` to
leave voice alone entirely.

## Sound

Every cue is a base game sound, so nothing needs streaming: match start, round
end, kills, headshots, eliminations, respawns, hitmarkers, killstreaks,
captures, the boundary warning, and win and loss stings.

A frontend sound name that does not exist is a no-op rather than an error, so if
you swap one in `Config.Sounds.events` and hear nothing, the name is wrong
rather than the code. To use your own audio instead, point
`Config.Sounds.resource` at a sound resource and give each event a `file`.
`interact-sound` works directly; anything else takes an export name.

## In the arena

**The loadout bar** sits along the bottom: your three slots, the key that
switches to each, live ammo, and the one in your hands lifted and filled in.
A slot greys out if something took the gun off you.

**Your side** runs down the left: who is alive, who is out, and who is talking.
The talking indicator reads the game rather than the voice resource, so it works
whatever you run.

**Host controls** are on **F7** during a match — end it now, swap sides, or kick
somebody, without leaving the arena. The full panel stays blocked mid-match on
purpose. The server re-checks host or admin on every action, and admins get in
too.

**Paint on the world.** Every shot you land leaves a splat in your team's colour
on whatever it hit, and they build up over a match. It is a base game decal
tinted to the team, so it needs no assets — turn it off or retune the size and
lifetime in `Config.PaintEffects.decals`.

**A leaderboard board** stands at the staging area. Walk up and read the top of
the table without opening anything. Move it with `Config.Leaderboard.board`.

## Inventories

With `Config.Loadout.manageInventory` on, joining a match snapshots the
player's inventory, saves it to the database, empties it, and hands over the
loadout weapons as items. Everything goes back at the end — and also on leaving,
disconnecting, the resource stopping, or the next time they load if the server
went down mid-match.

The order is deliberate and worth knowing: **the snapshot is taken and saved
before anything is emptied.** If either step fails, the inventory is left
completely alone and the match runs on ped weapons instead, so a bad read can
never cost anybody their items. If a restore ever fails the stash is kept rather
than dropped, and `/pbrestore <id>` puts it back by hand.

Turn it off and the ped's weapons are swapped while the inventory is untouched.

## Feel

Getting marked puts your hand up for the respawn, the way it does on a real
field. The waiting room is a safe zone — no firing in it, and none while you are
marked. There is a soft goggle vignette while you are on, a tank on your back for
the length of the match, and every shot you land leaves a splat in your team's
colour on whatever it hit. Ammo reads as paint.

All of it is asset-free and all of it can be switched off: `Config.Rules`
carries `handsUpWhenOut`, `safeZone` and `goggles`, `Config.Gear` the
tank, and `Config.PaintEffects.decals` the splats.

## Nobody actually dies

There is no death handling to hook up. A hit takes paint off a pool instead of
health, and running out eliminates you and starts a respawn timer. Your ped never
dies, so your ambulance script never fires, and your inventory, health and armour
come back exactly as they were when you leave.

It does that without ever pushing anyone above 200 health, so anticheats stay
quiet: real weapon damage is scaled down for everyone in the match and the paint
pool scales it back up. Guns hit exactly as hard as they should, nothing can be
lethal, and `Config.Rules.damageModifier` is there if your server streams
something that hits harder than vanilla.

Headshots eliminate outright. Friendly fire is off unless the host turns it on,
and a spawn shield covers you until it runs out or you take the first shot.

## Killstreaks

Earned on kills in one life, and configurable in `config.lua`:

- **UAV** at 4 — every enemy on your team's radar for thirty seconds
- **Resupply** at 6 — full ammo
- **Paint Vest** at 7 — more paint for this life
- **Death Machine** at 10 — a minigun for forty-five seconds

Gun Game and One In The Chamber ignore them, because they hand out their own
weapons.

## Wagers and payouts

Wagers are per lobby and taken when the match starts. Winners split the pot after
the house cut; a draw refunds everyone.

That is the only money that moves. There is no payout for winning, losing or
getting kills, so a match with no wager on it costs nothing and pays nothing.
Turn wagers off entirely with `Config.Economy.enabled = false`.

`Config.Economy.business` routes the house cut into a business account through
whatever resource you use for that. `Config.Economy.ticketItem` makes a match
cost an item instead of, or as well as, cash.

## Progression

Kills, headshots, assists, captures, streaks and results earn XP. Levels unlock
weapons — four are locked by default and the list is yours to change. There is an
all-time and a weekly leaderboard, per-player stats and a match history.

Turn the lot off with `Config.Progression.enabled = false` and everyone gets
every weapon.

## Unlocks

Levels and wins also earn cosmetics, picked in the Unlocks tab.

**Weapon tints** are the eight vanilla ones and need no assets at all — they go
on whatever you are carrying.

**Kits** are clothing sets worn only inside a match. The kit goes on when the
match starts and comes off when it ends: whatever the player walked in wearing is
captured first and put back afterwards, so their real character is never
modified. A kit beats the personal `/redoutfit` team kit when the player has
picked one.

The drawable and texture numbers in `Config.Cosmetics.kits` are **examples** —
take the real ones from your clothing menu, because they differ on every server
that streams custom clothing and differ again between the male and female
freemode models. The first kit is deliberately empty and means "your own
clothes", so nothing looks broken before you have set the others up.

Turn it all off with `Config.Cosmetics.enabled = false`.

## Loadouts

Forty-odd weapons across rifles, SMGs, shotguns, snipers, LMGs and sidearms,
plus a paint sprayer. No melee — it is paintball. Add your own addon weapons by putting the spawn name
in `Config.Weapons`. Players pick a primary and a secondary, and can save three presets.

Real weapons are taken off the ped for the match and given back after. Nothing
leaves the inventory, so nothing can be lost.

## Commands

| Command | Who | What |
|---|---|---|
| `/paintball` | anyone | Opens the panel |
| `/pbleave` | anyone | Leave the lobby or forfeit the match |
| `/redoutfit`, `/blueoutfit`, `/greenoutfit`, `/yellowoutfit` | anyone | Saves what you are wearing as that team's kit |
| `/pbbuild` | admin | Opens the builder |
| `/pbreload` | admin | Reloads maps and settings from the database |
| `/pblobbies` | admin | Lists open lobbies |
| `F7` | host | Host controls during a match |
| `/pbstart <id>` | admin | Force starts a lobby, ignoring the player minimum |
| `/pbrestore <id>` | admin | Gives a player a stashed inventory back by hand |
| `/pbpresets` | admin | Re-imports the shipped maps over the stored copies |
| `/pbend <id>` | admin | Ends or closes a lobby |
| `/pbstats` | admin | Prints the leaderboard |

## What it works with

Nothing is required beyond `ox_lib` and `oxmysql`.

- **Framework** — QBox (`qbx_core`) or QBCore (`qb-core`), auto-detected
- **Target** — `ox_target` or `qb-target`, or a marker and an E prompt if you run
  neither
- **Inventory** — `ox_inventory`, `qb-inventory`, `qs-inventory`,
  `codem-inventory`, `core_inventory` or `ps-inventory`, only used if you set a
  ticket item
- **Voice** — `pma-voice` for team channels, or any voice resource through
  `Config.Voice.generic`. Optional; proximity works either way
- **Sound** — `interact-sound` if you want your own audio instead of the base
  game cues. Optional

No other XS script is a dependency, and none of them is required for any part
of this to work.

## Hooks

Server side, three events fire with everything you need to build levelling,
achievements or logging on top:

```lua
AddEventHandler('XS-Paintball:matchStarted', function(data)
    -- lobby, mode, map, wager, players (server ids)
end)

AddEventHandler('XS-Paintball:playerEliminated', function(data)
    -- lobby, mode, victim, victimSource, killer, killerSource, headshot, streak
    -- victim and killer are citizenids. killer is nil for a self-elimination.
end)

AddEventHandler('XS-Paintball:matchEnded', function(data)
    -- lobby, mode, map, winner, duration, pot, players
end)
```

And read-only exports:

```lua
exports['XS-Paintball']:GetLobbies()
exports['XS-Paintball']:GetLobbyFor(source)
exports['XS-Paintball']:IsInMatch(source)
exports['XS-Paintball']:GetProfile(citizenid)
exports['XS-Paintball']:GetLeaderboard('all', 'kills')
exports['XS-Paintball']:GetMaps()

-- client side
exports['XS-Paintball']:IsPlayerInMatch()
```

## Config

`config.lua` holds what applies to the whole resource — bridges, admin access,
entry points, modes, weapons, killstreaks, payouts, progression and the prop list
the builder offers you. Everything about an individual map lives in the database
and is built in game.

A handful of switches are in the Settings tab instead, so you can change them
without a restart: wagers, killstreaks, default friendly fire, auto balance,
spectators, progression, lobby count and the payout numbers.

## License

Free to use on any server you own or operate, including commercial. Modify it for
your own server. No redistribution and no resale. See [LICENSE](LICENSE).
