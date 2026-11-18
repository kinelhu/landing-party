-- The road (the rivals consult, slice 4: Grubstake's economy is the road). A Grubstake claim (a prospect's, or a strip
-- camp that stayed) has no line home: every HAUL its camp sends a truck out to empty the claim's bins and bring the ore
-- home as feedstock. A truck killed on the way back spills its ore and the player is told what it cost ("expansion
-- delayed N minutes": the cargo against the camp's own intake). A claim with no ore home for LAPSE lapses: its mark
-- goes, the camp stops rebuilding it (its drills were there to take by holding until 0.2.452).
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local standing = require("__landing-party__.scripts.standing")

local road = {}

local HAUL = 5 * 3600
local LAPSE = 20 * 3600
local STUCK = 6 * 3600

local function home(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  return b.lander and b.lander.valid and b.lander or nil
end

local function tell(b, key, at, extra)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at[1], at[2], s.name), extra or ""})
    end
  end
end

local function lapse(b, m, why)
  m.lapsed = game.tick
  for _, r in ipairs(m.marks or {}) do if r.valid then r.destroy() end end
  b.claims_lapsed = (b.claims_lapsed or 0) + 1
  standing.incident(b.corp, "claim lapsed", {m.center[1], m.center[2]}, why)
  tell(b, "lp.claim-lapsed", m.center)
  base.trace(b, string.format("road: the claim at %.0f,%.0f lapses (%s)", m.center[1], m.center[2], why))
end

local function lost(b, m, r)
  local at = r.last or m.center
  local s = game.surfaces[b.surface]
  if r.cargo and r.cargo > 0 then
    -- (Its cargo lost with it, none spilled: the user, 2026-11-03, no materials dropped.)
    -- What it cost: the cargo against the camp's own intake a minute.
    local minutes = math.max(1, math.floor(r.cargo / math.max(1, b.rate_in or 1)))
    tell(b, "lp.road-lost", at, tostring(minutes))
    standing.incident(b.corp, "hauler lost", {at[1], at[2]}, string.format("%d ore, %d min", r.cargo, minutes))
  end
  b.hauls_lost = (b.hauls_lost or 0) + 1
  base.trace(b, string.format("road: the truck from the claim at %.0f,%.0f was lost with %d ore", m.center[1], m.center[2], r.cargo or 0))
end

local function launch(b, m)
  local s = game.surfaces[b.surface]
  local h = home(b)
  if not (h and h.valid) then return end
  local name = shared.variant(b.corp, "lp-hauler")
  local p = s.find_non_colliding_position(name, {h.position.x, h.position.y + 12}, 20, 1)
  local u = p and s.create_entity{name = name, position = p, force = h.force}
  if not u then return end
  u.commandable.set_command{type = defines.command.go_to_location, destination = m.center, radius = 6,
    distraction = defines.distraction.none}
  m.road.run = {unit = u, phase = "out", started = game.tick}
end

local function step(b, m)
  local rd = m.road
  local r = rd.run
  local tick = game.tick
  if not r then
    if tick - rd.last_home > (storage.road_lapse or LAPSE) then return lapse(b, m, "no ore home") end
    if tick >= rd.next then launch(b, m) end
    return
  end
  if not r.unit.valid then
    if r.phase == "home" then lost(b, m, r) end
    m.road.run, rd.next = nil, tick + (storage.road_haul or HAUL)
    return
  end
  local p = r.unit.position
  r.last = {p.x, p.y}
  if tick - r.started > STUCK then
    r.unit.destroy()
    m.road.run, rd.next = nil, tick + (storage.road_haul or HAUL)
    return
  end
  if r.phase == "out" and (p.x - m.center[1]) ^ 2 + (p.y - m.center[2]) ^ 2 < 12 * 12 then
    local cargo, ore = 0, nil
    for _, e in ipairs(m.entities) do
      if e.valid and e.type == "container" then
        local inv = e.get_inventory(defines.inventory.chest)
        for _, it in pairs(inv.get_contents()) do
          cargo = cargo + inv.remove{name = it.name, count = it.count, quality = it.quality}
          ore = ore or it.name
        end
      end
    end
    r.cargo, r.ore, r.phase = cargo, ore, "home"
    local h = home(b)
    if h then
      r.unit.commandable.set_command{type = defines.command.go_to_location, destination = h.position, radius = 10,
        distraction = defines.distraction.none}
    end
  elseif r.phase == "home" then
    local h = home(b)
    if h and h.valid and (p.x - h.position.x) ^ 2 + (p.y - h.position.y) ^ 2 < 18 * 18 then
      b.feedstock = (b.feedstock or 0) + (r.cargo or 0)
      b.hauled = (b.hauled or 0) + (r.cargo or 0)
      rd.last_home = tick
      r.unit.destroy()
      m.road.run, rd.next = nil, tick + (storage.road_haul or HAUL)
      b.hauls = (b.hauls or 0) + 1
      base.trace(b, string.format("road: %d ore home from the claim at %.0f,%.0f", r.cargo or 0, m.center[1], m.center[2]))
    end
  end
end

function road.tick(tick)
  if tick % 60 ~= 37 then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid and (shared.CORPS[b.corp].temper or {}).prospects then
      for _, m in ipairs(b.modules or {}) do
        if m.claim and m.built and not m.lapsed then
          m.road = m.road or {last_home = tick, next = tick + (storage.road_haul or HAUL)}
          step(b, m)
        end
      end
    end
  end
end

function road.stats(b)
  local claims, lapsed = 0, 0
  for _, m in ipairs(b.modules or {}) do
    if m.claim then claims = claims + 1; if m.lapsed then lapsed = lapsed + 1 end end
  end
  local centers = {}
  for _, m in ipairs(b.modules or {}) do if m.claim and m.built and not m.lapsed then table.insert(centers, m.center) end end
  return {hauls = b.hauls or 0, hauled = b.hauled or 0, lost = b.hauls_lost or 0, claims = claims, lapsed = lapsed,
    centers = centers}
end

return road
