# Changelog

## 1.4.0

### Added

- **Hand up and walk off.** Getting marked puts your hand up for the respawn,
  the way it works on a real field.
- **The waiting room is a safe zone.** No firing in it, and none while you are
  marked and waiting to come back on.
- **A goggle vignette** while you are on the field. Subtle, and it can be turned
  off with `Config.Rules.goggles`.
- **A tank on your back** for the length of a match, removed the moment you
  leave. Cosmetic, and `Config.Gear` tunes or disables it.
- **More in the host panel**: restart the round, set the next map, and the round
  number in the header, alongside end and swap sides. It now pulls live data
  from the server instead of rendering a stale roster.
- `/pbpresets` re-imports the shipped maps over the stored copies.

### Changed

- **Melee is gone.** It is paintball. The eight melee weapons are out of the
  weapon list, out of the Gun Game ladder, and out of the modes that handed one
  out. The slot itself still exists in config for anyone who wants it back.
- Ammo reads as **paint** on the loadout bar.

### Fixed

- **Props still floated.** Two separate causes. `PlaceObjectOnGroundProperly`
  is unreliable on a static object, so placement is now worked out directly:
  raycast for the real surface, then use the model's own dimensions to sit its
  base on it — a container's origin is its centre, which is why they hovered by
  half their height. And `Store.LoadPresets` imports a preset once and never
  again, so a corrected map file did nothing on a server that already had the
  old one. `/pbpresets` pushes the fix through.
- **The map vote could not be voted in.** 1, 2 and 3 are the game's own weapon
  select, so the keypress swapped your gun and never reached the vote. Those
  controls are now disabled while a vote is open.
- **Ending a match by hand no longer opens a map vote.** Somebody pulling the
  plug did not mean to start a poll.
- The in-world leaderboard board no longer gives up for the session when the
  config is missing the `board` block — it says so once and keeps checking.


## 1.3.2

### Fixed

- Inventory swapping could never work. The stash save checked
  `MySQL.prepare.await(...) ~= nil`, and oxmysql returns nil for a prepare
  INSERT whether it succeeded or not — so the check was always false, the save
  always "failed", and the safety path correctly refused to wipe every single
  time. The snapshot is now written and then **read back and compared** before
  anything is emptied, which is the guarantee that was wanted in the first
  place.
- On startup, if `manageInventory` is on but the `xs_paintball_stashes`
  table is missing or no inventory resource was found, it says so once and
  switches the feature off, rather than failing quietly on every match.
- A leftover stash from a previous run is now reported at startup.


## 1.3.1

### Fixed

- `Stash` had no fallback, so a missing `server/loadout.lua` crashed match
  start on `server/match.lua:229` instead of quietly turning inventory
  swapping off. The module was added after the fallback list was written and
  never added to it.
- `tools/check-fallbacks.mjs`: every global a loadable file defines now has to
  be either listed as core or covered by a fallback, so adding a module forces
  that decision rather than leaving a hole to find in game. Proven by removing
  `Stash` from the list and watching it fail.
- `tools/check-all.mjs` runs every checker in one command.


## 1.3.0

### Added

- **A loadout bar** along the bottom: three slots, the key for each, live ammo,
  and the one in your hands lifted and filled in. Reads the ped rather than
  trusting what the server handed out, so a gun taken off you shows as gone.
- **Your side down the left**, with alive, out and who is talking. Talking comes
  from the game, not the voice resource, so it works with any of them.
- **Host controls on F7** during a match — end it, swap sides, kick somebody —
  without leaving the arena. Server re-checks host or admin on every action.
- **Paint on the world.** Every landed shot leaves a splat in your team's colour
  on whatever it hit. A base game decal tinted to the team, so no assets.
- **A leaderboard board** at the staging area to walk up and read.
- **Inventory swapping.** Joining a match can snapshot the inventory, save it to
  the database, empty it and hand over the loadout as items, then give it all
  back afterwards. The snapshot is always taken and saved before anything is
  emptied — if either step fails the inventory is left alone and the match runs
  on ped weapons, so a bad read cannot cost anybody their items. Restores also
  fire on leaving, disconnecting, the resource stopping, and next login if the
  server went down mid-match. `/pbrestore <id>` is the manual escape hatch.

### Changed

- **Payouts are gone.** No money for winning, losing or getting kills. Wagers
  are the only thing that moves money, and a match without one costs and pays
  nothing.

### Fixed

- Props in the shipped presets floated, because they were generated at a flat
  ground height and a container's origin is its centre. Props now carry a
  `ground` flag and settle onto whatever is under them; both presets set it.
  In the builder, **G** toggles it while placing.
- Optional features can no longer crash the match. `Sounds` and `Dispatch`
  are guarded at their call sites as well as in the fallbacks file — one missing
  file was aborting match start before the loadout was ever handed out, which is
  what made props appear with no weapons and no HUD.


## 1.2.1

### Fixed

- One file failing to load took the whole panel down. `/paintball` died on
  `attempt to index a nil value (global 'Queue')` because `server/queue.lua`
  had not loaded, and the stack pointed at the caller rather than at the missing
  file. Optional modules now switch themselves off and the console names the
  file to go and fetch, on both the server and the client.
- `tools/check-manifest.mjs`: fxmanifest and the folder have to agree. Catches
  a file on disk that is not in the manifest (so it never loads), a manifest
  entry with no file behind it, and anything index.html pulls in that is missing
  from `files{}`.


## 1.2.0

### Added

- **Rounds.** Single, or best of three, five or seven. Sides swap at the halfway
  point and round wins follow the players across the swap, not the colour. Kills
  and deaths carry across the match; scores reset each round. A round scoreboard
  fills the break in between, and round two onwards reuses the props and the
  world override instead of tearing the arena down and rebuilding it.
- **Map vote** on the end screen. Three maps, press 1 to 3, highest wins, ties
  broken at random, and no votes at all picks one at random.
- **Quick play queue.** Wait at the staging area and the server opens a lobby as
  soon as enough people are queued. Same join rules, and wandering off loses
  your place.
- **Team voice.** Each team on its own radio channel for the match, proximity
  untouched underneath. pma-voice wired directly, everything else through a
  generic hook. Every call is wrapped so a signature change costs team voice and
  not the match.
- **Sound**, all of it from the base game so nothing needs streaming: match
  start, round end, kills, headshots, eliminations, respawns, hitmarkers,
  killstreaks, captures, the boundary warning, and win and loss stings. Custom
  audio can be routed through interact-sound or any resource with a play export.

### Changed

- The staging area and the entry ped now sit at the same coordinates. With
  `requireStaging` on they have to: otherwise you could open the panel at the
  ped and still be refused the join. One blip between them rather than two.
- Team colours and the notification palette now match the panel exactly, so
  blips, flags, markers and toasts all read as one thing.


## 1.1.0

### Added

- **A staging area.** `Config.Staging` is where the crowd waits, in its own
  routing bucket so they are invisible to the city and cannot be shot standing
  around. Joining puts you there, leaving puts you back exactly where you were.
- **Join rules**, all checked on the server. You have to be at the staging area,
  out of a vehicle, on your feet, and not have been in a fight in the last 45
  seconds. The combat check reads the server's own damage event, so it counts
  real hits rather than anything a client claims. That is what stops someone
  diving into a match to lose a chase.
- **A way to keep paintball off your dispatch board.** There is no NPC police in
  FiveM so there is no wanted level involved; what matters is your dispatch or
  MDT resource. Three ways to hook it: a client and server export to ask, an
  event to react to, and `Config.Dispatch.mute` to call a mute function your
  dispatch already has.
- **Cosmetic unlocks.** Weapon tints and clothing kits earned by level or wins,
  picked in a new Unlocks tab. A kit is worn only inside a match — whatever the
  player walked in wearing is captured first and put back at the end, so their
  real character is never modified.
- **Force start.** Admins get a button in the lobby and `/pbstart <id>`, both
  skipping the host check and the player minimum so a one-player test works.

### Fixed

- Two pieces of config the builder let you place but nothing ever read: the
  per-map staging point and the spectator cameras. The first is now the spawn
  fallback for a mode with no spawns placed (and is labelled "Fallback point",
  so it is not confused with the server-wide staging area), and the first
  spectator camera is now where a spectator's view starts.

### Removed

- The wanted level tick. FiveM has no NPC police, so clearing a wanted level
  every second was doing nothing.


## 1.0.0

First release.

### Added

- **A screen-printed look, not the usual dark panel.** Ink on paper, hard rules
  and offset blocks instead of glow and blur, poster type, and paint splatter
  doing the work colour usually does. Tabs run across the top rather than down a
  sidebar. The in-match HUD is the same language — paper chips, taped banners
  and a spray-filled paint gauge — so the panel and the HUD read as one thing.
- **An in-game map builder.** Boundary (circle or polygon), team and free-for-all
  spawns, flag stands, capture points, cover props, a staging point and spectator
  cameras, all placed from a free camera with grid snapping, drop-to-floor and
  fine nudging. The panel says which modes a map can run and what is stopping the
  rest. Maps export and import as JSON.
- **Eight game modes** — Team Deathmatch, Free For All, Capture The Flag,
  Domination, Kill Confirmed, Gun Game, One In The Chamber and Hold Your Own.
- **Lobbies with real isolation.** Up to eight matches at once, each in its own
  routing bucket. Join code, optional passcode, host settings that can be changed
  while people wait, auto team balance, kicking, and spectating with a free or
  follow camera.
- **A paint pool instead of health.** Nobody actually dies, so no medical script
  ever fires. Headshots eliminate outright, friendly fire is a host setting, and
  a spawn shield covers you until you take the first shot.
- **Killstreaks** — UAV, resupply, paint vest and death machine, all configurable.
- **Wagers and payouts.** Pot split among winners after a house cut, refunded on
  a draw, plus flat win, loss and per-kill payouts. Optional ticket item and an
  optional business account for the cut.
- **Progression.** XP, one hundred levels, weapon unlocks, an all-time and weekly
  leaderboard, per-player stats and a match history.
- **Loadouts** with over fifty weapons, three saved presets per player, and team
  outfits saved with `/redoutfit` and friends.
- Two preset maps built out of props on open tarmac, loaded on first start.
- Bridges for QBox and QBCore, ox_target and qb-target with a marker fallback,
  and six inventories. Nothing outside `bridge/` names another resource.
- Server events (`matchStarted`, `playerEliminated`, `matchEnded`) and read-only
  exports for anything you want to build on top.
