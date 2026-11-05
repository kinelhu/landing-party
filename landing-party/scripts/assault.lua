-- A siege's assault at a closed wall (Kessler-Hayashi's adaptive tactics: the consult, docs/reviews/2026-11-05-adaptive-
-- tactics-consult.md, section 4; the user, 2026-11-05: "You can start on tactics"). Its barrage over, no way open through
-- the wall (siege.lua open_way) and no orbital strike falling, a siege had one answer: its assault at its targets by name,
-- the units' own pathing breaking the piece in their way, a line trooper's beam doing 2 a shot to stone. Now that moment
-- is a menu, weighed and picked as every attacker's (tactics.expect, tactics.pick), each option kept in its own record:
--   walled    the assault as before;
--   wallfire  its guns (mortars and howitzer) turn on the wall piece on its way in first (wall_on_way), offered only
--             where the shells break that piece before the owner's robots get to it (race), the assault going once the
--             way is open.
-- Each priced before its own record by the siege's at that place (no edge assumed: the reading gates, the record
-- decides). (Built with it and taken out on the lab's word, 2026-11-05: armour first, the assault in ranks toughest first,
-- which broke more guns and got in less; and its line at the hold opened by the place's area share, which no lane put
-- under area fire. DESIGN, findings.)
local attempt = require("__landing-party__.scripts.attempt")
local tactics = require("__landing-party__.scripts.tactics")
local threat = require("__landing-party__.scripts.threat")

local assault = {}

assault.METHODS = {"walled", "wallfire"}
-- Its weighing's mind: nearness plays no part (every option goes at the same wall), any gain is worth weighing.
local MIND = {far = 1, min_gain = 0}

local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

-- The first wall or gate piece of foes on the line from `from` to `to`, a tile at a time (nil: none).
function assault.wall_on_way(s, foes, from, to)
  local dx, dy = to.x - from.x, to.y - from.y
  local n = math.ceil(math.sqrt(dx * dx + dy * dy))
  for i = 1, n - 1 do
    local w = s.find_entities_filtered{position = {from.x + dx * i / n, from.y + dy * i / n}, radius = 0.8,
      type = {"wall", "gate"}, force = foes, limit = 1}[1]
    if w then return w end
  end
end

-- What one of its guns (an artillery piece) does to `piece` a second, read from the piece's gun prototype (range, minimum
-- range, cooldown, damage modifier), the shell it holds (its projectile's blow, threat.blow, less the piece's resistances)
-- and its force's research on that ammunition; 0 out of its reach or with no shell.
local function gun_dps(m, piece)
  local g = m.prototype.indexed_guns and m.prototype.indexed_guns[1]
  local ap = g and g.attack_parameters
  if not ap then return 0, 0 end
  local d = math.sqrt(d2(m.position, piece.position))
  if d > ap.range * (1 + m.force.artillery_range_modifier) or d < (ap.min_range or 0) then return 0, 0 end
  local inv = m.get_inventory(defines.inventory.artillery_turret_ammo)
  local stack = inv and inv[1]
  if not (stack and stack.valid_for_read) then return 0, 0 end
  local at = prototypes.item[stack.name].get_ammo_type()
  local act = at and at.action and at.action[1]
  local del = act and act.action_delivery and act.action_delivery[1]
  local proj = del and del.projectile
  if not proj then return 0, 0 end
  local cat = ap.ammo_categories and ap.ammo_categories[1]
  local blow = threat.blow(proj, piece) * (ap.damage_modifier or 1) * (1 + (cat and m.force.get_ammo_damage_modifier(cat) or 0))
  return blow * 60 / math.max(1, ap.cooldown), blow
end

-- The robots' trip to `w`: ticks for a robot of the nearest powered roboport of its owner covering it, with construction
-- robots to send, to reach it (its prototype's speed, its force's research); nil where none covers it (no race).
-- (ops.mended_floor reads the same race for a raid.)
function assault.mend_ticks(s, foes, w)
  local best, by
  for _, r in ipairs(s.find_entities_filtered{position = w.position, radius = 120, type = "roboport", force = foes}) do
    local cr = r.prototype.construction_radius or 0
    local d = math.sqrt(d2(r.position, w.position))
    local net = r.logistic_network
    if d <= cr and r.energy > 0 and net and net.available_construction_robots > 0 and (not best or d < best) then
      best, by = d, r.force
    end
  end
  if not best then return nil end
  local bot = prototypes.entity["construction-robot"]
  local speed = (bot and bot.speed or 0.06) * (1 + by.worker_robots_speed_modifier)
  return math.max(1, best / speed)
end

-- The race at `piece`: how long its guns in reach take to break it (ticks), the shells that takes, and how long its
-- owner's robots take to get there (nil: no robots). (The consult: shell the wall only where the shells land faster
-- than the robots return.)
function assault.race(s, foes, guns, piece)
  local dps, blow, n = 0, 0, 0
  for _, m in ipairs(guns) do
    if m.valid then
      local v, b1 = gun_dps(m, piece)
      if v > 0 then dps, blow, n = dps + v, blow + b1, n + 1 end
    end
  end
  if dps <= 0 then return nil end
  return {guns = n, ticks = 60 * piece.health / dps, shells = math.ceil(piece.health / (blow / n)),
    mend = assault.mend_ticks(s, foes, piece)}
end

-- Whether wall fire wins its race at `piece` with `left` shells.
function assault.wins(r, left)
  return r ~= nil and r.shells <= left and (r.mend == nil or r.ticks < r.mend)
end

-- The menu at a closed wall: its options weighed by tactics.expect, each from its own record at the place, before any
-- by the siege's there (its best for what it spent; none: what stands at the target, the assault's size), the wall fire
-- offered only where `fire_ok`; picked by tactics.pick on its settlement's random source. Returns the method and a line
-- for its trace.
function assault.weigh(b, t, fire_ok, want, n_targets)
  local foe = t.owner or "player"
  local s = game.surfaces[b.surface]
  local sig = attempt.sig(s, foe, t.pos)
  local gain, lost, sent = math.max(1, n_targets or 1), 0, want
  local r = tactics.attempt(b.corp, foe, t.pos, "siege")
  local bv
  for _, a in ipairs(tactics.history(r, sig)) do
    local v = a.got / math.max(1, a.spent)
    if a.got > 0 and (not bv or v > bv) then bv, gain, lost, sent = v, a.got, a.spent, a.sent end
  end
  local options, all = {}, {}
  for _, m in ipairs(assault.METHODS) do
    if (m ~= "wallfire" or fire_ok) and not (storage.kh_tactics_off and storage.kh_tactics_off[m]) then
      local op = {method = m, at = t.pos, gain = gain, lost = lost, sent = sent, dist = 0}
      local ok = tactics.expect(b.corp, op, foe, sig, MIND, want, 0.1)
      all[#all + 1] = op
      if ok then options[#options + 1] = op end
    end
  end
  -- (Every one set aside by the ladder: it is at the wall now, and goes with the least failed.)
  if #options == 0 then
    table.sort(all, function(p, q) return p.ladder > q.ladder end)
    options = {all[1]}
  end
  -- A forced pick (tests, /lp): storage.kh_way.
  local pick
  if storage.kh_way then
    for _, o in ipairs(options) do if o.method == storage.kh_way then pick = o end end
  end
  pick = pick or tactics.pick(options, b.rng, function(o) return o.method end)
  local parts = {}
  for _, o in ipairs(all) do
    parts[#parts + 1] = string.format("%s %.2f%s%s", o.method, o.score or 0, o.known and " (its record)" or "",
      (o.ladder or 1) < tactics.LADDER_HOLD and " (set aside)" or "")
  end
  return pick.method, table.concat(parts, ", ")
end

return assault
