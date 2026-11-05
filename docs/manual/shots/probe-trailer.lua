-- A scouting pass on the trailer's fork for the manual's stills: each settlement's corporation and origin, and every
-- building of the rivals' forces by name with its position, written to script-output/factorio-film/probe-<tick>.txt at
-- the ticks below (before the corporations' war, during the siege of the Grubstake camp, before the strike).
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-trailer-12345-14" \
--     scripts/film.sh trailer-film fork.zip docs/manual/shots/probe-trailer.lua
local AT = {[29400] = true, [41400] = true, [47400] = true, [65400] = true, [67800] = true}
local function probe(tick)
  if not AT[tick] then return end
  local lines = {}
  for id = 1, 20 do
    local ok, st = pcall(remote.call, "landing-party", "stats", id)
    if ok and st then
      lines[#lines + 1] = string.format("base %d %s origin %.0f,%.0f era %s", id, tostring(st.corp or st.corporation),
        st.origin and st.origin.x or 0, st.origin and st.origin.y or 0, tostring(st.era))
    end
  end
  for _, f in pairs(game.forces) do
    if f.name:find("^lp%-") then
      for _, e in ipairs(game.surfaces[1].find_entities_filtered{force = f}) do
        if e.type ~= "unit" and e.type ~= "wall" and e.type ~= "gate" and e.type ~= "transport-belt"
          and e.type ~= "electric-pole" and e.type ~= "pipe" and e.type ~= "inserter" then
          lines[#lines + 1] = string.format("%s %s %.1f,%.1f", f.name, e.name, e.position.x, e.position.y)
        end
      end
      local units = game.surfaces[1].find_entities_filtered{force = f, type = "unit"}
      lines[#lines + 1] = string.format("%s units %d", f.name, #units)
      for _, u in ipairs(units) do lines[#lines + 1] = string.format("%s unit %s %.0f,%.0f", f.name, u.name, u.position.x, u.position.y) end
    end
  end
  helpers.write_file("factorio-film/probe-" .. tick .. ".txt", table.concat(lines, "\n") .. "\n")
end
return {name = "probe-trailer", resolution = {960, 540}, speed = 16, lapse = {{from = 0, to = 70000, speed = 16}},
  base = "siege", each = probe, shots = {
  {name = "p1", tick = 29400, pos = {0, 0}, zoom = 0.1, daytime = 0},
  {name = "p2", tick = 67800, pos = {-28, 243}, zoom = 0.3, daytime = 0},
}}
