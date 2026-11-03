-- The orbital strike (Kessler-Hayashi's late siege; the user, 2026-11-01: "a targeted (and telegraphed) orbital strike for
-- late game KH sieges ... A line of explosions spreading from a central point could be a scary sight"). An armed camp's
-- siege, its mortars up, calls one strike at the player's wall between its site and its target. A spotter, the guard
-- nearest that point, paints it for PAINT: a beam from the spotter, rings closing on the point. Killed or gone, the strike
-- is called off (the counter: an army that kills the spotter; the army brief, eyes). Then shells fall from orbit, the first
-- on the point, then outward along the wall's line STEP apart, REACH each way: a lane opened, not a base erased; and on
-- every gun of its foes whose reach covers that lane (threat.reach), as many shells as its health takes (threat.blow),
-- nearest the point first, a pair every PACE ticks. Seven shells on the wall alone opened it on the artillery base, and
-- the lasers behind it, covering the gap, held the siege off all the same: what it opens is read from what defends it. Once a siege; COOL between a camp's strikes. On for corporations with shared.CORPS orbital_strike
-- (Kessler-Hayashi), armed camps only; debug_tune strikes_off.
local shared = require("__landing-party__.shared")
local threat = require("__landing-party__.scripts.threat")

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
  -- (Once a siege; a standing siege again after the cooldown.)
  if game.tick < (b.strike_next or 0) or (op.strike_called and not op.standing) or not op.site then return false end
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

local function fall(st, s, b, at)
  local x, y = at[1], at[2]
  s.create_entity{name = "lp-orbital-projectile", position = {x - 10, y - FALL}, target = {x, y}, speed = 1,
    -- (Its lander the cause: a kill is credited to its camp, control.lua; its force as the cause, the strike's razing
    -- counted for nothing, not in its war ladder nor against its standing down, 0.2.161.)
    force = st.force, cause = b and b.lander.valid and b.lander or game.forces[st.force], source = b and b.lander.valid and b.lander or nil}
end

-- Where its shells fall, in order: the lane's points outward from its point, and the guns covering the lane, each as many
-- times as its health takes, all by distance from the point.
local function targets(st, s, b)
  local lane, out = {}, {}
  for k = 0, math.floor(REACH / STEP) do
    for _, sign in ipairs(k == 0 and {1} or {1, -1}) do
      local off = sign * k * STEP
      local p = {st.center[1] + math.cos(st.along) * off, st.center[2] + math.sin(st.along) * off}
      table.insert(lane, p)
      table.insert(out, {pos = p, d = math.abs(off)})
    end
  end
  local fs = b and foes(b) or {}
  if #fs > 0 then
    for _, g in ipairs(s.find_entities_filtered{position = st.center, radius = REACH + threat.far(), type = threat.FIRE,
      force = fs}) do
      local r, gp = threat.reach(g), g.position
      for _, p in ipairs(lane) do
        if (gp.x - p[1]) ^ 2 + (gp.y - p[2]) ^ 2 <= r * r then
          local d = math.sqrt((gp.x - st.center[1]) ^ 2 + (gp.y - st.center[2]) ^ 2)
          for _ = 1, threat.shells_for("lp-orbital-projectile", g) do table.insert(out, {pos = {gp.x, gp.y}, d = d, gun = true}) end
          st.guns = (st.guns or 0) + 1
          break
        end
      end
    end
  end
  table.sort(out, function(x, y) return x.d < y.d end)
  return out
end

function orbital.tick(tick)
  if not storage.kh_strikes or #storage.kh_strikes == 0 or tick % 10 ~= 0 then return end
  for i = #storage.kh_strikes, 1, -1 do
    local st = storage.kh_strikes[i]
    local s = game.surfaces[st.surface]
    local b = storage.bases[st.base]
    if not s then
      table.remove(storage.kh_strikes, i)
    elseif st.phase == "paint" and b and not (b.op and b.op.kind == "siege") then
      -- Its siege over before it falls: called off (it fell on the wall after its siege had packed up, the user's watch,
      -- 2026-11-03).
      trace(b, "its siege is over: called off")
      table.remove(storage.kh_strikes, i)
    elseif st.phase == "paint" then
      if not st.spotter.valid then
        if b then trace(b, "its spotter is down: called off"); b.strikes_off_called = (b.strikes_off_called or 0) + 1 end
        table.remove(storage.kh_strikes, i)
      elseif tick >= st.fire_at then
        st.phase, st.next = "fire", tick
        st.queue, st.k = targets(st, s, b), 1
        if b then b.strike_guns = (b.strike_guns or 0) + (st.guns or 0) end
        if b then trace(b, string.format("falls: %d shells, on the lane and the %d guns covering it", #st.queue, st.guns or 0)) end
      elseif tick % 30 == 0 then
        paint(st, s, tick)
      end
    elseif tick >= st.next then
      -- Its point, then a pair each PACE, outward.
      for _ = 1, st.k == 1 and 1 or 2 do
        local q = st.queue[st.k]
        if q then fall(st, s, b, q.pos); st.shells = (st.shells or 0) + 1; st.k = st.k + 1 end
      end
      st.next = tick + PACE
      if st.k > #st.queue then
        if b then b.strike_shells = (b.strike_shells or 0) + st.shells; trace(b, string.format("done: %d shells", st.shells)) end
        table.remove(storage.kh_strikes, i)
      end
    end
  end
end

return orbital
