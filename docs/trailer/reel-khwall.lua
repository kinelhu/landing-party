-- Kessler-Hayashi at the user's own wall (the user, 2026-11-05, on reel-fortress's test wall: "feels too tame... the
-- wall in that doesn't reach the bottom of the screen it feels staged"): nw's south wall, three rows at y 319 to 321 from
-- x -366 to 447, three lasers every 10.5 tiles, a roboport every 32 behind them at y 304, a walled laser bastion south of
-- it at -145,341. The camp is the one the game landed at -99,566 (an armed camp, era 4 by research) and its siege is its
-- own: nothing forced. Visit mix LP_MIX=khwall (tests/lp-sim/control.lua), saved at minute 15 (tick 12026291) by
-- scripts/visit_saves.sh with LP_MIX=khwall-saveat15.
-- Its beats from that save, run on headless as film.sh loads it (Landing Party alone, trace off; the same with trace on):
--   12031200  march: a tier 2 drop siege on the bastion's substation (-144,339), 18 guards from -99,527, site -137,374
--   12032800  deploy: 3 pods come down at the site; 12033420 its guns stand: mortars -139,375 and -135,374, howitzer
--             -126,372, a jamming mast
--   12034600  bombard: the fire plan on the bastion's roboport (-144,336), then the roboports behind the wall (-112,304,
--             -144,304); its orbital strike painted at -142,351 (12 s)
--   12035320  the strike falls: 25 shells on the lane and the 13 lasers covering it (lasers 64 to 51 in the box
--             x -230..-50, y 296..400, wall pieces 410 to 374); 12035321 the assault, 18 through the bastion's breach to
--             -142,351; 12035800 it falls back, 17 of 18, nothing left standing within 30 of the breach
--   12035820  bombard again from -137,374 on the roboports behind the wall (-80,304, -176,304, -112,304)
--   12037900  it moves up: lifted, 2 pods at -140,349 (12038200), mortars stand at -139,348 and -140,351 (12038820)
--   12040000  bombard from the bastion's foot, 30 tiles from the wall, over it: roboports at y 304 and lasers at y 317
--             (-132,317, -124,317, -144,315), the player's robots rebuilding between; shells resupplied from orbit
--             (pods 12046300, 12047500); 160 shells in all
--   12057700  packs up; 12058300 done, 17 of 17 home, 177 of the player's razed
-- Moves timed on its events (phase:deploy, phase:bombard, falling, phase:assault: the first of each after the save) where
-- they can be; the battery's second emplacement by tick (its phases were seen before).
-- No LP_FILM_SIM: nothing of the harness acts after the save.
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/trailer/reel-khwall.lua
return {name = "reel-khwall", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = "phase:deploy",
  moves = {
  -- Pods coming down at its site, its guns assembled where they land.
  {name = "k1-drop", after = "phase:deploy", dt = 0, frames = 330,
    from = {pos = {-133, 378}, zoom = 0.6, daytime = 0.3}, to = {pos = {-134, 376}, zoom = 0.7, daytime = 0.3}},
  -- The guns and the wall in one frame (guns at the bottom, the wall across the top, the bastion between): the first
  -- shells' arcs and its strike's paint, till the fall.
  {name = "k2-guns-wall", after = "phase:bombard", dt = 0, frames = 360,
    from = {pos = {-136, 347}, zoom = 0.5, daytime = 0.3}, to = {pos = {-137, 347}, zoom = 0.52, daytime = 0.31}},
  -- The strike: shells from orbit along the lane and on the lasers covering it, the wall across the top of the frame.
  {name = "k3-strike", after = "falling", dt = 0, frames = 120,
    from = {pos = {-142, 338}, zoom = 0.6, daytime = 0.31}, to = {pos = {-142, 339}, zoom = 0.62, daytime = 0.31}},
  -- The assault through the breach it opened in the bastion.
  {name = "k4-assault", after = "phase:assault", dt = 240, frames = 240,
    from = {pos = {-141, 352}, zoom = 0.75, daytime = 0.31}, to = {pos = {-142, 345}, zoom = 0.8, daytime = 0.31}},
  -- Close on the battery firing (its first emplacement, on the roboports behind the wall).
  {name = "k5-battery", after = "phase:bombard", dt = 1400, frames = 360,
    from = {pos = {-132, 374}, zoom = 1.0, daytime = 0.31}, to = {pos = {-131, 373}, zoom = 1.1, daytime = 0.32}},
  -- Close on the battery moved up to the bastion's foot, firing over the wall.
  {name = "k6-battery-up", tick = 12041000, frames = 360,
    from = {pos = {-139, 351}, zoom = 1.1, daytime = 0.32}, to = {pos = {-139, 349}, zoom = 1.2, daytime = 0.32}},
  -- Close on the wall taking it: lasers at y 317 and the roboports behind, the robots mending between hits.
  {name = "k7-wall", tick = 12042600, frames = 450,
    from = {pos = {-128, 312}, zoom = 0.8, daytime = 0.32}, to = {pos = {-130, 312}, zoom = 0.85, daytime = 0.33}},
  -- Wide over the wall: the battery at the bottom, the arcs over the wall onto the roboports behind it.
  {name = "k8-over", tick = 12044400, frames = 450,
    from = {pos = {-135, 330}, zoom = 0.6, daytime = 0.33}, to = {pos = {-135, 328}, zoom = 0.58, daytime = 0.34}},
}}
