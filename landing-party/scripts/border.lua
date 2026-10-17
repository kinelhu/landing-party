-- The border stake (the rivals consult, slice 3: Serenity takes a direction; the player may concede it). A player sets
-- a border stake toward a Serenity camp that holds them a rival: the camp acknowledges a border at the stake's distance
-- from its origin, drawn on the map, and its line (ops.perimeter, the cordon) does not step past it. Anything of the
-- player's built on Serenity's side breaks the treaty: Serenity is provoked (an enemy, for good) and the line moves
-- again. An enemy Serenity does not treat. A stake removed lets the line resume. Ordinary items, from the start: the
-- player must be able to concede early.
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")
local standing = require("__landing-party__.scripts.standing")

local border = {}

local REACH = 700                 -- a Serenity camp this near the stake is the one it treats with

local function serenity_near(ent)
  local best, bd
  for _, b in pairs(storage.bases or {}) do
    if (shared.CORPS[b.corp].temper or {}).provoked_only and not b.fallen and b.surface == ent.surface.index and b.origin then
      local d = math.sqrt((b.origin.x - ent.position.x) ^ 2 + (b.origin.y - ent.position.y) ^ 2)
      if d <= REACH and (not bd or d < bd) then best, bd = b, d end
    end
  end
  return best, bd
end

local function gps(e) return string.format("[gps=%d,%d,%s]", e.position.x, e.position.y, e.surface.name) end

local function void(br)
  for _, r in ipairs(br.marks or {}) do if r.valid then r.destroy() end end
  br.void = true
end

function border.placed(ent)
  storage.borders = storage.borders or {}
  local b, d = serenity_near(ent)
  local f = ent.force
  if not b then shared.reply(f, ent.position, {"lp.border-none"}); return end
  if standing.get(b.corp, f.name) ~= "rival" then shared.reply(f, ent.position, {"lp.border-refused", shared.corp_label(b.corp)}); return end
  if d <= (b.perimeter or b.claim_radius or 0) then
    -- Inside its claim already: encroachment, not a treaty (ops.encroachment provokes).
    shared.reply(f, ent.position, {"lp.border-inside", shared.corp_label(b.corp)})
    return
  end
  local s = ent.surface
  local c = shared.CORPS[b.corp].color
  local br = {entity = ent, owner = f.name, base = b.id, radius = d, placed = game.tick}
  br.marks = {rendering.draw_circle{color = {r = c.r, g = c.g, b = c.b, a = 0.9}, radius = d, width = 3, filled = false,
    target = {b.origin.x, b.origin.y}, surface = s, render_mode = "chart"}}
  table.insert(storage.borders, br)
  standing.incident(b.corp, "border", ent.position, string.format("a border at %d tiles", math.floor(d)))
  shared.reply(f, ent.position, {"lp.border-accepted", shared.corp_label(b.corp), gps(ent)})
end

-- The nearest border any player holds with this camp: its line stops short of it.
function border.cap(b)
  local cap
  for _, br in ipairs(storage.borders or {}) do
    if not br.void and br.base == b.id and br.entity.valid then
      if not cap or br.radius < cap then cap = br.radius end
    end
  end
  return cap and cap - 5
end
ops.border_cap = border.cap

function border.tick(tick)
  if tick % 600 ~= 433 or not storage.borders then return end
  for i = #storage.borders, 1, -1 do
    local br = storage.borders[i]
    local b = storage.bases[br.base]
    if br.void then
      table.remove(storage.borders, i)
    elseif not br.entity.valid or not b or b.fallen then
      void(br)
    elseif standing.get(b.corp, br.owner) ~= "rival" then
      void(br)
    else
      -- Anything of the player's on Serenity's side of the line breaks it (the stake itself stands on the line).
      local s = game.surfaces[b.surface]
      local inside = s.find_entities_filtered{position = {b.origin.x, b.origin.y}, radius = br.radius - 3, force = br.owner,
        limit = 1}[1]
      if inside then
        ops.provoke(b.lander.force.name, br.owner, inside)
        standing.incident(b.corp, "border broken", inside.position, inside.name)
        shared.notice(game.forces[br.owner], {"lp.border-broken", shared.corp_label(b.corp), gps(inside)})
        void(br)
      end
    end
  end
end

function border.stats()
  local n, held = 0, 0
  for _, br in ipairs(storage.borders or {}) do
    n = n + 1
    if not br.void and br.entity.valid then held = held + 1 end
  end
  return {borders = n, held = held}
end

return border
