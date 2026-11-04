-- Shot 2 (storyboard), the arrival, from the trailer visit's save at minute 19 (tick 12040691): Grubstake's lander
-- forced down (/lp land grubstake 654) at 12044000; it lands at 10,-676 beyond the factory's north edge. (In the visit it
-- landed by itself at 12044291; a replay from the save diverges and it never came, 2026-11-04. The storyboard named
-- Kessler-Hayashi's landing, at the visit's first tick, before any save.)
return {name = "shot-02", base = 2, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 12043800,
  dev = {{tick = 12044000, args = {"land", "grubstake", "654"}, at = {0, 0}}}, moves = {
  {name = "s02", tick = 12043880, frames = 300, every = 2, from = {pos = {10, -662}, zoom = 0.4, daytime = 0.15}, to = {pos = {10, -664}, zoom = 0.42, daytime = 0.15}},
}}
