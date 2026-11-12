-- Kessler-Hayashi's arc flamer firing (0.2.342: its own model; arcs, not a stream): the turret, eight medium biters
-- sent at it from 60 tiles east; stills every 4 ticks through two of its bolts, at night (its arcs light the ground)
-- and by day. (400 tiles south of the fresh save's own gallery at the origin.)
--   scripts/film.sh arcfilm fresh.zip docs/review/stills-arcflamer.lua docs/sim/film-arcflamer
local sent = false
local function each(tick)
  if sent or tick < 100 then return end
  sent = true
  local s = game.surfaces[1]
  -- (The gallery sets every force at peace: this turret and the biters at war again. On the player's force: a
  -- Kessler-Hayashi turret outside a settlement was gone by tick 150.)
  local kh, en = game.forces.player, game.forces.enemy
  kh.set_cease_fire(en, false); en.set_cease_fire(kh, false)
  kh.set_friend(en, false); en.set_friend(kh, false)
  local t = s.find_entities_filtered{name = "lp-flamer", area = {{-5, 395}, {5, 405}}, limit = 1}[1]
  log("arcflamer film: turret " .. tostring(t and t.valid))
  for i = 0, 7 do
    local b = s.create_entity{name = "medium-biter", position = {60 + (i % 4) * 3, 394 + math.floor(i / 4) * 12}, force = "enemy"}
    if b and t then b.commandable.set_command{type = defines.command.attack, target = t, distraction = defines.distraction.none} end
  end
end
-- (Day and night alternate through the same seconds: in a day series after the night one, the fight was over.)
local shots = {}
for k = 0, 59 do
  local night = k % 2 == 0
  shots[#shots + 1] = {name = string.format("arc-%s-%02d", night and "night" or "day", k), tick = 230 + k * 2, pos = {14, 400},
    zoom = 1.3, daytime = night and 0.5 or 0.05, hide_clouds = true}
end
return {name = "arcflamer", pad = {-8, 392, 34, 408}, tile = "grass-1", each = each, resolution = {1920, 1080},
  build = {{name = "lp-flamer", force = "player", pos = {0, 400}}}, shots = shots}
