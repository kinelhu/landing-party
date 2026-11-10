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
local achievements = require("__landing-party__.scripts.achievements")

local orbital = {}
local PAINT = 12 * 60
-- (REACH 36, 13 shells over a 72-tile line, took the whole of a 40-tile wall: half that opens a lane.)
local STEP, REACH, PACE = 6, 18, 20
local FALL = 30                   -- tiles above its point a shell starts (war.lua's barrage alike)
local COOL = 15 * 60 * 60
local SEEK = 80                   -- tiles from its site toward its target it looks for the wall
local WALLS = {"wall", "gate", "ammo-turret", "electric-turret", "fluid-turret"}
local COLOR = {r = 0.9, g = 0.2, b = 0.15}
-- Its look (the user, 2026-11-03: "more visual, more orbital"): a lance from LANCE_H above each point as its shell falls
-- straight down, a flash and a scorch where it lands; during the paint an uplink from the spotter into the sky, and the
-- platform's shadow crossing the strike, over its point as the first shell falls.
local LANCE_H = 60
local LANCE_TICKS = 14
local LIGHT = {r = 0.8, g = 0.95, b = 1}
local SHADOW_RUN = 90          -- tiles its shadow travels to reach the point at the fall
local SHADOW_TAIL = 6 * 60     -- ticks it goes on past it
local SHADOW_ALPHA = 0.42      -- its darkness at its lowest, over the point
local SHADOW_SPREAD = 0.5      -- how much larger (and so softer) it is from high up
-- Its outline in tiles, a hull and two wings (three strips: rendering polygons are triangle strips).
local SHADOW = {
  {{-14, -6}, {14, -6}, {-14, 6}, {14, 6}},
  {{-30, -3}, {-14, -3}, {-30, 3}, {-14, 3}},
  {{14, -3}, {30, -3}, {14, 3}, {30, 3}},
}

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
  -- (Its lever, lp-<corp>-orbital-strikes: off, its sieges go without them.)
  if not shared.setting("lp-" .. b.corp .. "-orbital-strikes", true) then return false end
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
  orbital.start(b, s, fs, center, math.atan2(dy, dx) + math.pi / 2, spotter)
  -- Its siege told at once (its step runs every 5 s, too coarse for a 12 s paint): its guards move up behind it.
  op.strike_center, op.strike_paint, op.step_at = center, game.tick, game.tick + 1
  trace(b, string.format("called on the wall at %.0f,%.0f; its spotter paints it for %d s", center[1], center[2], PAINT / 60))
  return true
end

-- A strike begun: painted from `spotter` for PAINT, then its shells along `along` through `center`; the platform's shadow
-- and the alert. dev: a forced one (orbital.force), its own record in place of a siege's.
-- Its platform's shadow (orbital.shadow_tick moves it), over its point `lead` ticks on.
-- (Its own list: a strike called off or done leaves its list while its shadow still crosses.)
-- A silhouette's scale over the ground (the player's platform, drawn from its tiles: larger than life, from orbit).
local SILHOUETTE_SCALE = 1.5
local function shadow(s, center, along, lead, silhouette)
  local sh = {objs = {}, dir = along, center = center, from = game.tick, at = game.tick + lead}
  -- The player's own platform (the user, 2026-11-10: "could we customize the looming shadow to represent our actual
  -- platform?"): its strips (cannon.silhouette: {x, y, w, h} in tiles from its middle, -y its bow), each a cell sprite
  -- scaled to its size and turned to the course, placed each tick by shadow_tick.
  if silhouette and #silhouette > 0 then
    sh.offs = {}
    for i, q in ipairs(silhouette) do
      sh.offs[i] = q
      sh.objs[i] = rendering.draw_sprite{sprite = "lp-shadow-cell", target = {center[1], center[2]}, surface = s,
        orientation = ((sh.dir + math.pi / 2) / (2 * math.pi)) % 1, tint = {r = 0, g = 0, b = 0, a = 0},
        render_layer = "higher-object-above", x_scale = q[3], y_scale = q[4]}
    end
    storage.kh_shadows = storage.kh_shadows or {}
    table.insert(storage.kh_shadows, sh)
    return
  end
  -- (A silhouette, its nose along its course, over all it crosses: three flat strips read as dark rectangles, the user,
  -- 2026-11-04, the strike's stills.)
  sh.objs[1] = rendering.draw_sprite{sprite = "lp-platform-shadow", target = {center[1], center[2]}, surface = s,
    -- (Above what it crosses, below explosions, projectiles and smoke: on the smoke layer it shaded the barrage's own
    -- fireballs, the user, 2026-11-04.)
    orientation = ((sh.dir + math.pi / 2) / (2 * math.pi)) % 1, tint = {r = 0, g = 0, b = 0, a = 0}, render_layer = "higher-object-above",
    x_scale = 1 + SHADOW_SPREAD, y_scale = 1 + SHADOW_SPREAD}
  storage.kh_shadows = storage.kh_shadows or {}
  table.insert(storage.kh_shadows, sh)
end

function orbital.start(b, s, fs, center, along, spotter, dev)
  storage.kh_strikes = storage.kh_strikes or {}
  table.insert(storage.kh_strikes, {base = b.id, surface = s.index, force = b.force, center = center,
    along = along, spotter = spotter, fire_at = game.tick + PAINT, k = 0, phase = "paint", dev = dev})
  b.strikes = (b.strikes or 0) + 1
  shadow(s, center, along, PAINT)
  if shared.notices_on() then
    for _, f in ipairs(fs) do
      for _, p in pairs(f.players) do
        p.add_custom_alert(spotter, {type = "virtual", name = "signal-explosion"}, {"lp.alert-orbital", shared.CORPS[b.corp].name}, true) -- notice-ok: gated above
      end
    end
  end
end

-- A strike now (dev: /lp strike; the user, 2026-11-04: "devise debug commands to force a strike"): from settlement b,
-- centred on `at`, its lane across the line from its camp, painted by a spotter of its infantry put down SPOTTER_OFF tiles
-- towards its camp. No siege, no armed camp, no cooldown. Its record in b.dev_strike (ops.summary reads it as a siege's).
local SPOTTER_OFF = 24
function orbital.force(b, at)
  local s = b.lander.surface
  local center = {at.x or at[1], at.y or at[2]}
  local dx, dy = center[1] - b.origin.x, center[2] - b.origin.y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local name = shared.variant(b.corp, "lp-infantry")
  local p = s.find_non_colliding_position(name, {center[1] - dx / len * SPOTTER_OFF, center[2] - dy / len * SPOTTER_OFF}, 10, 0.5)
  local spotter = p and s.create_entity{name = name, position = p, force = b.force}
  if not spotter then return "no ground for its spotter" end
  spotter.commandable.set_command{type = defines.command.stop, ticks_to_wait = PAINT + 600, distraction = defines.distraction.none}
  b.dev_strike = {center = center, paint = game.tick}
  orbital.start(b, s, foes(b), center, math.atan2(dy, dx) + math.pi / 2, spotter, true)
  trace(b, string.format("forced at %.0f,%.0f; its spotter paints it for %d s", center[1], center[2], PAINT / 60))
end

-- The player's strike (strike.lua; the user, 2026-11-05, on the trailer: "Any reason the player strike looks so
-- underwhelming compared to" Kessler-Hayashi's): its beacon the spotter, painted PLAYER_PAINT, the platform's shadow over
-- it as it falls, then its shells in the same lances, flashes and scorches, nearest its beacon first, a pair each PACE.
-- `at`: its points in order, a point once a shell. Not called off: the beacon is spent as it calls.
local PLAYER_PAINT = 4 * 60
function orbital.player(s, force, beacon, at, reach)
  local c = beacon.position
  storage.kh_strikes = storage.kh_strikes or {}
  -- (Its shadow's course: fixed, there is no camp to come from.)
  local along = math.pi / 4
  table.insert(storage.kh_strikes, {surface = s.index, force = force, center = {c.x, c.y}, along = along, spotter = beacon,
    fire_at = game.tick + PLAYER_PAINT, paint_for = PLAYER_PAINT, k = 0, phase = "paint", player = true, preset = at,
    reach = reach})
  shadow(s, {c.x, c.y}, along, PLAYER_PAINT)
end

-- From the player's orbital cannons (scripts/cannon.lua): centred on a point of the map, no beacon on the ground, painted
-- for CANNON_PAINT, the platform's shadow over it, then its shells (`at`, its points).
-- (5 s: a superweapon's warning, the railgun's charge heard over it, lp-cannon-charge.)
local CANNON_PAINT = 5 * 60
function orbital.from_orbit(s, force, center, at, reach, silhouette)
  storage.kh_strikes = storage.kh_strikes or {}
  s.play_sound{path = "lp-cannon-charge", position = {center[1], center[2]}}
  local along = math.pi / 4
  table.insert(storage.kh_strikes, {surface = s.index, force = force, center = {center[1], center[2]}, along = along,
    fire_at = game.tick + CANNON_PAINT, paint_for = CANNON_PAINT, k = 0, phase = "paint", player = true, preset = at,
    reach = reach, cannon = true})
  shadow(s, {center[1], center[2]}, along, CANNON_PAINT, silhouette)
end

local function paint(st, s, tick)
  local left = math.max(0, st.fire_at - tick) / (st.paint_for or PAINT)
  -- The uplink: from the spotter straight up, for its platform.
  if st.spotter and st.spotter.valid then
    local sp = st.spotter.position
    s.create_entity{name = "lp-orbital-lance", position = sp, source_position = {sp.x, sp.y - LANCE_H}, target_position = sp,
      duration = 31}
  end
  if st.spotter and st.spotter.valid then
    rendering.draw_line{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.8}, width = 2, from = st.spotter,
      to = st.center, surface = s, time_to_live = 31, dash_length = 1, gap_length = 0.5}
  end
  rendering.draw_circle{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.9}, radius = 2 + 10 * left, width = 3,
    filled = false, target = st.center, surface = s, time_to_live = 31}
  rendering.draw_circle{color = {r = COLOR.r, g = COLOR.g, b = COLOR.b, a = 0.35}, radius = st.reach or REACH, width = 1,
    filled = false, target = st.center, surface = s, time_to_live = 31, draw_on_ground = true}
end

local function fall(st, s, b, at)
  local x, y = at[1], at[2]
  -- Its lance, its flash, its scorch.
  s.create_entity{name = "lp-orbital-lance", position = {x, y}, source_position = {x, y - LANCE_H}, target_position = {x, y},
    duration = LANCE_TICKS}
  rendering.draw_light{sprite = "utility/light_medium", scale = 6, intensity = 1, color = LIGHT, target = {x, y},
    surface = s, time_to_live = LANCE_TICKS}
  -- (The cannon's: a shock on screen, the big explosion, a huge scorch, lp-cannon-shock.)
  if st.cannon then s.create_entity{name = "lp-cannon-shock", position = {x, y}}
  else s.create_entity{name = "medium-scorchmark-tintable", position = {x, y}} end
  -- Its flash, lighting by day as well (a game light shows only in the dark): additive, over the explosion.
  rendering.draw_sprite{sprite = "lp-impact-flash", target = {x, y}, surface = s, x_scale = 5, y_scale = 5,
    render_layer = "explosion", time_to_live = 14}
  -- (Straight down and fast, inside its lance: from 10 aside it arced in like a shell from the next screen.)
  s.create_entity{name = "lp-orbital-projectile", position = {x, y - FALL}, target = {x, y}, speed = 3,
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

-- Each tick while a strike's shadow crosses: its outline moved along its line, rotated to it; gone after its tail.
local function shadow_tick(sh, tick)
  local t = (tick - sh.from) / (sh.at - sh.from)
  local ca, sa = math.cos(sh.dir), math.sin(sh.dir)
  local cx, cy = sh.center[1] + ca * SHADOW_RUN * (t - 1), sh.center[2] + sa * SHADOW_RUN * (t - 1)
  local done = tick > sh.at + SHADOW_TAIL
  for i, o in ipairs(sh.objs) do
    if o.valid then
      if done then o.destroy()
      elseif o.type == "sprite" then
        -- Its low pass (the user, 2026-11-04: not "just disappearing": "fade into focus and disappear progressively, like
        -- if the ship made a low pass before rising up again"): faint and spread from high up, full and sharp over the
        -- strike, then fading and spreading as it climbs away. h: its height, 1 high, 0 at its lowest, over the point.
        local after = tick - sh.at
        local h = after <= 0 and (1 - t) or math.min(1, after / SHADOW_TAIL)
        local ease = h * h * (3 - 2 * h)
        local a = SHADOW_ALPHA * (1 - ease) ^ 1.5
        local sc = 1 + SHADOW_SPREAD * ease
        local q = sh.offs and sh.offs[i]
        if q then
          -- A strip of the player's platform: its place turned to the course (-y the bow, along it; x to its right).
          local k = sc * SILHOUETTE_SCALE
          local fx, fy = ca, sa
          local rx, ry = -sa, ca
          o.target = {cx + (-q[2] * fx + q[1] * rx) * k, cy + (-q[2] * fy + q[1] * ry) * k}
          o.x_scale, o.y_scale = q[3] * k, q[4] * k
        else
          o.target = {cx, cy}
          o.x_scale, o.y_scale = sc, sc
        end
        o.color = {r = 0, g = 0, b = 0, a = a}
      else
        -- (A strike begun before 0.2.198: its strips.)
        local v = {}
        for _, q in ipairs(SHADOW[i]) do v[#v + 1] = {x = cx + q[1] * ca - q[2] * sa, y = cy + q[1] * sa + q[2] * ca} end
        o.vertices = v
      end
    end
  end
  return done
end

function orbital.tick(tick)
  local shs = storage.kh_shadows
  if shs then
    for i = #shs, 1, -1 do if shadow_tick(shs[i], tick) then table.remove(shs, i) end end
  end
  if not storage.kh_strikes or #storage.kh_strikes == 0 or tick % 10 ~= 0 then return end
  for i = #storage.kh_strikes, 1, -1 do
    local st = storage.kh_strikes[i]
    local s = game.surfaces[st.surface]
    local b = storage.bases[st.base]
    if not s then
      table.remove(storage.kh_strikes, i)
    elseif st.phase == "paint" and b and not st.dev and not (b.op and b.op.kind == "siege") then
      -- Its siege over before it falls: called off (it fell on the wall after its siege had packed up, the user's watch,
      -- 2026-11-03).
      trace(b, "its siege is over: called off")
      table.remove(storage.kh_strikes, i)
    elseif st.phase == "paint" then
      if not (st.spotter and st.spotter.valid) and not st.player then
        if b then trace(b, "its spotter is down: called off"); b.strikes_off_called = (b.strikes_off_called or 0) + 1 end
        if b then achievements.spotter(game.forces[b.force]) end
        table.remove(storage.kh_strikes, i)
      elseif tick >= st.fire_at then
        st.phase, st.next = "fire", tick
        -- Falling: its siege's assault goes in behind it (siege.lua), its shells its enemies' only.
        -- (A forced one, /lp strike, tells no siege: its assault went in on a strike it had not called.)
        if not st.dev and b and b.op and b.op.kind == "siege" then b.op.strike_falling, b.op.step_at = tick, tick + 1 end
        if st.dev and b and b.dev_strike then b.dev_strike.falling = tick end
        if st.player then
          st.queue = {}
          for _, p in ipairs(st.preset) do st.queue[#st.queue + 1] = {pos = p} end
          -- Its beacon spent as its first shell falls.
          if st.spotter and st.spotter.valid then
            s.create_entity{name = "big-explosion", position = st.spotter.position}
            st.spotter.destroy()
          end
        else
          st.queue = targets(st, s, b)
        end
        st.k = 1
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
