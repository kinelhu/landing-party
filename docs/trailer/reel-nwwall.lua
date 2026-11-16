-- Synthexis at the user's own wall (the user, 2026-11-05: "make use of my wall design on nw/nwa at least to make the
-- synthexis attacks more realistic"): nwa's north wall (an outer wall, a double wall and two more behind it, lasers every
-- 6 tiles, a flamethrower line 10 tiles back), the culture landed by the mod north of it at 16,-923 (its own landing and
-- incubators), its wave staged by the visit's LP_MIX=nwwallheavy (tests/lp-sim/control.lua): 200 of a siege's kind
-- (30 big bursters, 30 cinders, 60 behemoths, 80 big biters) sent at minute 12 with its farm's plan, at 7,-397, 30 tiles
-- past the wall on its line to spawn. Saved at minute 13 (tick 30881784) by scripts/visit_saves.sh, before its march.
-- Its beats from that save, run on headless (Landing Party alone, as film.sh loads it; ticks after the save):
--   march   +4356  herd of 203 sets out from 7,-916
--   breach  +7440  its group at -8,-471; breach point -17,-418, 10 big bursters sent at the guns ahead
--   gap     +7954  open at -13,-426 (the outer wall); its bursts go off on the walls and the lasers behind them
--   inside  +8308  4 to 6 through, each at its own target round 6,-408
--   end     +8496  all dead: about 160 to the flamethrowers, 30 to the lasers; 118 wall pieces, 9 lasers, a flamethrower
--                  and 4 poles broken
-- The wall held: the gap opens and the bursts are real, the flood past it burns. (A milder herd, megaburst's 150 mediums,
-- 30 big, 20 cinders and 6 big bursters: 41 wall pieces, no gun, 3 home.)
-- No LP_FILM_SIM: nothing of the harness acts after the save (the wave was sent at minute 12).
--   scripts/film.sh nwa-nwwallheavy-saveat13 t13.zip docs/trailer/reel-nwwall.lua
-- (t13.zip re-saved headless on 0.2.429, 2026-11-16, auto_pause, its tick kept at 30881788: the 11-05 save held the
-- film at the migrated-content dialog; the original is kept as t13-pre-resave.zip. Refilmed on it: the breach as before,
-- the wave in Synthexis's graded colours; gallery still 03 is frame w2-breach 270.)
return {name = "reel-nwwall", base = 1, waves = true, resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "wave:march", moves = {
  -- The herd crossing open ground, tracked, the camera leading it south till the wall comes into the bottom of the frame.
  -- (A pan along the herd's own way on 0.2.320's save, not a track: its group point ran about 22 tiles ahead of it, and
  -- tracked, with a lead or without, the herd sat on the frame's top edge and left it; the scouting takes. The camera
  -- there went 31,-594 to 15,-496 in the shot: the herd 22 tiles behind.)
  {name = "w1-march", after = "wave:march", dt = 2400, frames = 300,
    from = {pos = {33, -616}, zoom = 0.55, daytime = 0.3}, to = {pos = {15, -518}, daytime = 0.31}},
  -- Locked on the breach from its first tick: the big bursters at the wall, the gap, the rush, the flamethrowers.
  -- (0.2.338, the user: "shows solar panels on half the screen, we don't see the coming biter wave": on the breach
  -- point (3.3,-401.6, 8 tiles inside) the outer wall (-425) was at the frame's top edge and the herd beyond it; now on
  -- the outer wall's line from the film log's breach point, the approach above it, the flamethrower line (-402) last.)
  {name = "w2-breach", after = "wave:breach", dt = 0, frames = 600,
    from = {pos = {3.3, -430}, zoom = 0.55, daytime = 0.31}, to = {pos = {3.3, -424}, zoom = 0.6, daytime = 0.33}},
  -- After: the broken wall, pulling out over the line. (Timed on the breach: the film reads a stage only while the wave
  -- has a group, and inside its biters each go their own way.)
  {name = "w3-after", after = "wave:breach", dt = 1200, frames = 240,
    from = {pos = "breach", zoom = 0.8, daytime = 0.33}, to = {off = {0, 0}, zoom = 0.45, daytime = 0.34}},
}}
