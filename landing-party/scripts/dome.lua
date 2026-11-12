-- The dome (Kessler-Hayashi; the user, 2026-11-01: "making KH camps artillery proof through shield domes? Would force
-- army encounters", then, on artillery set to auto-target firing into it for good: "maybe that's not a bug and rather a
-- feature"). Round its lander, RADIUS tiles, while its hull is up (its generators powered: base.lua makes the lander
-- indestructible then): every artillery shell that comes into it is destroyed in the air, a burst where it was caught,
-- a share of its charge spent (HOLD). At none the dome breaks, and stays down BREAK; then it is whole again. Units pass under it: it stops
-- shells, not bodies, so Synthexis's waves fight the camp as before and the player's troops can walk in. Shells crossing
-- it to something behind are caught as well (its ground shelters what lies beyond it until it breaks). The player's
-- artillery on auto-target keeps firing into it: the price of not sending troops; the first catch in ALERT_TICKS raises
-- an alert where alerts are on. Engine (scenario domeprobe, 2026-11-01): an artillery projectile is an entity a script finds by area and
-- destroys; one at a tile a tick is seen about 15 times inside 30 tiles at a look every 2 ticks, none got through.
-- Its hubs' domes (the user, 2026-11-02, on its camp growing into the player's artillery: "Isn't 2 much more elegant?"):
-- a dome projector at each hub after the first, put up once it has a block, a dome over that hub's blocks
-- (their farthest corner from it, RADIUS at least), up while it stands and its hull is up, its own charge from the guns that
-- reach it; destroyed, put back PROJECTOR_BACK after with its hull up. Landed 588 tiles from nwa's nearest artillery (its
-- reach 560), its camp grew 95 tiles toward the player and lost 16 depots, radars and turrets to it in 12 minutes, its
-- lander's dome 30 tiles round (2026-11-02).
-- On for corporations with shared.CORPS dome (Kessler-Hayashi); debug_tune domes = false turns it off.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local threat = require("__landing-party__.scripts.threat")
local ops = require("__landing-party__.scripts.ops")

local lights = require("__landing-party__.scripts.lights")
local dome = {}
local RADIUS = 30
-- What a dome takes before it breaks: HOLD of the fire of every foe's artillery that reaches it (its prototype's rate,
-- its force's research), at least one gun's; it mends a sixtieth of that a minute while up. A flat 300 before, tuned on
-- one battery of six (about 1.8 shells a second, broken in about three minutes); 20 bought a minute against them and the
-- camp was flattened as without it (forward artillery, artillery base, 2026-11-01). Measured in time, a battery of 6 and
-- one of 60 each take HOLD to break it: the guns buy no shortcut, troops do. (debug_tune dome_charge fixes it, tests.)
local HOLD = 3 * 60                -- seconds of the guns' fire
local MEND = 1 / 60                -- of its whole, a minute
local LOOK_GUNS = 60 * 60          -- ticks between counts of the guns that reach it
local ART = {"artillery-turret", "artillery-wagon"}
local BREAK = 3 * 60 * 60       -- down this long, then whole
local LOOK = 2                  -- ticks between looks for shells
local ALERT_TICKS = 10 * 60 * 60
local COLOR = {r = 0.55, g = 0.8, b = 0.85}
local PROJECTOR_BACK = 30 * 60 * 60
local LOOK_PROJECTORS = 60 * 60

local function trace(b, msg) if base.trace then base.trace(b, "dome: " .. msg) end end

-- Up while its camp's hull is (its generators powered: base.lua makes the lander indestructible then), a projector's
-- while it stands too. (By a projector's own power, put up before its district's pylons it stood dark, and nwa's
-- artillery took it a minute after: 0.2.146.)
local function powered(b, d)
  local a = d.anchor
  return a and a.valid and b.lander.valid and not b.lander.destructible or false
end

-- Shells a second from the foes' artillery that reaches its lander (each gun at its prototype's cooldown, its force's
-- gun speed research), at least one gun's.
local function fire_rate(b, d)
  local s, c, own = d.anchor.surface, d.anchor.position, game.forces[b.force]
  local RADIUS = d.radius
  local rate, one = 0, 0
  for name in pairs(prototypes.get_entity_filtered{{filter = "type", type = ART}}) do
    local p = threat.profile(name)
    if p then one = math.max(one, 60 / p.cooldown) end
  end
  local far = 0
  for _, f in pairs(game.forces) do if f ~= own then far = math.max(far, threat.artillery_reach(f)) end end
  for _, g in ipairs(s.find_entities_filtered{position = c, radius = far + RADIUS, type = ART}) do
    local f = g.force
    if f ~= own and not f.get_cease_fire(own) and f.name ~= "neutral" then
      local p = threat.profile(g.name)
      local r = threat.reach(g) + RADIUS
      if p and (g.position.x - c.x) ^ 2 + (g.position.y - c.y) ^ 2 <= r * r then
        local cat = prototypes.ammo_category["artillery-shell"] and "artillery-shell"
        rate = rate + 60 / p.cooldown * (1 + (cat and f.get_gun_speed_modifier(cat) or 0))
      end
    end
  end
  return math.max(rate, one)
end
-- Its whole, in shells: debug_tune's, or HOLD of the guns' fire (counted every LOOK_GUNS).
local function full(b, d)
  if storage.dome_charge then return storage.dome_charge end
  if not d.whole or game.tick >= (d.counted or 0) + LOOK_GUNS then
    d.whole, d.counted = math.max(1, math.floor(HOLD * fire_rate(b, d) + 0.5)), game.tick
  end
  return d.whole
end
-- (Its charge is kept as a share of its whole: more guns brought, more shells it takes, and the same time.)
local function fresh() return {left = 1, down_till = 0, caught = 0, breaks = 0} end
-- Round its lander, past the generators its hull stands on (base.lua hull: those within shared.HULL_RADIUS), read
-- again as the guns are counted: a fortress's pad sets its first two generators 14 tiles out and its corners' 33, and at
-- RADIUS a camp landed in nwa's artillery's reach lost its corners' four in 75 seconds, its hull went down and its lander
-- fell 9 minutes after landing (the visits at 0.2.359 and 0.2.360, seed 1; 0.2.360 read the first two only). Its guns
-- break it first now, then reach them: the troops it is meant to draw.
local PAD_SPARE = 4
local function pad_reach(b)
  -- (Its lander gone: a fallen camp's dome read by the tests raised here.)
  if not (b.lander and b.lander.valid) then return nil end
  local r, lx, ly = 0, b.lander.position.x, b.lander.position.y
  for _, g in ipairs(b.gens or {}) do
    if g.valid and g.force.name == b.force then
      local d = math.sqrt((g.position.x - lx) ^ 2 + (g.position.y - ly) ^ 2)
      if d <= shared.HULL_RADIUS and d > r then r = d end
    end
  end
  return r > 0 and r + PAD_SPARE or nil
end
local function state(b)
  b.dome = b.dome or fresh()
  if b.dome.charge and not b.dome.left then b.dome.left, b.dome.charge = math.min(1, b.dome.charge / 300), nil end
  if not b.dome.pad_at or game.tick - b.dome.pad_at >= LOOK_GUNS then b.dome.pad_r, b.dome.pad_at = pad_reach(b), game.tick end
  local r = math.max(RADIUS, b.dome.pad_r or 0)
  -- (Its ring drawn again at its new reach.)
  if r ~= b.dome.radius and b.dome.ring and b.dome.ring.valid then b.dome.ring.destroy(); b.dome.ring = nil end
  b.dome.anchor, b.dome.radius = b.lander, r
  return b.dome
end
local function charge(b, d) return d.left * full(b, d) end

-- Its shell over the camp, faint, drawn while it stands.
local function show(b, d, up)
  if up and not (d.ring and d.ring.valid) then
    d.ring = rendering.draw_circle{color = {r = COLOR.r * 0.25, g = COLOR.g * 0.25, b = COLOR.b * 0.25, a = 0.25},
      radius = d.radius, width = 3, filled = false, target = d.anchor, surface = d.anchor.surface, draw_on_ground = true}
  elseif not up and d.ring and d.ring.valid then
    d.ring.destroy()
    d.ring = nil
  end
end

-- (Gated as every alert is, shared.notices_on, off by default: the burst where a shell is caught is the tell.)
local function alert(b, pos, d)
  if game.tick < (storage.dome_alert or 0) or not shared.notices_on() then return end
  storage.dome_alert = game.tick + ALERT_TICKS
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) then
      for _, p in pairs(f.connected_players) do -- notice-ok: gated above
        p.add_custom_alert(d.anchor, {type = "item", name = "artillery-shell"},
          {"lp.dome-alert", shared.corp_label(b.corp)}, true) -- notice-ok: gated above
      end
    end
  end
end

-- Its catch, seen (the user, 2026-11-03: "Enlarged Tesla tower, fires a bolt at the shell when it arrives in its territory";
-- "A hemisphere effect rippling from the impact"): a bolt from its tower's crown (TOWER_CROWN tiles up; the lander's for
-- the camp's dome) to the shell, a small burst where it dies, and the ripple (data.lua: lp-dome-ripple).
local TOWER_CROWN, LANDER_CROWN = 3.4, 2
-- The hit seen over the whole dome (0.2.192; the user, 2026-11-04: "shouldn't the effect come from the impact and
-- dissipate over the whole bubble?"): a flash where the shell met its skin and a wave across it from there (data.lua:
-- lp-dome-wave-k, the impact's direction from the south, counter-clockwise seen from above), scaled to its radius. Its
-- frame is framed on the dome seen at 45 degrees: its middle WAVE_UP of the radius above the dome's centre on the ground.
-- Before it, a hemisphere 9 tiles across at the impact, which read as a puff, not the shield (the gallery, 2026-11-04).
local DW = shared.DOME_WAVE
local WAVE_UP, RISE_UP = 0.207, 0.16
local function once(name, frames, speed)
  return {animation = name, animation_speed = speed, animation_offset = -(game.tick * speed) % frames,
    time_to_live = math.floor(frames / speed)}
end
function dome.wave(d, pos)
  if not (d.anchor and d.anchor.valid) then return end
  local c = d.anchor.position
  local px, py = pos.x or pos[1], pos.y or pos[2]
  local az = math.atan2(-(py - c.y), px - c.x)              -- from the east, counter-clockwise, north up
  local k = math.floor((az + math.pi / 2) / (math.pi / 4) + 0.5) % 8 + 1
  local sc = d.radius / DW.ref
  local a = once("lp-dome-wave-" .. k, DW.frames, DW.speed)
  a.target, a.surface = {c.x, c.y - WAVE_UP * d.radius}, d.anchor.surface
  a.x_scale, a.y_scale = sc, sc
  rendering.draw_animation(a)
end
-- The dome going up (raised, whole again, or its power back): the ripple grown to its radius over its projector.
function dome.rise(d)
  if not (d.anchor and d.anchor.valid) then return end
  local c = d.anchor.position
  local sc = d.radius / DW.rise_r
  local a = once("lp-dome-rise", DW.rise_frames, DW.rise_speed)
  a.target, a.surface, a.x_scale, a.y_scale = {c.x, c.y - RISE_UP * d.radius}, d.anchor.surface, sc, sc
  rendering.draw_animation(a)
end
local function catch(b, d, pr)
  local s, pos = pr.surface, pr.position
  pr.destroy()
  if d.anchor and d.anchor.valid then
    local crown = d.anchor.name:find("dome-projector", 1, true) and TOWER_CROWN or LANDER_CROWN
    s.create_entity{name = "chain-tesla-turret-beam-start", position = d.anchor.position, source = d.anchor,
      source_offset = {0, -crown}, target_position = pos, duration = 12}
  end
  s.create_entity{name = "explosion", position = pos}
  dome.wave(d, pos)
  d.left, d.caught = math.max(0, d.left - 1 / full(b, d)), d.caught + 1
  alert(b, pos, d)
  if d.left <= 1e-9 then
    d.left = 0
    d.down_till, d.breaks = game.tick + BREAK, d.breaks + 1
    trace(b, string.format("broken after %d shells caught (%d breaks); down for %d s", d.caught, d.breaks, BREAK / 60))
  end
end

-- A hub's blocks' farthest corner from its projector, RADIUS at least.
local function hub_radius(b, hub, at)
  local r = RADIUS
  for _, k in ipairs(b.blocks or {}) do
    if k.hub == hub.id then
      for _, q in ipairs({{k.x0, k.y0}, {k.x0 + k.w, k.y0}, {k.x0, k.y0 + k.h}, {k.x0 + k.w, k.y0 + k.h}}) do
        r = math.max(r, math.sqrt((q[1] - at.x) ^ 2 + (q[2] - at.y) ^ 2))
      end
    end
  end
  return r
end
-- Where a hub's projector goes: by its blocks' middle, on no spot a queued job of the camp's is for (placed over one, the
-- relay took a fortress turret's spot). Waiting for the hub's jobs to be done instead, a district under the player's
-- artillery never got one: what the shells broke was queued again (nwa, 44 lost in 20 minutes, 0.2.146).
local function projector_spot(b, hub)
  local s = b.lander.surface
  local n, cx, cy = 0, 0, 0
  for _, k in ipairs(b.blocks or {}) do
    if k.hub == hub.id then n, cx, cy = n + 1, cx + k.x0 + k.w / 2, cy + k.y0 + k.h / 2 end
  end
  if n == 0 then return nil end
  cx, cy = cx / n, cy / n
  -- Each job's footprint, not its middle alone: 4 tiles clear of the launchpad's middle, the projector stood on the
  -- launchpad's 9 by 9 and the crew skipped it, and the camp never exported (no fund, no research; hazard research).
  local function half(name)
    local pr = name and prototypes.entity[name]
    if not pr then return 0 end
    local c = pr.collision_box
    return math.max(-c.left_top.x, c.right_bottom.x, -c.left_top.y, c.right_bottom.y)
  end
  local own = half("lp-dome-projector") + 0.5
  local jobs = {}
  local function avoid(job) if job.pos then jobs[#jobs + 1] = {job.pos[1], job.pos[2], half(job.name) + own} end end
  for _, job in ipairs(b.queue or {}) do avoid(job) end
  -- And the jobs a crew carries, off the queue since it left (a drone took the launch block's 9 jobs at 39330, the
  -- projector went on the launchpad's spot at 39600 and the crew skipped it: no export, no fund; hazard research, 0.2.352).
  for _, c in ipairs(b.crews or {}) do for _, job in ipairs(c.jobs or {}) do avoid(job) end end
  for r = 0, 24, 4 do
    for k = 0, (r == 0 and 0 or 7) do
      local a = k * math.pi / 4
      local p = s.find_non_colliding_position("lp-dome-projector", {cx + math.cos(a) * r, cy + math.sin(a) * r}, 2, 0.5)
      if p then
        local free = true
        for _, q in ipairs(jobs) do
          if (q[1] - p.x) ^ 2 + (q[2] - p.y) ^ 2 < 16 or math.abs(q[1] - p.x) < q[3] and math.abs(q[2] - p.y) < q[3] then
            free = false; break
          end
        end
        if free then return p end
      end
    end
  end
end
-- Its hubs' projectors: placed, or put back, where none stands; each dome's reach follows its hub's blocks.
local function projectors(b, tick)
  b.domes = b.domes or {}
  for _, hub in ipairs(b.hubs or {}) do
    if hub.id > 1 then
      local key = "hub" .. hub.id
      local d = b.domes[key]
      if d and not (d.anchor and d.anchor.valid) and not d.back_at then
        d.back_at, d.lost = tick + PROJECTOR_BACK, (d.lost or 0) + 1
        if d.ring and d.ring.valid then d.ring.destroy() end
        d.ring = nil
        trace(b, string.format("the projector of its %s destroyed: down for %d minutes", key, PROJECTOR_BACK / 3600))
      end
      if (not d or d.back_at) and tick >= ((d and d.back_at) or 0) and not b.lander.destructible then
        local s = b.lander.surface
        local p = projector_spot(b, hub)
        local e = p and s.create_entity{name = "lp-dome-projector", position = p, force = b.force}
        lights.attach(e, b.corp)
        if e then
          d = d or fresh()
          d.anchor, d.back_at, d.left, d.down_till = e, nil, 1, 0
          b.domes[key] = d
          trace(b, string.format("a projector up by its %s at %.0f,%.0f", key, p.x, p.y))
        end
      end
      if d and d.anchor and d.anchor.valid then
        local r = hub_radius(b, hub, d.anchor.position)
        if r ~= d.radius then
          d.radius = r
          if d.ring and d.ring.valid then d.ring.destroy() end
          d.ring = nil
        end
      end
    end
  end
end

-- A standing siege's dome (siege.lua, its bombard begun): a projector by its site, its dome over its pieces (the
-- farthest, and 6, RADIUS at least), the camp's charge rules; gone with the siege (ops.finish). The player's artillery
-- cannot take the site from afar: troops can.
function ops.site_dome(b, op)
  if storage.domes == false or not (shared.CORPS[b.corp] or {}).dome then return end
  local s = b.lander.surface
  local p = s.find_non_colliding_position("lp-dome-projector", {op.site[1], op.site[2]}, 12, 1)
  local e = p and s.create_entity{name = "lp-dome-projector", position = p, force = b.force}
  if not e then return end
  lights.attach(e, b.corp)
  local r = RADIUS
  for _, m in ipairs(op.mortars or {}) do
    if m.valid then r = math.max(r, math.sqrt((m.position.x - p.x) ^ 2 + (m.position.y - p.y) ^ 2) + 6) end
  end
  if op.howitzer and op.howitzer.valid then
    r = math.max(r, math.sqrt((op.howitzer.position.x - p.x) ^ 2 + (op.howitzer.position.y - p.y) ^ 2) + 6)
  end
  b.domes = b.domes or {}
  local d = fresh()
  d.anchor, d.radius = e, r
  b.domes.siege = d
  op.site_dome = e
  trace(b, string.format("a projector by its siege at %.0f,%.0f, %d tiles", p.x, p.y, r))
end
function ops.site_dome_down(b, op)
  if op.site_dome and op.site_dome.valid then op.site_dome.destroy() end
  local d = b.domes and b.domes.siege
  if d and d.ring and d.ring.valid then d.ring.destroy() end
  if b.domes then b.domes.siege = nil end
end

local function run(b, d, tick)
  if d.down_till > 0 and tick >= d.down_till then
    d.left, d.down_till = 1, 0
    trace(b, "whole again")
  end
  local up = d.down_till == 0 and powered(b, d)
  if up and not d.was_up then dome.rise(d) end
  d.was_up = up
  if tick % 60 == 0 then show(b, d, up) end
  if up and tick % 3600 == 0 then d.left = math.min(1, d.left + MEND) end
  if up then
    -- Its foes' shells only: its own mortars' and orbital barrage's shells are artillery projectiles too, fired from
    -- inside the dome or falling on its landing ground.
    local own = game.forces[b.force]
    for _, pr in pairs(d.anchor.surface.find_entities_filtered{type = "artillery-projectile", position = d.anchor.position,
      radius = d.radius}) do
      -- (An orbital shell passes: a dome stops artillery fired from the ground, not a strike from orbit. The player's
      -- strike, its counter taken from Kessler-Hayashi's own beacon, fell under a hub's dome and broke nothing, scenario
      -- strike, 0.2.158.)
      if pr.valid and pr.force ~= own and not pr.force.get_cease_fire(own) and pr.name ~= "lp-orbital-projectile" then
        catch(b, d, pr)
      end
      if d.left <= 0 then break end
    end
  end
end

function dome.tick(tick)
  if storage.domes == false or tick % LOOK ~= 0 then return end
  for _, b in pairs(storage.bases or {}) do
    if (shared.CORPS[b.corp] or {}).dome and not b.fallen and b.lander and b.lander.valid then
      run(b, state(b), tick)
      if tick % LOOK_PROJECTORS == 0 then projectors(b, tick) end
      for _, d in pairs(b.domes or {}) do
        if d.anchor and d.anchor.valid then run(b, d, tick) end
      end
    end
  end
end

-- Tests: a camp's dome (charge, caught, breaks, up).
function dome.state(b)
  local d = state(b)
  return {charge = math.floor(charge(b, d) + 0.5), whole = full(b, d), caught = d.caught, breaks = d.breaks, radius = d.radius,
    up = d.down_till == 0 and powered(b, d), projectors = (function()
      local n, caught = 0, 0
      for _, h in pairs(b.domes or {}) do
        if h.anchor and h.anchor.valid then n = n + 1 end
        caught = caught + h.caught
      end
      return {up = n, caught = caught}
    end)()}
end

-- The player's dome (the user, 2026-11-04: in place of a directional shield projector, "a repurposed dome (smaller than
-- KH) that the player can use to protect from shelling"): a projector of the player's, shared.PLAYER_DOME.radius round
-- it, catching its foes' shells as Kessler-Hayashi's do, by their rule (the rewards consult: never holding for good): it
-- takes HOLD of the fire of the guns that reach it, then is down BREAK, mending while up; up while it has power. Not the
-- orbital strike. Bullets, beams and biters pass: the army still has to answer the guns.
local function pd_list() storage.pdomes = storage.pdomes or {} return storage.pdomes end
function dome.player_built(ent)
  if not (ent and ent.valid) then return end
  local d = fresh()
  d.anchor, d.radius, d.force = ent, shared.PLAYER_DOME.radius, ent.force.name
  pd_list()[ent.unit_number] = d
end
local function pd_catch(d, pr)
  local s, pos = pr.surface, pr.position
  pr.destroy()
  s.create_entity{name = "chain-tesla-turret-beam-start", position = d.anchor.position, source = d.anchor,
    source_offset = {0, -TOWER_CROWN}, target_position = pos, duration = 12}
  s.create_entity{name = "explosion", position = pos}
  dome.wave(d, pos)
  d.left, d.caught = math.max(0, d.left - 1 / full({force = d.force}, d)), d.caught + 1
  if d.left <= 1e-9 then d.left, d.down_till, d.breaks = 0, game.tick + BREAK, d.breaks + 1 end
end
local function pd_run(d, tick)
  if d.down_till > 0 and tick >= d.down_till then d.left, d.down_till = 1, 0 end
  local up = d.down_till == 0 and d.anchor.energy > 0
  if up and not d.was_up then dome.rise(d) end
  d.was_up = up
  if tick % 60 == 0 then show(nil, d, up) end
  if up and tick % 3600 == 0 then d.left = math.min(1, d.left + MEND) end
  if not up then return end
  local own = game.forces[d.force]
  for _, pr in pairs(d.anchor.surface.find_entities_filtered{type = "artillery-projectile", position = d.anchor.position,
    radius = d.radius}) do
    if pr.valid and pr.force ~= own and not pr.force.get_cease_fire(own) and not pr.force.get_friend(own)
      and pr.name ~= "lp-orbital-projectile" then
      pd_catch(d, pr)
    end
    if d.down_till > 0 then break end
  end
end
function dome.player_tick(tick)
  if not storage.pdomes or tick % LOOK ~= 0 then return end
  for n, d in pairs(storage.pdomes) do
    if not (d.anchor and d.anchor.valid) then
      if d.ring and d.ring.valid then d.ring.destroy() end
      storage.pdomes[n] = nil
    else
      pd_run(d, tick)
    end
  end
end
-- Tests: each of the player's domes, by its projector's unit number.
function dome.player_stats()
  local out = {}
  for n, d in pairs(storage.pdomes or {}) do
    out[n] = {caught = d.caught, breaks = d.breaks, down = d.down_till > 0, left = d.left}
  end
  return out
end

return dome
