-- Strip camps (split from ops.lua, 2026-10-18, along the AI graph's seams: docs/ai-graph.md): Grubstake's, a hauler and
-- guards setting up beside a player's drills, out of the turrets' reach, mining the player's ore and carrying it home.
-- The code is as it was in ops; install runs it with ops' helpers bound (K) and returns what ops calls.
local shared = require("__landing-party__.shared")
local studies = require("__landing-party__.scripts.studies")

local strip = {}

function strip.install(ops, K)
local COOL_TICKS = K.COOL_TICKS
local PLAYER_REACH = K.PLAYER_REACH
local STRIP_COST = K.STRIP_COST
local STRIP_DRILLS = K.STRIP_DRILLS
local STRIP_GUARDS = K.STRIP_GUARDS
local STRIP_TICKS = K.STRIP_TICKS
local TURRETS = K.TURRETS
local against_player = K.against_player
local alert = K.alert
local alive = K.alive
local budget = K.budget
local enemies = K.enemies
local field = K.field
local finish = K.finish
local floor_of = K.floor_of
local home = K.home
local notify = K.notify
local order_all = K.order_all
local pool = K.pool
local push_escort = K.push_escort
local rd = K.rd
local sneak_route = K.sneak_route
local stance = K.stance
-- A camp site: ore within 45 tiles of a player's drill, 15 or more from it, beyond every player turret's reach
-- and clear of the player's buildings.
local function strip_site(b, t)
  local s = game.surfaces[b.surface]
  local foes = enemies(game.forces[b.force])
  -- Prospector's eye (Grubstake) looks half as far again for ore by the player's drills.
  local reach = rd.has(b.corp, "prospector") and 68 or 45
  for _, r in pairs(s.find_entities_filtered{position = t.pos, radius = reach, type = "resource", limit = 900}) do
    if r.prototype.resource_category == "basic-solid" then
      local p = r.position
      local d2 = (p.x - t.pos[1]) ^ 2 + (p.y - t.pos[2]) ^ 2
      if d2 >= 15 * 15 and s.count_entities_filtered{position = p, radius = PLAYER_REACH, type = TURRETS, force = foes} == 0
        and s.count_entities_filtered{position = p, radius = 10, force = foes, limit = 1} == 0
        and s.count_entities_filtered{position = p, radius = 6, type = "resource"} >= 25 then
        return {p.x, p.y}
      end
    end
  end
end

local function choose_strip(b, army)
  local temper = shared.CORPS[b.corp].temper or {}
  if not temper.strips or game.tick < (b.next_strip or 0) then return end
  -- Why none, traced once in a while (the factory scenario: no strip in hours, and no word why).
  local said = game.tick >= (b.strip_said or 0)
  local function why(text)
    if said and ops.trace then b.strip_said = game.tick + 30 * 3600; ops.trace(b, "strip: none (" .. text .. ")") end
  end
  if (b.parts or 0) < STRIP_COST then return why(string.format("parts %d of %d", b.parts or 0, STRIP_COST)) end
  if field(b, army) < STRIP_GUARDS then return why(string.format("guards %d of %d", field(b, army), STRIP_GUARDS)) end
  local h = home(b)
  local in_flight = ops.player_ops()
  local best, bd, site, bdrills
  local drills, sited = 0, 0
  for key, t in pairs(b.intel.targets) do
    if (t.drills or 0) > 0 and against_player(t.owner) then drills = drills + 1 end
    -- Any outpost with a camp site beyond turret reach (strip_site checks it): requiring an undefended drill as
    -- well left a careful player's outposts, each with two lasers, never stripped.
    if (t.drills or 0) > 0 and against_player(t.owner) and in_flight < budget(t.owner)
      and not ops.marked(b, t.pos) and stance.may(b.corp, t.owner, "strip") then
      local d = (t.pos[1] - h.position.x) ^ 2 + (t.pos[2] - h.position.y) ^ 2
      if not bd or d < bd then
        local p = strip_site(b, t)
        if p then sited = sited + 1 end
        -- A patch it already holds (a camp kept there) is not stripped again.
        local held = p and (b.claims or {})[math.floor(p[1] / 64) .. "," .. math.floor(p[2] / 64)] or 0
        if p and held < 2 then best, bd, site, bdrills = key, d, p, t.drills end
      end
    end
  end
  if not best then why(string.format("%d of the player's drills known, %d with a camp site out of turret reach, %d operations "
    .. "against it in flight", drills, sited, in_flight)) end
  -- Its worth, beside a raid's and a siege's (ops' decider): the drills there over distance.
  return best, site, best and (bdrills or 1) / (1 + math.sqrt(bd) / 300) or nil
end

local function launch_strip(b, key, site, trace, army)
  local t = b.intel.targets[key]
  local h = home(b)
  local s = game.surfaces[b.surface]
  local p = s.find_non_colliding_position(shared.variant(b.corp, "lp-hauler"), {h.position.x + (site[1] - h.position.x) * 0.1,
    h.position.y + (site[2] - h.position.y) * 0.1}, 20, 0.5)
  local hauler = p and s.create_entity{name = shared.variant(b.corp, "lp-hauler"), position = p, force = h.force}
  if not hauler then return false end
  local guards = pool.take(b, STRIP_GUARDS, floor_of(b, army), function(u) return u.type == "unit" end)
  b.parts = b.parts - STRIP_COST
  b.op = {kind = "strip", target = key, phase = "march", members = guards, launched = #guards, hauler = hauler,
    site = site, started = game.tick, phase_at = game.tick, cargo = 0}
  -- Round biter country (the hauler is slow and alone: through a nest field it never arrived).
  local hroute = sneak_route(b, {hauler.position.x, hauler.position.y}, site,
    {turrets = false, nests = (b.intel.targets[key] or {}).owner ~= "enemy"})
  if not hroute and b.intel.targets[key] and push_escort(b, b.intel.targets[key], {hauler.position.x, hauler.position.y}, site) then
    hroute = {}
    b.op.pushed = true
    trace(b, string.format("hauler pushes through biter country to %.0f,%.0f", site[1], site[2]))
  end
  if not hroute then
    for _, u in ipairs(guards) do table.insert(b.garrison, u) end
    b.op = nil
    b.parts = b.parts + STRIP_COST
    hauler.destroy()
    local tt = b.intel.targets[key]
    if tt then tt.cool = game.tick + COOL_TICKS end
    trace(b, string.format("%s to %.0f,%.0f: no way round biter country; not sent", "strip camp", site[1], site[2]))
    b.next_strip = game.tick + 2 * 3600
    b.next_op = game.tick + 2 * 3600
    return false
  end
  local hcmds = {}
  for _, w in ipairs(hroute) do
    table.insert(hcmds, {type = defines.command.go_to_location, destination = w, radius = 4,
      distraction = defines.distraction.none})
  end
  table.insert(hcmds, {type = defines.command.go_to_location, destination = site, radius = 2,
    distraction = defines.distraction.none})
  hauler.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = hcmds}
  order_all(guards, {type = defines.command.go_to_location, destination = hauler.position, radius = 6,
    distraction = defines.distraction.by_enemy})
  b.ops_launched = b.ops_launched + 1
  b.strips = (b.strips or 0) + 1
  storage.threat_last = game.tick
  trace(b, string.format("strip-mining beside %s at %.0f,%.0f: a camp to %.0f,%.0f, %d guards", t.kind, t.pos[1],
    t.pos[2], site[1], site[2], #guards))
  return true
end

local function strip_step(b, trace, army)
  local op = b.op
  local n = alive(op)
  if game.tick - op.started > STRIP_TICKS + 8 * 3600 then return finish(b, "aborted", trace, army) end
  if (op.phase == "march" or op.phase == "deploy") and not op.hauler.valid then
    trace(b, "strip-mining: the hauler was destroyed on the way")
    return finish(b, "intercepted", trace, army)
  end
  local s = game.surfaces[b.surface]
  if op.phase == "march" then
    local hp = op.hauler.position
    if not op.hauler.commandable.has_command then
      op.hauler.commandable.set_command{type = defines.command.go_to_location, destination = op.site, radius = 2,
        distraction = defines.distraction.none}
    end
    order_all(op.members, {type = defines.command.go_to_location, destination = hp, radius = 6,
      distraction = defines.distraction.by_enemy})
    if (hp.x - op.site[1]) ^ 2 + (hp.y - op.site[2]) ^ 2 < 6 * 6 then
      op.phase, op.phase_at = "deploy", game.tick
      op.hauler.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      order_all(op.members, {type = defines.command.compound, structure_type = defines.compound_command.return_last,
        commands = {{type = defines.command.go_to_location, destination = op.site, radius = 8,
          distraction = defines.distraction.by_damage},
          {type = defines.command.wander, radius = 8, distraction = defines.distraction.by_damage}}})
    end
  elseif op.phase == "deploy" then
    if game.tick - op.phase_at >= 20 * 60 then
      local f = game.forces[b.force]
      local function put(kind, x, y)
        local name = shared.variant(b.corp, kind)
        local p = s.find_non_colliding_position(name, {op.site[1] + x, op.site[2] + y}, 6, 0.5)
        return p and s.create_entity{name = name, position = p, force = f}
      end
      op.camp = {}
      -- Its strip camp on the map of a player with its claims register (a field study, studies.lua).
      for _, pf in pairs(game.forces) do
        if shared.is_player_force(pf) and studies.has(pf, "lp-claims-register") then
          pf.add_chart_tag(s, {position = {op.site[1], op.site[2]}, icon = {type = "item", name = "electric-mining-drill"},
            text = "Grubstake strip camp"})
        end
      end
      local pylon = put("lp-pylon", 0, 0)
      table.insert(op.camp, pylon)
      table.insert(op.camp, put("lp-generator", -5, 0))
      op.bins = {}
      for k = 1, STRIP_DRILLS do
        local dx = (k - 2) * 4
        local pos = s.find_non_colliding_position(shared.variant(b.corp, "lp-drill"), {op.site[1] + dx, op.site[2] + 4}, 6, 1)
        local drill = pos and s.create_entity{name = shared.variant(b.corp, "lp-drill"), position = pos, force = f,
          direction = defines.direction.south}
        if drill then
          table.insert(op.camp, drill)
          local bin = s.create_entity{name = shared.variant(b.corp, "lp-bin"), position = drill.drop_position, force = f}
          if bin then table.insert(op.camp, bin); table.insert(op.bins, bin) end
        end
      end
      op.drills = 0
      for _, e in ipairs(op.camp) do if e and e.valid and e.type == "mining-drill" then op.drills = op.drills + 1 end end
      op.phase, op.phase_at = "mine", game.tick
      alert(b, b.intel.targets[op.target], "lp.alert-strip", op.site)
      trace(b, string.format("strip-mining: camp up at %.0f,%.0f with %d bins", op.site[1], op.site[2], #op.bins))
    end
  elseif op.phase == "mine" then
    local working = 0
    for _, e in ipairs(op.camp) do if e and e.valid and e.type == "mining-drill" then working = working + 1 end end
    local done = game.tick - op.phase_at >= (storage.strip_fast and 3 * 3600 or STRIP_TICKS)
    -- Unanswered (every drill standing, nobody lost): the patch is claimed; the second time, the camp stays as a
    -- Grubstake outpost on the player's ore (late pressure: ignoring two camps leaves a patch to assault).
    if done and working == (op.drills or working) and n >= op.launched then
      b.claims = b.claims or {}
      -- By patch (64-tile squares round the camp), not by target cell: the next camp may aim at another drill.
      local patch = math.floor(op.site[1] / 64) .. "," .. math.floor(op.site[2] / 64)
      local times = (b.claims[patch] or 0) + 1
      b.claims[patch] = times
      notify(b, times >= 2 and "lp.claim-outpost" or "lp.claim", op.site)
      if times >= 2 and ops.settle then
        ops.settle(b, op.site, op.camp)
        op.camp = nil
        trace(b, string.format("strip-mining: the camp at %.0f,%.0f stays as an outpost", op.site[1], op.site[2]))
        return finish(b, "claimed", trace, army)
      end
    end
    if working == 0 or n < 0.5 * op.launched or done then
      local cargo = 0
      for _, bin in ipairs(op.bins or {}) do if bin.valid then cargo = cargo + bin.get_inventory(defines.inventory.chest).get_item_count() end end
      op.cargo = cargo
      op.packing_because = done and "done" or "aborted"
      op.phase, op.phase_at = "pack", game.tick
      trace(b, string.format("strip-mining: packing up with %d ore (%s)", cargo, op.packing_because))
    end
  elseif op.phase == "pack" then
    if game.tick - op.phase_at >= 10 * 60 then return finish(b, op.packing_because, trace, army) end
  end
end
return {choose_strip = choose_strip, launch_strip = launch_strip, strip_site = strip_site, strip_step = strip_step}
end

return strip
