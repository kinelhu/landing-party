-- Shots 6 and 8 (storyboard), from the trailer visit's save at minute 9 (tick 12004751): Synthexis's farm 1 at 700,-281
-- as its first wave gathers (bred at 12009300), and Kessler-Hayashi's fortress at -99,566 growing (a frame every 120
-- ticks over 6 minutes, played at 30 fps).
return {name = "shots-06-08", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 12005400, moves = {
  -- 8: the fortress, a lock-off timelapse, a whip pan out over the last frames.
  {name = "s08", tick = 12005500, frames = 180, every = 120, from = {pos = {-99, 566}, zoom = 0.35, daytime = 0.36}, to = {pos = {-99, 566}, zoom = 0.35, daytime = 0.37}},
  -- 6: a drift across the creep's edge, the herd gathering.
  {name = "s06", tick = 12009300, frames = 180, from = {pos = {680, -281}, zoom = 0.5, daytime = 0.3}, to = {pos = {720, -281}, zoom = 0.5, daytime = 0.32}},
}}
