-- Fliers shot down fall (the user, 2026-11-09: "could we make fliers spin out and fall to the ground instead of
-- disappearing where they stand upon death? something a little more graphically interesting?"). A flier's death leaves
-- its wreck on the ground at once (its prototype's corpse); for the kinds in shared.FALL the wreck is taken up again
-- (on_post_entity_died names it), and the flier's own still (units.lua, the fall's sprite) spins down from its flying
-- height over FALL.TICKS, faster as it falls, its shadow closing under it; where it lands, FALL.crash (a small blast that
-- hurts what is under it) and the wreck, facing as it would have.
-- storage.falls: a list of {k, s, x, y, dir, corpse, o, at, body, shadow}.
local shared = require("__landing-party__.shared")
local SHEETS = require("__landing-party__.graphics.sheets")

local fall = {}
local F = shared.FALL

function fall.on_post_died(e)
  if not e.corpses then return end
  for _, c in ipairs(e.corpses) do
    local k = c.valid and F.kinds[c.name]
    if k and SHEETS[k.sheet .. "/base"] then
      local s, p, dir, name = c.surface, c.position, c.direction, c.name
      c.destroy()
      local B, R = SHEETS[k.sheet .. "/base"], SHEETS[k.sheet .. "/" .. k.rotor]
      local o = dir / 16
      local f = {k = k, s = s.index, x = p.x, y = p.y, dir = dir, corpse = name, o = o, at = game.tick,
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
        s.create_entity{name = F.crash, position = {f.x, f.y}}
        s.create_entity{name = f.corpse, position = {f.x, f.y}, direction = f.dir}
      end
      storage.crashed = (storage.crashed or 0) + 1
      table.remove(list, i)
    else
      -- Its height falling as under gravity, its spin quickening (a turn and a half in all).
      local t = u * u
      local o = f.o + 0.4 * u + 1.1 * t
      if f.body.valid then
        f.body.target = {f.x, f.y + f.h * (1 - t)}
        f.body.orientation = o
      end
      if f.shadow.valid then
        f.shadow.target = {f.x + f.sx * (1 - t), f.y + f.sy * (1 - t)}
        f.shadow.orientation = o
      end
    end
  end
end

function fall.stats()
  return {fallen = storage.fallen or 0, crashed = storage.crashed or 0, falling = #(storage.falls or {})}
end

return fall
