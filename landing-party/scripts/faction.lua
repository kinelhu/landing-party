-- The faction across settlements: when landings come, where they land, and the tier its exports buy.
--   Landings: the first answers the player's first rocket launch; then one every CADENCE, each later launch
--   bringing the next one HASTE sooner; at most MAX_ALIVE settlements stand at once.
--   Tier: parts exported by mature settlements, faction-wide. Each tier unlocks units, adds damage and
--   garrison room (army.lua reads it).
local shared = require("__landing-party__.shared")
local site = require("__landing-party__.scripts.site")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")

local faction = {}

local CADENCE = 90 * 3600
local HASTE = 15 * 3600
local MAX_ALIVE = 4
local DISTANCE = 350
local APART = 200                -- a new landing keeps this far from every standing lander
local SITE_SEARCH = 120
local SITE_MIN_ORE = 300
local UPLINK_LANDING = 3

faction.TIERS = {3000, 8000, 20000, 45000}           -- parts exported to reach tiers 1..4

function faction.state()
  storage.faction = storage.faction or {tier = 0, exported = 0, landings = 0, cadence = CADENCE,
    tiers = faction.TIERS}
  return storage.faction
end

local function landers()
  local out = {}
  for _, b in pairs(storage.bases) do if b.lander.valid then table.insert(out, b.lander.position) end end
  return out
end

-- A landing site about `distance` from `from`: in the first of eight directions (seeded order, turned by
-- the landing count) with a rich enough patch within SITE_SEARCH tiles of the ring and no lander within
-- APART. A single point per direction found no ore at 300 tiles on most maps (seed 2: 7 of 8 empty).
function faction.site(surface, from, distance, count)
  local start = (surface.map_gen_settings.seed + 3 * (count or 0)) % 8
  local avoid = landers()
  local fallback, fallback_n = nil, -1
  for i = 0, 7 do
    local a = 2 * math.pi * ((start + i) % 8) / 8
    local p = {from.x + distance * math.cos(a), from.y + distance * math.sin(a)}
    surface.request_to_generate_chunks(p, math.ceil(SITE_SEARCH / 32) + 1)
    surface.force_generate_chunk_requests()
    local per = {}
    for _, r in pairs(surface.find_entities_filtered{position = p, radius = SITE_SEARCH, type = "resource",
      name = site.ORES}) do
      local k = math.floor(r.position.x / 32) .. ":" .. math.floor(r.position.y / 32)
      per[k] = (per[k] or 0) + 1
    end
    local best, bn = nil, 0
    for k, n in pairs(per) do
      if n > bn or (n == bn and best and k < best) then best, bn = k, n end
    end
    if best then
      local cx, cy = best:match("(-?%d+):(-?%d+)")
      local c = {tonumber(cx) * 32 + 16, tonumber(cy) * 32 + 16}
      -- Land beside the patch, not on it: a third of the way back towards the ring point.
      local spot = {c[1] + (p[1] - c[1]) / 3, c[2] + (p[2] - c[2]) / 3}
      local clear = true
      for _, l in ipairs(avoid) do
        if (l.x - spot[1]) ^ 2 + (l.y - spot[2]) ^ 2 < APART * APART then clear = false end
      end
      if clear then
        local n = surface.count_entities_filtered{position = c, radius = 60, type = "resource", name = site.ORES}
        if n > SITE_MIN_ORE then return spot end
        if n > fallback_n then fallback, fallback_n = spot, n end
      end
    end
  end
  -- No direction rich and clear: the best clear one seen (seed 2024 once landed blind on two drills' worth).
  return fallback
end

local function announce(b, surface)
  for _, f in pairs(game.forces) do
    if #f.players > 0 then
      f.chart(surface, {{b.origin.x - 48, b.origin.y - 48}, {b.origin.x + 48, b.origin.y + 48}})
      f.print({"lp.landed", string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)})
    end
  end
end

-- A landing now, `distance` from `from` (a table with x, y). opts as for base.land.
function faction.arrive(surface, from, opts, quiet)
  local f = faction.state()
  -- Further rings when the first has no clear, ore-bearing site (seed 12345: two landings blocked their
  -- neighbours at 350 tiles and the other directions were barren).
  local pos
  for _, extra in ipairs({0, 120, 240}) do
    pos = faction.site(surface, from, ((opts and opts.distance) or DISTANCE) + extra, f.landings)
    if pos then break end
  end
  -- The third landing is the uplink (unless one already stands or has fallen).
  if f.landings == UPLINK_LANDING - 1 and not f.uplink_landed then
    opts = opts or {}
    opts.uplink, opts.doctrine = true, "fortress"
  end
  local b = pos and base.land(surface, pos, opts)
  if not b then
    -- Try again later, and say why: a failed landing retried silently every 10 s once.
    f.next = game.tick + 5 * 3600
    if storage.trace then
      helpers.write_file("landing-party/decisions.txt", string.format("%8d faction  landing failed: %s\n", game.tick,
        pos and string.format("no pad fits near %.0f,%.0f", pos[1], pos[2]) or "no site clear of other landers"), true)
    end
    return nil
  end
  f.landings = f.landings + 1
  ops.heard_landing(b)
  if opts and opts.uplink then f.uplink_landed = b.id end
  f.surface, f.from = surface.index, {x = from.x, y = from.y}
  f.next = game.tick + f.cadence
  base.trace(b, string.format("landing %d of the faction (tier %d)", f.landings, f.tier))
  if not quiet then announce(b, surface) end
  return b
end

-- The first launch is heard; each later one brings the next landing sooner.
function faction.on_launch(silo)
  local f = faction.state()
  if not f.surface then
    faction.arrive(silo.surface, silo.position)
  elseif f.next then
    f.next = math.max(game.tick, f.next - HASTE)
  end
end

local function alive()
  local n = 0
  for _, b in pairs(storage.bases) do if b.lander.valid then n = n + 1 end end
  return n
end

function faction.tick(tick)
  if tick % 600 ~= 0 then return end
  local f = faction.state()
  if f.next and tick >= f.next and f.surface and not f.uplink_down then
    if alive() < MAX_ALIVE then
      faction.arrive(game.surfaces[f.surface], f.from, nil, storage.quiet)
    else
      f.next = tick + f.cadence
    end
  end
end

-- Tiers no longer add damage (a hidden evolution factor by another name, design review 2026-10-13); they will
-- buy capabilities per corporation (docs/campaign.md, development).
local function apply_tier(f) end

-- Parts sent off-world by a mature settlement.
function faction.export(b, parts)
  local f = faction.state()
  f.exported = f.exported + parts
  b.exported = (b.exported or 0) + parts
  -- With the uplink down, exports go nowhere: the tier is frozen.
  if f.uplink_down then return end
  while f.tiers[f.tier + 1] and f.exported >= f.tiers[f.tier + 1] do
    f.tier = f.tier + 1
    apply_tier(f)
    base.trace(b, string.format("faction tier %d (%d parts exported)", f.tier, f.exported))
  end
end

-- The uplink falls: no more landings, the tier frozen. The settlements already down stay.
function faction.uplink_lost(entity)
  local f = faction.state()
  if f.uplink_down then return end
  f.uplink_down = game.tick
  f.next = nil
  for _, force in pairs(game.forces) do
    if #force.players > 0 then force.print({"lp.uplink-down"}) end
  end
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d faction  uplink destroyed: no more landings, tier %d frozen\n",
      game.tick, f.tier), true)
  end
end

-- Base reports exports through this hook (base cannot require this module: it is required by it).
base.on_export = faction.export

return faction
