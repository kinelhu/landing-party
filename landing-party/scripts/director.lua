-- The director (docs/director.md; Fable's consult, docs/reviews/2026-11-13-director-consult.md; the user, 2026-11-13:
-- "think rimworld storyteller", then "Shouldn't the director cover the possible operations stemming from all camps in
-- play?"). One layer above every camp: it decides when the pressure on the player rises and falls, never how. Its
-- first step (the consult's order): its state, budget and readings; two dials that act from the first camp on, tempo
-- (a corporation's spree: its gaps between operations shortened, tune.sooner) and lull (its operations held, the truce
-- standing, stance.standing); and the pressure floor (20 minutes without an operation, ops.choose and the perimeter)
-- taken over while it is on. Synthexis keeps its own waves (decision 2): its tempo is never touched.
-- Its budget is counted in landings: it fills by (1 + era / 2) times the difficulty and the personality each landing
-- interval, up to DIRECTOR.cap; a spree costs DIRECTOR.spree_cost. A spree, then a lull, then filling again: a rise, a
-- peak, a valley. No threat while the player's losses of the last half hour pass twice their usual and 5% of their factory's
-- worth, and the fill halves while their guns are fewer than an hour ago (the slow spiral a window misses).
-- On after the opening's arrival (phases.lua) and DIRECTOR.grace more (decision 5), or by debug_tune director. Off
-- (setting lp-director), none of this runs and tune.sooner, the floor and the truces are as they were.
-- Its state is storage.director, all of it: a save, a load or a player joining sees the same director.
local shared = require("__landing-party__.shared")
local valuemap = require("__landing-party__.scripts.valuemap")
local ops = require("__landing-party__.scripts.ops")
local stance = require("__landing-party__.scripts.stance")
local faction = require("__landing-party__.scripts.faction")
local farm = require("__landing-party__.scripts.farm")
local rng = require("__landing-party__.scripts.rng")
local pods = require("__landing-party__.scripts.pods")
local war = require("__landing-party__.scripts.war")

local director = {}

-- The factory's worth, read cheaply (LuaForce.get_entity_count, not a search over its ground): these prototypes, each
-- weighed as valuemap weighs it; its guns counted apart.
local WORTH_NAMES = {"assembling-machine-1", "assembling-machine-2", "assembling-machine-3", "stone-furnace",
  "steel-furnace", "electric-furnace", "electric-mining-drill", "burner-mining-drill", "lab", "roboport", "radar",
  "substation", "beacon", "rocket-silo", "solar-panel", "accumulator", "steam-engine", "steam-turbine", "nuclear-reactor",
  "oil-refinery", "chemical-plant", "foundry", "electromagnetic-plant", "biochamber", "cryogenic-plant", "big-mining-drill"}
local GUN_NAMES = {"gun-turret", "laser-turret", "flamethrower-turret", "artillery-turret", "railgun-turret", "tesla-turret",
  "rocket-turret"}

local function tun(k)
  local t = storage.director_tune
  return t and t[k] or shared.DIRECTOR[k]
end

local function st()
  storage.director = storage.director or {budget = 0, phase = "fill", losses = {}, guns = {}, tempo = {}, beats = 0,
    last_spree = {}}
  return storage.director
end

local function trace(text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d director  %s\n", game.tick, text), true)
  end
  local s = st()
  s.log = s.log or {}
  table.insert(s.log, {tick = game.tick, text = text})
  if #s.log > 40 then table.remove(s.log, 1) end
end

function director.personality()
  if storage.director_force then return storage.director_force end
  return shared.setting("lp-director", "steady")
end

-- On: a personality other than off, and the opening over by its grace (or forced by a test).
local function on(tick)
  if director.personality() == "off" then return false end
  if storage.director_force then return true end
  local arrived = storage.phases and storage.phases.arrived
  return arrived ~= nil and tick >= arrived + tun("grace") * 3600
end

-- A loss of the player's, for the half hour's window (control.lua, beside storage.player_razed).
function director.note_loss(owner, ent)
  if not (storage.director and storage.director.active) then return end
  local s = st()
  table.insert(s.losses, {game.tick, owner, valuemap.razed_of(ent)})
end

-- Every prototype valuemap weighs (by name or by type: a mod's buildings too) and every turret, built once from the
-- prototypes (the same on every peer; only time is saved by keeping it). (Until 0.2.384 the 26 names above: on the
-- user's saves 1.2 to 2.4 times less than this, the belts, inserters, poles and accumulators unseen; the user,
-- 2026-11-14: "We are not monitoring building amounts?")
local VALUED, TURRETS
local TURRET_TYPES = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true}
local function valued()
  if VALUED then return VALUED, TURRETS end
  VALUED, TURRETS = {}, {}
  for name, p in pairs(prototypes.entity) do
    local wt = valuemap.NAMES[name] or valuemap.WORTH[p.type]
    if wt then VALUED[#VALUED + 1] = {name, wt} end
    if TURRET_TYPES[p.type] then TURRETS[#TURRETS + 1] = name end
  end
  table.sort(VALUED, function(a, b) return a[1] < b[1] end)
  table.sort(TURRETS)
  return VALUED, TURRETS
end
local function worth_of(force)
  local w, guns = 0, 0
  local v, t = valued()
  for _, e in ipairs(v) do
    local c = force.get_entity_count(e[1])
    if c > 0 then w = w + c * e[2] end
  end
  for _, n in ipairs(t) do guns = guns + force.get_entity_count(n) end
  return w, guns
end
-- The 26 names' worth, for the readings beside it.
local function worth_26(force)
  local w = 0
  for _, n in ipairs(WORTH_NAMES) do
    local p = prototypes.entity[n]
    if p then
      local c = force.get_entity_count(n)
      if c > 0 then w = w + c * (valuemap.NAMES[n] or valuemap.WORTH[p.type] or 0) end
    end
  end
  return w
end

-- Tests and visits (remote debug_readings): what it reads of a player force now, beside what a fuller reading would
-- read (the user, 2026-11-14: "We are not monitoring building amounts?", "an idea of player advancement from tech
-- tree"): its worth from the 26 names it counts against one from every prototype whose type valuemap weighs; the
-- buildings by type; its era from the research count against tiers by science packs (a tech's tier, how many kinds of
-- pack it takes); the fill a minute and the minutes to a spree's cost; the hurt line.
function director.readings(owner)
  local f = game.forces[owner or "player"]
  if not f then return nil end
  local w1x, guns = worth_of(f)
  local w0 = worth_26(f)
  local by_type, w1, n1 = {}, 0, 0
  for name, p in pairs(prototypes.entity) do
    local wt = valuemap.NAMES[name] or valuemap.WORTH[p.type]
    if wt then
      local c = f.get_entity_count(name)
      if c > 0 then
        by_type[p.type] = (by_type[p.type] or 0) + c
        w1, n1 = w1 + c * wt, n1 + c
      end
    end
  end
  local researched, tiers = 0, {}
  -- Infinite research (max_level past any real count): never "researched"; its levels bought, each with its packs.
  local infinite, depth, levels = {}, 0, 0
  for _, t in pairs(f.technologies) do
    local k = 0
    local ing = t.research_unit_ingredients or {}
    for _ in pairs(ing) do k = k + 1 end
    if t.prototype.max_level >= 4294967295 then
      local bought = math.max(0, t.level - t.prototype.level)
      if bought > 0 then infinite[t.name] = {bought = bought, packs = k} end
      levels, depth = levels + bought, depth + bought * k
    end
    tiers[k] = tiers[k] or {done = 0, all = 0}
    tiers[k].all = tiers[k].all + 1
    if t.researched then researched = researched + 1; tiers[k].done = tiers[k].done + 1 end
  end
  local era = storage.era_override or ops.era(f)
  local interval = shared.setting("lp-landing-interval", shared.LANDING_MINUTES.default)
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  local fill = (1 + era / 2) * d / math.max(1, interval)
  return {worth_now = w0, guns = guns, worth_all = w1, buildings = n1, by_type = by_type, researched = researched,
    era = era, tiers = tiers, fill_per_min = fill, minutes_to_spree = tun("spree_cost") / fill,
    hurt_line = tun("loss_share") * w0, hurt_floor_now = tun("hurt_floor") * w1, interval = interval, era_tiers = ops.era(f),
    infinite = infinite, infinite_levels = levels, depth = depth}
end

-- The corporations at war with this player with a camp standing, the one longest without a spree first.
local function pick(s, owner, tick)
  local best, bt
  for corp in pairs(shared.CORPS) do
    if faction.alive(corp) > 0 and stance.standing(corp, owner) == "enemy" then
      local t = s.last_spree[corp] or -math.huge
      if not best or t < bt then best, bt = corp, t end
    end
  end
  return best
end

-- The corporations at war with this player with a camp standing (Synthexis apart: its waves are its own, decision 2),
-- and how many camps they have between them.
local function at_war(owner)
  local corps, camps = {}, 0
  for corp in pairs(shared.CORPS) do
    local n = faction.alive(corp)
    if corp ~= "biotech" and n > 0 and stance.standing(corp, owner) == "enemy" then
      corps[#corps + 1] = corp
      camps = camps + n
    end
  end
  table.sort(corps)
  return corps, camps
end

-- Its next beat, drawn as it starts filling (its rng in storage, seeded by the map): spree, surge or focus strike by
-- beat_weights; a surge or a focus only with two camps at war or more (one camp's surge is a spree).
local function draw(s, owner)
  if not s.rng then s.rng = {s = rng.new((game.surfaces[1] and game.surfaces[1].map_gen_settings.seed or 1) + 7919).s} end
  local _, camps = at_war(owner)
  local w = (tun("weights_of") or {})[director.personality()] or tun("beat_weights")
  local list = camps >= 2 and {"spree", "surge", "focus", "wave", "supply"} or {"spree", "wave", "supply"}
  local total = 0
  for _, k in ipairs(list) do total = total + (w[k] or 0) end
  local x = rng.next(s.rng) * total
  for _, k in ipairs(list) do
    x = x - (w[k] or 0)
    if x < 0 then return k end
  end
  return list[#list]
end

local function cost_of(beat)
  return tun((beat == "surge" and "surge_cost") or (beat == "focus" and "focus_cost") or (beat == "wave" and "wave_cost")
    or (beat == "supply" and "supply_cost") or "spree_cost")
end

-- The place on the player's ground its camps know best: their targets against the player, by cell of focus_radius,
-- each target's value summed over every camp that knows it.
local function focus_point(owner)
  local r = tun("focus_radius")
  local cells = {}
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.corp ~= "biotech" then
      for _, t in pairs(b.intel and b.intel.targets or {}) do
        if t.owner == owner and t.pos then
          local key = math.floor(t.pos[1] / r) .. "," .. math.floor(t.pos[2] / r)
          local c = cells[key] or {w = 0, x = 0, y = 0, n = 0}
          local v = t.value or 1
          c.w, c.x, c.y, c.n = c.w + v, c.x + t.pos[1] * v, c.y + t.pos[2] * v, c.n + 1
          cells[key] = c
        end
      end
    end
  end
  local best, bk
  for k, c in pairs(cells) do
    if not best or c.w > best.w or (c.w == best.w and k < bk) then best, bk = c, k end
  end
  return best and {best.x / best.w, best.y / best.w} or nil
end

local function names(corps)
  local out = {}
  for _, c in ipairs(corps) do out[#out + 1] = shared.CORPS[c].name end
  if #out <= 1 then return out[1] or "" end
  return table.concat(out, ", ", 1, #out - 1) .. " and " .. out[#out]
end

local function tell(owner, key, ...)
  local f = game.forces[owner]
  if f and #f.players > 0 then shared.notice(f, {key, ...}) end
end

function director.tick(tick)
  if tick % 3600 ~= 0 then return end
  local s = st()
  local active = on(tick)
  if active ~= s.active then
    s.active = active
    if active then
      s.on_at = s.on_at or tick
      trace(string.format("on (%s)", director.personality()))
    end
  end
  if not active then return end
  local forces = shared.player_forces()
  local owner = forces[1] and forces[1].name
  if not owner then return end
  local f = game.forces[owner]
  -- Its readings.
  local era = storage.era_override or ops.era(f)
  local w, guns = worth_of(f)
  -- Its losses: the last half hour against its own rate over hurt_hours (a half hour's share of it), kept that long.
  local span = tun("hurt_hours") * 60 * 3600
  local cut = tick - span
  local k = 1
  while s.losses[k] and s.losses[k][1] < cut do k = k + 1 end
  if k > 1 then
    local keep = {}
    for i = k, #s.losses do keep[#keep + 1] = s.losses[i] end
    s.losses = keep
  end
  local lost, long = 0, 0
  for _, l in ipairs(s.losses) do
    if l[2] == owner then
      long = long + l[3]
      if l[1] >= tick - 30 * 3600 then lost = lost + l[3] end
    end
  end
  -- (Its rate over as much of the span as it has been on: a director on for 40 minutes reads 40.)
  local had = math.min(span, tick - (s.on_at or tick))
  local usual = had > 30 * 3600 and long * (30 * 3600) / had or 0
  if tick % (10 * 3600) == 0 then
    table.insert(s.guns, guns)
    if #s.guns > 7 then table.remove(s.guns, 1) end
  end
  local falling = #s.guns >= 7 and guns < s.guns[1]
  -- Hurt: the last half hour's losses past hurt_factor times its usual half hour, and past hurt_floor of the factory's
  -- worth (a pylon is not a beating). (Until 0.2.384 past 2% of its worth alone: routine raids passed it, and in the
  -- calibration it held the director nearly always; on the user's start save that line was two assemblers.) A player
  -- with nothing left standing who is still losing is hurt too.
  local hurt = lost > 0 and lost > tun("hurt_factor") * usual and lost > tun("hurt_floor") * w
  local depth = ops.depth(f)
  s.read = {era = era, worth = w, guns = guns, lost = lost, usual = usual, falling = falling, hurt = hurt, depth = depth}
  -- Its budget, in landings a landing interval.
  local interval = shared.setting("lp-landing-interval", shared.LANDING_MINUTES.default)
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  local rate = (storage.director_tune and storage.director_tune.fill)
    or (1 + era / 2) * d * (tun("personality")[director.personality()] or 1) / math.max(1, interval)
  -- Depth (infinite research): its pace up, by a capped logarithm, depth_max at most (the bounded era stays the camps').
  rate = rate * math.min(tun("depth_max"), 1 + math.log(1 + depth / tun("depth_scale"), 10))
  if falling then rate = rate / 2 end
  -- Its first beat first_minutes after it comes on, whatever the era (it waited 90 minutes at era 0 to afford one).
  if not s.seeded and rate > 0 then
    s.seeded = true
    s.budget = math.max(s.budget, tun("spree_cost") - rate * tun("first_minutes"))
  end
  -- Adaptation (RimWorld's; the user, 2026-11-13: "Yes to the climb"): a player who goes unhurt is pressed harder as the
  -- hours pass, adapt_climb more an hour up to adapt_max; hurt (the loss window), back to 1.
  if hurt then s.adapt = 1
  else s.adapt = math.min(tun("adapt_max"), (s.adapt or 1) + tun("adapt_climb") / 60) end
  rate = rate * s.adapt
  s.read.adapt = s.adapt
  s.budget = math.min(tun("cap"), s.budget + rate)
  director.expeditions(s, owner, tick)
  director.supplies(s, tick)
  -- Its beats: a spree, a surge or a focus strike, then a lull, then filling again; or a drop wave.
  if (s.phase == "spree" or s.phase == "surge") and tick >= s.phase_till then
    director.start_lull(s, owner, tick)
  elseif s.phase == "lull" and tick >= s.phase_till then
    director.end_lull(s, tick)
    s.phase, s.phase_till = "fill", nil
    s.next_beat = nil
    trace(string.format("fill: budget %.2f", s.budget))
  end
  if s.phase == "fill" and not s.next_beat then
    s.next_beat = draw(s, owner)
    -- (Chaotic: each beat held a random while past its cost, up to chaos_minutes.)
    s.hold_till = director.personality() == "chaotic" and tick + math.floor(rng.next(s.rng) * tun("chaos_minutes") * 3600) or nil
    trace(string.format("next beat: %s (costs %d; budget %.2f)%s", s.next_beat, cost_of(s.next_beat), s.budget,
      s.hold_till and string.format(", held till %d min", math.floor(s.hold_till / 3600)) or ""))
  end
  if s.phase == "fill" and s.hold_till and tick < s.hold_till then return end
  if s.phase == "fill" and s.budget >= cost_of(s.next_beat) then
    if hurt then
      if s.held_for ~= "hurt" then
        s.held_for = "hurt"
        trace(string.format("holds: %s lost %.0f of %.0f worth in half an hour", owner, lost, w))
      end
      return
    end
    -- Never on Synthexis's waves (decision 2): none out, none due within the spree.
    if farm.wave_soon(tun("spree_minutes") * 3600) then
      if s.held_for ~= "wave" then s.held_for = "wave"; trace("holds: a Synthexis wave out or due within a spree") end
      return
    end
    local why = string.format("era %d, worth %.0f, guns %d", era, w, guns)
    if s.next_beat == "surge" or s.next_beat == "focus" then
      -- (Two camps or more at war still: else the beat drawn is a spree after all.)
      local _, camps = at_war(owner)
      if camps < 2 then s.next_beat = "spree" end
    end
    if s.next_beat == "supply" then
      s.held_for = nil
      s.budget = s.budget - tun("supply_cost")
      director.start_supply(s, owner, tick, why)
      s.phase, s.next_beat = "fill", nil
      return
    end
    if s.next_beat == "wave" then
      local corp = pick(s, owner, tick)
      if not corp then return end
      s.held_for = nil
      s.budget = s.budget - tun("wave_cost")
      director.start_wave(s, owner, corp, tick, why)
      s.phase, s.next_beat = "fill", nil
      return
    end
    if s.next_beat == "surge" or s.next_beat == "focus" then
      s.held_for = nil
      local beat = s.next_beat
      s.budget = s.budget - cost_of(beat)
      director.start_surge(s, owner, tick, beat == "focus", why)
      return
    end
    local corp = pick(s, owner, tick)
    if not corp then return end
    -- (Grubstake's thefts are night-bound: its spree waits for dusk, as its skims do.)
    local surface = game.surfaces[1]
    if corp == "grubstake" and surface and surface.darkness < tun("dusk") then
      if s.held_for ~= "dusk" then s.held_for = "dusk"; trace("holds: Grubstake's spree waits for dusk") end
      return
    end
    s.held_for = nil
    s.budget = s.budget - tun("spree_cost")
    director.start_spree(s, owner, corp, tick, why)
  end
end

-- A supply drop now (an off-map beat): a crate of supply_parts from its headquarters by pod to the camp at war with the
-- fewest parts, landing supply_out tiles from it toward the player, marked on the map; supply_wait minutes on, if the
-- crate still stands its parts reach the camp, else nothing does. The crate holds what the player can take: its parts
-- as iron plates.
local function crate_at(s, n, surface, pos)
  local p = surface.find_non_colliding_position("iron-chest", pos, 12, 0.5)
  local sp = s.supplies and s.supplies[n]
  if not (p and sp) then return end
  local b = storage.bases[sp.base]
  local c = surface.create_entity{name = "iron-chest", position = p, force = b and b.force or "neutral"}
  if not c then return end
  c.insert{name = "iron-plate", count = math.max(1, math.floor(tun("supply_parts") / 2))}
  sp.crate, sp.at, sp.pos = c, game.tick, {p.x, p.y}
  local owner = sp.owner and game.forces[sp.owner]
  if owner then
    sp.tag = owner.add_chart_tag(surface, {position = p, text = "Supply drop", icon = {type = "item", name = "iron-chest"}})
  end
end
pods.handlers.supply = function(p, surface, pos)
  local s = storage.director
  if s then crate_at(s, p.n, surface, {pos.x, pos.y}) end
end

function director.start_supply(s, owner, tick, why)
  local corps = at_war(owner)
  local best
  for _, b in pairs(storage.bases or {}) do
    for _, corp in ipairs(corps) do
      if b.corp == corp and not b.fallen and not b.expedition and b.lander.valid and (not best or (b.parts or 0) < (best.parts or 0)) then
        best = b
      end
    end
  end
  if not best then return false end
  local surface = game.surfaces[best.surface]
  local lp = best.lander.position
  local sp = game.forces[owner].get_spawn_position(surface)
  local dx, dy = sp.x - lp.x, sp.y - lp.y
  local l = math.max(1, math.sqrt(dx * dx + dy * dy))
  local at = {lp.x + dx / l * tun("supply_out"), lp.y + dy / l * tun("supply_out")}
  s.supplies = s.supplies or {}
  s.supply_n = (s.supply_n or 0) + 1
  local n = s.supply_n
  s.supplies[n] = {base = best.id, owner = owner, sent = tick}
  s.beats = s.beats + 1
  local sent = not storage.pods_off and pods.send(surface, at, best.force, {kind = "supply", n = n})
  if not sent then crate_at(s, n, surface, at) end
  trace(string.format("supply drop %d: %d parts to camp %d by %s, landing at %.0f,%.0f (budget %.2f left; %s)", n,
    tun("supply_parts"), best.id, sent and "pod" or "crate", at[1], at[2], s.budget, why or "forced"))
  tell(owner, "lp.director-supply", shared.CORPS[best.corp].name, string.format("[gps=%.0f,%.0f,%s]", at[1], at[2], surface.name))
  return true
end

-- Its supply drops collected or lost (every minute).
function director.supplies(s, tick)
  for n, sp in pairs(s.supplies or {}) do
    if sp.at and tick - sp.at >= tun("supply_wait") * 3600 then
      local b = storage.bases[sp.base]
      local where = sp.pos and string.format("[gps=%.0f,%.0f,%s]", sp.pos[1], sp.pos[2], b and game.surfaces[b.surface].name or "nauvis") or ""
      if sp.crate and sp.crate.valid and b and not b.fallen then
        sp.crate.destroy()
        b.parts = (b.parts or 0) + tun("supply_parts")
        s.supplied = (s.supplied or 0) + 1
        trace(string.format("supply drop %d reached camp %d: %d parts", n, b.id, tun("supply_parts")))
        tell(sp.owner, "lp.director-supply-in", shared.CORPS[b.corp].name, where)
      else
        if sp.crate and sp.crate.valid then sp.crate.destroy() end
        s.supply_lost = (s.supply_lost or 0) + 1
        trace(string.format("supply drop %d lost: its crate gone before the camp took it", n))
        tell(sp.owner, "lp.director-supply-lost", b and shared.CORPS[b.corp].name or "-", where)
      end
      if sp.tag and sp.tag.valid then sp.tag.destroy() end
      s.supplies[n] = nil
    elseif not sp.at and tick - sp.sent > 5 * 3600 then
      s.supplies[n] = nil
    end
  end
end

-- A drop wave now: wave_size landings of `corp` queued at once (faction.request, kind "wave": the landing queue lands
-- them one after another, each seeing the last, APART for free), each an expedition (faction's after.wave). Told
-- first, factually; each landing tells itself as any does.
function director.start_wave(s, owner, corp, tick, why)
  local f = faction.state()
  local surface = f.surface and game.surfaces[f.surface]
  if not (surface and f.from) then return false end
  local n = tun("wave_size")
  s.waves = (s.waves or 0) + 1
  for _ = 1, n do
    faction.request(surface, f.from, {corp = corp, wave = true}, storage.quiet, "wave", {wave = s.waves})
  end
  s.beats = s.beats + 1
  s.last_spree[corp] = tick
  trace(string.format("drop wave %d: %d landings of %s (budget %.2f left; %s)", s.waves, n, corp, s.budget, why or "forced"))
  tell(owner, "lp.director-wave", shared.CORPS[corp].name, n)
  return true
end

-- Its expeditions resolved at expedition_minutes (the user's rule, 2026-11-14): one settles where its corporation has
-- room under the camp cap; else it takes the place of its corporation's weakest standing camp (fewest parts exported)
-- if it has exported more and the player has not hurt that camp in fought_minutes, that camp departing; else it
-- withdraws. Each told factually.
function director.expeditions(s, owner, tick)
  local base = director.base
  local due = tun("expedition_minutes") * 3600
  local ids = {}
  for id, b in pairs(storage.bases or {}) do
    if b.expedition and not b.fallen and b.lander.valid and tick - b.expedition.since >= due then ids[#ids + 1] = id end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local b = storage.bases[id]
    local surface = game.surfaces[b.surface]
    local where = string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, surface.name)
    local name = shared.CORPS[b.corp].name
    if faction.alive(b.corp) < faction.camps(b.corp) then
      b.expedition = nil
      s.settled = (s.settled or 0) + 1
      trace(string.format("expedition %d settles: %s has room (%d of %d camps)", id, b.corp, faction.alive(b.corp) - 1,
        faction.camps(b.corp)))
      tell(owner, "lp.director-settled", name, where)
    else
      local weakest
      for _, o in pairs(storage.bases) do
        if o.corp == b.corp and not o.expedition and not o.fallen and not o.hq and o.lander.valid
          and (not weakest or (o.exported or 0) < (weakest.exported or 0)) then weakest = o end
      end
      local fought = weakest and weakest.player_hit_at and tick - weakest.player_hit_at < tun("fought_minutes") * 3600
      if weakest and (b.exported or 0) > (weakest.exported or 0) and not fought then
        local ws = game.surfaces[weakest.surface]
        local wwhere = string.format("[gps=%d,%d,%s]", weakest.origin.x, weakest.origin.y, ws.name)
        base.depart(weakest, "replaced by expedition " .. id)
        b.expedition = nil
        s.settled, s.replaced = (s.settled or 0) + 1, (s.replaced or 0) + 1
        trace(string.format("expedition %d settles in place of camp %d (exported %d against %d)", id, weakest.id,
          b.exported or 0, weakest.exported or 0))
        tell(owner, "lp.director-departed", name, wwhere)
        tell(owner, "lp.director-settled", name, where)
      else
        base.depart(b, "expedition withdrawn")
        s.withdrawn = (s.withdrawn or 0) + 1
        trace(string.format("expedition %d withdraws: no room, and %s", id, not weakest and "no camp to replace"
          or fought and string.format("camp %d was fought lately", weakest.id)
          or string.format("exported %d, no more than camp %d's %d", b.exported or 0, weakest.id, weakest.exported or 0)))
        tell(owner, "lp.director-departed", name, where)
      end
    end
  end
end

-- A surge now: every corporation at war with `owner` (its camps standing, Synthexis apart) spree_factor times as often
-- and the cap on operations against it at once surge_add higher (ops' budget), surge_minutes; with `focused`, a focus
-- strike: targets within focus_radius of the place their camps know best focus_weight times as relevant to every camp
-- (ops' relevance), so they converge on it from their own directions.
function director.start_surge(s, owner, tick, focused, why, at)
  local corps = at_war(owner)
  if #corps == 0 then return false end
  local minutes = tun("surge_minutes")
  local till = tick + minutes * 3600
  local factor = tun("surge_factor")
  for _, corp in ipairs(corps) do
    s.tempo[corp] = {factor = factor, till = till}
    s.last_spree[corp] = tick
    for _, b in pairs(storage.bases or {}) do
      if b.corp == corp and not b.fallen and b.next_op_why == "pace" and (b.next_op or 0) > tick then
        b.next_op = tick + math.floor((b.next_op - tick) / factor)
      end
    end
  end
  s.intensity = {owner = owner, add = tun("surge_add"), till = till}
  -- Reinforcements first, by pod from each camp's headquarters (an off-map beat: war.reinforce).
  local sent = 0
  for _, b in pairs(storage.bases or {}) do
    for _, corp in ipairs(corps) do
      if b.corp == corp and not b.fallen and not b.expedition and b.lander.valid then sent = sent + war.reinforce(b, owner, tun("surge_reinforce")) end
    end
  end
  s.reinforced = (s.reinforced or 0) + sent
  at = focused and (at or focus_point(owner)) or nil
  if focused and not at then focused = false end
  s.focus = at and {owner = owner, pos = at, radius = tun("focus_radius"), weight = tun("focus_weight"), till = till} or nil
  s.phase, s.phase_till = "surge", till
  s.beats = s.beats + 1
  if focused then s.focuses = (s.focuses or 0) + 1 else s.surges = (s.surges or 0) + 1 end
  trace(string.format("%s: %s against %s %dx as often, %d more at once, for %d minutes%s (budget %.2f left; %s)",
    focused and "focus strike" or "surge", table.concat(corps, ", "), owner, factor, tun("surge_add"), minutes,
    at and string.format(", on %.0f,%.0f", at[1], at[2]) or "", s.budget, why or "forced"))
  if at then
    local surface = game.surfaces[1]
    tell(owner, "lp.director-focus", names(corps), string.format("[gps=%.0f,%.0f,%s]", at[1], at[2], surface and surface.name or "nauvis"), minutes)
  else
    tell(owner, "lp.director-surge", names(corps), minutes)
  end
  return true
end

-- A lull now: every corporation's operations against `owner` held lull_minutes (the truce standing).
function director.start_lull(s, owner, tick)
  local minutes = tun("lull_minutes") * ((tun("lull_scale") or {})[director.personality()] or 1)
  storage.truces = storage.truces or {}
  for corp in pairs(shared.CORPS) do storage.truces[corp .. "|" .. owner] = tick + minutes * 3600 end
  s.phase, s.phase_till = "lull", tick + minutes * 3600
  s.lull_from, s.lull_owner = tick, owner
  s.lulls = (s.lulls or 0) + 1
  trace(string.format("lull: every corporation's operations against %s held %d minutes", owner, minutes))
  tell(owner, "lp.director-lull", minutes)
end

-- A lull's time does not count on the ladder (stance.rung: minutes since the last raze): its clock moved on by the lull,
-- else a lull of 15 minutes bought every corporation a rung and the next peak came in desperate (the consult).
function director.end_lull(s, tick)
  local owner, from = s.lull_owner, s.lull_from
  if not (owner and from) then return end
  local held = tick - from
  for k, t in pairs(storage.last_raze or {}) do
    if k == owner or k:sub(1, #owner + 1) == owner .. "|" then storage.last_raze[k] = t + held end
  end
  s.lull_from, s.lull_owner = nil, nil
  s.ladder_paused = (s.ladder_paused or 0) + held
end

-- A spree now: `corp`'s operations against `owner` spree_factor times as often for spree_minutes.
function director.start_spree(s, owner, corp, tick, why)
  local minutes = tun("spree_minutes")
  s.tempo[corp] = {factor = tun("spree_factor"), till = tick + minutes * 3600}
  s.last_spree[corp] = tick
  -- Its kind's operations preferred for the spree (ops' prefer: Grubstake's strips and raids, Kessler-Hayashi's sieges).
  local mix = (tun("spree_mix") or {})[corp]
  s.mix = s.mix or {}
  if mix then s.mix[corp] = {till = tick + minutes * 3600, raid = mix.raid, siege = mix.siege, strip = mix.strip} end
  s.phase, s.phase_till = "spree", tick + minutes * 3600
  s.beats, s.sprees = s.beats + 1, (s.sprees or 0) + 1
  -- A spree pulls its camps' next operations in (a pace, never a hold: ops.finish's gaps, b.next_op_why).
  for _, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen and b.next_op_why == "pace" and (b.next_op or 0) > tick then
      b.next_op = tick + math.floor((b.next_op - tick) / tun("spree_factor"))
    end
  end
  trace(string.format("spree: %s's operations against %s %dx as often for %d minutes (budget %.2f left; %s)",
    corp, owner, tun("spree_factor"), minutes, s.budget, why or "forced"))
  tell(owner, "lp.director-spree", shared.CORPS[corp].name, minutes)
end

-- The debug panel's and tests' hand on it (director_gui.lua, remote director_cmd): on (steady, no grace), off, a spree
-- now (`arg` a corporation, else the one it would pick), a lull now, the budget full or empty, the beat ended. Returns
-- what it did, or why not.
function director.cmd(action, arg)
  local s = st()
  local tick = game.tick
  local owner = (shared.player_forces()[1] or {}).name
  if action == "on" then
    storage.director_force = "steady"
    s.active = true
    trace("on (forced)")
    return "on"
  elseif action == "off" then
    storage.director_force = "off"
    s.active, s.phase, s.phase_till = false, "fill", nil
    for _, t in pairs(s.tempo) do t.till = tick end
    if s.intensity then s.intensity.till = tick end
    if s.focus then s.focus.till = tick end
    for _, m in pairs(s.mix or {}) do m.till = tick end
    trace("off (forced)")
    return "off"
  elseif action == "auto" then
    storage.director_force = nil
    return "as the setting says"
  end
  if not owner then return "no player force" end
  if action == "spree" then
    local corp = arg or pick(s, owner, tick)
    if not corp or not shared.CORPS[corp] then return "no corporation at war with a camp standing" end
    director.start_spree(s, owner, corp, tick, "forced")
    return "spree: " .. corp
  elseif action == "surge" or action == "focus" then
    -- (A focus's point given, `arg` a position: tests; else the place its camps know best.)
    local at = type(arg) == "table" and {arg[1] or arg.x, arg[2] or arg.y} or nil
    if not director.start_surge(s, owner, tick, action == "focus", "forced", at) then return "no corporation at war with a camp standing" end
    return action == "focus" and (s.focus and "focus strike" or "surge (no focus known)") or "surge"
  elseif action == "wave" then
    local corp = (type(arg) == "string" and shared.CORPS[arg] and arg) or pick(s, owner, tick)
    if not corp then return "no corporation at war with a camp standing" end
    return director.start_wave(s, owner, corp, tick, "forced") and ("drop wave: " .. corp) or "no landing ground known"
  elseif action == "supply" then
    return director.start_supply(s, owner, tick, "forced") and "supply drop" or "no camp at war"
  elseif action == "collect" then
    -- (Tests and the panel: every supply drop down now collected or lost.)
    for _, sp in pairs(s.supplies or {}) do if sp.at then sp.at = tick - tun("supply_wait") * 3600 end end
    director.supplies(s, tick)
    return "supply drops resolved"
  elseif action == "resolve" then
    -- (Tests and the panel: every expedition due now.)
    for _, b in pairs(storage.bases or {}) do if b.expedition then b.expedition.since = tick - tun("expedition_minutes") * 3600 end end
    director.expeditions(s, owner, tick)
    return "expeditions resolved"
  elseif action == "lull" then
    director.start_lull(s, owner, tick)
    return "lull"
  elseif action == "fill" then
    s.budget = tun("cap")
    return "budget full"
  elseif action == "empty" then
    s.budget = 0
    return "budget empty"
  elseif action == "end" then
    if s.phase == "lull" and owner then
      for corp in pairs(shared.CORPS) do (storage.truces or {})[corp .. "|" .. owner] = tick end
      director.end_lull(s, tick)
    end
    for _, t in pairs(s.tempo) do t.till = tick end
    if s.intensity then s.intensity.till = tick end
    if s.focus then s.focus.till = tick end
    for _, m in pairs(s.mix or {}) do m.till = tick end
    s.phase, s.phase_till = "fill", nil
    trace("beat ended (forced)")
    return "beat ended"
  end
  return "unknown: " .. tostring(action)
end

-- For the panel: its tune (the priors as they stand) and its personality.
function director.tune(k) return tun(k) end

function director.state() return storage.director end

return director
