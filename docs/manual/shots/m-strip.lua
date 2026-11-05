-- The manual's Grubstake strip camp: the strip scenario (an ore patch 130 tiles from its camp towards the player, two of
-- the player's drills on its north edge; strip_fast on) from its fork at minute 4, its harness run to 25: a hauler and its
-- guards set up a mining camp on the patch and mine it. The point "strip" is the patch's centre (the player's drills at
-- its north edge, +15,+17), a still on it every half minute by full day; what stands on it is logged each minute to
-- script-output/factorio-film/probe-strip-<tick>.txt.
--   LP_FORK_MINUTES=25 scripts/film_fork.sh strip 12345 10
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-strip-12345-10" \
--     scripts/film.sh strip-film fork.zip docs/manual/shots/m-strip.lua docs/sim/film-m-strip
-- (A first pass on the patch's centre found the camp on its north edge, by the player's drills, from about 25200 to 32400
-- (fork at 14400): the stills are taken there, at -155,-161.)
local shots = {}
for at = 9600, 18600, 600 do
  shots[#shots + 1] = {name = string.format("strip-z12-%05d", at), at_load = at, pos = {-156, -161}, zoom = 1.2, daytime = 0.02,
    hide_clouds = true}
  shots[#shots + 1] = {name = string.format("strip-z08-%05d", at), at_load = at + 1, pos = {-156, -158}, zoom = 0.8, daytime = 0.02,
    hide_clouds = true}
end
local function each(tick)
  local s = game.surfaces[1]
  if not storage.labels_hidden then
    for _, o in pairs(rendering.get_all_objects("landing-party")) do
      if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
    end
    storage.labels_hidden = true
  end
  local d = s.find_entities_filtered{name = "electric-mining-drill", force = "player", limit = 2}
  if #d == 0 then return end
  local c = {d[1].position.x + 15, d[1].position.y + 17}
  if #d == 2 then c = {(d[1].position.x + d[2].position.x) / 2 + 15.5, d[1].position.y + 17} end
  storage.points.strip = c
  if tick % 3600 == 0 then
    local lines = {string.format("strip point %.1f,%.1f", c[1], c[2])}
    for _, e in ipairs(s.find_entities_filtered{area = {{c[1] - 40, c[2] - 30}, {c[1] + 40, c[2] + 30}}}) do
      if e.force.name ~= "neutral" then
        lines[#lines + 1] = string.format("%s %s %s %.1f,%.1f", e.force.name, e.type, e.name, e.position.x, e.position.y)
      end
    end
    helpers.write_file("factorio-film/probe-strip-" .. tick .. ".txt", table.concat(lines, "\n") .. "\n")
  end
end
return {name = "m-strip", resolution = {2560, 1440}, anti_alias = true, speed = 8, lapse = {{from = 0, to = 10000000, speed = 8}},
  each = each, shots = shots}
