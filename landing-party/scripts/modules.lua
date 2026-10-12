-- Free-standing modules, off the hub grids (hub blocks are in blocks.lua). Positions are entity centres relative to the module origin (a tile
-- corner); box is the module's footprint {x0, y0, x1, y1} in tiles, also relative to the origin.
-- The pylon comes first so everything after it is powered as it is placed.
local S, N = defines.direction.south, defines.direction.north

local modules = {}

-- Two drills facing a shared bin. Each drill drops 1.85 tiles ahead of its centre, into the bin's tile.
modules.mining = {kind = "mining", box = {-1, -3, 3, 4}, ore = true, entities = {
  {"lp-pylon", 2.5, 0.5}, {"lp-bin", 0.5, 0.5}, {"lp-drill", 0.5, -1.5, S}, {"lp-drill", 0.5, 2.5, N}}}

-- Turrets may stand on ore: defence beats the few tiles they cover.
modules.turrets = {kind = "turrets", box = {0, 0, 5, 2}, on_ore = true, entities = {
  {"lp-pylon", 2.5, 0.5}, {"lp-turret", 1, 1}, {"lp-turret", 4, 1}}}

-- Mining modules tile a lattice anchored on the lander: one tile of margin between neighbours.
modules.MINING_LATTICE = {x = 5, y = 8}

return modules
