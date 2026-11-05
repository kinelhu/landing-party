-- The manual's stills from the trailer's fork (trailer 12345 at minute 8; its beats in docs/trailer/stage.lua, places
-- scouted by docs/manual/shots/probe-trailer.lua): by full day (daytime 0.02) and two to three times closer than the
-- trailer's frames. The player's army at the Grubstake camp (429,-158); Kessler-Hayashi's drop siege on the Grubstake
-- camp at -590,40 (pods 44750, mortars at -541,24..36, assault 49300); a Grubstake claim stake at 48,-16 (planted about
-- 47000, stills after it); Synthexis's wave at the wall (-39,-288); the armed camp's strike on the player's wall
-- (paint 67600, lances 68320, wall -28,243). Each still's place is logged (probe-<tick>.txt: the rivals' buildings and
-- units) for the callouts.
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-trailer-12345-14" \
--     scripts/film.sh trailer-film fork.zip docs/manual/shots/m-trailer.lua docs/sim/film-m-trailer
local shots, probes = {}, {}
local function at(name, tick, pos, zoom, probe_r)
  shots[#shots + 1] = {name = string.format("%s-%06d", name, tick), tick = tick, pos = pos, zoom = zoom, daytime = 0.02,
    hide_clouds = true}
  if probe_r and tick % 60 == 0 then probes[tick] = {pos, probe_r} end
end
for t = 41100, 43500, 120 do
  shots[#shots + 1] = {name = string.format("army-z12-%06d", t), tick = t, pos = "army", zoom = 1.2, daytime = 0.02, hide_clouds = true}
  shots[#shots + 1] = {name = string.format("army-z08-%06d", t + 1), tick = t + 1, pos = "army", zoom = 0.8, daytime = 0.02, hide_clouds = true}
end
for t = 44700, 45300, 40 do at("drop", t, {-545, 30}, 1.2) end
for _, t in ipairs({46020, 46620, 47400, 48180}) do
  at("guns-z09", t, {-552, 31}, 0.9, 60); at("guns-z13", t + 1, {-546, 30}, 1.3)
end
for t = 49250, 49950, 70 do at("assault", t, {-562, 32}, 1.1) end
for _, t in ipairs({50040, 54000, 58020, 62040}) do at("claim", t, {48, -16}, 0.8, 50) end
for t = 65250, 65950, 50 do at("wave", t, {-39, -288}, 1.1) end
at("siege-wall", 67020, {-31, 262}, 1.0, 40)
for t = 67560, 68560, 25 do at("strike", t, {-28, 250}, 0.9) end
local function probe(tick)
  local p = probes[tick]
  if not p then return end
  local c, r = p[1], p[2]
  local lines = {}
  local area = {{c[1] - r, c[2] - r}, {c[1] + r, c[2] + r}}
  for _, e in ipairs(game.surfaces[1].find_entities_filtered{area = area}) do
    if e.force.name ~= "neutral" and e.type ~= "transport-belt" and e.type ~= "electric-pole" and e.type ~= "pipe" then
      lines[#lines + 1] = string.format("%s %s %s %.1f,%.1f", e.force.name, e.type, e.name, e.position.x, e.position.y)
    end
  end
  helpers.write_file("factorio-film/probe-" .. tick .. ".txt", table.concat(lines, "\n") .. "\n")
end
return {name = "m-trailer", army = true, resolution = {2560, 1440}, anti_alias = true, speed = 8,
  lapse = {{from = 0, to = 41000, speed = 16}, {from = 41000, to = 70000, speed = 8}},
  each = probe, shots = shots}
