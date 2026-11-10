-- The player's orbital cannons (orbital_cannon.lua; DESIGN.md, "Orbital cannons", decided 2026-11-10). A strike is called
-- with the remote on Nauvis; it spends one charge from every ready cannon of every platform of the force stopped over
-- Nauvis with a targeting array (pooled: decided, 1), at most once each shared.CANNON.COOLDOWN, and its shells (SHELLS a
-- charge) fall within RADIUS of the point: first one on each hostile building and nest there, nearest first, then the rest
-- spread inside the circle. The look is Kessler-Hayashi's strike's (orbital.from_orbit). A corporation struck counts it an
-- attack through its losses, as any (decided, 4: no answer of its own).
local shared = require("__landing-party__.shared")
local orbital = require("__landing-party__.scripts.orbital")

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

-- Charges ready over Nauvis (one a cannon is what a strike takes), cannons and platforms counted.
function cannon.readout(force)
  local ready, charges, cannons, platforms = 0, 0, 0, 0
  for _, b in ipairs(cannon.batteries(force)) do
    platforms = platforms + 1
    for _, e in ipairs(b.cannons) do
      cannons = cannons + 1
      local n = charges_in(e)
      charges = charges + n
      if n > 0 then ready = ready + 1 end
    end
  end
  local wait = math.max(0, ((storage.cannon_next or {})[force.name] or 0) - game.tick)
  return {ready = ready, charges = charges, cannons = cannons, platforms = platforms, cooldown = wait}
end

-- Its shells' points: one on each target (nearest first), the rest spread over the circle (a sunflower, by the index: no
-- dice in what changes the game).
local function points(s, force, c, n)
  local found = {}
  for _, t in pairs(s.find_entities_filtered{position = c, radius = C.RADIUS, force = hostile(force)}) do
    if t.valid and t.health and t.type ~= "unit" and t.type ~= "spider-unit" and not SPARE[t.type] then found[#found + 1] = t end
  end
  table.sort(found, function(x, y)
    return (x.position.x - c[1]) ^ 2 + (x.position.y - c[2]) ^ 2 < (y.position.x - c[1]) ^ 2 + (y.position.y - c[2]) ^ 2
  end)
  local out = {}
  for k = 1, math.min(n, #found) do out[k] = {found[k].position.x, found[k].position.y} end
  local rest = n - #out
  for k = 1, rest do
    local r = C.RADIUS * 0.9 * math.sqrt(k / rest)
    local a = k * 2.39996
    out[#out + 1] = {c[1] + r * math.cos(a), c[2] + r * math.sin(a)}
  end
  return out, #found
end

local store   -- (below: a cannon's store, stopped when full)

-- A strike at pos (the remote). Returns nil and why not, or the charges spent.
function cannon.fire(force, s, pos, player)
  local function no(key, ...)
    if player and player.valid then player.create_local_flying_text{text = {key, ...}, position = pos, create_at_cursor = true} end
    return nil, key
  end
  if s.name ~= "nauvis" then return no("lp.cannon-nauvis") end
  storage.cannon_next = storage.cannon_next or {}
  local wait = (storage.cannon_next[force.name] or 0) - game.tick
  if wait > 0 then return no("lp.cannon-cooldown", math.ceil(wait / 60)) end
  local spent = 0
  for _, b in ipairs(cannon.batteries(force)) do
    for _, e in ipairs(b.cannons) do
      if charges_in(e) > 0 then
        e.get_inventory(defines.inventory.crafter_output).remove{name = "lp-orbital-charge", count = 1}
        spent = spent + 1
      end
    end
  end
  if spent == 0 then return no("lp.cannon-empty") end
  store()
  storage.cannon_next[force.name] = game.tick + C.COOLDOWN
  local c = {pos.x or pos[1], pos.y or pos[2]}
  local at, targets = points(s, force, c, spent * C.SHELLS)
  orbital.from_orbit(s, force.name, c, at, C.RADIUS)
  storage.cannon_strikes = (storage.cannon_strikes or 0) + 1
  storage.cannon_shells = (storage.cannon_shells or 0) + #at
  shared.reply(force, {x = c[1], y = c[2]}, {"lp.cannon-fired", spent, #at, targets,
    string.format("[gps=%d,%d,%s]", c[1], c[2], s.name)})
  return spent
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
      l.caption = r.cooldown > 0 and {"lp.cannon-readout-wait", r.ready, r.cannons, math.ceil(r.cooldown / 60)}
        or {"lp.cannon-readout", r.ready, r.cannons}
      l.tooltip = {"lp.cannon-tooltip", r.platforms, r.charges}
    end
  end
end

-- Its store: a cannon holding STORE charges stops (disabled by script, its status saying why) and goes on after a strike;
-- a craft under way keeps its progress.
store = function()
  for _, f in pairs(game.forces) do
    for _, pl in pairs(f.platforms) do
      local s = pl.valid and pl.surface
      if s and s.valid then
        for _, e in pairs(s.find_entities_filtered{name = "lp-orbital-cannon"}) do
          local full = charges_in(e) >= C.STORE
          if full ~= e.disabled_by_script then
            e.disabled_by_script = full
            e.custom_status = full and {diode = defines.entity_status_diode.green, label = {"lp.cannon-full"}} or nil
          end
        end
      end
    end
  end
end
cannon.store = store

function cannon.tick(tick)
  if tick % 60 == 25 then cannon.gui_tick() end
  if tick % 30 == 10 then store() end
end

function cannon.stats()
  return {strikes = storage.cannon_strikes or 0, shells = storage.cannon_shells or 0}
end

return cannon
