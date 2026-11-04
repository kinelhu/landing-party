-- Action for shots 10 and 11: Kessler-Hayashi's drop siege on the fortress scenario's laser wall (its fork at minute 14),
-- the barrage and the assault in ranks, at dusk.
--   LP_FILM_SIM=<fork's sim dir> scripts/film.sh fortress-film fork.zip docs/trailer/act-kh-assault.lua
return {name = "act-kh-assault", base = "siege", resolution = {1920, 1080}, anti_alias = true, speed = 8,
  fast_until = "phase:deploy", moves = {
  {name = "k1-bombard", after = "phase:bombard", dt = 200, frames = 240, from = {pos = "escort", zoom = 0.55, daytime = 0.36}, to = {off = {0, -8}, daytime = 0.37}},
  {name = "k2-assault", after = "phase:assault", dt = 0, frames = 360, from = {pos = "escort", zoom = 0.6, daytime = 0.37}, to = {off = {0, -12}, daytime = 0.38}},
}}
