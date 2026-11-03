-- Stills of Kessler-Hayashi's orbital strike on the artillery reference base (its siege at minute 33, seed 3):
-- scripts/film.sh artillery-era3-t169-seed3-saveat32 t32.zip docs/trailer/stills-strike.lua
local breach, between = {-92, -54}, {-104, -54}
local shots = {}
local function both(name, after, dt, pos, zoom)
  shots[#shots + 1] = {name = name .. "-day", after = after, dt = dt, pos = pos, zoom = zoom, daytime = 0.05}
  shots[#shots + 1] = {name = name .. "-night", after = after, dt = dt, pos = pos, zoom = zoom, daytime = 0.5, hide_clouds = true}
end
both("1-paint-early", "paint", 180, between, 0.4)
both("2-paint-late", "paint", 660, between, 0.4)
both("3-first-lance", "falling", 4, breach, 0.7)
both("4-barrage", "falling", 60, breach, 0.7)
both("5-barrage-late", "falling", 200, breach, 0.6)
both("6-walking-in", "falling", 300, between, 0.5)
both("7-after", "falling", 900, breach, 0.6)
return {name = "strike", base = 1, fast_until = 125500, speed = 8, shots = shots}
