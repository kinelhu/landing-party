-- The lightning's stun's look alone (its sticker over a stunned unit): /lp stun on LP_MIX=scenes's Prism stage troopers
-- (60,120), twice, 4 s apart, close. The stun close-up (stun-close.lua) showed the Tesla's chains and no current on a
-- trooper: this tells a sticker not drawn from stuns that did not land.
--   scripts/film.sh scenes scenes.zip docs/trailer/stun-fx.lua
local T = 11160
return {name = "stun-fx", resolution = {1920, 1080}, anti_alias = true, speed = 1, fast_until = T - 60,
  dev = {
    {tick = T + 30, args = {"stun", "20"}, at = {60, 120}},
    {tick = T + 270, args = {"stun", "20"}, at = {60, 120}},
  },
  moves = {
    {name = "fx1", tick = T, frames = 200, every = 2, from = {pos = {61, 120}, zoom = 2.6, daytime = 0.2}, to = {pos = {61, 120}, zoom = 2.6, daytime = 0.2}},
  },
}
