-- The orbital strike (Kessler-Hayashi's late siege; the user, 2026-11-01: "a targeted (and telegraphed) orbital strike for
-- late game KH sieges ... A line of explosions spreading from a central point could be a scary sight"). An armed camp's
-- siege, its mortars up, calls one strike at the player's wall between its site and its target. A spotter, the guard
-- nearest that point, paints it for PAINT: a beam from the spotter, rings closing on the point. Killed or gone, the strike
-- is called off (the counter: an army that kills the spotter; the army brief, eyes). Then shells fall from orbit, the first
-- on the point, then outward along the wall's line STEP apart, a pair every PACE ticks, REACH each way: a lane opened,
-- not a base erased. Once a siege; COOL between a camp's strikes. On for corporations with shared.CORPS orbital_strike
-- (Kessler-Hayashi), armed camps only; debug_tune strikes_off.
local shared = require("__landing-party__.shared")

local orbital = {}
local PAINT = 12 * 60
-- (REACH 36, 13 shells over a 72-tile line, took the whole of a 40-tile wall: half that opens a lane.)
local STEP, REACH, PACE = 6, 18, 20
local FALL = 30                   -- tiles above its point a shell starts (war.lua's barrage alike)
local COOL = 15 * 60 * 60
local SEEK = 80                   -- tiles from its site toward its target it looks for the wall
local WALLS = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret"}
local COLOR = {r = 0.9, g = 0.2, b = 0.15}

-- (base.trace's line, written here: base requires the siege, which requires this.)
local function trace(b, msg)
  local line = string.format("%8d base %d  orbital strike: %s", game.tick, b.id, msg)
  if storage.trace then helpers.write_file("landing-party/decisions.txt", line .. "\n", true) end
  table.insert(b.log, line)
  if #b.log > 30 then table.remove(b.log, 1) end
end

local function foes(b)
  local out = {}
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) and not f.get_cease_fire(b.force) then out[#out + 1] = f end
  end
  return out
end

-- A siege's call (siege.lua, its mortars up). Called or not.
function orbital.call(b, op)
  if storage.kh_strikes_off or not b.armed or not (shared.CORPS[b.corp] or {}).orbital_strike then return false end
  if game.tick < (b.strike_next or 0) or op.strike_called or not op.site then return false end
  local t = op.target and b.intel and b.intel.targets[op.target]
  if not (t and t.pos) then return false end
  local s = b.lander.surface
  local fs = foes(b)
  if #fs == 0 then return false end
  local dx, dy = t.pos[1] - op.site[1], t.pos[2] - op.site[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return false end
  -- The first of the player's walls or guns on its line from its site toward its target.
  local center
  for d = 4, math.min(SEEK, len), 2 do
    local p = {op.site[1] + dx / len * d, op.site[2] + dy / len * d}
    if s.count_entities_filtered{position = p, radius = 3, force = fs, type = WALLS, limit = 1} > 0 then center = p; break end
  end
  if not center then return false end
  local spotter, sd
  for _, u in ipairs(op.members or {}) do
    if u.valid then
      local d = (u.position.x - center[1]) ^ 2 + (u.position.y - center[2]) ^ 2
      if not sd or d < sd then spotter, sd = u, d end
    end
  end
  if not spotter then return false end
  op.strike_called = true
  b.strike_next = game.tick + COOL
  storage.kh_strikes = storage.kh_strikes or {}
  table.insert(storage.kh_strikes, {base = b.id, surface = s.index, force = b.force, center = center,
    along = math.atan2(dy, dx) + math.pi / 2, spotter = spotter, fire_at = game.tick + PAINT, k = 0, phase = "paint"})
  b.strikes = (b.strikes or 0) + 1
  trace(b, string.format("called on the wall at %.0f,%.0f; its spotter paints it for %d s", center[1], center[2], PAINT / 60))
  return true
end

local function paint(st, s, tick)
  local left = math.max(0, st.fire_at - tick) / PAINT
  rendering.draw_line{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.8}, width = 2, from = st.spotter,
    to = st.center, surface = s, time_to_live = 31, dash_length = 1, gap_length = 0.5}
  rendering.draw_circle{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.9}, radius = 2 + 10 * left, width = 3,
    filled = false, target = st.center, surface = s, time_to_live = 31}
  rendering.draw_circle{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.35}, radius = REACH, width = 1,
    filled = false, target = st.center, surface = s, time_to_live = 31, draw_on_ground = true}
end

local function fall(st, s, b, off)
  local x = st.center[1] + math.cos(st.along) * off
  local y = st.center[2] + math.sin(st.along) * off
  s.create_entity{name = "lp-orbital-projectile", position = {x - 10, y - FALL}, target = {x, y}, speed = 1,
    force = st.force, cause = game.forces[st.force], source = b and b.lander.valid and b.lander or nil}
end

function orbital.tick(tick)
  if not storage.kh_strikes or #storage.kh_strikes == 0 or tick % 10 ~= 0 then return end
  for i = #storage.kh_strikes, 1, -1 do
    local st = storage.kh_strikes[i]
    local s = game.surfaces[st.surface]
    local b = storage.bases[st.base]
    if not s then
      table.remove(storage.kh_strikes, i)
    elseif st.phase == "paint" then
      if not st.spotter.valid then
        if b then trace(b, "its spotter is down: called off"); b.strikes_off_called = (b.strikes_off_called or 0) + 1 end
        table.remove(storage.kh_strikes, i)
      elseif tick >= st.fire_at then
        st.phase, st.next = "fire", tick
        if b then trace(b, "falls") end
      elseif tick % 30 == 0 then
        paint(st, s, tick)
      end
    elseif tick >= st.next then
      -- Its point, then a pair outward each PACE.
      if st.k == 0 then fall(st, s, b, 0) else fall(st, s, b, st.k * STEP); fall(st, s, b, -st.k * STEP) end
      st.shells = (st.shells or 0) + (st.k == 0 and 1 or 2)
      st.k = st.k + 1
      st.next = tick + PACE
      if st.k * STEP > REACH then
        if b then b.strike_shells = (b.strike_shells or 0) + st.shells; trace(b, string.format("done: %d shells", st.shells)) end
        table.remove(storage.kh_strikes, i)
      end
    end
  end
end

return orbital
