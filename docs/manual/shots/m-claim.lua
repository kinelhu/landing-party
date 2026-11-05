-- The manual's Grubstake claim: the prospect scenario (three ore patches 150 to 250 tiles from its camp towards the
-- player, the nearest drilled by the player) from its fork at minute 14, its harness run to 30: Grubstake stakes a patch
-- and a hauler builds the claim on it. The point "claim" is found every second (the centre of the Grubstake drills more
-- than 60 tiles from its lander, else its stake), and a still taken on it every minute, by full day; what stands round it
-- is logged to script-output/factorio-film/probe-claim-<tick>.txt.
--   LP_FORK_MINUTES=30 scripts/film_fork.sh prospect 12345 20
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-prospect-12345-20" \
--     scripts/film.sh prospect-film fork.zip docs/manual/shots/m-claim.lua docs/sim/film-m-claim
local shots = {}
-- (The point is the centre of all the far drills: with two claims it fell between them, 2026-11-05. The first claim, at
-- -142,-48 when the fork loads, is filmed where it stands; the rest is the record of that first pass.)
local CLAIM = {-142, -48}
for k, z in ipairs({0.7, 1.0, 1.4}) do
  shots[#shots + 1] = {name = string.format("first-z%02d", z * 10), at_load = 120 + k, pos = CLAIM, zoom = z, daytime = 0.02,
    hide_clouds = true}
  shots[#shots + 1] = {name = string.format("first-late-z%02d", z * 10), at_load = 7200 + k, pos = CLAIM, zoom = z,
    daytime = 0.02, hide_clouds = true}
end
local FIRST_ONLY = true   -- (false: the first pass's stills on the moving point as well)
for k = 1, (FIRST_ONLY and 0 or 14) do
  shots[#shots + 1] = {name = string.format("claim-z10-%02d", k), at_load = k * 3600, pos = "claim", zoom = 1.0, daytime = 0.02,
    hide_clouds = true}
  shots[#shots + 1] = {name = string.format("claim-z06-%02d", k), at_load = k * 3600 + 1, pos = "claim", zoom = 0.6,
    daytime = 0.02, hide_clouds = true}
end
local function each(tick)
  local s = game.surfaces[1]
  if not storage.labels_hidden then
    for _, o in pairs(rendering.get_all_objects("landing-party")) do
      if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
    end
    storage.labels_hidden = true
  end
  local landers = s.find_entities_filtered{name = "lp-grubstake-lander"}
  local sx, sy, n = 0, 0, 0
  for _, d in ipairs(s.find_entities_filtered{name = "lp-grubstake-drill"}) do
    local far = true
    for _, l in ipairs(landers) do
      if (l.position.x - d.position.x) ^ 2 + (l.position.y - d.position.y) ^ 2 < 60 * 60 then far = false end
    end
    if far then sx, sy, n = sx + d.position.x, sy + d.position.y, n + 1 end
  end
  local p
  if n > 0 then p = {sx / n, sy / n}
  else
    local st = s.find_entities_filtered{name = "lp-claim-stake", limit = 1}[1]
    if st then p = {st.position.x, st.position.y} end
  end
  if FIRST_ONLY then p = CLAIM end
  if p then
    storage.points.claim = p
    storage.claim_seen = (storage.claim_seen or 0) + 1
    if tick % 3600 == 0 then
      local lines = {string.format("claim point %.1f,%.1f drills %d", p[1], p[2], n)}
      for _, e in ipairs(s.find_entities_filtered{area = {{p[1] - 40, p[2] - 40}, {p[1] + 40, p[2] + 40}}}) do
        if e.force.name ~= "neutral" then
          lines[#lines + 1] = string.format("%s %s %s %.1f,%.1f", e.force.name, e.type, e.name, e.position.x, e.position.y)
        end
      end
      helpers.write_file("factorio-film/probe-claim-" .. tick .. ".txt", table.concat(lines, "\n") .. "\n")
    end
  end
end
return {name = "m-claim", resolution = {2560, 1440}, anti_alias = true, speed = 8, lapse = {{from = 0, to = 10000000, speed = 8}},
  each = each, shots = shots}
