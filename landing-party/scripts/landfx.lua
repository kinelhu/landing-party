-- A landing's look (the user, 2026-11-04, on the trailer's Grubstake landing: "the lack of animation is a little jarring.
-- Perhaps we could add some falling cargo pods dropping with the crashed lander?"). Drawn only: the settlement, its lander
-- and its timings are what they were. All of it is rendering and sound, nothing the game makes: an explosion or a
-- projectile is an entity, and layout.area_free refuses ground holding one (a landing's look moving a hub); scorch
-- corpses, trivial smoke and particles turned the fights of rail and herd (the regression of 2026-11-05). Its pictures:
-- descent.lua.
--   descent: a landing that comes by cargo pod (faction's landing jobs) knows when its lander will appear: the hull's
--     shadow darkens and tightens on the spot and the hull comes down on its flames, to touch as the lander is created.
--     The lander stands where its pod fell (until 2026-11-06 its pods' bursts pushed it to the next free pad, 15 tiles off
--     on seed 12345); the pad is asked again once they are down (landfx.locate), the hull steering onto it if the ground
--     changed meanwhile.
--   crash: the lander created (base.land, every landing): its blast, flash, scorch and dust, then PODS cargo pods
--     streaking down round it over the next few seconds (the camp's first parts), each bursting where it falls.
-- Spots and delays from rng.lua, seeded by the settlement; the state in storage.landfx, its counts in b.landfx (scenario
-- landfx).
local shared = require("__landing-party__.shared")
local rng = require("__landing-party__.scripts.rng")

local landfx = {}
local FX = shared.LANDFX
-- Where a lander sent to `site` would stand now (faction sets it: layout.find_pad).
landfx.locate = nil

-- A landing by pod: its pod's 399-tick descent (pods.lua's spike), then the landing check of the next whole second
-- (faction's landing jobs run every 60 ticks, the pod sent on one of them): the lander comes 420 ticks after its pod.
landfx.AFTER_POD = 420
local SHADOW_LEAD = 240        -- the hull's shadow shows this long before it lands
local SHADOW_ALPHA = 0.6
local SHADOW_SPREAD = 1.6      -- its shadow's spread while the hull is high (1 + this times its scale at the start)
local HULL_HEIGHT = 70         -- tiles above its spot the hull is first drawn
local HULL_TICKS = 120         -- its fall, slowing on its flames
local RETARGET = 15            -- ticks before the landing the spot is asked again (its pods down 21 ticks before)
local PODS = 6
local POD_FIRST = 24           -- ticks after the crash the first pod is sent
local POD_EVERY = 30           -- and between pods, plus up to POD_JITTER
local POD_JITTER = 14
local POD_HEIGHT = 34
local POD_TICKS = 50
local POD_NEAR, POD_FAR = 12, 19   -- tiles from the lander's centre (its hull spans about 19 x 12)
local FLASH = {r = 1, g = 0.62, b = 0.3}

local function list()
  storage.landfx = storage.landfx or {}
  return storage.landfx
end

-- An explosion's animation from its first frame, gone after its last.
local function boom(s, key, x, y, scale)
  local n = FX.frames[key]
  rendering.draw_animation{animation = FX[key], target = {x, y}, surface = s, render_layer = "explosion",
    animation_speed = FX.speed, animation_offset = -(game.tick * FX.speed) % n, time_to_live = math.floor(n / FX.speed),
    x_scale = scale, y_scale = scale}
end

-- A puff of dust or smoke (the artillery smoke's animation, from its first frame). Not the engine's trivial smoke nor
-- its particles: those are made by the game, and with them on the fights of rail and herd turned out otherwise.
local DUST_SPEED = 1 / 6
local DUST = {r = 0.55, g = 0.48, b = 0.38, a = 0.85}
local function puff(s, x, y, scale, tint)
  local n = FX.frames.dust
  rendering.draw_animation{animation = FX.dust, target = {x, y}, surface = s, render_layer = "smoke", tint = tint or DUST,
    animation_speed = DUST_SPEED, animation_offset = -(game.tick * DUST_SPEED) % n, time_to_live = math.floor(n / DUST_SPEED),
    x_scale = scale, y_scale = scale}
end
-- A scorch mark: drawn, and gone after SCORCH_TICKS (a corpse would have been an entity, see puff).
local SCORCH_TICKS = 3 * 3600
local function scorch(s, sprite, x, y)
  rendering.draw_sprite{sprite = sprite, target = {x, y}, surface = s, render_layer = "ground-patch-higher2",
    time_to_live = SCORCH_TICKS, tint = {r = 1, g = 1, b = 1, a = 0.9}}
end
local SMOKE = {r = 0.25, g = 0.25, b = 0.25, a = 0.7}

local function flash(s, x, y, scale, ttl)
  rendering.draw_sprite{sprite = "lp-impact-flash", target = {x, y}, surface = s, x_scale = scale, y_scale = scale,
    render_layer = "explosion", time_to_live = ttl}
  rendering.draw_light{sprite = "utility/light_medium", scale = scale, intensity = 1, color = FLASH, target = {x, y},
    surface = s, time_to_live = 2 * ttl}
end

-- The hull's descent onto `at` of `surface` (site: the search's point, to ask the spot again), its lander due at `eta`.
function landfx.descent(surface, site, at, corp, eta)
  if storage.landfx_off then return end
  local x, y = at[1] or at.x, at[2] or at.y
  local start = math.max(game.tick, eta - SHADOW_LEAD)
  local shadow = rendering.draw_sprite{sprite = FX.shadow, target = {x, y}, surface = surface, render_layer = "lower-object",
    tint = {r = 0, g = 0, b = 0, a = 0}, x_scale = 1 + SHADOW_SPREAD, y_scale = 1 + SHADOW_SPREAD}
  table.insert(list(), {kind = "descent", surface = surface.index, site = {site[1] or site.x, site[2] or site.y},
    from = {x, y}, at = {x, y}, corp = corp, eta = eta, start = start, shadow = shadow, launch = eta - HULL_TICKS})
  storage.landfx_descents = (storage.landfx_descents or 0) + 1
end

local function descent_tick(d, tick, s)
  -- Its spot asked again once its pods are down (something built there meanwhile moves the landing).
  if not d.asked and tick >= d.eta - RETARGET then
    d.asked = true
    local now = landfx.locate and landfx.locate(s, d.site)
    if now then d.from, d.at, d.steer = {d.at[1], d.at[2]}, {now[1], now[2]}, tick end
  end
  local x, y = d.at[1], d.at[2]
  if d.steer then
    local k = math.min(1, (tick - d.steer) / math.max(1, d.eta - d.steer))
    x, y = d.from[1] + (d.at[1] - d.from[1]) * k, d.from[2] + (d.at[2] - d.from[2]) * k
  end
  if not d.hull and tick >= d.launch then
    -- (Its re-entry roar as the hull shows, its touchdown's blast 2 s on: the Sound Sheet's round four.)
    shared.cue(s, "landing-roar", {x, y})
    d.hull = rendering.draw_animation{animation = shared.variant(d.corp, "lp-lander") .. FX.fall, target = {x, y - HULL_HEIGHT},
      surface = s, render_layer = "air-object", animation_speed = 0.5}
    d.hull_at = tick
    d.light = rendering.draw_light{sprite = "utility/light_medium", scale = 12, intensity = 0.9, color = FLASH,
      target = {x, y - HULL_HEIGHT + 6}, surface = s}
  end
  local t = math.min(1, math.max(0, (tick - d.start) / math.max(1, d.eta - d.start)))
  if d.shadow and d.shadow.valid then
    local e = t * t
    d.shadow.target = {x, y}
    d.shadow.color = {r = 0, g = 0, b = 0, a = SHADOW_ALPHA * e}
    local sc = 1 + SHADOW_SPREAD * (1 - e)
    d.shadow.x_scale, d.shadow.y_scale = sc, sc
  end
  if d.hull and d.hull.valid then
    -- Slowing on its flames: its height (1 - p)^1.6 of its first.
    local p = math.min(1, (tick - d.launch) / HULL_TICKS)
    local h = HULL_HEIGHT * (1 - p) ^ 1.6
    d.hull.target = {x, y - h}
    if d.light and d.light.valid then d.light.target = {x, y - h + 6} end
    if tick % 4 == 0 then puff(s, x + (tick % 7) - 3, y - h + 7, 2, SMOKE) end
  end
  -- Done once its lander is down (landfx.crash ends it), or a while after it was due (a pod lost: POD_WAIT).
  if tick > d.eta + 60 then
    for _, o in ipairs({d.shadow, d.hull, d.light}) do if o and o.valid then o.destroy() end end
    return true
  end
end

local function crash_tick(p, tick, s)
  local b = storage.bases and storage.bases[p.base]
  local fx = b and b.landfx
  local done = true
  for _, q in ipairs(p.pods) do
    if not q.sent and tick >= q.launch then
      q.sent = true
      q.pod = rendering.draw_animation{animation = FX.pod, target = {q.at[1], q.at[2] - POD_HEIGHT}, surface = s,
        render_layer = "air-object", animation_speed = 0.5}
      q.light = rendering.draw_light{sprite = "utility/light_medium", scale = 3, intensity = 0.8, color = FLASH,
        target = {q.at[1], q.at[2] - POD_HEIGHT + 2}, surface = s}
      q.shadow = rendering.draw_circle{color = {r = 0, g = 0, b = 0, a = 0}, radius = 0.4, filled = true, target = q.at,
        surface = s, draw_on_ground = true}
      if fx then fx.drawn = fx.drawn + 3 end
    end
    if q.sent and not q.hit then
      local x, y = q.at[1], q.at[2]
      if tick >= q.land then
        q.hit = true
        for _, o in ipairs({q.pod, q.light, q.shadow}) do if o and o.valid then o.destroy() end end
        boom(s, "blast", x, y, 1)
        flash(s, x, y, 4, 12)
        for k = 1, 3 do puff(s, x + k - 2, y + (k % 2) - 0.5, 2.5) end
        scorch(s, FX.scorch, x, y)
        s.play_sound{path = FX.sound, position = {x, y}, volume_modifier = 0.6}
        if fx then fx.fell = fx.fell + 1; fx.drawn = fx.drawn + 7 end
      else
        local k = (tick - q.launch) / (q.land - q.launch)
        local h = POD_HEIGHT * (1 - k) ^ 1.2
        if q.pod and q.pod.valid then q.pod.target = {x, y - h} end
        if q.light and q.light.valid then q.light.target = {x, y - h + 2} end
        if q.shadow and q.shadow.valid then
          q.shadow.color = {r = 0, g = 0, b = 0, a = 0.45 * k}
          q.shadow.radius = 0.4 + 0.8 * k
        end
        if tick % 4 == 0 then puff(s, x, y - h + 2.5, 1, SMOKE) end
      end
    end
    if not q.hit then done = false end
  end
  return done
end

-- The lander of b down (base.land): its crash, and its pods to follow.
function landfx.crash(b)
  if storage.landfx_off or not (b.lander and b.lander.valid) then return end
  local s, c = b.lander.surface, b.lander.position
  local fx = {tick = game.tick, pods = PODS, fell = 0, drawn = 0, made = 0, descended = false}
  b.landfx = fx
  -- Its descent, if it came by pod: over (the lander's own picture takes over from its hull).
  local all = list()
  for i = #all, 1, -1 do
    local d = all[i]
    -- (Its own: due about now on this surface. A fortress's lander stands off the pad asked for: its hull goes all the same.)
    if d.kind == "descent" and d.surface == s.index and math.abs(game.tick - d.eta) <= 60 then
      for _, o in ipairs({d.shadow, d.hull, d.light}) do if o and o.valid then o.destroy() end end
      fx.descended = d.hull ~= nil
      fx.hull_at, fx.hull_off = d.hull_at, math.floor(math.sqrt((d.at[1] - c.x) ^ 2 + (d.at[2] - c.y) ^ 2) * 10 + 0.5) / 10
      fx.steered = d.from and math.floor(math.sqrt((d.at[1] - d.from[1]) ^ 2 + (d.at[2] - d.from[2]) ^ 2) + 0.5) or 0
      table.remove(all, i)
    end
  end
  local r = rng.new(b.id * 7919 + math.floor(c.x) * 31 + math.floor(c.y))
  -- The blast: its centre and along the hull, scorched ground under and beside it.
  boom(s, "crash", c.x, c.y, 1.3)
  for _, o in ipairs({{-7, -2}, {6, -3}, {-4, 3}, {5, 3}, {0, -4}}) do
    boom(s, "blast", c.x + o[1] + rng.next(r) * 2 - 1, c.y + o[2] + rng.next(r) * 2 - 1, 1.2)
  end
  scorch(s, FX.scorch_big, c.x, c.y)
  for _, o in ipairs({{-8, 2}, {8, 2}, {0, 5}}) do scorch(s, FX.scorch, c.x + o[1], c.y + o[2]) end
  -- Its dust thrown out round the hull.
  for k = 1, 16 do
    local a = (k + rng.next(r)) / 16 * 2 * math.pi
    puff(s, c.x + math.cos(a) * 11, c.y + math.sin(a) * 7, 5)
  end
  flash(s, c.x, c.y, 14, 20)
  s.play_sound{path = FX.sound, position = c}
  fx.drawn = 8 + 4 + 16
  -- Its pods, round it at seeded bearings and distances, one after another.
  local p = {kind = "crash", base = b.id, surface = s.index, pods = {}}
  local a0 = rng.next(r) * 2 * math.pi
  local due = game.tick + POD_FIRST
  for k = 1, PODS do
    local a = a0 + (k - 1) / PODS * 2 * math.pi + (rng.next(r) - 0.5) * 0.6
    local d = POD_NEAR + rng.next(r) * (POD_FAR - POD_NEAR)
    table.insert(p.pods, {at = {c.x + math.cos(a) * d * 1.2, c.y + math.sin(a) * d * 0.8}, launch = due, land = due + POD_TICKS})
    due = due + POD_EVERY + rng.int(r, 0, POD_JITTER)
  end
  table.insert(all, p)
end

function landfx.tick(tick)
  local all = storage.landfx
  if not (all and all[1]) then return end
  for i = #all, 1, -1 do
    local e = all[i]
    local s = game.surfaces[e.surface]
    local done = not s or (e.kind == "descent" and descent_tick(e, tick, s)) or (e.kind == "crash" and crash_tick(e, tick, s))
    if done then table.remove(all, i) end
  end
end

-- What is in flight (tests).
function landfx.active() return #(storage.landfx or {}) end

return landfx
