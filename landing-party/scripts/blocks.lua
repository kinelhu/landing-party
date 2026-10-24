-- Block layouts. A block is one cell of a hub's grid: SIZE x SIZE tiles, roads of ROAD tiles around it.
-- Positions are entity centres in block-local tiles (0..SIZE). `fixed` is built when the block opens;
-- `slots` are filled one at a time as the planner needs them. Walls (tile ring 0 and SIZE-1, an opening
-- in the middle of each side) and corner turrets come later, from the fortify rule.
-- Usable ground inside a walled block is tiles 3..14 (corners 1..2 and 15..16 hold the turrets).
local blocks = {}

blocks.SIZE = 18
blocks.ROAD = 4
blocks.PITCH = blocks.SIZE + blocks.ROAD
blocks.OPENING = 4

-- Every walled block keeps the cross from its openings to its middle clear (rows and columns 7 to 10), and leaves no
-- lane under three tiles: a lane of two lets no unit through, and Kessler-Hayashi's tanks stood in its blocks raid after
-- raid while its infantry left (scenarios wayout and blockexit, 2026-10-24). Buildings sit in the four quadrants
-- (tiles 3 to 6 and 11 to 14), the pylon off the cross.
local P = {"lp-pylon", 11.5, 11.5}
local function fab(x, y) return {"lp-fabricator", x, y} end
local function gen(x, y) return {"lp-generator", x, y} end

blocks.fab = {
  {fixed = {P}, slots = {fab(4.5, 4.5), fab(13.5, 4.5), fab(4.5, 13.5), fab(13.5, 13.5)}},
  {fixed = {P}, slots = {fab(5.5, 4.5), fab(12.5, 4.5), fab(5.5, 13.5), fab(12.5, 13.5)}},
  {fixed = {P}, slots = {fab(4.5, 5.5), fab(13.5, 5.5), fab(4.5, 12.5), fab(13.5, 12.5)}},
}

blocks.gen = {
  {fixed = {P}, slots = {gen(4, 4), gen(6, 4), gen(12, 4), gen(14, 4), gen(4, 14), gen(6, 14), gen(12, 14), gen(14, 14)}},
  {fixed = {P}, slots = {gen(4, 4), gen(4, 6), gen(14, 4), gen(14, 6), gen(4, 12), gen(4, 14), gen(14, 12), gen(14, 14)}},
}

-- The yard open (it is paved in the corporation's floor, layout.livery). Units appear 4 tiles below the depot
-- (army.lua): on the cross, by a way out.
blocks.depot = {
  {fixed = {P, {"lp-depot", 5, 5}, {"lp-turret", 5, 14}, {"lp-turret", 14, 14}},
    slots = {}},
  {fixed = {{"lp-pylon", 6.5, 11.5}, {"lp-depot", 13, 5}, {"lp-turret", 5, 5}, {"lp-turret", 5, 14}},
    slots = {}},
}

-- A hub's hard point: its own generators, so cutting its lines does not silence its turrets.
blocks.compound = {
  {fixed = {P, gen(6, 14), gen(13, 14), gen(6, 5), gen(13, 5)}, slots = {}},
  {fixed = {P, gen(4, 4), gen(14, 4), gen(4, 14), gen(14, 14)}, slots = {}},
}

-- The landing pad: two cells and the road between them (W x SIZE), the lander at its centre (its box spans
-- about x 12 to 28).
blocks.PAD_W = 2 * blocks.SIZE + blocks.ROAD
blocks.pad = {
  {fixed = {{"lp-pylon", 5.5, 5.5}, {"lp-pylon", 14.5, 16.5}, {"lp-pylon", 25.5, 16.5}, {"lp-pylon", 34.5, 5.5}}, slots = {}},
}

-- A picket: radar and two turrets in a small walled square, off the grid, facing the threat.
blocks.PICKET = 12
blocks.picket = {
  {fixed = {{"lp-pylon", 3.5, 8.5}, {"lp-radar", 6.5, 5.5}, {"lp-turret", 3, 3}, {"lp-turret", 9, 9}}, slots = {}},
}

-- The launch pad of a mature settlement: surplus parts leave from here, raising the faction's tier.
-- (Its pad fills the middle: no unit is made in it, and scenario blockexit leaves it out.)
blocks.launch = {
  {fixed = {{"lp-pylon", 4.5, 4.5}, {"lp-launchpad", 9.5, 9.5}}, slots = {}},
}

blocks.TURRETS = {{2, 2}, {16, 2}, {2, 16}, {16, 16}}

-- A layout seen through a mirror and/or a transpose (square blocks only): position (x, y) -> new position.
function blocks.transform(x, y, size, t)
  if t.flip_x then x = size - x end
  if t.flip_y then y = size - y end
  if t.transpose then x, y = y, x end
  return x, y
end

return blocks
