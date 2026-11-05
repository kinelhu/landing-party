-- The trailer's action (the user, 2026-11-04: "We barely show any battles, player mustering troops, inter-faction
-- interactions"), from the trailer scenario's fork at minute 8 (scripts/film_fork.sh trailer 12345 14). Ticks and places
-- from a scouting pass of that fork (docs/sim/trailer-12345/trailer-beats.txt gives each beat's start):
--   muster 30 trained at 30000, all 77 at 32400 (barracks at 261,-104); the army leaves at 39600, fights from 41000 to
--   44400 round 390,-160; Kessler-Hayashi's siege of a Grubstake camp drops its pieces 44800, bombards 46600 to 49300
--   (site -541,30, target -573,33), its assault goes in through the breach 49300 to 49900; Synthexis's wave marches 64080,
--   breaks in at 65400 (-39,-286), its gap open 65704, rushes the heart 65844; the armed camp's siege on the player's wall
--   (site -30,269, wall -28,243) deploys 65800, paints 67600, its lances fall 68320, its assault 68321.
--   (Refilmed 2026-11-05 on 0.2.206: the yard, the assault through the breach, the herd through its gap.)
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh trailer-film fork.zip docs/trailer/stage.lua
return {name = "stage", base = 1, army = true, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = 29300, moves = {
  -- Muster: the barracks turning out the army, a timelapse (a frame every 15 ticks: 3000 ticks in 6.7 s).
  {name = "m1-muster", tick = 29400, frames = 200, every = 15, from = {pos = {261, -104}, zoom = 0.9, daytime = 0.2}, to = {pos = {261, -100}, zoom = 0.75, daytime = 0.2}},
  -- The army moving out, tracked.
  {name = "m2-move-out", tick = 39800, frames = 180, track = true, from = {pos = "army", zoom = 0.8, daytime = 0.2}, to = {daytime = 0.2}},
  -- The battle at the Grubstake camp: a lock-off on the line, then tracked on what is left of the army.
  {name = "m3-battle", tick = 41400, frames = 240, from = {pos = {392, -158}, zoom = 0.75, daytime = 0.22}, to = {pos = {396, -158}, zoom = 0.8, daytime = 0.22}},
  {name = "m4-battle", tick = 42600, frames = 240, track = true, from = {pos = "army", zoom = 0.9, daytime = 0.22}, to = {daytime = 0.22}},
  -- Kessler-Hayashi against Grubstake: the drop, then the barrage on the camp.
  {name = "c1-drop", tick = 44750, frames = 180, every = 3, from = {pos = {-548, 31}, zoom = 0.7, daytime = 0.25}, to = {pos = {-550, 31}, zoom = 0.72, daytime = 0.25}},
  {name = "c2-barrage", tick = 47000, frames = 240, from = {pos = {-560, 31}, zoom = 0.6, daytime = 0.26}, to = {pos = {-566, 32}, zoom = 0.7, daytime = 0.26}},
  -- Its assault through the breach (siege.lua open_way: at what stands behind, not the wall beside the gap).
  {name = "c3-assault", tick = 49250, frames = 360, from = {pos = {-556, 32}, zoom = 0.75, daytime = 0.27}, to = {pos = {-568, 33}, zoom = 0.8, daytime = 0.27}},
  -- Synthexis: the herd marching (tracked), its breach, inside.
  {name = "s1-march", tick = 64300, frames = 180, track = true, from = {pos = "wave", zoom = 0.6, daytime = 0.33}, to = {daytime = 0.33}},
  {name = "s2-breach", tick = 65250, frames = 300, from = {pos = {-41, -290}, zoom = 0.75, daytime = 0.34}, to = {pos = {-36, -292}, zoom = 0.8, daytime = 0.34}},
  {name = "s3-inside", tick = 65800, frames = 180, track = true, from = {pos = "wave", zoom = 0.75, daytime = 0.35}, to = {daytime = 0.35}},
  -- The strike on the player's wall: the deploy, then the paint and the lances.
  {name = "k1-deploy", tick = 65850, frames = 180, every = 3, from = {pos = {-30, 262}, zoom = 0.65, daytime = 0.36}, to = {pos = {-30, 260}, zoom = 0.68, daytime = 0.36}},
  {name = "k2-strike", tick = 67700, frames = 1000, from = {pos = {-29, 258}, zoom = 0.5, daytime = 0.38}, to = {pos = {-28, 250}, zoom = 0.75, daytime = 0.38}},
}}
