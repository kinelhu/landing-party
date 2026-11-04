-- Shots 4, 5 and 14 (storyboard), from the trailer visit's save at minute 38 (tick 12109091: a
-- save's tick is when the server wrote it, not minute x 3600; frames before it never come): Grubstake's camp (lander
-- 3,-654) after 19 minutes; a raid forced on the factory's wall nearest it (/lp raid), tracked on its escort; the end
-- card's pull-out over the factory at dawn.
return {name = "shots-04-05-14", base = 2, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = 12109150,
  dev = {{tick = 12109200, args = {"raid", "2"}, at = {wall = true}}}, moves = {
  {name = "s04", tick = 12109200, frames = 180, from = {pos = {6, -665}, zoom = 0.4, daytime = 0.2}, to = {pos = {6, -665}, zoom = 0.6, daytime = 0.2}},
  {name = "s05", tick = 12111600, frames = 240, from = {pos = "escort", zoom = 0.7, daytime = 0.2}, to = {off = {0, 8}, daytime = 0.2}},
  {name = "s14", tick = 12112200, frames = 180, from = {pos = {0, 0}, zoom = 0.5, daytime = 0.78}, to = {pos = {0, 0}, zoom = 0.3, daytime = 0.78}},
}}
