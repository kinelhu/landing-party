-- Fliers shot down fall (the user, 2026-11-09: "could we make fliers spin out and fall to the ground instead of
-- disappearing where they stand upon death? something a little more graphically interesting?"). A flier's death leaves
-- its wreck on the ground at once (its prototype's corpse); for the kinds in shared.FALL the wreck is taken up again
-- (on_post_entity_died names it), and the flier's own still (units.lua, the fall's sprite) tumbles down from its flying
-- height over FALL.TICKS to a spot LAND_MIN to LAND_MAX tiles off, on a slight curve, half a turn of spin, faster as it
-- falls, its shadow closing under it; where it lands, FALL.crash (a small blast that hurts what is under it) and the wreck.
-- (Spun in place, a turn and a half where it died, it read as a spin, not a fall: the user, 2026-11-09, "a pure spin in
-- place... I was picturing a small spin from the death spot landing them randomly somewhere close".)
-- storage.falls: a list of {k, s, x, y, lx, ly, side, dir, corpse, o, at, h, sx, sy, body, shadow}.
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")
local SHEETS = require("__landing-party-graphics__.graphics.sheets")

local LAND_MIN, LAND_MAX = 1.5, 4
local CURVE = 0.6           -- tiles the path bows to one side at its middle
local SPIN = 0.5            -- turns in all

local fall = {}
local F = shared.FALL

-- A death its own attack dealt (the bomb drone bursting on its target): no fall (on_entity_died, before this).
function fall.skip(e)
  local u = e.entity
  if e.cause == u and u.unit_number then
    storage.fall_skip = storage.fall_skip or {}
    storage.fall_skip[u.unit_number] = game.tick
  end
end

function fall.on_post_died(e)
  if not e.corpses then return end
  if storage.fall_skip and e.unit_number and storage.fall_skip[e.unit_number] then
    storage.fall_skip[e.unit_number] = nil
    return
  end
  for _, c in ipairs(e.corpses) do
    local k = c.valid and F.kinds[c.name]
    if k and SHEETS[k.sheet .. "/base"] then
      local s, p, dir, name = c.surface, c.position, c.direction, c.name
      c.destroy()
      local B, R = SHEETS[k.sheet .. "/base"], SHEETS[k.sheet .. "/" .. k.rotor]
      local o = dir / 16
      storage.fall_rng = storage.fall_rng or rng.new(20261110)
      local r = storage.fall_rng
      local a, d = rng.next(r) * 2 * math.pi, LAND_MIN + (LAND_MAX - LAND_MIN) * rng.next(r)
      local f = {k = k, s = s.index, x = p.x, y = p.y, lx = p.x + math.cos(a) * d, ly = p.y + math.sin(a) * d,
        side = rng.next(r) < 0.5 and -1 or 1, dir = dir, corpse = name, o = o, at = game.tick,
        h = B.shift[2], sx = R.shift[1], sy = R.shift[2]}
      f.shadow = rendering.draw_sprite{sprite = k.sprite .. "-shadow", surface = s, target = {p.x + f.sx, p.y + f.sy},
        orientation = o, render_layer = "object"}
      f.body = rendering.draw_sprite{sprite = k.sprite, surface = s, target = {p.x, p.y + f.h}, orientation = o,
        render_layer = "air-object"}
      storage.falls = storage.falls or {}
      table.insert(storage.falls, f)
      storage.fallen = (storage.fallen or 0) + 1
    end
  end
end

function fall.tick(tick)
  local list = storage.falls
  if not list or #list == 0 then return end
  for i = #list, 1, -1 do
    local f = list[i]
    local u = (tick - f.at) / F.TICKS
    if u >= 1 then
      if f.body.valid then f.body.destroy() end
      if f.shadow.valid then f.shadow.destroy() end
      local s = game.surfaces[f.s]
      if s then
        s.create_entity{name = f.k.crash or F.crash, position = {f.lx, f.ly}}
        s.create_entity{name = f.corpse, position = {f.lx, f.ly}, direction = f.dir}
      end
      storage.crashed = (storage.crashed or 0) + 1
      table.remove(list, i)
    else
      -- Over the ground at its momentum's pace, bowed to one side; its height falling as under gravity; its spin
      -- quickening as it drops.
      local t = u * u
      local dx, dy = f.lx - f.x, f.ly - f.y
      local len = math.sqrt(dx * dx + dy * dy)
      local bow = f.side * CURVE * math.sin(math.pi * u) / math.max(len, 0.01)
      local gx, gy = f.x + dx * u - dy * bow, f.y + dy * u + dx * bow
      local o = f.o + f.side * SPIN * (0.3 * u + 0.7 * t)
      if f.body.valid then
        f.body.target = {gx, gy + f.h * (1 - t)}
        f.body.orientation = o
      end
      if f.shadow.valid then
        f.shadow.target = {gx + f.sx * (1 - t), gy + f.sy * (1 - t)}
        f.shadow.orientation = o
      end
    end
  end
end

function fall.stats()
  return {fallen = storage.fallen or 0, crashed = storage.crashed or 0, falling = #(storage.falls or {})}
end

return fall
