-- The threat scanner (the user, 2026-10-18: "a building that scans for enemy units in a radius and gives signals for
-- each unit type with a number depending on units present in the radius of the scanner would probably be super useful
-- for circuit engineering"). The rally beacon's input half: the player's army takes its orders from circuits, and this
-- gives circuits eyes. Once a second each scanner counts the corporations' units within shared.SCAN_RADIUS, by role
-- (shared.SCAN_GROUPS: one virtual signal each), the crews apart (builders, not an army), a total a corporation, and the
-- biters, and writes them to its output. Its window does not open: what it says is what it sees.
-- A leaf: it reads the surface and storage only.
local shared = require("__landing-party__.shared")

local scanner = {}

local EVERY = 60
local GROUP_OF = {}
for _, g in ipairs(shared.SCAN_GROUPS) do
  for _, k in ipairs(g.kinds) do GROUP_OF[k] = g.signal end
end

function scanner.placed(ent)
  ent.operable = false
  storage.scanners = storage.scanners or {}
  table.insert(storage.scanners, ent)
  scanner.scan(ent)
end

local function corp_of(force_name)
  for corp, c in pairs(shared.CORPS) do if c.force == force_name then return corp end end
end

-- A hostile jammer mast within shared.JAM_RADIUS: the scanner is blinded. It says so (lp-scan-jammed = 1) and counts
-- nothing, so a circuit can still answer it, and the player learns a mast stands near (Serenity's eyes against the
-- player's: a raid under a jammer comes unseen).
local function jammed(ent)
  for _, j in ipairs(storage.jammers or {}) do
    local m = j.mast
    if m.valid and m.surface == ent.surface and m.force ~= ent.force and not m.force.get_cease_fire(ent.force)
      and (m.position.x - ent.position.x) ^ 2 + (m.position.y - ent.position.y) ^ 2 <= shared.JAM_RADIUS ^ 2 then
      return true
    end
  end
end

-- What one scanner sees: {signal name = count}.
function scanner.count(ent)
  local s = ent.surface
  if jammed(ent) then return {["lp-scan-jammed"] = 1} end
  local out = {}
  local forces = {"enemy"}
  for _, c in pairs(shared.CORPS) do if game.forces[c.force] then forces[#forces + 1] = c.force end end
  local crews = storage.crew_owner or {}
  for _, u in pairs(s.find_entities_filtered{position = ent.position, radius = shared.SCAN_RADIUS, force = forces,
    type = {"unit", "spider-unit"}}) do
    local key
    if u.force.name == "enemy" then
      key = "lp-scan-biters"
    else
      local corp = corp_of(u.force.name)
      if corp then out["lp-scan-" .. corp] = (out["lp-scan-" .. corp] or 0) + 1 end
      key = (u.unit_number and crews[u.unit_number]) and "lp-scan-crew" or GROUP_OF[shared.kind_of(u.name)]
    end
    if key then out[key] = (out[key] or 0) + 1 end
  end
  return out
end

function scanner.scan(ent)
  local cb = ent.get_or_create_control_behavior()
  local section = cb.get_section(1) or cb.add_section()
  local seen = scanner.count(ent)
  local names = {}
  for name in pairs(seen) do names[#names + 1] = name end
  table.sort(names)
  for i = 1, math.max(#names, section.filters_count) do
    local name = names[i]
    if name then
      section.set_slot(i, {value = {type = "virtual", name = name, quality = "normal"}, min = seen[name]})
    else
      section.clear_slot(i)
    end
  end
end

function scanner.tick(tick)
  if tick % EVERY ~= 23 or not storage.scanners then return end
  for i = #storage.scanners, 1, -1 do
    local e = storage.scanners[i]
    if e.valid then scanner.scan(e) else table.remove(storage.scanners, i) end
  end
end

return scanner
