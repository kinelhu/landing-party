-- The selection's cards in game (scripts/cards.lua, 0.2.339): /lp squad three times, each replacing the selection:
-- one unit (its own card: the unit moving in it), twelve (a card each, every third hurt, every fifth ranked), forty
-- (past 24: a card a kind). The bars over their heads, the panel at the bottom. GUI shown (the toolkit's gui = true).
--   scripts/film.sh gallery fresh.zip docs/review/stills-cards.lua docs/sim/film-cards
local step = 0
local CALLS = {{at = 100, n = "1", pos = {0, 0}}, {at = 400, n = "12", pos = {0, 30}}, {at = 700, n = "40", pos = {0, 60}}}
local function each(tick)
  local c = CALLS[step + 1]
  if c and tick >= c.at then
    step = step + 1
    remote.call("landing-party", "dev", {"squad", c.n}, c.pos)
  end
end
local shot = function(name, tick, pos, zoom)
  return {name = name, tick = tick, pos = pos, zoom = zoom, daytime = 0.05, hide_clouds = true, gui = true}
end
return {name = "cards", pad = {-10, -10, 40, 80}, tile = "grass-1", build = {}, each = each, resolution = {3840, 2160},
  shots = {shot("cards-one", 360, {8, 0}, 1.4), shot("cards-twelve", 660, {14, 31}, 1.2),
    shot("cards-forty", 960, {16, 64}, 0.9)}}
