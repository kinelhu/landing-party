-- The manual's director pictures (docs/manual/headquarters.qmd): scenario director's film set (LP_MIX=film, tests/lp-sim:
-- Kessler-Hayashi's camp at -344,215 and Grubstake's at -385,-55; the player's two clusters of assemblers and labs 150
-- toward spawn, the second ringed by eight gun turrets; a silo, a radar), forked at minute 7, its beats driven here by the
-- plugin's director list (tests/lp-film-hooks): a launch jammer and a blackout mast, a strike force at the labs (its pods
-- coming down, then the fight), a crashed shuttle with its guards, a focus strike on the ringed cluster (it breaks and
-- walks home), the director's panel. Stills on the plugin's events and points, by full day.
--   scripts/film_fork.sh director 12345 13 film
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-director-film-12345-13" \
--     scripts/film.sh director-film-film fork.zip docs/manual/shots/m-director.lua docs/sim/film-m-director
local C2 = {-143, 254}
local shots = {}
local function still(name, after, dt, pos, zoom, extra)
  local s = {name = name, after = after, dt = dt, pos = pos, zoom = zoom, daytime = 0.02, hide_clouds = true}
  for k, v in pairs(extra or {}) do s[k] = v end
  shots[#shots + 1] = s
end
-- The mast, standing by its camp.
for _, z in ipairs({0.8, 1.2}) do still(string.format("mast-z%02d", z * 10), "mast", 240, "mast", z) end
-- The strike force's pods coming down where it lands (sent to touchdown about 400 ticks), every 15.
for dt = 240, 480, 15 do still(string.format("pods-%04d", dt), "strike1:sent", dt, "dstrike1", 0.9) end
-- Its fight in the labs.
for _, dt in ipairs({120, 360, 720}) do still(string.format("fight-%04d", dt), "strike1:landed", dt, "dforce1", 0.8) end
-- The shuttle and its guards.
for _, z in ipairs({0.9, 1.3}) do still(string.format("salvage-z%02d", z * 10), "salvage", 300, "salvage", z) end
-- The second force broken at the ringed cluster, walking home.
for _, dt in ipairs({120, 300, 600, 900}) do still(string.format("home-%04d", dt), "strike2:broken", dt, "dforce2", 0.7) end
-- The panel, the screen GUI shown, at the window's own size (it is placed by the window's size).
still("panel", nil, nil, {-217, 135}, 0.6, {at_load = 9300, gui = true})
shots[#shots].after, shots[#shots].dt = nil, nil
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "m-director", resolution = {2560, 1440}, anti_alias = true, speed = 1, stop_after = 10200, each = each,
  director = {
    {at = 60, cmd = "jammer"}, {at = 70, cmd = "blackout"},
    {at = 90, cmd = "strike", arg = "research"},
    {at = 150, cmd = "salvage", arg = "core"},
    {at = 2400, cmd = "focus", arg = C2},
    {at = 9200, cmd = "panel"},
  },
  shots = shots}
