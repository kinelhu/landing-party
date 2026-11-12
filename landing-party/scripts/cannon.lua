-- The player's orbital cannons (orbital_cannon.lua; DESIGN.md, "Orbital cannons", decided 2026-11-10, changed 2026-11-12).
-- A strike is called with the remote on Nauvis; it fires ONE platform of the force stopped over Nauvis with a targeting
-- array (the ready one with the most charged cannons; each platform its own COOLDOWN: more platforms, more strikes, the
-- artillery remote's way with a platform for a gun), one charge from every charged cannon on it. Its shells (SHELLS a
-- charge) fall within shared.cannon_radius(cannons) of the point: each hostile building and nest there, nearest first, as
-- many as its health takes (threat.shells_for, the strike beacon's rule), then the rest spread inside the circle. (Until
-- 0.2.346: every cannon of every platform pooled, a radius of 20, one shell a target.) The look is Kessler-Hayashi's strike's (orbital.from_orbit). A corporation struck counts it an
-- attack through its losses, as any (decided, 4: no answer of its own).
local shared = require("__landing-party__.shared")
local orbital = require("__landing-party__.scripts.orbital")
local threat = require("__landing-party__.scripts.threat")

local cannon = {}
local C = shared.CANNON
local SPARE = {wall = true, gate = true, ["electric-pole"] = true}

local function hostile(force)
  local out = {"enemy"}
  for _, c in pairs(shared.CORPS) do
    if game.forces[c.force] and not force.get_friend(c.force) then out[#out + 1] = c.force end
  end
  local bio = shared.BIOTECH.force
  if game.forces[bio] and not force.get_friend(bio) then out[#out + 1] = bio end
  return out
end

-- The force's platforms stopped over Nauvis with an array, and their cannons.
function cannon.batteries(force)
  local out = {}
  for _, pl in pairs(force.platforms) do
    local loc = pl.valid and pl.scheduled_for_deletion == 0 and pl.space_location
    local s = loc and loc.name == "nauvis" and pl.surface
    if s and s.valid and s.count_entities_filtered{name = "lp-targeting-array", limit = 1} > 0 then
      out[#out + 1] = {platform = pl, cannons = s.find_entities_filtered{name = "lp-orbital-cannon"}}
    end
  end
  return out
end

local function charges_in(e)
  local inv = e.valid and e.get_inventory(defines.inventory.crafter_output)
  return inv and inv.get_item_count("lp-orbital-charge") or 0
end

-- A platform's wait before it fires again (ticks; 0 ready).
local function wait_of(pl)
  return math.max(0, ((storage.cannon_next_pl or {})[pl.index] or 0) - game.tick)
end

-- Over Nauvis: strikes ready (platforms not realigning with a charged cannon), charged cannons, cannons, platforms,
-- charges stored, and the shortest wait of a platform realigning (ticks).
function cannon.readout(force)
  local ready, loaded, charges, cannons, platforms, wait = 0, 0, 0, 0, 0, nil
  for _, b in ipairs(cannon.batteries(force)) do
    platforms = platforms + 1
    local n_loaded = 0
    for _, e in ipairs(b.cannons) do
      cannons = cannons + 1
      local n = charges_in(e)
      charges = charges + n
      if n > 0 then n_loaded = n_loaded + 1 end
    end
    loaded = loaded + n_loaded
    local w = wait_of(b.platform)
    if n_loaded > 0 then
      if w == 0 then ready = ready + 1 elseif not wait or w < wait then wait = w end
    end
  end
  return {ready = ready, loaded = loaded, charges = charges, cannons = cannons, platforms = platforms, cooldown = wait or 0}
end

-- Its shells' points within radius R: each target (nearest first) as many as its health takes, while shells last, the
-- rest spread over the circle (a sunflower, by the index: no dice in what changes the game). Returns the points, the
-- targets in the circle and those given their shells.
local function points(s, force, c, n, R)
  local found = {}
  for _, t in pairs(s.find_entities_filtered{position = c, radius = R, force = hostile(force)}) do
    if t.valid and t.health and t.type ~= "unit" and t.type ~= "spider-unit" and not SPARE[t.type] then found[#found + 1] = t end
  end
  table.sort(found, function(x, y)
    return (x.position.x - c[1]) ^ 2 + (x.position.y - c[2]) ^ 2 < (y.position.x - c[1]) ^ 2 + (y.position.y - c[2]) ^ 2
  end)
  local out, covered, most = {}, 0, 0
  for _, t in ipairs(found) do
    if #out >= n then break end
    local k = math.min(threat.shells_for("lp-orbital-projectile", t), n - #out)
    for _ = 1, k do out[#out + 1] = {t.position.x, t.position.y} end
    covered, most = covered + 1, math.max(most, k)
  end
  local rest = n - #out
  for k = 1, rest do
    local r = R * 0.9 * math.sqrt(k / rest)
    local a = k * 2.39996
    out[#out + 1] = {c[1] + r * math.cos(a), c[2] + r * math.sin(a)}
  end
  return out, #found, covered, most
end
cannon.points = points

-- Its platform's silhouette, for the strike's shadow (orbital.lua shadow): the middles of the cells of CELL tiles its
-- foundation covers, and of its cannons' barrels over the void; {x, y} in tiles from the middle of its tiles, -y its bow,
-- and the cell's size (each a soft splat there). Coarser cells while it would take more than MAX splats.
local SIL_CELL, SIL_MAX = 3, 350
function cannon.silhouette(pl, cannons)
  local s = pl and pl.valid and pl.surface
  if not (s and s.valid) then return nil end
  local tiles = s.find_tiles_filtered{name = "space-platform-foundation"}
  if #tiles == 0 then return nil end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(tiles) do
    local p = t.position
    if p.x < x0 then x0 = p.x end; if p.y < y0 then y0 = p.y end
    if p.x > x1 then x1 = p.x end; if p.y > y1 then y1 = p.y end
  end
  local mx, my = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2
  -- Its barrels' rectangles (C.REACH past the deck's edge, 4 tiles wide), as tiles of their own.
  local DIR = {[defines.direction.north] = {0, -1}, [defines.direction.east] = {1, 0}, [defines.direction.south] = {0, 1},
    [defines.direction.west] = {-1, 0}}
  local extra = {}
  for _, e in ipairs(cannons or {}) do
    local d = e.valid and DIR[e.direction]
    if d then
      for u = 9, 9 + C.REACH - 1 do
        for v = -2, 1 do
          extra[#extra + 1] = {x = e.position.x + d[1] * u + d[2] * v, y = e.position.y + d[2] * u + d[1] * v}
        end
      end
    end
  end
  local cell = SIL_CELL
  local pts
  repeat
    local seen = {}
    pts = {}
    local function add(x, y)
      local i, j = math.floor((x - x0) / cell), math.floor((y - y0) / cell)
      local key = i .. "," .. j
      if not seen[key] then
        seen[key] = true
        pts[#pts + 1] = {x0 + (i + 0.5) * cell - mx, y0 + (j + 0.5) * cell - my}
      end
    end
    for _, t in ipairs(tiles) do add(t.position.x, t.position.y) end
    for _, p in ipairs(extra) do add(p.x, p.y) end
    cell = cell + 1
  until #pts <= SIL_MAX
  return {cell = cell - 1, pts = pts}
end

local store   -- (below: a cannon's store, stopped when full)

-- A strike at pos (the remote). Returns nil and why not, or the charges spent.
function cannon.fire(force, s, pos, player)
  local function no(key, ...)
    if player and player.valid then player.create_local_flying_text{text = {key, ...}, position = pos, create_at_cursor = true} end
    return nil, key
  end
  if s.name ~= "nauvis" then return no("lp.cannon-nauvis") end
  storage.cannon_next_pl = storage.cannon_next_pl or {}
  -- The platform that fires: ready (not realigning), the most charged cannons (ties: the first listed).
  local lead, lead_n, wait
  for _, b in ipairs(cannon.batteries(force)) do
    local n = 0
    for _, e in ipairs(b.cannons) do if charges_in(e) > 0 then n = n + 1 end end
    local w = wait_of(b.platform)
    if n > 0 and w > 0 then
      if not wait or w < wait then wait = w end
    elseif n > 0 and (not lead_n or n > lead_n) then
      lead, lead_n = b, n
    end
  end
  if not lead then
    if wait then return no("lp.cannon-cooldown", math.ceil(wait / 60)) end
    return no("lp.cannon-empty")
  end
  local spent = 0
  do
    local b = lead
    for _, e in ipairs(b.cannons) do
      if charges_in(e) > 0 then
        e.get_inventory(defines.inventory.crafter_output).remove{name = "lp-orbital-charge", count = 1}
        spent = spent + 1
        -- Its shot on the platform: the sound, a flash at the muzzle (C.MUZZLE tiles out its barrel's way).
        local d = ({[defines.direction.north] = {0, -1}, [defines.direction.east] = {1, 0}, [defines.direction.south] = {0, 1},
          [defines.direction.west] = {-1, 0}})[e.direction] or {0, -1}
        local m = {e.position.x + d[1] * C.MUZZLE, e.position.y + d[2] * C.MUZZLE}
        e.surface.play_sound{path = "lp-cannon-fire", position = m}
        e.surface.create_entity{name = "lp-cannon-blast", position = m}
        rendering.draw_sprite{sprite = "lp-impact-flash", target = m, surface = e.surface, x_scale = 9, y_scale = 9,
          render_layer = "explosion", time_to_live = 8}
        rendering.draw_light{sprite = "utility/light_medium", scale = 10, intensity = 1, color = {r = 0.55, g = 0.85, b = 1},
          target = m, surface = e.surface, time_to_live = 10}
        cannon.recoil(e)
      end
    end
  end
  if spent == 0 then return no("lp.cannon-empty") end
  store()
  storage.cannon_next_pl[lead.platform.index] = game.tick + C.COOLDOWN
  -- (The shadow is the platform that fired.)
  cannon.fall(force, s, pos, spent, cannon.silhouette(lead.platform, lead.cannons), lead.platform.index)
  return spent
end

-- A strike of n cannons' charges at pos: its radius, its shells' points and their fall from orbit (sil: the shadow).
function cannon.fall(force, s, pos, spent, sil, platform)
  local c = {pos.x or pos[1], pos.y or pos[2]}
  local R = shared.cannon_radius(spent)
  local at, targets, covered, most = points(s, force, c, spent * C.SHELLS, R)
  storage.cannon_silhouette = sil and #sil.pts or 0
  orbital.from_orbit(s, force.name, c, at, R, sil)
  storage.cannon_strikes = (storage.cannon_strikes or 0) + 1
  storage.cannon_shells = (storage.cannon_shells or 0) + #at
  storage.cannon_last = {spent = spent, radius = R, shells = #at, targets = targets, covered = covered, most = most,
    platform = platform}
  shared.reply(force, {x = c[1], y = c[2]}, {"lp.cannon-fired", spent, #at, targets, math.floor(R + 0.5),
    string.format("[gps=%d,%d,%s]", c[1], c[2], s.name)})
end

-- The readout: a line in the army's panel's place for each player whose force has the technology.
function cannon.gui_tick()
  for _, p in pairs(game.connected_players) do
    local t = p.force.technologies["lp-orbital-cannon"]
    local frame = p.gui.top.lp_orbital
    if not (t and t.researched) then
      if frame then frame.destroy() end
    else
      if not frame then
        frame = p.gui.top.add{type = "frame", name = "lp_orbital", direction = "horizontal", style = "slot_window_frame"}
        frame.style.padding = 4
        frame.add{type = "label", name = "lp_orbital_label", style = "caption_label"}
      end
      local r = cannon.readout(p.force)
      local l = frame.lp_orbital_label
      l.caption = r.cooldown > 0 and {"lp.cannon-readout-wait", r.ready, r.platforms, math.ceil(r.cooldown / 60)}
        or {"lp.cannon-readout", r.ready, r.platforms}
      l.tooltip = {"lp.cannon-tooltip", r.platforms, r.loaded, r.cannons, r.charges}
    end
  end
end

-- Its store: a cannon holding STORE charges stops (disabled by script, its status saying why) and goes on after a strike;
-- a craft under way keeps its progress.
-- Its barrel (the cannon's own sprite, apart: lp-cannon-barrel-<direction>), drawn over it, made again if gone or turned.
local DIRNAME = {[defines.direction.north] = "north", [defines.direction.east] = "east", [defines.direction.south] = "south",
  [defines.direction.west] = "west"}
local function barrel(e)
  storage.cannon_barrel = storage.cannon_barrel or {}
  local id = e.unit_number
  local b = storage.cannon_barrel[id]
  local d = DIRNAME[e.direction] or "north"
  if b and b.obj and b.obj.valid and b.dir == d then return b end
  if b and b.obj and b.obj.valid then b.obj.destroy() end
  local sprite = "lp-cannon-barrel-" .. d
  if not helpers.is_valid_sprite_path(sprite) then return nil end
  b = {obj = rendering.draw_sprite{sprite = sprite, target = {entity = e, offset = {0, 0}}, surface = e.surface,
    render_layer = "higher-object-under"}, dir = d}
  storage.cannon_barrel[id] = b
  return b
end
cannon.barrel = barrel

-- Its recoil (the user: "No firing animation? no recoil?"): the barrel slammed back RECOIL tiles in KICK ticks, eased
-- home over SETTLE; its coils' glow (the body's, which stays put) off meanwhile, the cannon held for the length of it.
local RECOIL, KICK, SETTLE = 1.4, 4, 50
local BACK = {north = {0, 1}, east = {-1, 0}, south = {0, -1}, west = {1, 0}}
function cannon.recoil(e)
  local b = barrel(e)
  if not b then return end
  storage.cannon_recoil = storage.cannon_recoil or {}
  storage.cannon_recoil[e.unit_number] = {e = e, t0 = game.tick, dir = b.dir}
  e.disabled_by_script = true
  storage.cannon_recoils = (storage.cannon_recoils or 0) + 1
end
local function recoil_tick(tick)
  for id, r in pairs(storage.cannon_recoil or {}) do
    local e = r.e
    local b = storage.cannon_barrel and storage.cannon_barrel[id]
    if not (e and e.valid and b and b.obj.valid) then
      storage.cannon_recoil[id] = nil
    else
      local t = tick - r.t0
      local k
      if t <= KICK then k = t / KICK
      elseif t <= KICK + SETTLE then local u = (t - KICK) / SETTLE; k = 1 - u * u * (3 - 2 * u)
      else k = 0 end
      local v = BACK[r.dir]
      b.obj.target = {entity = e, offset = {v[1] * RECOIL * k, v[2] * RECOIL * k}}
      if k > (storage.cannon_recoil_max or 0) then storage.cannon_recoil_max = k end
      if t > KICK + SETTLE then
        storage.cannon_recoil[id] = nil
        e.disabled_by_script = charges_in(e) >= C.STORE
      end
    end
  end
end

store = function()
  for _, f in pairs(game.forces) do
    for _, pl in pairs(f.platforms) do
      local s = pl.valid and pl.surface
      if s and s.valid then
        for _, e in pairs(s.find_entities_filtered{name = "lp-orbital-cannon"}) do
          barrel(e)
          local full = charges_in(e) >= C.STORE
          if storage.cannon_recoil and storage.cannon_recoil[e.unit_number] then
            -- (Recoiling: held till it is home, recoil_tick.)
          elseif full ~= e.disabled_by_script then
            e.disabled_by_script = full
            e.custom_status = full and {diode = defines.entity_status_diode.green, label = {"lp.cannon-full"}} or nil
          end
        end
      end
    end
  end
end
cannon.store = store

-- Its arcs while it charges (the user: "the arcs look like crap. Can't we add those at the game level?"): the game's own
-- lightning between the two capacitor towers' terminals, and from each to the first coil's contact post. Points from the
-- model (tools/blender/orbital_cannon.py, 1.5 times its units), for a cannon whose barrel points north: {x, y, height};
-- drawn at y less its height (the camera's 45 degrees, the sheet's stretch: a height of h is h tiles up the screen).
local TOWERS = {{-4.725, 6.825, 7.875}, {4.725, 6.825, 6.825}}   -- (the left one taller, TOWER_LIFT)
local POSTS = {{-3.29, -5.57, 5.47}, {3.29, -5.57, 5.47}}
local TURN = {[defines.direction.north] = function(x, y) return x, y end,
  [defines.direction.east] = function(x, y) return -y, x end,
  [defines.direction.south] = function(x, y) return -x, -y end,
  [defines.direction.west] = function(x, y) return y, -x end}
local function drawn(e, p)
  local x, y = (TURN[e.direction] or TURN[defines.direction.north])(p[1], p[2])
  return {e.position.x + x, e.position.y + y - p[3]}
end
local function arcs(tick)
  for _, f in pairs(game.forces) do
    for _, pl in pairs(f.platforms) do
      local s = pl.valid and pl.surface
      if s and s.valid then
        for _, e in pairs(s.find_entities_filtered{name = "lp-orbital-cannon"}) do
          if e.status == defines.entity_status.working then
            -- (Which arcs strike, by the tick and the cannon: no dice.)
            local k = (math.floor(tick / 30) + (e.unit_number or 0)) % 3
            local a, b = drawn(e, TOWERS[1]), drawn(e, TOWERS[2])
            if k ~= 2 then s.create_entity{name = "lp-cannon-arc", position = a, source_position = a, target_position = b, duration = 20} end
            for i = 1, 2 do
              if k == 0 or k == i then
                local t, q = drawn(e, TOWERS[i]), drawn(e, POSTS[i])
                s.create_entity{name = "lp-cannon-arc", position = t, source_position = t, target_position = q, duration = 16}
              end
            end
          end
        end
      end
    end
  end
end
cannon.arcs = arcs

function cannon.tick(tick)
  if tick % 60 == 25 then cannon.gui_tick() end
  if tick % 30 == 10 then store() end
  if tick % 30 == 20 then arcs(tick) end
  if storage.cannon_recoil and next(storage.cannon_recoil) then recoil_tick(tick) end
end

function cannon.stats()
  local barrels = 0
  for _, b in pairs(storage.cannon_barrel or {}) do if b.obj and b.obj.valid then barrels = barrels + 1 end end
  return {strikes = storage.cannon_strikes or 0, shells = storage.cannon_shells or 0, silhouette = storage.cannon_silhouette or 0,
    barrels = barrels, recoils = storage.cannon_recoils or 0, recoil_max = storage.cannon_recoil_max or 0,
    last = storage.cannon_last, shocks = storage.cannon_shocks or 0, impacts = storage.cannon_impacts or 0}
end

return cannon
