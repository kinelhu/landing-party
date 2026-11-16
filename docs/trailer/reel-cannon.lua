-- The player's orbital cannons answering back (cut 28; the user, 2026-11-16: "can we get a shot of an orbital cannon
-- battery firing in the trailer?"; on cut 28's dev deck: "the underlying platform is artificial"; on cut 29's wing on
-- Deep Space Ten: "Really not satisfied", four graft designs as stills, "Okay on D"): on nw at minute 15 (reel-khwall.lua's
-- save, a copy), the user's own Skipjack (platform-2, in transit in the save: parked over Nauvis here, its schedule
-- cleared) given graft D: two cannons facing forward on outriggers either side of its walled gun bow, swept back into its
-- shoulders, charged, and a targeting array; fired on Kessler-Hayashi's siege outside the user's south wall once its
-- guns stand. The strike's shadow is the firing platform's own (cannon.silhouette: its foundation tiles and its barrels),
-- so the Skipjack's with its outriggers. Beats on 0.2.431 from a rehearsal: march 12097800, deploy 12099400 (guns and its
-- jamming mast under their shield round -133,371), bombard and paint 12101200. A strike falls about 510 ticks after its
-- shot.
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/trailer/reel-cannon.lua
local FIRE = 12100700
-- (Fitted 200 ticks before the shot, its cannons kept from harm: fitted 1700 before, the third take, the port cannon was
-- gone by the shot, an asteroid's doing over Nauvis.)
local SETUP = FIRE - 200
-- The battery fitted (once, at SETUP): the Skipjack parked over Nauvis, graft D's outriggers (corners cut, as the
-- graft stills), the cannons charged, the array on a pad of its own.
local function shape(s, x0, y0, x1, y1, cuts)
  local t = {}
  for x = x0, x1 do for y = y0, y1 do
    local keep = true
    local function cut(c, dx, dy) if c and dx + dy < c then keep = false end end
    cut(cuts.nw, x - x0, y - y0); cut(cuts.ne, x1 - x, y - y0); cut(cuts.sw, x - x0, y1 - y); cut(cuts.se, x1 - x, y1 - y)
    if keep then t[#t + 1] = {name = "space-platform-foundation", position = {x, y}} end
  end end
  s.set_tiles(t)
end
local function each()
  if storage.battery_fitted or game.tick < SETUP then return end
  storage.battery_fitted = true
  local s = game.surfaces["platform-2"]
  local pl = s.platform
  pl.schedule = nil
  pl.paused = true
  pl.space_location = "nauvis"
  shape(s, -23, -21, -10, -3, {nw = 4, sw = 2})
  shape(s, 9, -21, 22, -3, {ne = 4, se = 2})
  shape(s, -10, -12, -9, -4, {}); shape(s, 8, -12, 8, -4, {})
  -- (Parked over Nauvis its outriggers sat in the asteroid field: one drifting over the port outrigger kept that cannon
  -- from being placed, the second take. The asteroids over the new foundation cleared first.)
  for _, e in ipairs(s.find_entities_filtered{area = {{-24, -22}, {23, 1}}, type = "asteroid"}) do e.destroy() end
  for _, x in ipairs({-17, 16}) do
    local c = s.create_entity{name = "lp-orbital-cannon", position = {x, -12}, force = "player", direction = defines.direction.north}
    log("reel-cannon: cannon at " .. x .. ",-12: " .. tostring(c and c.valid))
    if c then c.destructible = false end
    if c then
      c.insert{name = "lp-orbital-shell", count = 4}
      c.get_inventory(defines.inventory.crafter_output).insert{name = "lp-orbital-charge", count = 2}
    end
  end
  -- Its array on a pad behind the port cannon (its deck has no 3 by 3 free: find_non_colliding_position found none).
  shape(s, -19, -2, -14, 0, {sw = 2})
  local a = s.create_entity{name = "lp-targeting-array", position = {-16.5, -0.5}, force = "player"}
  log(string.format("reel-cannon: the Skipjack at %s, %d cannons, its array %s", tostring(pl.space_location and pl.space_location.name),
    s.count_entities_filtered{name = "lp-orbital-cannon"}, a and serpent.line(a.position) or "none"))
end
return {name = "reel-cannon", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = SETUP - 100,
  stop_after = 90000, each = each,
  dev = {{tick = FIRE, args = {"cannon", "fire"}, at = {-134, 373}}},
  moves = {
    -- The battery firing: the whole Skipjack, Nauvis's curve beside it, both barrels flashing.
    {name = "fire", tick = FIRE - 40, frames = 240, every = 1, surface = "platform-2",
      from = {pos = {0, -4}, zoom = 0.4}, to = {pos = {0, -4}, zoom = 0.42}},
    -- Its strike on the siege: the ring, the platform's shadow, the shells, the bastion above. (Centred at 352 the
    -- siege sat on the frame's bottom edge.)
    {name = "strike", tick = FIRE + 210, frames = 600, every = 1,
      from = {pos = {-136, 360}, zoom = 0.55, daytime = 0.3}, to = {pos = {-136, 362}, zoom = 0.6, daytime = 0.3}},
  }}
