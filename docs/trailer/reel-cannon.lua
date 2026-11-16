-- The player's orbital cannons answering back (cut 28; the user, 2026-11-16: "can we get a shot of an orbital cannon
-- battery firing in the trailer?"; on cut 28's dev deck: "looks kind of stupid because the underlying platform is
-- artificial ... Can you not poach one of my actual platforms and modify it?"): on nw at minute 15 (reel-khwall.lua's
-- save, a copy), the user's own Deep Space Ten (platform-1, stopped over Nauvis: its hub, seven asteroid collectors on
-- its bow, crushers, assemblers, belts round its edge and a solar tail, 21 by 38 tiles) given a battery as a player
-- would: a foundation wing along its starboard side (x 11 to 28, its own tiles and buildings untouched; a cannon is 12
-- by 18 and none fits on the deck as built), three cannons on it facing east, barrels out over the void, charged, and a
-- targeting array; fired on Kessler-Hayashi's siege outside the user's south wall once its guns stand. The strike's
-- shadow is the firing platform's own (cannon.silhouette: its foundation tiles and its barrels), so Deep Space Ten's
-- with its wing. Beats on 0.2.431 from a rehearsal: march 12097800, deploy 12099400 (guns and its jamming mast under
-- their shield round -133,371), bombard and paint 12101200. A strike falls about 510 ticks after its shot.
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/trailer/reel-cannon.lua
local FIRE, SETUP = 12100700, 12099000
-- The battery fitted (once, at SETUP): the wing, the cannons charged, the array.
local function each()
  if storage.battery_fitted or game.tick < SETUP then return end
  storage.battery_fitted = true
  local s = game.surfaces["platform-1"]
  local tiles = {}
  for x = 11, 28 do for y = -13, 30 do tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}} end end
  s.set_tiles(tiles)
  for _, y in ipairs({-2, 11, 24}) do
    local c = s.create_entity{name = "lp-orbital-cannon", position = {20, y}, force = "player", direction = defines.direction.east}
    if c then
      c.insert{name = "lp-orbital-shell", count = 4}
      c.get_inventory(defines.inventory.crafter_output).insert{name = "lp-orbital-charge", count = 2}
    end
  end
  s.create_entity{name = "lp-targeting-array", position = {20.5, -10.5}, force = "player"}
  log("reel-cannon: battery fitted on Deep Space Ten, " .. s.count_entities_filtered{name = "lp-orbital-cannon"} .. " cannons")
end
return {name = "reel-cannon", base = 1, resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = FIRE - 100,
  stop_after = 90000, each = each,
  dev = {{tick = FIRE, args = {"cannon", "fire"}, at = {-134, 373}}},
  moves = {
    -- The battery firing on Deep Space Ten: its hub, collectors and belts beside the wing, the barrels east over the void.
    {name = "fire", tick = FIRE - 40, frames = 240, every = 1, surface = "platform-1",
      from = {pos = {12, 8}, zoom = 0.72}, to = {pos = {13, 8}, zoom = 0.76}},
    -- Its strike on the siege: the ring, the platform's shadow, the shells, the bastion above. (Centred at 352 the
    -- siege sat on the frame's bottom edge.)
    {name = "strike", tick = FIRE + 210, frames = 600, every = 1,
      from = {pos = {-136, 360}, zoom = 0.55, daytime = 0.3}, to = {pos = {-136, 362}, zoom = 0.6, daytime = 0.3}},
  }}
