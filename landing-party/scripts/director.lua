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
  -- (A false override kept: "t and t[k] or" fell through to the default for false, and an ablation's lulls stayed on.)
  if t and t[k] ~= nil then return t[k] end
  return shared.DIRECTOR[k]
end

local function st()
  storage.director = storage.director or {budget = 0, phase = "fill", losses = {}, guns = {}, tempo = {}, beats = 0,
    last_spree = {}}
  return storage.director
end

local function trace(text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d director  %s\n", game.tick, text), true)
    shared.event("director", {text = text})
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
-- Its worth split by who razed it: by corporation (lost_by), and what of it the director's strike teams razed
-- (lost_strike: their killer one of a team's units). (Totals over whole visits did not tell steady from off in five
-- seeds, each game branching from the first beat; the teams' own share is the director's pressure, 0.2.392.)
function director.note_loss(owner, ent, cause, corp)
  -- (Every loss's worth, on or off: the calibration's measure, razed worth an hour; the consult part three.)
  local s = st()
  local v = valuemap.razed_of(ent)
  s.lost_total = s.lost_total or {}
  s.lost_total[owner] = (s.lost_total[owner] or 0) + v
  if corp then
    s.lost_by = s.lost_by or {}
    s.lost_by[corp] = (s.lost_by[corp] or 0) + v
  end
  if cause and cause.valid and cause.unit_number and s.strike_unit and s.strike_unit[cause.unit_number] then
    s.lost_strike = s.lost_strike or {}
    s.lost_strike[owner] = (s.lost_strike[owner] or 0) + v
  end
  if not s.active then return end
  table.insert(s.losses, {game.tick, owner, v})
end

-- Every building valuemap weighs, a mod's too, and every turret (valuemap.force_worth). (Until 0.2.384 the 26 names
-- above: on the user's saves 1.2 to 2.4 times less, the belts, inserters, poles and accumulators unseen; the user,
-- 2026-11-14: "We are not monitoring building amounts?")
local function worth_of(force) return valuemap.force_worth(force) end
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
-- Its random source, in storage, seeded by the map (made at its first use: the first beat is no longer drawn).
local function rng_of(s)
  if not s.rng then s.rng = {s = rng.new((game.surfaces[1] and game.surfaces[1].map_gen_settings.seed or 1) + 7919).s} end
  return s.rng
end

local function draw(s, owner)
  rng_of(s)
  local _, camps = at_war(owner)
  local w = (tun("weights_of") or {})[director.personality()] or tun("beat_weights")
  -- (A surge with one camp too: its intensity is the cap on that camp's siege tier, the consult; a focus wants two.)
  local list = camps >= 2 and {"spree", "surge", "focus", "wave", "supply"} or {"spree", "surge", "wave", "supply"}
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
  -- (While tracing, told with no player there too: the event stream records what the player would have read.)
  if f and (#f.players > 0 or storage.trace) then shared.notice(f, {key, ...}) end
end

function director.tick(tick)
  if tick % 3600 ~= 0 then return end
  local s = st()
  -- (Its state a minute, on or off, and the minute's losses on each side: the event stream.)
  if storage.trace then
    local ev = storage.ev_minute or {}
    storage.ev_minute = {}
    local r = s.read or {}
    shared.event("minute", {active = s.active or false, phase = s.phase, budget = s.budget, next_beat = s.next_beat,
      held_for = s.held_for, adapt = s.adapt, era = r.era, worth = r.worth, guns = r.guns, lost = r.lost, usual = r.usual,
      hurt = r.hurt or false, depth = r.depth, intensity = s.intensity and tick < s.intensity.till and s.intensity.add or 0,
      focus = s.focus and tick < s.focus.till and s.focus.pos or nil, losses = ev})
  end
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
  -- At least a spree's cost every beat_minutes (the calibration: one beat in 85 minutes at era 0 and 1).
  if not (storage.director_tune and storage.director_tune.fill) then
    rate = math.max(rate, d * (tun("personality")[director.personality()] or 1) * tun("spree_cost") / tun("beat_minutes"))
  end
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
  director.strikes(s, tick)
  -- Its beats: a spree, a surge or a focus strike, then a lull, then filling again; or a drop wave.
  if (s.phase == "spree" or s.phase == "surge") and tick >= s.phase_till then
    -- A lull only when earned: the beat pushed the player's losses past their usual for as long (lull_if_razed; the
    -- usual a half hour's, s.read.usual). Earned by any loss, on the start save every beat earned one, and its lulls
    -- took more of Kessler-Hayashi's own sieges than its sprees added: 511 lost at steady against 1,156 off.
    local lost_in = 0
    for _, l in ipairs(s.losses) do if l[2] == owner and l[1] >= (s.beat_from or 0) then lost_in = lost_in + l[3] end end
    local usual = (s.read and s.read.usual or 0) * (tick - (s.beat_from or tick)) / (30 * 3600)
    if not tun("lull_if_razed") or (lost_in > 0 and lost_in > usual) then
      director.start_lull(s, owner, tick, s.beat_corps)
    else
      s.phase, s.phase_till, s.next_beat = "fill", nil, nil
      s.unearned = (s.unearned or 0) + 1
      trace(string.format("no lull: the beat's losses %.0f, the player's usual for as long %.0f; filling", lost_in, usual))
    end
  elseif false then
  elseif s.phase == "lull" and tick >= s.phase_till then
    director.end_lull(s, tick)
    s.phase, s.phase_till = "fill", nil
    s.next_beat = nil
    trace(string.format("fill: budget %.2f", s.budget))
  end
  if s.phase == "fill" and not s.next_beat then
    -- (Its first a spree: drawn, a first surge at twice the cost came at minute 80.)
    s.next_beat = (s.beats or 0) == 0 and "spree" or draw(s, owner)
    -- (Chaotic: each beat held a random while past its cost, up to chaos_minutes.)
    s.hold_till = director.personality() == "chaotic" and tick + math.floor(rng.next(rng_of(s)) * tun("chaos_minutes") * 3600) or nil
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
    -- (Synthexis's waves by their effect only, the hurt reading above, which counts what they raze against the player's
    -- usual: no hold on their timing. Held for any wave out or due within a spree, against railbase_end's waves it never
    -- acted in three hours; the user, 2026-11-14: "Should a director care what synthexis does?", agreed: by its effect.
    -- Synthexis keeps its own cadence, never driven by the director, decision 2.)
    local why = string.format("era %d, worth %.0f, guns %d", era, w, guns)
    if s.next_beat == "focus" then
      -- (Two camps or more at war still: else the focus drawn is a surge after all.)
      local _, camps = at_war(owner)
      if camps < 2 then s.next_beat = "surge" end
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
      local beat = s.next_beat
      -- (Its budget kept if no corporation is at war with a camp standing: it was spent on nothing, a camp stood down.)
      if director.start_surge(s, owner, tick, beat == "focus", why) then
        s.held_for = nil
        s.budget = s.budget - cost_of(beat)
      elseif s.held_for ~= "none at war" then
        s.held_for = "none at war"
        trace("holds: no corporation at war with a camp standing (stood down, or none landed)")
      end
      return
    end
    local corp = pick(s, owner, tick)
    if not corp then
      if s.held_for ~= "none at war" then
        s.held_for = "none at war"
        trace("holds: no corporation at war with a camp standing (stood down, or none landed)")
      end
      return
    end
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
        -- (An armed camp's into its siege fund, which buys its shells: siege_tier's purse; else its parts.)
        if b.armed then b.siege_fund = (b.siege_fund or 0) + tun("supply_parts")
        else b.parts = (b.parts or 0) + tun("supply_parts") end
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
  shared.event("beat", {kind = "wave", corp = corp, n = n, wave = s.waves})
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

-- Headquarters pays the gap (ops.pay_gap, from launch): under its tempo, a camp short of units for a raid it chose is
-- sent what it lacks by pod, gap_max at most a beat. Returns whether any were sent.
ops.pay_gap = function(b, owner, gap, cap)
  local s = storage.director
  local t = s and s.active and s.tempo and s.tempo[b.corp]
  if not (t and game.tick < t.till) or b.expedition or b.fallen then return false end
  local key = t.till
  if not b.gap_paid or b.gap_paid.key ~= key then b.gap_paid = {key = key, n = 0} end
  local most = math.ceil(tun("gap_share") * (cap or 0))
  local n = math.min(gap, most - b.gap_paid.n)
  if n <= 0 then return false end
  local sent = war.reinforce(b, owner, n)
  if sent <= 0 then return false end
  b.gap_paid.n = b.gap_paid.n + sent
  s.gap_paid = (s.gap_paid or 0) + sent
  trace(string.format("gap paid: %d units by pod to camp %d (short %d of a raid it chose; %d of %d this beat)", sent, b.id, gap,
    b.gap_paid.n, most))
  return true
end

-- Its threat points as units a camp (RimWorld's): the player's worth times points_per_worth, the difficulty, the
-- personality and the adaptation, points_max at most.
local function strike_units(s, owner)
  local f = game.forces[owner]
  local w = (s.read and s.read.worth) or (f and valuemap.force_worth(f)) or 0
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  local pers = tun("personality")[director.personality()] or 1
  return math.min(tun("points_max"), math.floor(w * tun("points_per_worth") * d * pers * (s.adapt or 1)))
end
-- The player's buildings a strike team goes for (its target when its camp knows none, and each minute after).
local STRIKE_TYPES = {"assembling-machine", "furnace", "mining-drill", "electric-pole", "ammo-turret", "electric-turret",
  "fluid-turret", "radar", "lab", "roboport", "solar-panel", "accumulator", "wall", "transport-belt", "inserter"}
local STRIKE_REACH = 600
-- Its strike force (threat points, RimWorld's raid): a team of its own by pod behind one lead camp of `corps`
-- (war.strike_team), sent at a target, fighting on to the nearest of the player's buildings each minute, lifted out after
-- strike_minutes; never the camp's garrison. Its points the beat's, not a camp's. The lead: a camp with no operation out,
-- nearest the focus if there is one, else nearest the player's spawn. Its target: the focus, else the lead camp's known
-- target of the player's of most value.
local function strike(s, owner, corps, tick)
  local n = strike_units(s, owner)
  if n <= 0 then return 0 end
  local set = {}
  for _, c in ipairs(corps) do set[c] = true end
  local f = game.forces[owner]
  local at = s.focus and tick < s.focus.till and s.focus.pos
  local lead, ld, lbusy
  for _, b in pairs(storage.bases or {}) do
    if set[b.corp] and not b.fallen and not b.expedition and b.lander.valid then
      local p = at or (f and f.get_spawn_position(b.lander.surface)) or {x = 0, y = 0}
      local px, py = p.x or p[1], p.y or p[2]
      local d = (b.lander.position.x - px) ^ 2 + (b.lander.position.y - py) ^ 2
      local busy = b.op ~= nil
      if not lead or (lbusy and not busy) or (busy == lbusy and d < ld) then lead, ld, lbusy = b, d, busy end
    end
  end
  if not lead then return 0 end
  local target = at
  if not target then
    local best
    for _, t in pairs(lead.intel and lead.intel.targets or {}) do
      if t.owner == owner and t.pos and (not best or (t.value or 0) > (best.value or 0)) then best = t end
    end
    target = best and best.pos
  end
  -- (Else the player's building nearest the camp within STRIKE_REACH: the director's, not the camp's, knowledge; in
  -- scenario director the camp's targets razed, four sprees in five sent none.)
  if not target then
    local e = lead.lander.surface.find_entities_filtered{position = lead.lander.position, radius = STRIKE_REACH,
      force = owner, type = STRIKE_TYPES}
    local bd
    for _, x in ipairs(e) do
      local d = (x.position.x - lead.lander.position.x) ^ 2 + (x.position.y - lead.lander.position.y) ^ 2
      if not bd or d < bd then target, bd = {x.position.x, x.position.y}, d end
    end
  end
  if not target then
    trace(string.format("strike force: nothing of %s's within %d of camp %d; none sent", owner, STRIKE_REACH, lead.id))
    return 0
  end
  s.strike_n = (s.strike_n or 0) + 1
  local key = s.strike_n
  s.strikes = s.strikes or {}
  s.strikes[key] = {base = lead.id, owner = owner, target = {target[1] or target.x, target[2] or target.y}, units = {},
    sent = n, at = tick, till = tick + tun("strike_minutes") * 3600}
  local pods_sent = war.strike_team(lead, owner, n, key)
  s.reinforced = (s.reinforced or 0) + n
  s.points_sent = (s.points_sent or 0) + n
  s.strike_lead = lead.id
  trace(string.format("strike force %d: %d units by %d pods behind camp %d, at %.0f,%.0f for %d minutes", key, n, pods_sent,
    lead.id, s.strikes[key].target[1], s.strikes[key].target[2], tun("strike_minutes")))
  return n
end

-- Its strike teams' units as they land (war's pods.handlers.strike), sent at their target.
war.on_strike_landed = function(key, units)
  local s = storage.director
  local k = s and s.strikes and s.strikes[key]
  if not k then for _, u in ipairs(units) do if u.valid then u.destroy() end end; return end
  s.strike_landed = (s.strike_landed or 0) + #units
  s.strike_unit = s.strike_unit or {}
  for _, u in ipairs(units) do
    k.units[#k.units + 1] = u
    s.strike_unit[u.unit_number] = key
    u.commandable.set_command{type = defines.command.attack_area, destination = k.target, radius = 32,
      distraction = defines.distraction.by_anything}
  end
end

-- Each minute: its teams fight on to the nearest of the player's buildings within 80 of them; after strike_minutes, or
-- all dead, the rest lifted out.
function director.strikes(s, tick)
  for key, k in pairs(s.strikes or {}) do
    local live, cx, cy = {}, 0, 0
    for _, u in ipairs(k.units) do if u.valid then live[#live + 1] = u; cx, cy = cx + u.position.x, cy + u.position.y end end
    k.units = live
    local landed = tick - k.at > 2 * 3600
    if tick >= k.till or (landed and #live == 0) then
      -- (Its units counted in the lead camp's garrison, if any were: a team that joined it, scenario director's check.)
      local b, mine = storage.bases[k.base], {}
      for _, u in ipairs(live) do mine[u.unit_number] = true end
      for _, g in ipairs(b and b.garrison or {}) do
        if g.valid and mine[g.unit_number] then s.strike_enlisted = (s.strike_enlisted or 0) + 1 end
      end
      s.strike_lifted = (s.strike_lifted or 0) + #live
      s.strikes_over = (s.strikes_over or 0) + 1
      for _, u in ipairs(live) do u.destroy() end
      trace(string.format("strike force %d over: %d of %d lifted out", key, #live, k.sent))
      shared.event("strike_over", {key = key, left = #live, sent = k.sent})
      s.strikes[key] = nil
      for un, kk in pairs(s.strike_unit or {}) do if kk == key then s.strike_unit[un] = nil end end
    elseif #live > 0 then
      local c = {cx / #live, cy / #live}
      local surface = live[1].surface
      local near = surface.find_entities_filtered{position = c, radius = 80, force = k.owner, type = STRIKE_TYPES, limit = 40}
      local best, bd
      for _, e in ipairs(near) do
        local d = (e.position.x - c[1]) ^ 2 + (e.position.y - c[2]) ^ 2
        if not bd or d < bd then best, bd = e, d end
      end
      local dest = best and {best.position.x, best.position.y} or k.target
      for _, u in ipairs(live) do
        local cmd = u.commandable and u.commandable.command
        if not cmd or cmd.type ~= defines.command.attack_area then
          u.commandable.set_command{type = defines.command.attack_area, destination = dest, radius = 32,
            distraction = defines.distraction.by_anything}
        end
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
  -- Committed: its camps at war decide as desperate camps do for the beat (ops.committed).
  local set = {}
  for _, corp in ipairs(corps) do set[corp] = true end
  s.commit = {owner = owner, corps = set, till = till}
  -- Its strike force first, by pod from each camp's headquarters (threat points: strike_units).
  local sent = strike(s, owner, corps, tick)
  shared.event("beat", {kind = focused and "focus" or "surge", corps = corps, minutes = tun("surge_minutes"),
    strike = sent, lead = s.strike_lead, focus = s.focus and s.focus.pos or nil})
  at = focused and (at or focus_point(owner)) or nil
  if focused and not at then focused = false end
  s.focus = at and {owner = owner, pos = at, radius = tun("focus_radius"), weight = tun("focus_weight"), till = till} or nil
  s.phase, s.phase_till = "surge", till
  s.beat_from, s.beat_corps = tick, corps
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
-- `corps`: the corporations held, those of the beat that earned it (the user, 2026-11-14, agreed): the others keep
-- their own pace. Held all, on the start save the lulls took more of Kessler-Hayashi's own pressure than its sprees
-- added (the player's buildings lost: off 1,155, steady 607, chaotic 352). None given (the panel's "Lull now"): all.
function director.start_lull(s, owner, tick, corps)
  local minutes = tun("lull_minutes") * ((tun("lull_scale") or {})[director.personality()] or 1)
  storage.truces = storage.truces or {}
  local held = {}
  if corps and #corps > 0 then held = corps else for corp in pairs(shared.CORPS) do held[#held + 1] = corp end; table.sort(held) end
  for _, corp in ipairs(held) do storage.truces[corp .. "|" .. owner] = tick + minutes * 3600 end
  s.phase, s.phase_till = "lull", tick + minutes * 3600
  s.lull_from, s.lull_owner, s.lull_corps = tick, owner, held
  s.lulls = (s.lulls or 0) + 1
  shared.event("beat", {kind = "lull", minutes = minutes, corps = held})
  trace(string.format("lull: %s's operations against %s held %d minutes", table.concat(held, ", "), owner, minutes))
  tell(owner, #held > 1 and "lp.director-lull-many" or "lp.director-lull", names(held), minutes)
end

-- A lull's time does not count on the ladder (stance.rung: minutes since the last raze): its clock moved on by the lull,
-- else a lull of 15 minutes bought every corporation a rung and the next peak came in desperate (the consult).
function director.end_lull(s, tick)
  local owner, from = s.lull_owner, s.lull_from
  if not (owner and from) then return end
  local held = tick - from
  -- (The ladder's clock moved on only for the corporations held: owner|force keys.)
  local forces = {}
  for _, corp in ipairs(s.lull_corps or {}) do if shared.CORPS[corp] then forces[owner .. "|" .. shared.CORPS[corp].force] = true end end
  for k, t in pairs(storage.last_raze or {}) do
    if forces[k] or (not s.lull_corps and (k == owner or k:sub(1, #owner + 1) == owner .. "|")) then storage.last_raze[k] = t + held end
  end
  s.lull_from, s.lull_owner, s.lull_corps = nil, nil, nil
  s.ladder_paused = (s.ladder_paused or 0) + held
end

-- A spree now: `corp`'s operations against `owner` spree_factor times as often for spree_minutes.
function director.start_spree(s, owner, corp, tick, why)
  local minutes = tun("spree_minutes")
  s.tempo[corp] = {factor = tun("spree_factor"), till = tick + minutes * 3600}
  s.last_spree[corp] = tick
  -- Its intensity too (the consult: at era 0 the cap of 1 held every second operation and the siege at tier 1).
  s.intensity = {owner = owner, add = tun("spree_add"), till = tick + minutes * 3600}
  s.beat_from, s.beat_corps = tick, {corp}
  -- Its kind's operations preferred for the spree (ops' prefer: Grubstake's strips and raids, Kessler-Hayashi's sieges).
  local mix = (tun("spree_mix") or {})[corp]
  s.mix = s.mix or {}
  if mix then s.mix[corp] = {till = tick + minutes * 3600, raid = mix.raid, siege = mix.siege, strip = mix.strip} end
  s.phase, s.phase_till = "spree", tick + minutes * 3600
  s.beats, s.sprees = s.beats + 1, (s.sprees or 0) + 1
  local sent = strike(s, owner, {corp}, tick)
  shared.event("beat", {kind = "spree", corp = corp, minutes = minutes, factor = tun("spree_factor"), strike = sent,
    lead = s.strike_lead, mix = s.mix and s.mix[corp] or nil})
  -- A spree pulls its camps' next operations in (a pace, never a hold: ops.finish's gaps, b.next_op_why).
  for _, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen and b.next_op_why == "pace" and (b.next_op or 0) > tick then
      b.next_op = tick + math.floor((b.next_op - tick) / tun("spree_factor"))
    end
  end
  trace(string.format("spree: %s's operations against %s %dx as often for %d minutes, a strike force of %d by pod (budget %.2f left; %s)",
    corp, owner, tun("spree_factor"), minutes, sent, s.budget, why or "forced"))
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
    if s.commit then s.commit.till = tick end
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
    if s.commit then s.commit.till = tick end
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
