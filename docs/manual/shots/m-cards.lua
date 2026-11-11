-- The manual's selection panel (scripts/cards.lua, 0.2.339): twelve of the player's units by /lp squad (every third
-- hurt, every fifth ranked), selected, the panel above the quickbar and the bars over their heads, the camera above
-- them so both fit one crop. The screen GUI shown (gui = true), at the window's own 3840x2160 (the panel is placed by
-- the window's size: a smaller still cuts it off). By full day.
--   scripts/film.sh gallery fresh.zip docs/manual/shots/m-cards.lua docs/sim/film-m-cards
local done = false
local function each(tick)
  if not done and tick >= 100 then
    done = true
    remote.call("landing-party", "dev", {"squad", "12"}, {-60, 30})
  end
end
local function shot(name, tick, pos, zoom)
  return {name = name, tick = tick, pos = pos, zoom = zoom, daytime = 0.02, hide_clouds = true, gui = true}
end
return {name = "m-cards", pad = {-80, 0, -20, 50}, tile = "grass-1", build = {}, each = each, resolution = {3840, 2160},
  shots = {shot("cards-z20", 420, {-45, 22}, 2.0), shot("cards-z16", 424, {-45, 20}, 1.6)}}
