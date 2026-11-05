-- A burst's look (the user, 2026-11-05, watching the trailer: "I almost feel like the burster is underwhelming graphically
-- compared to its usefulness"). Two parts:
--   its wind-up: a burster set off (a cinder's attack raises shared.BURSTFX.windup, biotech.lua; a big burster set off by its
--     herd at its gun or the wall, herd.lua detonate) stops where it stands, past harm, and for KIND.windup ticks swells
--     in a pulsing acid-green glow that quickens, its light growing, a ring on the ground closing in from its blast's
--     reach, a hiss; then it dies, and its death is its blast (biotech.lua's trigger, and for a big burster the rest of it
--     in herd.lua). Past harm while it winds up: set off, it blasts whole as before, when it died on the spot;
--   its blast: any death of a burster (set off, or killed short: a cinder's eruption, a big burster's core alone) draws a
--     flash and its light, a glow swelling out, a shockwave ring on the ground and the nuke's shockwave puffs thrown out
--     to its reach, gibs flung in arcs, acid splashes that leave pools, and a sizzle. Scaled to its blast (KIND): the big
--     burster's the largest, the cinder's smaller, a big burster killed short its core's.
-- Drawn only (rendering and sound, burstlook.lua): its damage is its prototype's and herd.lua's, as before. Never an entity
-- nor a particle (landfx.lua: those are made on the game's dice, and with them fights elsewhere turned out otherwise).
-- Spreads from rng.lua, seeded by where and when. State in storage.burstfx; its counts in storage.burstfx_stats (tests).
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")

local burstfx = {}
local FX = shared.BURSTFX
local ACID = {r = 0.45, g = 1, b = 0.25}
local SPEED = 0.5   -- the copied animations' frames a tick (the base game's)
local POOL_FADE = 120

-- By kind: its wind-up's ticks, its glow's scale and light's from start to end; its blast's reach (the ring's, the puffs'),
-- puffs and their scale, gibs, splashes and their scale, how long its pools stay, its flash's scale.
local KIND = {
  cinder = {windup = 30, glow = {0.3, 0.75}, light = {2, 7}, r = shared.CINDER_BURST.r, puffs = 8, puff = 0.3, gibs = 7,
    splashes = 3, splash = 0.7, pool = 10 * 60, flash = 16, sound = 0.8},
  big = {windup = 45, glow = {0.7, 1.7}, light = {5, 16}, r = shared.BIG_BURST.r, puffs = 16, puff = 0.55, gibs = 16,
    splashes = 6, splash = 1.3, pool = 25 * 60, flash = 40, sound = 1},
  -- (A big burster killed short: its core alone, BIG_BURST.core within half its reach.)
  fizzle = {r = shared.BIG_BURST.r / 2, puffs = 8, puff = 0.35, gibs = 9, splashes = 2, splash = 0.9, pool = 10 * 60,
    flash = 18, sound = 0.7},
}
burstfx.KIND = KIND
local OF = {["lp-bred-cinder"] = "cinder", ["lp-bred-big-burster"] = "big"}

-- What sets a kind off once wound up (herd.lua sets "big": its death and the rest of its blast). Default: its death.
burstfx.on_blast = {}

local function st()
  storage.burstfx = storage.burstfx or {winding = {}, moving = {}}
  return storage.burstfx
end
local function stats()
  storage.burstfx_stats = storage.burstfx_stats or {windups = 0, blasts = {}, drawn = 0}
  return storage.burstfx_stats
end
local function acid(a, k)
  k = k or 1
  return {r = ACID.r * a * k, g = ACID.g * a * k, b = ACID.b * a * k, a = a}
end
local function destroy(objs)
  for _, o in pairs(objs) do if o and o.valid then o.destroy() end end
end

-- Whether u is winding up (herd.lua leaves it be).
function burstfx.winding(u)
  return u and u.valid and u.unit_number and st().winding[u.unit_number] ~= nil
end

-- u set off: its wind-up. `kind` from its name unless given.
function burstfx.windup(u, kind)
  if not (u and u.valid and u.unit_number) then return false end
  kind = kind or OF[u.name]
  local k = KIND[kind]
  local w = st().winding
  if not (k and k.windup) or w[u.unit_number] then return false end
  -- Stopped and past harm: set off, it bursts whole.
  u.disabled_by_script = true
  u.destructible = false
  local s, p = u.surface, u.position
  local objs = {
    ring = rendering.draw_circle{color = acid(0.3), radius = k.r, width = 2, filled = false, target = p, surface = s,
      draw_on_ground = true},
    glow = rendering.draw_sprite{sprite = FX.glow, target = u, surface = s, render_layer = "explosion", tint = acid(0.4),
      x_scale = k.glow[1], y_scale = k.glow[1]},
    light = rendering.draw_light{sprite = "utility/light_medium", target = u, surface = s, color = ACID, scale = k.light[1],
      intensity = 0.5},
  }
  s.play_sound{path = FX.hiss, position = p, volume_modifier = k.sound}
  w[u.unit_number] = {u = u, kind = kind, start = game.tick, at = {x = p.x, y = p.y}, objs = objs}
  local n = stats()
  n.windups = n.windups + 1
  n.last = {x = p.x, y = p.y, tick = game.tick, kind = kind}
  n.drawn = n.drawn + 3
  return true
end

local function wind_tick(e, tick)
  local u, k = e.u, KIND[e.kind]
  if not u.valid then destroy(e.objs); return true end
  local t = (tick - e.start) / k.windup
  if t >= 1 then
    destroy(e.objs)
    u.destructible = true
    local blast = burstfx.on_blast[e.kind]
    if blast then blast(u) else u.die(u.force) end
    if u.valid then u.disabled_by_script = false end
    return true
  end
  -- Its pulse quickens: from two a second to eight.
  local phase = 2 * math.pi * (2 * t + 3 * t * t) * k.windup / 60
  local pulse = 0.5 + 0.5 * math.sin(phase)
  local o = e.objs
  if o.glow.valid then
    local sc = k.glow[1] + (k.glow[2] - k.glow[1]) * t ^ 1.5
    o.glow.x_scale, o.glow.y_scale = sc, sc
    o.glow.color = acid(0.35 + 0.45 * t, 0.6 + 0.4 * pulse)
  end
  if o.light.valid then
    o.light.scale = k.light[1] + (k.light[2] - k.light[1]) * t
    o.light.intensity = 0.4 + 0.6 * pulse
  end
  if o.ring.valid then
    o.ring.radius = k.r * (1 - t) + 0.6 * t
    o.ring.width = 2 + 4 * t
    o.ring.color = acid(0.3 + 0.6 * t)
  end
end

-- Something drawn that moves or changes for a while: from {x0, y0} by {dx, dy} over T ticks, eased out, along an arc of
-- height h; its scale from s0 to s1 (a ring's radius from r0 to r1, its width w0 to w1) and its alpha a0 to a1.
local function move(m) table.insert(st().moving, m) end

local function move_tick(m, tick)
  if not m.obj.valid then return true end
  local p = (tick - m.t0) / m.T
  if p < 0 then return false end
  if p >= 1 then
    if m.keep then return true end
    m.obj.destroy()
    return true
  end
  local e = m.linear and p or 1 - (1 - p) * (1 - p)
  if m.dx then
    m.obj.target = {m.x0 + m.dx * e, m.y0 + m.dy * e - (m.h or 0) * 4 * p * (1 - p)}
  end
  if m.r0 then
    m.obj.radius = m.r0 + (m.r1 - m.r0) * e
    m.obj.width = m.w0 + (m.w1 - m.w0) * p
  end
  if m.s0 then
    local sc = m.s0 + (m.s1 - m.s0) * e
    m.obj.x_scale, m.obj.y_scale = sc, sc
  end
  if m.a0 then m.obj.color = acid(m.a0 + (m.a1 - m.a0) * p, m.k) end
  return false
end

-- A pool left by a splash: its last frame, its colour fading over its last POOL_FADE ticks.
local POOL_TINT = {r = 0.62, g = 1, b = 0.45, a = 1}
local function pool_fade_tick(m, tick)
  if not m.obj.valid then return true end
  if tick < m.fade then return false end
  local a = 1 - (tick - m.fade) / POOL_FADE
  if a <= 0 then m.obj.destroy(); return true end
  m.obj.color = {r = POOL_TINT.r * a, g = POOL_TINT.g * a, b = POOL_TINT.b * a, a = a}
  return false
end

-- A burst's blast drawn at pos of surface s, of `kind`.
function burstfx.blast(s, pos, kind)
  local k = KIND[kind]
  if not k or storage.burstfx_off then return end
  local x, y, t0 = pos.x, pos.y, game.tick
  local r = rng.new(math.floor(x * 7) + math.floor(y * 13) * 31 + t0 * 17)
  local drawn = 0
  -- Its flash: a burst of light, and its glow swelling out and fading.
  rendering.draw_light{sprite = "utility/light_medium", scale = k.flash, intensity = 1, color = ACID, target = pos,
    surface = s, time_to_live = 20}
  rendering.draw_light{sprite = "utility/light_medium", scale = k.flash * 0.5, intensity = 0.6, color = ACID, target = pos,
    surface = s, time_to_live = 90}
  local glow = rendering.draw_sprite{sprite = FX.glow, target = pos, surface = s, render_layer = "explosion", tint = acid(0.9),
    x_scale = k.r * 0.2, y_scale = k.r * 0.2}
  move{obj = glow, t0 = t0, T = 24, s0 = k.r * 0.2, s1 = k.r * 0.55, a0 = 0.9, a1 = 0}
  -- Its shockwave: a ring on the ground racing out past its reach, and a fainter one behind it.
  local ring = rendering.draw_circle{color = acid(0.9), radius = 0.5, width = 10, filled = false, target = pos, surface = s,
    draw_on_ground = true}
  move{obj = ring, t0 = t0, T = 16, r0 = 0.5, r1 = k.r * 1.25, w0 = 12, w1 = 1, a0 = 0.9, a1 = 0}
  local ring2 = rendering.draw_circle{color = acid(0), radius = 0.3, width = 6, filled = false, target = pos, surface = s,
    draw_on_ground = true}
  move{obj = ring2, t0 = t0 + 4, T = 22, r0 = 0.3, r1 = k.r, w0 = 20, w1 = 2, a0 = 0.5, a1 = 0, k = 0.6}
  local disc = rendering.draw_circle{color = acid(0.35), radius = k.r * 0.4, filled = true, target = pos, surface = s,
    draw_on_ground = true}
  move{obj = disc, t0 = t0, T = 30, r0 = k.r * 0.4, r1 = k.r, w0 = 0, w1 = 0, a0 = 0.35, a1 = 0}
  drawn = drawn + 6
  -- The nuke's shockwave puffs, thrown out to its reach, each facing out.
  local a0 = rng.next(r) * 2 * math.pi
  local life = math.floor(FX.frames.wave / SPEED)
  for i = 1, k.puffs do
    local a = a0 + (i - 1) / k.puffs * 2 * math.pi + (rng.next(r) - 0.5) * 0.3
    local d = k.r * (0.75 + 0.3 * rng.next(r))
    local o = rendering.draw_animation{animation = FX.wave, target = {x, y}, surface = s, render_layer = "explosion",
      tint = acid(0.85), orientation = a / (2 * math.pi) + 0.25, animation_speed = SPEED,
      animation_offset = -(t0 * SPEED) % FX.frames.wave, time_to_live = life, x_scale = k.puff, y_scale = k.puff}
    move{obj = o, t0 = t0, T = 28, x0 = x, y0 = y, dx = math.cos(a) * d, dy = math.sin(a) * d * 0.8, keep = true}
  end
  drawn = drawn + k.puffs
  -- Gibs flung in arcs, tumbling, gone where they land.
  for _ = 1, k.gibs do
    local a = rng.next(r) * 2 * math.pi
    local d = k.r * (0.4 + 0.8 * rng.next(r))
    local T = 22 + rng.int(r, 0, 18)
    local sc = (0.5 + 0.5 * rng.next(r)) * (kind == "cinder" and 0.8 or 1)
    local o = rendering.draw_animation{animation = FX.gib, target = {x, y}, surface = s, render_layer = "air-object",
      tint = (rng.next(r) < 0.5) and {r = 0.6, g = 1, b = 0.35, a = 1} or {r = 0.75, g = 0.45, b = 1, a = 1},
      animation_speed = 0.4 + 0.3 * rng.next(r), animation_offset = rng.int(r, 0, FX.frames.gib - 1), x_scale = sc, y_scale = sc}
    move{obj = o, t0 = t0, T = T, x0 = x, y0 = y, dx = math.cos(a) * d, dy = math.sin(a) * d * 0.8,
      h = k.r * (0.3 + 0.4 * rng.next(r)), linear = true}
  end
  drawn = drawn + k.gibs
  -- Acid splashes round where it burst, each leaving its pool a while.
  for i = 1, k.splashes do
    local a = rng.next(r) * 2 * math.pi
    local d = (i == 1) and 0 or k.r * (0.2 + 0.4 * rng.next(r))
    local px, py = x + math.cos(a) * d, y + math.sin(a) * d * 0.8
    local v = rng.int(r, 1, FX.splashes)
    local sc = k.splash * (0.8 + 0.4 * rng.next(r))
    local delay = (i == 1) and 0 or rng.int(r, 2, 14)
    local spot = {s = s.index, px = px, py = py, v = v, sc = sc, pool = k.pool}
    table.insert(st().moving, {splash = spot, t0 = t0 + delay, made = false, life = math.floor(FX.frames.splash[v] / SPEED)})
  end
  drawn = drawn + 2 * k.splashes
  s.play_sound{path = FX.sizzle, position = pos, volume_modifier = k.sound}
  local n = stats()
  n.blasts[kind] = (n.blasts[kind] or 0) + 1
  n.drawn = n.drawn + drawn
end

-- A splash due (made after its delay), then its pool once it has landed.
local function splash_tick(m, tick)
  local sp = m.splash
  local s = game.surfaces[sp.s]
  if not s then return true end
  if not m.made then
    if tick < m.t0 then return false end
    m.made = true
    rendering.draw_animation{animation = FX.splash .. sp.v, target = {sp.px, sp.py}, surface = s,
      render_layer = "lower-object-above-shadow", tint = POOL_TINT, animation_speed = SPEED,
      animation_offset = -(tick * SPEED) % FX.frames.splash[sp.v], time_to_live = m.life, x_scale = sp.sc, y_scale = sp.sc}
    return false
  end
  if tick < m.t0 + m.life - 1 then return false end
  local o = rendering.draw_sprite{sprite = FX.pool .. sp.v, target = {sp.px, sp.py}, surface = s,
    render_layer = "lower-object-above-shadow", tint = POOL_TINT, x_scale = sp.sc, y_scale = sp.sc}
  table.insert(st().moving, {obj = o, pool = true, fade = tick + sp.pool - POOL_FADE})
  return true
end

-- A burster's death (control.lua's on_entity_died): its blast's look. Set off (wound up) a big burster's is whole; killed
-- short, its core's (fizzle).
local whole = {}
function burstfx.on_died(e)
  local ent = e.entity
  local kind = OF[ent.name]
  if not kind then return end
  if kind == "big" and not whole[ent.unit_number] then kind = "fizzle" end
  whole[ent.unit_number] = nil
  burstfx.blast(ent.surface, ent.position, kind)
end
-- (Set by the big burster's blast in herd.lua just before its death: whole.)
function burstfx.mark_whole(u) whole[u.unit_number] = true end

-- A cinder's attack: its wind-up.
function burstfx.on_trigger(e)
  if e.effect_id ~= FX.windup then return end
  local u = e.source_entity
  if u and u.valid and u.type == "unit" then burstfx.windup(u) end
end

function burstfx.tick(tick)
  local s = storage.burstfx
  if not s then return end
  if next(s.winding) then
    local done = {}
    for n, e in pairs(s.winding) do
      if wind_tick(e, tick) then done[#done + 1] = n end
    end
    for _, n in ipairs(done) do s.winding[n] = nil end
  end
  local m = s.moving
  if not m[1] then return end
  local keep = {}
  for _, x in ipairs(m) do
    local done
    if x.splash then done = splash_tick(x, tick)
    elseif x.pool then done = pool_fade_tick(x, tick)
    else done = move_tick(x, tick) end
    if not done then keep[#keep + 1] = x end
  end
  -- (Those added while it ran, a splash's pool, came after its end: ipairs reached them, kept above.)
  s.moving = keep
end

-- Its counts (tests, the film helper): wind-ups, blasts by kind, objects drawn; how many are winding and drawn now; the last
-- wind-up (where, when, its kind).
function burstfx.stats()
  local n = stats()
  local winding = 0
  for _ in pairs(st().winding) do winding = winding + 1 end
  return {windups = n.windups, blasts = n.blasts, drawn = n.drawn, winding = winding, moving = #st().moving, last = n.last}
end

return burstfx
