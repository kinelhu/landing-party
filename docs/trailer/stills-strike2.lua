-- Stills of Kessler-Hayashi's orbital strike on the `orbital` scenario's wall (40 stones, five gun turrets; its fork at
-- minute 10, scripts/fork.sh orbital 12345 16), forced by /lp strike a few seconds in (it never came by itself before the
-- film gave up), each still aimed at the strike's centre (lp-film: pos = "strike").
--   scripts/film.sh orbital-film fork.zip docs/trailer/stills-strike2.lua
local shots = {}
local function both(name, after, dt, zoom, off)
  shots[#shots + 1] = {name = name .. "-day", after = after, dt = dt, pos = "strike", off = off, zoom = zoom, daytime = 0.05}
  shots[#shots + 1] = {name = name .. "-night", after = after, dt = dt + 1, pos = "strike", off = off, zoom = zoom, daytime = 0.5,
    hide_clouds = true}
end
both("1-paint-early", "paint", 180, 0.4)
both("2-paint-late", "paint", 660, 0.4)
both("3-first-lance", "falling", 4, 0.7)
both("4-barrage", "falling", 60, 0.7)
both("5-barrage-late", "falling", 200, 0.6)
both("6-walking-in", "falling", 300, 0.5)
both("7-after", "falling", 900, 0.6)
local fork_tick = 35940
return {name = "strike2", base = 1, log_every = 10, resolution = {1280, 720}, anti_alias = false, dev = {{tick = fork_tick + 120, args = {"strike", "1"}, at = {toward = 120}}},
  shots = shots}
