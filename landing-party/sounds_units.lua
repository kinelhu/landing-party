-- The units' movement and death sounds and the faction cues, round four (the user's picks on the Sound Sheet,
-- 2026-11-15; the board's cards in docs/sound/round4.lua). Read by data-final-fixes.lua (walking and dying sounds on the
-- units and their plated variants) and by control (the cues, shared.cue).
--   slot: walk (walking_sound on its run cycle at positions, so it plays only while moving: a vehicle's one-frame run
--     animation loops every distance_per_frame, half a tile, and its engine plays as a bed capped by its aggregation),
--     die (dying_sound), cue (a sound prototype the script plays at its event);
--   files: the game's own recordings at speed and volume (no copies), or a file of the mod's (sound/...: rendered by
--     tools/sound/round4.py where the board laid a hum or cut a clip, the user having kept the arc flamer's copy);
--   max: the aggregation's max_count (vanilla's own limits: 3, 2 for heavy vehicles, 1 for a cue).
-- Round five (0.2.426): Grubstake's heavy engine, the laser drones' and the harrier's flight, Kessler-Hayashi's steps,
-- the foot units' deaths (Kessler-Hayashi's machines, Grubstake's people), the siege horn and the dome's catch.
local FOOT = {5, 16} -- (Two steps a cycle of the 22-frame run.)
local KH_FOOT = {"lp-infantry", "lp-lance", "lp-railgunner", "lp-sapper", "lp-shock"}
local GS_FOOT = {"lp-grubstake-infantry", "lp-grubstake-lance", "lp-grubstake-railgunner", "lp-grubstake-sapper",
  "lp-grubstake-shock", "lp-grubstake-skyguard"}
return {
  {id = "gs-heavy-engine", slot = "walk", max = 2, positions = {0},
    units = {"lp-grubstake-tank", "lp-grubstake-dozer", "lp-grubstake-howitzer-truck", "lp-grubstake-aegis",
      "lp-grubstake-tesla", "lp-grubstake-prism"},
    files = {"landing-party/sound/gs-heavy-drive.ogg"}, speed = 1, volume = 1},
  {id = "drone-flight", slot = "walk", max = 3, positions = {0}, units = {"lp-laser-drone", "lp-grubstake-laser-drone"},
    files = {"base/sound/fight/distractor-robot-loop.ogg"}, speed = 1.15, volume = 0.55},
  {id = "harrier-flight", slot = "walk", max = 3, positions = {0}, units = {"lp-harrier", "lp-grubstake-harrier"},
    files = {"landing-party/sound/harrier-drive.ogg"}, speed = 1, volume = 1},
  {id = "kh-feet", slot = "walk", max = 3, positions = FOOT, units = KH_FOOT,
    files = {"space-age/sound/entity/mech-armor/mech-armor-land-concrete-1.ogg", "space-age/sound/entity/mech-armor/mech-armor-land-concrete-2.ogg",
      "space-age/sound/entity/mech-armor/mech-armor-land-concrete-3.ogg"}, speed = 1.3, volume = 0.5},
  {id = "kh-death", slot = "die", max = 3, units = KH_FOOT,
    files = {"landing-party/sound/kh-death-1.ogg", "landing-party/sound/kh-death-2.ogg", "landing-party/sound/kh-death-3.ogg"},
    speed = 1, volume = 1},
  {id = "gs-death", slot = "die", max = 3, units = GS_FOOT,
    files = {"landing-party/sound/gs-death-1.ogg", "landing-party/sound/gs-death-2.ogg", "landing-party/sound/gs-death-3.ogg"},
    speed = 1, volume = 1},
  {id = "siege-horn", slot = "cue", max = 1, files = {"landing-party/sound/siege-horn.ogg"}, speed = 1, volume = 1},
  {id = "dome-catch", slot = "cue", max = 2, files = {"landing-party/sound/dome-catch-1.ogg", "landing-party/sound/dome-catch-2.ogg"},
    speed = 1, volume = 1},
  {id = "gs-light-engine-a", slot = "walk", max = 3, positions = {0},
    units = {"lp-grubstake-buggy", "lp-grubstake-slug", "lp-grubstake-scorcher", "lp-grubstake-flak-buggy", "lp-grubstake-hauler"},
    files = {"base/sound/car-engine-driving.ogg"}, speed = 0.8, volume = 0.35},
  {id = "kh-light-engine", slot = "walk", max = 3, positions = {0},
    units = {"lp-buggy", "lp-slug", "lp-scorcher", "lp-flak-buggy", "lp-hauler", "lp-howitzer-truck"},
    files = {"landing-party/sound/kh-light-drive.ogg"}, speed = 1, volume = 1},
  {id = "kh-heavy-engine", slot = "walk", max = 2, positions = {0},
    units = {"lp-tank", "lp-dozer", "lp-aegis", "lp-tesla", "lp-prism"},
    files = {"landing-party/sound/kh-heavy-drive.ogg"}, speed = 1, volume = 1},
  {id = "gs-feet", slot = "walk", max = 3, positions = FOOT,
    units = {"lp-grubstake-infantry", "lp-grubstake-lance", "lp-grubstake-railgunner", "lp-grubstake-sapper",
      "lp-grubstake-shock", "lp-grubstake-skyguard"},
    files = {"base/sound/walking/dirt-1-1.ogg", "base/sound/walking/dirt-1-2.ogg", "base/sound/walking/dirt-1-3.ogg",
      "base/sound/walking/dirt-1-4.ogg"}, speed = 0.85, volume = 0.8},
  {id = "player-feet", slot = "walk", max = 3, positions = FOOT,
    units = {"lp-trooper", "lp-rocket-trooper", "lp-flame-trooper", "lp-breacher", "lp-skyguard"},
    files = {"base/sound/walking/grass-1.ogg", "base/sound/walking/grass-2.ogg", "base/sound/walking/grass-3.ogg",
      "base/sound/walking/grass-4.ogg"}, speed = 1.0, volume = 1.0},
  {id = "death-light", slot = "die", max = 3,
    units = {"lp-buggy", "lp-slug", "lp-flak-buggy", "lp-grubstake-buggy", "lp-grubstake-slug", "lp-grubstake-flak-buggy"},
    files = {"base/sound/fight/car-explosion-1.ogg", "base/sound/fight/car-explosion-2.ogg", "base/sound/fight/car-explosion-3.ogg"},
    speed = 0.95, volume = 0.7},
  {id = "death-heavy", slot = "die", max = 3,
    units = {"lp-tank", "lp-dozer", "lp-hauler", "lp-howitzer-truck", "lp-scorcher", "lp-aegis", "lp-tesla", "lp-prism",
      "lp-battle-tank", "lp-grubstake-tank", "lp-grubstake-dozer", "lp-grubstake-hauler", "lp-grubstake-howitzer-truck",
      "lp-grubstake-scorcher", "lp-grubstake-aegis", "lp-grubstake-tesla", "lp-grubstake-prism"},
    files = {"base/sound/fight/tank-explosion-1.ogg", "base/sound/fight/tank-explosion-2.ogg", "base/sound/fight/tank-explosion-3.ogg"},
    speed = 0.9, volume = 0.8},
  -- (The board laid the robot's blast 12 ticks after the whoosh; the drones' dying explosions already play a robot's
  -- blast, so the whoosh is heard with it at once.)
  {id = "death-drone", slot = "die", max = 3,
    units = {"lp-laser-drone", "lp-harrier", "lp-scavenger", "lp-grubstake-laser-drone", "lp-grubstake-harrier",
      "lp-grubstake-scavenger"},
    files = {"base/sound/fight/robot-die-whoosh-1.ogg", "base/sound/fight/robot-die-whoosh-2.ogg"}, speed = 1.0, volume = 0.5},
  {id = "pods-alarm", slot = "cue", max = 1, files = {"landing-party/sound/pods-alarm.ogg"}, speed = 1, volume = 1},
  {id = "landing-roar", slot = "cue", max = 1, files = {"base/sound/procession/cargo-pod-reentry-flame.ogg"},
    speed = 0.7, volume = 0.6},
  {id = "mast-up", slot = "cue", max = 1, files = {"landing-party/sound/mast-up.ogg"}, speed = 1, volume = 1},
}
