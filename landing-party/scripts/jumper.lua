-- The claim jumper (Grubstake; the user; docs/reviews/2026-10-15-grubstake-flavour-consult.md): a heist, never an
-- assault. A drill rig (lp-claim-rig, 1,200 health, a military target) digs in out of the turrets' reach, 40 to 60 tiles
-- from a guarded player target with chests; inside the wall a mound of dirt grows for a minute (a tell, not a target);
-- then four to six Shotgun hands come up through it, empty the chests within 16 tiles (the raid's loot, ops.loot), break
-- what they stand by for a while, and go back down. What they carry home becomes parts. The counter: kill the rig within
-- the minute and nothing comes up; killed after, the tunnel caves in and the hands are left inside. One rig a settlement
-- at a time, from its ladder's second rung against the player.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")
local war = require("__landing-party__.scripts.war")

local jumper = {}

local COOLDOWN = 15 * 3600
-- The mound grows this long before the hands come up: 2.5 minutes, so the chart (the rig, a Grubstake structure that was
-- not there) and the dust line are a fair warning with no notice (Fable's notices consult: a minute was not).
local DIG = 150 * 60
local LOOT_TICKS = 60 * 60        -- they look for chests this long
local RAZE_TICKS = 30 * 60        -- then break what is near this long
local LEAVE_TICKS = 45 * 60       -- then go back down; who is not at the mound by then stays
local RIG_MIN, RIG_MAX = 40, 60
local REACH = 19
local HANDS_MIN, HANDS_MAX = 4, 6
local CHEST_RADIUS = 16
local RUNG = 2
local STAGES = {{"small-sand-rock", 3}, {"medium-sand-rock", 2}, {"sand-dune-decal", 1}}

local function tell(b, key, at)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at.x, at.y, s.name)})
    end
  end
end

local function home(b)
  for _, d in ipairs(b.depots or {}) do if d.valid then return d end end
  if b.lander and b.lander.valid then return b.lander end
end

local function chests(s, owner, pos)
  return s.find_entities_filtered{position = pos, radius = CHEST_RADIUS, force = owner,
    type = {"container", "logistic-container"}}
end

-- Where the rig digs in: from the target toward home, 40 to 60 tiles, out of every player turret's reach.
local function rig_point(s, owner, tpos, hpos)
  local dx, dy = hpos.x - tpos[1], hpos.y - tpos[2]
  local len = math.sqrt(dx * dx + dy * dy)
  if len < RIG_MAX + 10 then return nil end
  for d = RIG_MIN, RIG_MAX, 2 do
    local q = {tpos[1] + dx / len * d, tpos[2] + dy / len * d}
    if s.count_entities_filtered{position = q, radius = REACH, force = owner,
      type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 then
      return s.find_non_colliding_position("lp-claim-rig", q, 6, 0.5)
    end
  end
end

-- The mound: by the target's chests, where a hand can stand.
local function mound_point(s, owner, tpos)
  local cs = chests(s, owner, tpos)
  if #cs == 0 then return nil end
  local c = cs[1].position
  return s.find_non_colliding_position(shared.variant("grubstake", "lp-infantry"), {c.x + 3, c.y + 3}, 6, 0.5)
end

function jumper.launch(b, tpos)
  local s = game.surfaces[b.surface]
  local h = home(b)
  if not h then return "no home" end
  local owner = "player"
  local at = rig_point(s, owner, tpos, h.position)
  if not at then return "no rig point" end
  local m = mound_point(s, owner, tpos)
  if not m then return "no chests" end
  local rig = s.create_entity{name = "lp-claim-rig", position = at, force = b.lander.force}
  if not rig then return "no room" end
  s.create_entity{name = "big-explosion", position = at}
  b.jump = {phase = "dig", rig = rig, mound = {x = m.x, y = m.y}, target = tpos, started = game.tick, stage = 0,
    owner = owner}
  b.jumps = (b.jumps or 0) + 1
  for _, pf in pairs(game.forces) do
    if #pf.players > 0 and not shared.is_corp(pf.name) then
      for _, pl in pairs(pf.connected_players) do
        if shared.notices_on() then
          pl.add_custom_alert(rig, {type = "virtual", name = shared.CORPS[b.corp].icon}, {"lp.alert-rig"}, true) -- notice-ok: gated above
        end
      end
    end
  end
  tell(b, "lp.rig", rig.position)
  base.trace(b, string.format("claim rig %d dug in at %.0f,%.0f; the mound at %.0f,%.0f", b.jumps, at.x, at.y, m.x, m.y))
  return "launched"
end

local function cave_in(b, j)
  local s = game.surfaces[b.surface]
  s.destroy_decoratives{position = j.mound, radius = 3}
  s.create_trivial_smoke{name = "lp-dust-smoke", position = j.mound}
end

local function finish(b, j, why)
  if j.rig and j.rig.valid then j.rig.destroy() end
  cave_in(b, j)
  -- Hands left above ground stay where they are (the garrison does not know them): they fight to the end.
  if j.loot and j.loot.value > 0 and (j.home_with or 0) > 0 then
    b.parts = b.parts + math.floor(j.loot.value)
    b.looted = (b.looted or 0) + j.loot.items
  end
  base.trace(b, string.format("claim jump over: %s (%d items carried home, %d of %d hands back)", why,
    j.loot and j.home_with and j.home_with > 0 and j.loot.items or 0, j.home_with or 0, #(j.hands or {})))
  b.hands_back = (b.hands_back or 0) + (j.home_with or 0)
  b.jump = nil
  b.next_jump = game.tick + (storage.jump_cooldown or COOLDOWN)
end

local function emerge(b, j)
  local s = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-infantry")
  local n = math.random(HANDS_MIN, HANDS_MAX)
  if storage.jump_hands then n = storage.jump_hands end
  j.hands = {}
  for _ = 1, n do
    local p = s.find_non_colliding_position(name, j.mound, 4, 0.5)
    local u = p and s.create_entity{name = name, position = p, force = b.lander.force}
    if u then
      -- An order at once: idle, a unit attacks whatever it sees, and the hands charged the wall's turrets 20 tiles off.
      u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_damage, ticks_to_wait = 120}
      table.insert(j.hands, u)
    end
  end
  j.phase, j.phase_at = "loot", game.tick
  j.loot = {items = 0, value = 0, looted = {}}
  s.create_entity{name = "explosion", position = j.mound}
  base.trace(b, string.format("claim jump: %d hands up at %.0f,%.0f", #j.hands, j.mound.x, j.mound.y))
end

local function alive(j)
  local n = 0
  for _, u in ipairs(j.hands or {}) do if u.valid then n = n + 1 end end
  return n
end

local function step(b, j)
  local s = game.surfaces[b.surface]
  local rig_up = j.rig and j.rig.valid
  if j.phase == "dig" then
    if not rig_up then
      tell(b, "lp.rig-down", j.mound)
      return finish(b, j, "the rig was destroyed before it broke through")
    end
    local k = math.floor((game.tick - j.started) / DIG * #STAGES)
    if k > j.stage and k <= #STAGES then
      j.stage = k
      local st = STAGES[k]
      s.create_decoratives{check_collision = false, decoratives = {{name = st[1], position = {j.mound.x, j.mound.y},
        amount = st[2]}}}
    end
    s.create_trivial_smoke{name = "lp-dust-smoke", position = j.mound}
    s.create_trivial_smoke{name = "lp-dust-smoke", position = j.rig.position}
    -- The tunnel's line: dust puffs creeping from the rig toward the mound at the dig's pace, so a player who sees the
    -- mound can trace it back to the rig, and one who sees the rig can see where it goes.
    local f = math.min(1, (game.tick - j.started) / DIG)
    local r = j.rig.position
    for _, g in ipairs({f, f - 0.06, f - 0.12}) do
      if g > 0 then
        s.create_trivial_smoke{name = "lp-dust-smoke", position = {r.x + (j.mound.x - r.x) * g, r.y + (j.mound.y - r.y) * g}}
      end
    end
    if game.tick - j.started >= DIG then emerge(b, j) end
    return
  end
  -- None left above: fallen, or all gone back down (the log said "every hand fell" with four of six home).
  if alive(j) == 0 then
    return finish(b, j, (j.home_with or 0) > 0 and "back down the tunnel" or "every hand fell")
  end
  if not rig_up and not j.caved then
    j.caved = true
    cave_in(b, j)
    base.trace(b, "claim jump: the rig fell, the tunnel caved in")
  end
  local t = {owner = j.owner, pos = {j.mound.x, j.mound.y}}
  if j.phase == "loot" then
    ops.loot(b, j, t, j.mound, s, base.trace)
    -- Each hand to the nearest chest not yet emptied.
    local cs = chests(s, j.owner, j.mound)
    for i, u in ipairs(j.hands) do
      if u.valid then
        local c = cs[(i - 1) % math.max(1, #cs) + 1]
        if c and not j.loot.looted[c.unit_number] then
          u.commandable.set_command{type = defines.command.go_to_location, destination = c.position, radius = 2,
            distraction = defines.distraction.by_damage}
        end
      end
    end
    local left = 0
    for _, c in ipairs(cs) do if not j.loot.looted[c.unit_number] then left = left + 1 end end
    if left == 0 or game.tick - j.phase_at > LOOT_TICKS then
      j.phase, j.phase_at = "raze", game.tick
    end
  elseif j.phase == "raze" then
    -- Each hand on a building within 10 of the mound that no turret of the player's reaches (REACH), the nearest, told
    -- again when it falls; none left, back to the mound. Told to attack the area, they went for turrets beyond it and
    -- five of six fell 10 tiles from the turret that killed them, 15 to 21 from the mound (jumper).
    local ents = {}
    for _, e in pairs(s.find_entities_filtered{position = j.mound, radius = 10, force = j.owner}) do
      if e.type ~= "character" and e.type ~= "unit" and not e.type:find("turret") and s.count_entities_filtered{position = e.position,
        radius = REACH, force = j.owner, type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1} == 0 then
        ents[#ents + 1] = e
      end
    end
    for _, u in ipairs(j.hands) do
      if u.valid then
        local c = u.commandable.command
        local busy = c and c.type == defines.command.attack and c.target and c.target.valid
        if not busy then
          local e = #ents > 0 and s.get_closest(u.position, ents)
          u.commandable.set_command(e and {type = defines.command.attack, target = e, distraction = defines.distraction.by_damage}
            or {type = defines.command.go_to_location, destination = j.mound, radius = 2, distraction = defines.distraction.by_damage})
        end
      end
    end
    if game.tick - j.phase_at > RAZE_TICKS then
      j.phase, j.phase_at = "leave", game.tick
      for _, u in ipairs(j.hands) do
        if u.valid then
          u.commandable.set_command{type = defines.command.go_to_location, destination = j.mound, radius = 1.5,
            distraction = defines.distraction.none}
        end
      end
    end
  elseif j.phase == "leave" then
    if j.caved then return finish(b, j, "the tunnel caved in: the hands are left inside") end
    j.home_with = j.home_with or 0
    for _, u in ipairs(j.hands) do
      if u.valid and (u.position.x - j.mound.x) ^ 2 + (u.position.y - j.mound.y) ^ 2 < 3 * 3 then
        u.destroy()
        j.home_with = j.home_with + 1
      end
    end
    if alive(j) == 0 or game.tick - j.phase_at > LEAVE_TICKS then return finish(b, j, "back down the tunnel") end
  end
end

-- The guarded player target with chests nearest home.
local function consider(b)
  if storage.jump_off or not (shared.CORPS[b.corp].temper or {}).jumps then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_jump or 0) then return end
  local owner, rung = war.at_war(b, "jump")
  if not owner then return end
  if ops.truce and ops.truce(b, owner) then return end
  if (rung or 0) < RUNG then
    -- Its ladder resets with every raze: a camp that keeps razing never needs the rig (traced once in a while).
    if game.tick >= (b.jump_said or 0) then
      b.jump_said = game.tick + 30 * 3600
      base.trace(b, string.format("claim jump: waits for rung %d (at %d)", RUNG, rung or 0))
    end
    return
  end
  local h = home(b)
  if not h then return end
  local s = game.surfaces[b.surface]
  local best, bd
  for _, t in pairs(b.intel and b.intel.targets or {}) do
    if t.owner == owner and t.pos and (t.exposure or t.defence or 0) > 0 and not ops.marked(b, t.pos) then
      local d = (t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2
      if (not bd or d < bd) and #chests(s, owner, t.pos) > 0 then best, bd = t, d end
    end
  end
  if not best then
    if game.tick >= (b.jump_said or 0) then
      b.jump_said = game.tick + 30 * 3600
      local guarded = 0
      for _, t in pairs(b.intel and b.intel.targets or {}) do
        if t.owner == owner and (t.exposure or t.defence or 0) > 0 then guarded = guarded + 1 end
      end
      base.trace(b, string.format("claim jump: none (%d guarded targets known, none with chests within 16)", guarded))
    end
    b.next_jump = game.tick + 3600
    return
  end
  if jumper.launch(b, best.pos) ~= "launched" then b.next_jump = game.tick + 3600 end
end

function jumper.tick(tick)
  if tick % 60 ~= 13 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.jump then
      step(b, b.jump)
    elseif tick % 600 == 13 + 540 then
      consider(b)
    end
  end
end

return jumper
