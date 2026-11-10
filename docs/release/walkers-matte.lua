-- The two walkers of units-extra-matte.lua again, for their icons: spider units walked off their stills there (after
-- the other forces' units), and held by teleport their legs re-stepped between the dark and the white still (the matte
-- ghosted). Here each walker is set down alone, frozen once its legs settle (disabled_by_script), shot on the dark
-- ground, and the ground under it turned white for its white twin: the same entity, the same pose.
--   scripts/film.sh gallery fresh.zip docs/release/walkers-matte.lua <out>   (docs/manual/shots/matte.py cuts it)
local FORCE = {kh = "lp-serenity", gs = "lp-grubstake"}
local units = {{"lp-walker", "kh"}, {"lp-grubstake-walker", "gs"}}
local GAP, ZOOMS, R = 40, {1.5, 2, 3}, 14
local FREEZE, WHITE = 200, 300
local GROUND = {GAP, 0}
local build, shots = {}, {}
local function shoot(name, pos, t)
  for k, z in ipairs(ZOOMS) do
    shots[#shots + 1] = {name = string.format("%s-z%s", name, tostring(z):gsub("%.", "p")), tick = t + 2 * (k - 1),
      pos = {pos[1], pos[2] - 2}, zoom = z, daytime = 0, hide_clouds = true}
  end
end
for i, u in ipairs(units) do
  local pos = {0, (i - 1) * GAP}
  build[#build + 1] = {name = u[1], force = FORCE[u[2]], pos = pos}
  shoot(u[1] .. "-f0-dark", pos, 240 + 10 * i)
  shoot(u[1] .. "-f0-white", pos, WHITE + 10 + 10 * i)
end
shots[#shots + 1] = {name = "ground-dark-z3", tick = 240, pos = GROUND, zoom = 3, daytime = 0, hide_clouds = true}
shots[#shots + 1] = {name = "ground-white-z3", tick = WHITE + 10, pos = GROUND, zoom = 3, daytime = 0, hide_clouds = true}
local function whiten(surface, c)
  local tiles = {}
  for x = c[1] - R, c[1] + R do
    for y = c[2] - R - 4, c[2] + R do tiles[#tiles + 1] = {name = "lab-white", position = {x, y}} end
  end
  surface.set_tiles(tiles, true, false, false)
end
local function each(tick)
  if tick <= FREEZE then   -- (from its first tick: at 200 the KH walker had already walked off its still)
    for _, e in ipairs(storage.built or {}) do
      if e.valid then e.disabled_by_script = true end
    end
  elseif tick == WHITE then
    local s = storage.built[1].surface
    for i = 1, #units do whiten(s, {0, (i - 1) * GAP}) end
    whiten(s, GROUND)
  end
end
return {name = "matte-walkers", pad = {-24, -24, GAP + 24, #units * GAP + 4}, tile = "lab-dark-2", build = build,
  shots = shots, resolution = {1200, 1200}, each = each}
