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
local pool = require("__landing-party__.scripts.pool")
local stance = require("__landing-party__.scripts.stance")
local faction = require("__landing-party__.scripts.faction")
local farm = require("__landing-party__.scripts.farm")
local rng = require("__landing-party__.scripts.rng")
local pods = require("__landing-party__.scripts.pods")
local war = require("__landing-party__.scripts.war")
local jammer = require("__landing-party__.scripts.jammer")
local rd = require("__landing-party__.scripts.rd")
local army = require("__landing-party__.scripts.army")

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
  -- (A bounty's target: who destroyed it, for its payout.)
  if s.bounty and s.bounty.entity == ent and corp then s.bounty.killer = corp end
  s.lost_total = s.lost_total or {}
  s.lost_total[owner] = (s.lost_total[owner] or 0) + v
  if corp then
    s.lost_by = s.lost_by or {}
    s.lost_by[corp] = (s.lost_by[corp] or 0) + v
  end
  if cause and cause.valid and cause.unit_number and s.strike_unit and s.strike_unit[cause.unit_number] then
    s.lost_strike = s.lost_strike or {}
    s.lost_strike[owner] = (s.lost_strike[owner] or 0) + v
    -- (Its first hit, for the warning's lead: told to first loss.)
    local key = s.strike_unit[cause.unit_number]
    local k = s.strikes and s.strikes[key]
    -- (Broken, it razes nothing more: tests.)
    -- (Broken, it razes nothing more but the guns shooting it, which it answers since 0.2.428: tests. A turret counted
    -- apart, lost_after_break_guns.)
    -- (From break_grace seconds after it broke: a tank's shell already in the air killed an assembler 83 ticks after, its
    -- command the walk home, scenario director repel.)
    if k and k.broken and game.tick > (k.broken_at or 0) + tun("break_grace") * 60 then
      if ent.type == "ammo-turret" or ent.type == "electric-turret" or ent.type == "fluid-turret" then
        s.lost_after_break_guns = (s.lost_after_break_guns or 0) + 1
      else
        s.lost_after_break = (s.lost_after_break or 0) + 1
      end
    end
    if k and not k.hit then
      k.hit = game.tick
      shared.event("strike_hit", {key = key, lead = game.tick - k.warned, pos = {ent.position.x, ent.position.y}})
      s.strike_leads = s.strike_leads or {}
      table.insert(s.strike_leads, game.tick - k.warned)
    end
  end
  -- (A building the corporation killed while its truce on `owner` held: the truce broken; a strike unit's apart. Tests.)
  if corp then
    for c, cd in pairs(shared.CORPS) do
      if cd.force == corp and (storage.truces or {})[c .. "|" .. owner] and game.tick < storage.truces[c .. "|" .. owner] then
        s.truce_lost = (s.truce_lost or 0) + 1
        local role = "other"
        if cause and cause.valid and cause.unit_number and s.strike_unit and s.strike_unit[cause.unit_number] then
          s.truce_lost_strike = (s.truce_lost_strike or 0) + 1
          role = "strike"
        elseif cause and cause.valid and cause.unit_number then
          for _, b in pairs(storage.bases or {}) do
            for _, u in ipairs(b.op and b.op.members or {}) do
              if u.valid and u.unit_number == cause.unit_number then role = "op " .. tostring(b.op.kind) end
            end
            for _, u in ipairs(b.returning or {}) do
              if u.valid and u.unit_number == cause.unit_number then role = "returning" end
            end
            for _, r in ipairs(b.raids or {}) do
              for _, u in ipairs(r.members or {}) do
                if u.valid and u.unit_number == cause.unit_number then role = role .. "+" .. tostring(r.kind) end
              end
            end
          end
        end
        -- (Who broke it, for the event stream: a strike team, an operation's squad, or another of its units.)
        if storage.trace then
          shared.event("truce_loss", {corp = c, role = role, cause = cause and cause.valid and cause.name or nil,
            pos = {math.floor(ent.position.x), math.floor(ent.position.y)},
            from = cause and cause.valid and {math.floor(cause.position.x), math.floor(cause.position.y)} or nil,
            cmd = cause and cause.valid and cause.commandable and cause.commandable.command
              and cause.commandable.command.type or nil,
            -- (Its command's own distraction, or its first step's, and what it was engaging: who ordered it.)
            dist = (function()
              local c = cause and cause.valid and cause.commandable and cause.commandable.command
              if not c then return nil end
              local d = c.distraction or (c.commands and c.commands[1] and c.commands[1].distraction)
              if not d then return "default" end
              for name, v in pairs(defines.distraction) do if v == d then return name end end
              return tostring(d)
            end)(),
            ctype = (function()
              local c = cause and cause.valid and cause.commandable and cause.commandable.command
              if c then for name, v in pairs(defines.command) do if v == c.type then return name end end end
            end)(),
            group = cause and cause.valid and cause.commandable and cause.commandable.parent_group and (function()
              local g = cause.commandable.parent_group
              local c = g.command
              if c then for name, v in pairs(defines.command) do if v == c.type then return name end end end
              return "idle"
            end)() or nil,
            steps = cause and cause.valid and cause.commandable and cause.commandable.command
              and cause.commandable.command.commands and #cause.commandable.command.commands or nil,
            engaged = cause and cause.valid and cause.commandable and cause.commandable.distraction_command
              and cause.commandable.distraction_command.type or nil})
        end
      end
    end
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

-- Its masts (the user, 2026-11-15): a camp raises one, and while it stands the player's entities of `type` within its
-- radius are held (disabled_by_script, a status in their GUI), `on` seconds of every `on` + `off`, or all along. The
-- launch jammer, Kessler-Hayashi's, at rocket silos; the blackout mast, Grubstake's, at radars (strike forces then land
-- unseen: strike's radar cover reads working radars only). Drawn only with such an entity in a camp's reach.
local MASTS = {
  jammer = {corp = "serenity", type = "rocket-silo", status = "lp.silo-jammed", radius = "jam_radius", on = "jam_on",
    off = "jam_off", minutes = "jam_minutes", cost = "jam_cost", text = "Kessler-Hayashi jammer"},
  blackout = {corp = "grubstake", type = "radar", status = "lp.radar-blacked-out", radius = "blackout_radius",
    minutes = "blackout_minutes", cost = "blackout_cost", text = "Grubstake blackout mast"},
}

-- A mast's site: its corporation's camp at war nearest one of `owner`'s entities of its type within its radius.
local function mast_site(kind, owner)
  local m = MASTS[kind]
  if stance.standing(m.corp, owner) ~= "enemy" then return nil end
  local best, bd, near
  for _, b in pairs(storage.bases or {}) do
    if b.corp == m.corp and not b.fallen and not b.expedition and b.lander and b.lander.valid then
      local lp = b.lander.position
      for _, e in ipairs(b.lander.surface.find_entities_filtered{type = m.type, force = owner, position = lp,
        radius = tun(m.radius)}) do
        local d = e.name ~= "lp-command-relay" and (e.position.x - lp.x) ^ 2 + (e.position.y - lp.y) ^ 2
        if d and (not bd or d < bd) then best, bd, near = b, d, e end
      end
    end
  end
  return best, near
end

local function draw(s, owner)
  rng_of(s)
  local _, camps = at_war(owner)
  local w = (tun("weights_of") or {})[director.personality()] or tun("beat_weights")
  -- (A surge with one camp too: its intensity is the cap on that camp's siege tier, the consult; a focus wants two.)
  local list = camps >= 2 and {"spree", "surge", "focus", "wave", "supply", "climax"} or {"spree", "surge", "wave", "supply",
    "climax"}
  -- (A mast only with its target in a camp's reach and none of its kind up already.)
  for _, kind in ipairs({"jammer", "blackout"}) do
    if not (s.masts and s.masts[kind]) and mast_site(kind, owner) then list[#list + 1] = kind end
  end
  if not s.bounty and director.bounty_target(owner) then list[#list + 1] = "bounty" end
  list[#list + 1] = "research"
  -- (A joint strike with two corporations at war; a contract or a rotation, one at a time.)
  if #director.joint_corps(owner) >= 2 then list[#list + 1] = "joint" end
  if not (s.contract and game.tick < s.contract.till) then list[#list + 1] = "contract" end
  if not s.rotation then list[#list + 1] = "rotation" end
  local total = 0
  for _, k in ipairs(list) do total = total + (w[k] or 0) end
  local x = rng.next(s.rng) * total
  for _, k in ipairs(list) do
    x = x - (w[k] or 0)
    if x < 0 then return k end
  end
  return list[#list]
end

-- Whether a told beat still waits out its forecast (forecast_minutes from the telling; untold, it waits to be told).
local function kind_told_wait(s, tick)
  if not s.next_beat then return false end
  return not s.told_at or tick < s.told_at + tun("forecast_minutes") * 3600
end

local function cost_of(beat)
  if beat == "climax" then return tun("cap") end
  return tun((beat == "surge" and "surge_cost") or (beat == "focus" and "focus_cost") or (beat == "wave" and "wave_cost")
    or (beat == "supply" and "supply_cost") or (MASTS[beat] and MASTS[beat].cost) or (beat == "bounty" and "bounty_cost") or (beat == "research" and "research_cost")
    or (beat == "joint" and "joint_cost") or (beat == "contract" and "contract_cost") or (beat == "rotation" and "rotation_cost")
    or "spree_cost")
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
  -- (Told or held, counted: every beat told at default settings, scenario director's check.)
  if f and (#f.players > 0 or storage.trace) then
    local s = st()
    if shared.notice(f, {key, ...}) then
      s.tell_told = (s.tell_told or 0) + 1
      s.tell_keys = s.tell_keys or {}
      s.tell_keys[key] = (s.tell_keys[key] or 0) + 1
    else s.tell_held = (s.tell_held or 0) + 1; s.tell_held_keys = s.tell_held_keys or {}; s.tell_held_keys[key] = true end
  end
end

local morale, walking, send_home, masts_tick, bounty_tick, strike_mix -- (below: after walk_back, start_mast and start_bounty)

function director.tick(tick)
  if tick % 300 == 150 and storage.director then morale(storage.director, tick) end
  if tick % 3600 == 1800 and storage.director then
    director.contract_tick(storage.director, tick)
    director.rotation_tick(storage.director, tick)
  end
  if tick % 60 == 45 and storage.director then walking(storage.director) end
  -- (A radar's warning on the second, not on the director's minute: 0.2.456. Checked by director.strikes alone, once a
  -- minute, a warning at the edge of a radar's reach (30 s) came as the pods landed, 0 s ahead: the playtest of
  -- 2026-11-18, "Didn't see the radar warning", deathworld10x's first strike, its pods seen by a command relay.)
  if tick % 60 == 15 and storage.director and storage.director.strikes then
    for _, k in pairs(storage.director.strikes) do
      if k.spot and not k.seen and tick >= k.spot.at then director.spot(storage.director, k) end
    end
  end
  if tick % 60 == 30 and storage.director and storage.director.masts then masts_tick(storage.director, tick) end
  if tick % 60 == 30 and storage.director and storage.director.bounty then bounty_tick(storage.director, tick) end
  if tick % 300 == 200 and storage.director and storage.director.salvage then director.salvage_tick(storage.director) end
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
  -- (The cost of the beat drawn, since 0.2.394: a spree's alone, steady's dearer beats, a climax of 4 and a focus of 3,
  -- took 80 and 60 minutes to afford, and in the campaign gentle's sprees razed as much as steady or more.)
  if not (storage.director_tune and storage.director_tune.fill) then
    local cost = s.next_beat and cost_of(s.next_beat) or tun("spree_cost")
    rate = math.max(rate, d * (tun("personality")[director.personality()] or 1) * cost / tun("beat_minutes"))
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
  if s.focus_tag and tick >= (s.focus_tag_till or 0) then
    if s.focus_tag.valid then s.focus_tag.destroy() end
    s.focus_tag, s.focus_tag_till = nil, nil
  end
  -- Its beats: a spree, a surge or a focus strike, then a lull, then filling again; or a drop wave.
  if (s.phase == "spree" or s.phase == "surge") and tick >= s.phase_till then
    -- A lull only when earned: the beat pushed the player's losses past their usual for as long (lull_if_razed; the
    -- usual a half hour's, s.read.usual). Earned by any loss, on the start save every beat earned one, and its lulls
    -- took more of Kessler-Hayashi's own sieges than its sprees added: 511 lost at steady against 1,156 off.
    local lost_in = 0
    for _, l in ipairs(s.losses) do if l[2] == owner and l[1] >= (s.beat_from or 0) then lost_in = lost_in + l[3] end end
    local usual = (s.read and s.read.usual or 0) * (tick - (s.beat_from or tick)) / (30 * 3600)
    -- (A lull after every beat since 0.2.393, its length the beat's cost to the player: lull_floor unearned, lull_minutes
    -- times the losses over the usual earned, lull_max at most and after a climax. Fable's fun consult: recovery the
    -- player can learn and plan around.)
    local minutes
    if s.climax_beat then minutes = tun("lull_max")
    elseif not tun("lull_if_razed") or (lost_in > 0 and lost_in > usual) then
      minutes = usual > 0 and math.min(tun("lull_max"), math.max(tun("lull_minutes"), tun("lull_minutes") * lost_in / usual))
        or tun("lull_minutes")
    else
      minutes = tun("lull_floor")
      s.unearned = (s.unearned or 0) + 1
      trace(string.format("short lull: the beat's losses %.0f, the player's usual for as long %.0f", lost_in, usual))
    end
    s.climax_beat = nil
    director.start_lull(s, owner, tick, s.beat_corps, minutes)
  elseif false then
  elseif s.phase == "lull" and tick >= s.phase_till then
    director.end_lull(s, tick)
    s.phase, s.phase_till = "fill", nil
    trace(string.format("fill: budget %.2f", s.budget))
  end
  -- (Drawn and told as the lull begins, the lull the forecast's lead: drawn after it, the forecast's wait came on top of
  -- every lull and a run's beats fell from 6 to 2, scenario director, 0.2.393.)
  if (s.phase == "fill" or s.phase == "lull") and not s.next_beat then
    -- (Its first a spree: drawn, a first surge at twice the cost came at minute 80.)
    s.next_beat = (s.beats or 0) == 0 and "spree" or draw(s, owner)
    -- (Steady's cycle: every climax_every-th beat the climax.)
    if director.personality() == "steady" and ((s.beats or 0) + 1) % tun("climax_every") == 0 then s.next_beat = "climax" end
    s.next_corp, s.told_at = nil, nil
    -- (Chaotic: each beat held a random while past its cost, up to chaos_minutes.)
    s.hold_till = director.personality() == "chaotic" and tick + math.floor(rng.next(rng_of(s)) * tun("chaos_minutes") * 3600) or nil
    trace(string.format("next beat: %s (costs %d; budget %.2f)%s", s.next_beat, cost_of(s.next_beat), s.budget,
      s.hold_till and string.format(", held till %d min", math.floor(s.hold_till / 3600)) or ""))
  end
  -- The beat drawn and its corporation, fixed forecast_minutes at least before it comes (a camp at war standing). Not
  -- told since 0.2.405 (the user, 2026-11-15, on RimWorld: the storyteller is never heard, a threat is told when it
  -- arrives); kept as the beat's lead time and its event.
  if (s.phase == "fill" or s.phase == "lull") and s.next_beat and not s.told_at and director.personality() ~= "chaotic" then
    local kind = s.next_beat
    -- (In a lull its truce makes no corporation at war: the held ones are named, those with a camp standing.)
    local held = {}
    if s.phase == "lull" then
      for _, c in ipairs(s.lull_corps or {}) do if c ~= "biotech" and faction.alive(c) > 0 then held[#held + 1] = c end end
    end
    if kind == "spree" or kind == "wave" then
      s.next_corp = pick(s, owner, tick)
      if not s.next_corp and #held > 0 then
        table.sort(held, function(a, b) return (s.last_spree[a] or -math.huge) < (s.last_spree[b] or -math.huge) end)
        s.next_corp = held[1]
      end
      if s.next_corp then
        s.told_at = tick
      end
    elseif kind == "surge" or kind == "focus" or kind == "climax" then
      local corps = at_war(owner)
      if #corps == 0 then table.sort(held); corps = held end
      if #corps > 0 then
        s.told_at = tick
      end
    else s.told_at = tick end
    if s.told_at then
      s.forecasts = (s.forecasts or 0) + 1
      shared.event("forecast", {kind = kind, corp = s.next_corp})
    end
  end
  if s.phase == "fill" and director.personality() ~= "chaotic" and kind_told_wait(s, tick) then return end
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
    if s.next_beat == "research" then
      s.phase, s.next_beat = "fill", nil
      if director.start_research(s, owner, tick, why) then s.budget = s.budget - tun("research_cost") end
      return
    end
    if s.next_beat == "joint" or s.next_beat == "contract" or s.next_beat == "rotation" then
      local beat = s.next_beat
      s.phase, s.next_beat = "fill", nil
      if director["start_" .. beat](s, owner, tick, why) then s.budget = s.budget - tun(beat .. "_cost") end
      return
    end
    if s.next_beat == "bounty" then
      s.phase, s.next_beat = "fill", nil
      if director.start_bounty(s, owner, tick, why) then s.budget = s.budget - tun("bounty_cost") end
      return
    end
    if MASTS[s.next_beat] then
      local kind = s.next_beat
      s.phase, s.next_beat = "fill", nil
      if director.start_mast(s, kind, owner, tick, why) then s.budget = s.budget - tun(MASTS[kind].cost) end
      return
    end
    if s.next_beat == "supply" then
      s.held_for = nil
      s.budget = s.budget - tun("supply_cost")
      director.start_supply(s, owner, tick, why)
      s.phase, s.next_beat = "fill", nil
      return
    end
    -- (A forecast named a corporation that can no longer come: told again with the one that will, and waited out again;
    -- a campaign's forecast named Grubstake and Serenity came, 0.2.394.)
    if (s.next_beat == "wave" or s.next_beat == "spree") and s.next_corp and director.personality() ~= "chaotic"
      and not (faction.alive(s.next_corp) > 0 and stance.standing(s.next_corp, owner) == "enemy") then
      local again = pick(s, owner, tick)
      if again and again ~= s.next_corp then
        trace(string.format("forecast corrected: %s, not %s", again, s.next_corp))
        s.next_corp, s.told_at = nil, nil
        s.corrected = (s.corrected or 0) + 1
        return
      end
    end
    if s.next_beat == "wave" then
      local corp = s.next_corp and faction.alive(s.next_corp) > 0 and s.next_corp or pick(s, owner, tick)
      if not corp then return end
      s.held_for = nil
      s.budget = s.budget - tun("wave_cost")
      director.start_wave(s, owner, corp, tick, why)
      s.phase, s.next_beat = "fill", nil
      return
    end
    if s.next_beat == "climax" then
      if director.start_surge(s, owner, tick, true, why, nil, true) then
        s.held_for = nil
        s.budget = s.budget - cost_of("climax")
      elseif s.held_for ~= "none at war" then
        s.held_for = "none at war"
        trace("holds: no corporation at war with a camp standing (stood down, or none landed)")
      end
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
    local corp = s.next_corp and faction.alive(s.next_corp) > 0 and stance.standing(s.next_corp, owner) == "enemy"
      and s.next_corp or pick(s, owner, tick)
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

-- A mast now: raised by the camp 20 tiles toward its target, a chart tag on it while it stands (a thing in the world,
-- not a message). masts_tick holds its targets.
function director.start_mast(s, kind, owner, tick, why)
  local m = MASTS[kind]
  local b, near = mast_site(kind, owner)
  if not b then return false end
  local lp, sp = b.lander.position, near.position
  local dx, dy = sp.x - lp.x, sp.y - lp.y
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local mast = jammer.raise(b.lander.surface, {lp.x + dx / len * 20, lp.y + dy / len * 20}, b.force)
  if not mast then return false end
  local f = game.forces[owner]
  s.masts = s.masts or {}
  s.masts[kind] = {mast = mast, owner = owner, base = b.id, from = tick, till = tick + tun(m.minutes) * 3600, held = {},
    tag = f and f.add_chart_tag(mast.surface, {position = mast.position, text = m.text,
      icon = {type = "virtual", name = "signal-alert"}})}
  s.mast_count = s.mast_count or {}
  s.mast_count[kind] = (s.mast_count[kind] or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = kind, corps = {m.corp}, minutes = tun(m.minutes), pos = {mast.position.x, mast.position.y}})
  trace(string.format("%s: camp %d's mast at %.0f,%.0f, %s's %s within %d held%s, %d minutes (%s)", kind, b.id,
    mast.position.x, mast.position.y, owner, m.type, tun(m.radius), m.on and string.format(" %d s in every %d", tun(m.on),
    tun(m.on) + tun(m.off)) or "", tun(m.minutes), why or "forced"))
  return true
end

local function mast_release(j)
  for _, e in pairs(j.held) do
    if e.valid then e.disabled_by_script = false; e.custom_status = nil end
  end
  j.held = {}
end

-- Every second while a mast stands: its targets in reach held (its on-seconds of each cycle, or all along), a status in
-- their GUI; over at its minutes (the mast lowered) or when the player destroys it.
masts_tick = function(s, tick)
  for kind, j in pairs(s.masts) do
    local m = MASTS[kind]
    if not j.mast.valid or tick >= j.till then
      mast_release(j)
      if j.tag and j.tag.valid then j.tag.destroy() end
      local killed = not j.mast.valid
      if j.mast.valid then jammer.lower(j.mast) end
      if killed then s.masts_killed = s.masts_killed or {}; s.masts_killed[kind] = (s.masts_killed[kind] or 0) + 1 end
      shared.event("mast_over", {kind = kind, why = killed and "destroyed" or "done", held = j.jammed or 0})
      trace(string.format("%s over: %s, %d entity-seconds held", kind, killed and "destroyed" or "its time", j.jammed or 0))
      s.masts[kind] = nil
    else
      local on = not m.on or ((tick - j.from) / 60) % (tun(m.on) + tun(m.off)) < tun(m.on)
      if on then
        for _, e in ipairs(j.mast.surface.find_entities_filtered{type = m.type, force = j.owner, position = j.mast.position,
          radius = tun(m.radius)}) do
          -- (Not the command relay, a radar by prototype (player.lua): the blackout took the player's army offline with
          -- it, no reason shown; the army consult, 2026-11-16.)
          if e.name == "lp-command-relay" then goto next_entity end
          j.held[e.unit_number] = e
          e.disabled_by_script = true
          e.custom_status = {diode = defines.entity_status_diode.red, label = {m.status}}
          j.jammed = (j.jammed or 0) + 1
          ::next_entity::
        end
      else
        mast_release(j)
      end
    end
  end
end

-- A research breakthrough now: a corporation at war (the one picked, as a spree's) buys its next node, lent the fund for it
-- and the fund then as it was. Nothing told: its new units are the tell.
function director.start_research(s, owner, tick, why)
  local corp = pick(s, owner, tick)
  if not corp or corp == "biotech" then return false end
  local t = rd.state(corp)
  local before = t.fund
  t.fund = before + 1e6
  local id = rd.choose(corp)
  t.fund = before
  if not id then return false end
  s.researched = (s.researched or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = "research", corp = corp, node = id})
  trace(string.format("research breakthrough: %s bought %s at once (%s)", corp, id, why or "forced"))
  return id
end

-- The corporations at war with `owner` with a camp standing that could lead a strike (Synthexis apart), in their order.
function director.joint_corps(owner)
  local out = {}
  for _, c in ipairs(at_war(owner)) do
    if shared.CORPS[c] then
      for _, b in pairs(storage.bases or {}) do
        if b.corp == c and not b.fallen and not b.expedition and b.lander.valid then out[#out + 1] = c; break end
      end
    end
  end
  return out
end
-- A joint strike: the first corporation's force chooses the target (its motive), the second's goes at it, both landing
-- together. (`want` "joint" on the second: past a power strike's hold, which its own first set.)
function director.start_joint(s, owner, tick, why)
  local corps = director.joint_corps(owner)
  if #corps < 2 then return false end
  local share = tun("joint_share")
  local a = director.strike_force(s, owner, {corps[1]}, tick, share)
  if a <= 0 then return false end
  local k1 = s.strikes[s.strike_n]
  local b = director.strike_force(s, owner, {corps[2]}, tick, share, nil, {k1.target[1], k1.target[2]}, "joint")
  local k2 = b > 0 and s.strikes[s.strike_n] or nil
  k1.joint = true
  if k2 then k2.joint, k2.pods_at = true, k1.pods_at end
  s.joints = (s.joints or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = "joint", corps = {corps[1], corps[2]}, strike = a + b, pos = k1.target})
  trace(string.format("joint strike: %s %d and %s %d at %.0f,%.0f, landing together (%s)", corps[1], a, corps[2], b,
    k1.target[1], k1.target[2], why or "forced"))
  return true
end
-- An export contract: one corporation at war (pick's), its camps' operations against the player held (ops), an export
-- beam at each camp's pad every minute, a tag at each; at its end, contract_parts an era to each camp not hit since.
function director.start_contract(s, owner, tick, why)
  if s.contract and tick < s.contract.till then return false end
  local corp = pick(s, owner, tick)
  if not corp or not shared.CORPS[corp] then return false end
  local f = game.forces[owner]
  local c = {corp = corp, owner = owner, at = tick, till = tick + tun("contract_minutes") * 3600, tags = {}, camps = {}}
  for id, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen and b.lander.valid then
      c.camps[#c.camps + 1] = id
      if f then
        c.tags[#c.tags + 1] = f.add_chart_tag(b.lander.surface, {position = b.lander.position,
          text = shared.CORPS[corp].name .. " export contract", icon = {type = "virtual", name = shared.CORPS[corp].icon}})
      end
    end
  end
  if #c.camps == 0 then return false end
  s.contract = c
  s.contracts = (s.contracts or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = "contract", corp = corp, camps = #c.camps, minutes = tun("contract_minutes")})
  trace(string.format("export contract: %s's %d camps hold off %s and export for %d minutes (%s)", corp, #c.camps, owner,
    tun("contract_minutes"), why or "forced"))
  return true
end
local function pad_of(b)
  for _, x in ipairs(b.launchpads or {}) do if x.valid then return x end end
  return b.lander
end
local function beam(e)
  rendering.draw_line{from = e, to = {e.position.x, e.position.y - 60}, surface = e.surface,
    color = {0.6, 0.85, 1, 0.8}, width = 6, time_to_live = 90}
end
local function contract_tick(s, tick)
  local c = s.contract
  if not c or c.done then return end
  if tick < c.till then
    for _, id in ipairs(c.camps) do
      local b = storage.bases[id]
      if b and not b.fallen and b.lander.valid then beam(pad_of(b)) end
    end
    return
  end
  local era = math.max(1, (s.read and s.read.era) or 1)
  local paid, camps = 0, 0
  for _, id in ipairs(c.camps) do
    local b = storage.bases[id]
    if b and not b.fallen and b.lander.valid and not (b.player_hit_at and b.player_hit_at >= c.at) then
      b.parts = (b.parts or 0) + tun("contract_parts") * era
      paid, camps = paid + tun("contract_parts") * era, camps + 1
    end
  end
  for _, t in ipairs(c.tags) do if t.valid then t.destroy() end end
  c.done = true
  s.contract_paid = (s.contract_paid or 0) + paid
  shared.event("contract_over", {corp = c.corp, paid = paid, camps = camps, of = #c.camps})
  trace(string.format("export contract over: %s, %d parts to %d of %d camps (the others hit)", c.corp, paid, camps, #c.camps))
end
-- A garrison rotation: the camp at war nearest the player's spawn ships its garrison out (all but pool.GUARD), a beam a
-- unit; rotation_minutes later as many come back by pod (war.rotation_in). Tagged at the camp while it lasts.
function director.start_rotation(s, owner, tick, why)
  if s.rotation then return false end
  local f = game.forces[owner]
  local set = {}
  for _, c in ipairs(director.joint_corps(owner)) do set[c] = true end
  local sp = f and f.get_spawn_position(game.surfaces[1]) or {x = 0, y = 0}
  local best, bd
  for _, b in pairs(storage.bases or {}) do
    if set[b.corp] and not b.fallen and not b.op and b.lander.valid and pool.home(b) > pool.GUARD then
      local d = (b.lander.position.x - sp.x) ^ 2 + (b.lander.position.y - sp.y) ^ 2
      if not bd or d < bd then best, bd = b, d end
    end
  end
  if not best then return false end
  local out = pool.take(best, tun("rotation_max"), pool.GUARD)
  local p = pad_of(best)
  for _, u in ipairs(out) do if u.valid then pool.discharge(best, u.unit_number); u.destroy() end end
  beam(p)
  local tag = f and f.add_chart_tag(best.lander.surface, {position = best.lander.position,
    text = shared.CORPS[best.corp].name .. " garrison rotating", icon = {type = "virtual", name = shared.CORPS[best.corp].icon}})
  s.rotation = {base = best.id, n = #out, back = tick + tun("rotation_minutes") * 3600, tag = tag}
  s.rotations = (s.rotations or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = "rotation", corp = best.corp, base = best.id, n = #out})
  trace(string.format("garrison rotation: camp %d's %d units shipped out, back in %d minutes (%s)", best.id, #out,
    tun("rotation_minutes"), why or "forced"))
  return true
end
local function rotation_tick(s, tick)
  local r = s.rotation
  if not r or tick < r.back then return end
  local b = storage.bases[r.base]
  local pods_sent = b and war.rotation_in(b, r.n) or 0
  if r.tag and r.tag.valid then r.tag.destroy() end
  s.rotation = nil
  s.rotated_back = (s.rotated_back or 0) + (pods_sent > 0 and r.n or 0)
  shared.event("rotation_back", {base = r.base, n = r.n, pods = pods_sent})
  trace(string.format("garrison rotation over: %d units back to camp %d by %d pods", r.n, r.base, pods_sent))
end
director.contract_tick, director.rotation_tick = contract_tick, rotation_tick

-- The bounty's target: of the player's buildings its camps at war know, the one of most worth (valuemap) among those
-- that matter: production and its infrastructure, not poles, belts or walls (a pole was priced in all five railbase_end
-- visits: the camps' target values ranked a big pole first, 0.2.411).
local BOUNTY_TYPES = {"assembling-machine", "furnace", "lab", "rocket-silo", "roboport", "radar", "beacon", "reactor",
  "generator", "mining-drill", "boiler", "accumulator", "solar-panel"}
function director.bounty_target(owner)
  local set = {}
  for _, c in ipairs(at_war(owner)) do set[c] = true end
  local surface = game.surfaces[1]
  local best, bv
  for _, b in pairs(storage.bases or {}) do
    if set[b.corp] and not b.fallen then
      for _, t in pairs(b.intel and b.intel.targets or {}) do
        if t.owner == owner and t.pos then
          for _, e in ipairs(surface.find_entities_filtered{position = t.pos, radius = 3, force = owner, type = BOUNTY_TYPES}) do
            local v = valuemap.worth_of(e)
            if not bv or v > bv then best, bv = e, v end
          end
        end
      end
    end
  end
  return best
end

-- A bounty now: its target tagged on the player's map (a price on it, not a message), every camp's preferred target.
function director.start_bounty(s, owner, tick, why)
  local e = director.bounty_target(owner)
  if not e then return false end
  local f = game.forces[owner]
  local corps = at_war(owner)
  local era = math.max(1, (s.read and s.read.era) or 1)
  local parts = tun("bounty_parts") * era
  -- Named in the world (the tag says whose bounty), paid to the camp whose units destroy it, a strike force sent at it
  -- (0.2.416; a tag reading "Bounty" alone said nothing of who, and one camp's raid was no convergence). Its price off
  -- the tag since 0.2.417 (the user: "Im just not sure what the payout being visible to the player brings").
  s.bounty = {owner = owner, pos = {e.position.x, e.position.y}, entity = e, weight = tun("bounty_weight"),
    till = tick + tun("bounty_minutes") * 3600, parts = parts, corps = corps, tag = f and f.add_chart_tag(e.surface,
      {position = e.position, text = string.format("%s bounty", names(corps)),
      icon = {type = "virtual", name = "signal-alert"}})}
  s.bounty.strike = director.strike_force(s, owner, corps, tick, 1, nil, s.bounty.pos)
  s.bounties = (s.bounties or 0) + 1
  s.beats = s.beats + 1
  shared.event("beat", {kind = "bounty", minutes = tun("bounty_minutes"), pos = s.bounty.pos, target = e.name})
  trace(string.format("bounty: %s at %.0f,%.0f, %dx as relevant to every camp for %d minutes (%s)", e.name, e.position.x,
    e.position.y, tun("bounty_weight"), tun("bounty_minutes"), why or "forced"))
  return true
end

bounty_tick = function(s, tick)
  local bo = s.bounty
  if bo.entity.valid and tick < bo.till then return end
  local taken = not bo.entity.valid
  if taken then s.bounties_taken = (s.bounties_taken or 0) + 1 end
  -- Paid: to the camp of the corporation whose units destroyed it nearest it (director.note_loss records the killer).
  if taken and bo.killer then
    local best, bd
    for _, b in pairs(storage.bases or {}) do
      if shared.CORPS[b.corp] and shared.CORPS[b.corp].force == bo.killer and not b.fallen and b.lander and b.lander.valid then
        local d = (b.lander.position.x - bo.pos[1]) ^ 2 + (b.lander.position.y - bo.pos[2]) ^ 2
        if not bd or d < bd then best, bd = b, d end
      end
    end
    if best then
      best.parts = best.parts + bo.parts
      s.bounty_paid = (s.bounty_paid or 0) + bo.parts
      trace(string.format("bounty paid: %d parts to camp %d (%s)", bo.parts, best.id, best.corp))
    end
  end
  if bo.tag and bo.tag.valid then bo.tag.destroy() end
  shared.event("bounty_over", {why = taken and "taken" or "held"})
  trace(string.format("bounty over: %s", taken and "its target destroyed" or "held to its time"))
  s.bounty = nil
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
  tell(owner, "lp.director-wave", shared.CORPS[corp].name, n, string.format("[gps=%.0f,%.0f,%s]", f.from.x, f.from.y,
    surface.name))
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

-- Its threat points as units a camp (RimWorld's): the player's worth times points_per_worth and the personality,
-- points_max at most; then the difficulty and the adaptation.
local function strike_units(s, owner)
  local f = game.forces[owner]
  local w = (s.read and s.read.worth) or (f and valuemap.force_worth(f)) or 0
  local d = shared.DIFFICULTY[shared.setting("lp-difficulty", "normal")] or 1
  local pers = tun("personality")[director.personality()] or 1
  -- (Difficulty and adaptation after the cap since 0.2.420: on any established base the worth term passed the cap and
  -- easy, hard and very hard all sent 40, adaptation never counting; railbase_end's worth gave 103 before it.)
  local base = math.min(tun("points_max"), w * tun("points_per_worth") * pers)
  return math.floor(base * d * (s.adapt or 1))
end
-- The player's buildings a strike team goes for (its target when its camp knows none, and each minute after).
-- (Buildings that matter, and the guns placed to be shot at: no walls, belts, inserters or poles, which a team chewed
-- one at a time, 138 rails for 16 of worth on railbase_end, 0.2.392; walls in its way still fall, its path's.)
local STRIKE_TYPES = {"assembling-machine", "furnace", "mining-drill", "ammo-turret", "electric-turret", "fluid-turret",
  "radar", "lab", "roboport", "solar-panel", "accumulator", "generator", "boiler", "reactor", "beacon", "rocket-silo"}
local STRIKE_REACH = 600

-- Its target by motive (shared.DIRECTOR's strike_kinds): the types of each kind this game has (fusion's with Space Age).
local KIND_TYPES
local function kind_types(kind)
  if not KIND_TYPES then
    local have = {}
    for _, p in pairs(prototypes.entity) do have[p.type] = true end
    KIND_TYPES = {}
    for k, list in pairs(shared.DIRECTOR.strike_kinds) do
      KIND_TYPES[k] = {}
      for _, t in ipairs(list) do if have[t] then table.insert(KIND_TYPES[k], t) end end
    end
  end
  return KIND_TYPES[kind] or {}
end
-- The densest cluster of `kind` among the strike_candidates of the player's nearest `from`: its entity, or nil. Water: a
-- pump with a boiler within strike_cluster (one whose water boils).
local function kind_target(surface, owner, kind, from)
  local names = shared.DIRECTOR.strike_kind_names[kind]
  local types = not names and kind_types(kind) or nil
  if names then
    local have = {}
    for _, nm in ipairs(names) do if prototypes.entity[nm] then have[#have + 1] = nm end end
    names = have
    if #names == 0 then return nil end
  elseif #types == 0 then return nil end
  local function filt(t) t.force = owner; if names then t.name = names else t.type = types end; return t end
  local near = {}
  local cap = tun("strike_candidates")
  for _, e in ipairs(surface.find_entities_filtered(filt{})) do
    local d = (e.position.x - from.x) ^ 2 + (e.position.y - from.y) ^ 2
    if #near < cap or d < near[#near].d then
      local i = #near + 1
      while i > 1 and near[i - 1].d > d do i = i - 1 end
      table.insert(near, i, {e = e, d = d})
      if #near > cap then near[#near] = nil end
    end
  end
  local r = tun("strike_cluster")
  local best, bn
  for _, c in ipairs(near) do
    local n = surface.count_entities_filtered(filt{position = c.e.position, radius = r})
    if kind == "water" and surface.count_entities_filtered{position = c.e.position, radius = r, force = owner,
      type = "boiler", limit = 1} == 0 then n = 0 end
    if n > 0 and (not bn or n > bn) then best, bn = c.e, n end
  end
  return best
end
-- Its grudges (retaliation): the player's guns that killed its corporation's units, by unit_number, each its count
-- within grudge_minutes of the last (control.lua, on_entity_died).
local GRUDGE_TYPES = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true,
  ["artillery-turret"] = true, ["artillery-wagon"] = true, unit = true}  -- (unit: the player's army's, 0.2.420)
function director.note_unit_loss(force_name, cause)
  if not (cause and cause.valid and cause.unit_number and GRUDGE_TYPES[cause.type]) then return end
  if not shared.is_player_force(cause.force) then return end
  local corp
  for c, cd in pairs(shared.CORPS) do if cd.force == force_name then corp = c end end
  if not corp then return end
  local s = st()
  s.grudge = s.grudge or {}
  s.grudge[corp] = s.grudge[corp] or {}
  local g = s.grudge[corp][cause.unit_number]
  if not g or game.tick - g.last > tun("grudge_minutes") * 3600 then
    g = {n = 0, entity = cause, owner = cause.force.name}
    s.grudge[corp][cause.unit_number] = g
  end
  g.n, g.last = g.n + 1, game.tick
end
-- The gun whose cluster (its kills and those of the guns within grudge_cluster) killed most of `corp`'s units against
-- `owner`, grudge_kills at least, still standing (stale ones dropped). The player's army's units: their nearest
-- barracks, else the unit itself.
local function grudge_target(s, corp, owner)
  local live = {}
  for un, g in pairs(s.grudge and s.grudge[corp] or {}) do
    if not g.entity.valid or game.tick - g.last > tun("grudge_minutes") * 3600 then s.grudge[corp][un] = nil
    elseif g.owner == owner then live[#live + 1] = g end
  end
  table.sort(live, function(a, b) return a.entity.unit_number < b.entity.unit_number end)
  local r2 = tun("grudge_cluster") ^ 2
  local best, bn
  for _, g in ipairs(live) do
    local p, n = g.entity.position, 0
    for _, h in ipairs(live) do
      local q = h.entity.position
      if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 <= r2 then n = n + h.n end
    end
    if n >= tun("grudge_kills") and (not bn or n > bn) then best, bn = g, n end
  end
  if not best then return nil end
  if best.entity.type == "unit" then
    local e = best.entity
    local bar = e.surface.find_entities_filtered{name = "lp-barracks", force = owner, position = e.position, radius = 400}
    local bb, bd
    for _, x in ipairs(bar) do
      local d = (x.position.x - e.position.x) ^ 2 + (x.position.y - e.position.y) ^ 2
      if not bd or d < bd then bb, bd = x, d end
    end
    return bb or e
  end
  return best.entity
end
-- A player there in person: a character on `surface`, not in the remote view.
local function in_person(f, surface)
  for _, p in pairs(f.connected_players) do
    if p.character and p.physical_surface == surface and p.controller_type == defines.controllers.character then return true end
  end
  return false
end
-- Its pods' spot: within strike_land of the target, on three rings of 16, where the fewest of the player's turrets reach
-- (each its prototype's range, +4), the nearest such; land, not water.
local TURRET_TYPES = {"ammo-turret", "electric-turret", "fluid-turret"}
local REACH = {}
local function landing_spot(surface, owner, tx, ty)
  local land = tun("strike_land")
  local guns = {}
  for _, t in ipairs(surface.find_entities_filtered{position = {tx, ty}, radius = land + 60, force = owner,
    type = TURRET_TYPES}) do
    local r = REACH[t.name]
    if not r then
      r = t.prototype.turret_range or (t.prototype.attack_parameters and t.prototype.attack_parameters.range) or 0
      REACH[t.name] = r
    end
    guns[#guns + 1] = {t.position.x, t.position.y, (r + 4) ^ 2}
  end
  local best, bc
  for ring = 1, 3 do
    local d = land * ring / 3
    for a = 0, 15 do
      local ang = (a + ring / 3) * math.pi / 8
      local x, y = tx + math.cos(ang) * d, ty + math.sin(ang) * d
      local tile = surface.get_tile(x, y)
      if tile.valid and not tile.collides_with("water_tile") then
        local c = 0
        for _, g in ipairs(guns) do if (g[1] - x) ^ 2 + (g[2] - y) ^ 2 <= g[3] then c = c + 1 end end
        if not bc or c < bc then best, bc = {x, y}, c end
      end
    end
  end
  return best, bc
end
-- Its strike force (threat points, RimWorld's raid): a team of its own by pod behind one lead camp of `corps`
-- (war.strike_team), sent at a target, fighting on to the nearest of the player's buildings each minute, lifted out after
-- strike_minutes; never the camp's garrison. Its points the beat's, not a camp's. The lead: a camp with no operation out,
-- nearest the focus if there is one, else nearest the player's spawn. Its target: the focus, else the lead camp's known
-- target of the player's of most value.
local function strike(s, owner, corps, tick, mult, warn, aim, want)
  -- (None while a power strike's hold stands: the blackout is one strike's.)
  if not want and s.power_hold and s.power_hold[owner] and tick < s.power_hold[owner] then return 0 end
  local n = math.floor(strike_units(s, owner) * (mult or 1))
  if n <= 0 then return 0 end
  local set = {}
  for _, c in ipairs(corps) do set[c] = true end
  local f = game.forces[owner]
  -- (`aim`: a bounty's target, 0.2.416; else the focus, else the lead camp's own.)
  local at = aim or (s.focus and tick < s.focus.till and s.focus.pos)
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
  local surface = lead.lander.surface
  local kind, tent = aim and (want == "joint" and "joint" or want == "aimed" and "aimed" or "bounty") or at and "focus" or nil, nil
  -- By motive (0.2.418): retaliation first, else a kind drawn, its corporation's own strike_motive_weight times another's;
  -- power and water only with a player there in person (or tracing). `want`: a kind forced (tests, the panel).
  if not target and f then
    if not want or want == "retaliation" then
      tent = grudge_target(s, lead.corp, owner)
      if tent then kind = "retaliation" end
    end
    if not tent then
      if not s.strike_rng then
        s.strike_rng = {s = rng.new((game.surfaces[1] and game.surfaces[1].map_gen_settings.seed or 1) + 130363).s}
      end
      local mine = {}
      for _, k in ipairs(tun("strike_motive")[lead.corp] or {}) do mine[k] = true end
      local here = in_person(f, surface) or storage.trace
      local opts, sum = {}, 0
      for _, k in ipairs(tun("strike_kind_order")) do
        if (not want or want == k) and (here or (k ~= "power" and k ~= "water" and k ~= "engineer")) then
          local e, w
          if k == "engineer" then
            -- (The engineer: a character of the player's on this surface, in person; none while tracing headless.)
            for _, p in pairs(f.connected_players) do
              if p.character and p.physical_surface == surface and p.controller_type == defines.controllers.character then
                e = p.character
              end
            end
            -- (Tracing, headless with no player connected: a character of the force there stands in. Tests, visits.)
            if not e and storage.trace then
              e = surface.find_entities_filtered{type = "character", force = f, limit = 1}[1]
            end
            w = tun("strike_engineer_weight")
          else
            e = kind_target(surface, owner, k, lead.lander.position)
            w = mine[k] and tun("strike_motive_weight") or 1
          end
          if e then
            opts[#opts + 1] = {k = k, e = e, w = w}
            sum = sum + w
          end
        end
      end
      if sum > 0 then
        local x = rng.next(s.strike_rng) * sum
        for _, o in ipairs(opts) do
          x = x - o.w
          if x < 0 or o == opts[#opts] then kind, tent = o.k, o.e; break end
        end
      end
    end
    if tent then target = {tent.position.x, tent.position.y} end
  end
  if not target and want then return 0 end
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
  local tx, ty = target[1] or target.x, target[2] or target.y
  local minutes = warn or tun("warn_minutes")
  local land, cover = landing_spot(surface, owner, tx, ty)
  local k = {base = lead.id, owner = owner, corp = lead.corp, target = {tx, ty}, units = {}, sent = n, warned = tick,
    pods_at = tick + minutes * 3600, kind = kind or "known", tent = tent, land = land, cover = cover,
    hunt = kind == "engineer" and tent or nil}
  s.strikes[key] = k
  local mix = strike_mix(lead, k)  -- (Its mix as chosen, for the record and tests; drawn again as its pods go.)
  -- Its points priced by strength (0.2.457; the playtest of 2026-11-18, the user: "The invading army seemed quite strong
  -- all things considered", then "First + third seem appropriate. Be careful not to over nerf"): a point is point_scale
  -- of the lead camp's infantrymen in parts, the units as many as its mix's average price buys. Counted a unit a point,
  -- Kessler-Hayashi's first strike on the director save was 41 at the cap (17 infantry, 16 railgunners, 8 tanks), 1,059
  -- parts, two and a half times a 40-strong army of troopers. Prices are the arena's, tuned to equal spend.
  local per = tun("point_scale")
  if per and per > 0 and mix then
    local wsum, csum = 0, 0
    for name, x in pairs(mix) do
      wsum = wsum + x
      csum = csum + x * shared.unit_cost(lead.corp, name == "lp-hauler" and "lp-infantry" or name)
    end
    if wsum > 0 and csum > 0 then
      local priced = math.max(1, math.floor(n * per * shared.unit_cost(lead.corp, "lp-infantry") * wsum / csum + 0.5))
      k.points, k.sent = n, priced
      n = priced
    end
  end
  s.reinforced = (s.reinforced or 0) + n
  s.points_sent = (s.points_sent or 0) + n
  s.strike_lead = lead.id
  -- Told as RimWorld tells a raid (the user, 2026-11-15): when it lands, by director.on_strike_landed. Ahead only if the
  -- player's radar sees where its pods come down (by its target since 0.2.418, behind the lead camp before): who, how
  -- many, where, when. A player who built radar cover earns the lead time. (0.2.393 to 0.2.404 warned every strike at
  -- its target, the director's intent read out; Fable's fun consult had asked for it.) Power and water apart: told
  -- ahead, target named and tagged, and the operations against the player held (shared.DIRECTOR's power_hold).
  local c = shared.CORPS[lead.corp]
  local lp = land and {x = land[1], y = land[2]} or lead.lander.position
  -- (Seen: within a working radar's constant reveal, its prototype's nearby reach in chunks, quality's included. Not
  -- LuaForce.is_chunk_visible: headless, with no player connected, a powered radar's own chunk read unseen.)
  -- (How far ahead, by the radar's distance (the user, 2026-11-16, "Yes to radar distance": 2 minutes was generous once
  -- the defend stance answers at once): the full warning with a radar over the landing chunk, warn_edge of it at the
  -- edge of its reach, between in proportion; the best radar's. Told then, not at once.)
  local seen, frac, eye = false, nil, nil
  if f then
    local cx, cy = math.floor(lp.x / 32), math.floor(lp.y / 32)
    -- (A command relay reveals as a radar does, but not under a blackout mast: kept powered for the army, its cover goes.)
    local bo = s.masts and s.masts.blackout
    local bo_r = bo and bo.mast and bo.mast.valid and bo.owner == owner and tun(MASTS.blackout.radius)
    for _, r in ipairs(surface.find_entities_filtered{type = "radar", force = f, position = lp, radius = 32 * 8}) do
      if bo_r and r.name == "lp-command-relay" and (r.position.x - bo.mast.position.x) ^ 2
        + (r.position.y - bo.mast.position.y) ^ 2 <= bo_r * bo_r then goto next_radar end
      local reach = r.prototype.get_max_distance_of_nearby_sector_revealed(r.quality) or 0
      local rx, ry = math.floor(r.position.x / 32), math.floor(r.position.y / 32)
      local d = math.max(math.abs(rx - cx), math.abs(ry - cy))
      if r.status == defines.entity_status.working and d <= reach then
        seen = true
        local fr = reach > 0 and d / reach or 0
        if not frac or fr < frac then frac, eye = fr, r end
      end
      ::next_radar::
    end
  end
  if f and s.intercept and not (kind == "power" or kind == "water") then
    s.intercept = nil
    k.intercepted = true
    k.ttag = f.add_chart_tag(surface, {position = {tx, ty}, text = c.name .. " strike target (intercepted)",
      icon = {type = "virtual", name = c.icon}})
  end
  if f and (kind == "power" or kind == "water") then
    k.advertised = true
    s.power_hold = s.power_hold or {}
    s.power_hold[owner] = k.pods_at + (tun("strike_minutes") + tun("power_hold")) * 3600
    s.strikes_advertised = (s.strikes_advertised or 0) + 1
    k.ttag = f.add_chart_tag(surface, {position = {tx, ty}, text = c.name .. " strike target",
      icon = {type = "virtual", name = c.icon}})
    tell(owner, "lp.director-strike-target", c.name, n, string.format("[entity=%s]", tent.name),
      string.format("[gps=%.0f,%.0f,%s]", tx, ty, surface.name), minutes)
  end
  if seen then
    local lead = minutes * (1 - (1 - tun("warn_edge")) * frac)
    k.spot = {at = k.pods_at - math.floor(lead * 3600), x = lp.x, y = lp.y, surface = surface.index, key = key, radar = eye}
    if tick >= k.spot.at then director.spot(s, k) end
  end
  shared.event("strike_warn", {key = key, corp = lead.corp, n = n, pos = {tx, ty}, minutes = minutes, base = lead.id,
    seen = seen or false, kind = k.kind, land = land, cover = cover, target = tent and tent.name or nil})
  trace(string.format("strike force %d: %d units of camp %d's, at %s %.0f,%.0f, landing %s (%s turrets reach), its pods in %d minutes (%s)",
    key, n, lead.id, k.kind, tx, ty, land and string.format("%.0f,%.0f", land[1], land[2]) or "behind its camp",
    tostring(cover), minutes, k.advertised and "told, its target named" or seen and "seen by radar, told" or "unseen"))
  return n
end

director.strike_force = strike

-- Its strike teams' units as they land (war's pods.handlers.strike), sent at their target.
war.on_strike_landed = function(key, units)
  local s = storage.director
  local k = s and s.strikes and s.strikes[key]
  if not k then for _, u in ipairs(units) do if u.valid then u.destroy() end end; return end
  s.strike_landed = (s.strike_landed or 0) + #units
  k.landed_n = (k.landed_n or 0) + #units
  s.strike_unit = s.strike_unit or {}
  if not k.landed_at and units[1] then
    k.landed_at = {units[1].position.x, units[1].position.y}
    s.strike_landings = (s.strike_landings or 0) + 1
    shared.event("strike_landed", {key = key, n = #units, pos = k.landed_at})
    -- Told as it lands: a notice with its place, a tag there and an alert on its first unit while the force is out.
    local f, c = game.forces[k.owner], shared.CORPS[k.corp]
    if f and c then
      local surface = units[1].surface
      if k.tag and k.tag.valid then k.tag.destroy() end
      if k.spot_alert and k.spot_alert.valid then
        f.remove_alert{entity = k.spot_alert, type = defines.alert_type.custom}
        k.spot_alert = nil
      end
      k.tag = f.add_chart_tag(surface, {position = k.landed_at, text = c.name .. " strike force",
        icon = {type = "virtual", name = c.icon}})
      local gps = string.format("[gps=%.0f,%.0f,%s]", k.landed_at[1], k.landed_at[2], surface.name)
      k.alert = units[1]
      f.add_custom_alert(units[1], {type = "virtual", name = c.icon}, {"lp.director-strike-landed", c.name, k.sent, gps}, true) -- notice-ok: a threat landed, told as it arrives
      tell(k.owner, "lp.director-strike-landed", c.name, k.sent, gps)
    end
  end
  for _, u in ipairs(units) do
    k.units[#k.units + 1] = u
    s.strike_unit[u.unit_number] = key
    -- (A team already sent back: its late pods walk home with it. Pods in flight at a lull's recall landed and went
    -- for their target in the truce: railbase_end's climax, 3 of 80 down when recalled, Grubstake razed 224 in it.)
    if k.truce and not k.lift_at then k.lift_at = game.tick + tun("home_minutes") * 3600 end
    if k.lift_at then
      send_home(k, {u})
    elseif u.type == "unit" then
      -- In one group, at its slowest's pace (0.2.417): sent each on its own, its harriers flew 250 tiles ahead into the
      -- player's guns and the force broke at half before its tanks came (railbase_end, every strike within 40 s).
      if not (k.group and k.group.valid) then
        k.group = u.surface.create_unit_group{position = k.landed_at, force = u.force}
      end
      k.group.add_member(u)
    else
      u.commandable.set_command{type = defines.command.attack_area, destination = k.target, radius = 32,
        distraction = defines.distraction.by_enemy}
    end
  end
  if k.group and k.group.valid and not k.lift_at then
    k.group.set_command{type = defines.command.attack_area, destination = k.target, radius = 32,
      distraction = defines.distraction.by_enemy}
  end
end

-- Each minute: its teams' pods sent once their warning has run (a camp fallen meanwhile, none); its teams fight on to the
-- nearest of the player's buildings within 80 of them; at strike_minutes they walk back to where they landed and are
-- home to their camp (walking, send_home). A team all dead first is the player's: finished.
-- Sent back to where they landed, lifted there or at lift_at. `truce`: a lull's recall, distraction none, so they walk
-- home through the player's guns without fighting (by_enemy, a team recalled in scenario director's lull razed 3 of the
-- player's on its way back, the minute after the truce, 0.2.398).
-- Home (the user, 2026-11-15: "The lift makes little sense for factorio? ... you need a rocket to reach space"): its
-- lead camp, or the nearest of its corporation's standing; none, stranded. Walked there by ops.walk_home (quiet in a
-- truce or broken); at the camp, into its garrison while it has room (army.cap), the rest to its launchpad (its lander
-- with none) and off on its rocket, an export's beam. Lifted out where they landed until 0.2.419.
local function home_of(k)
  local b = storage.bases[k.base]
  if b and not b.fallen and b.lander and b.lander.valid then return b end
  local best, bd
  for _, c in pairs(storage.bases or {}) do
    if c.corp == k.corp and not c.fallen and c.lander and c.lander.valid and k.landed_at then
      local d = (c.lander.position.x - k.landed_at[1]) ^ 2 + (c.lander.position.y - k.landed_at[2]) ^ 2
      if not bd or d < bd then best, bd = c, d end
    end
  end
  if best then k.base = best.id end
  return best
end
-- Its walk home (0.2.428; the user, on the walk-home loop: "a squad walking passively under turret fire. Is this really
-- how we coded things?"): round the player's guns where there is a way (ops.walk_home's `guns`, a cell in reach
-- home_gun_cost times as dear), its walk distraction none (by_enemy razed on its way, 0.2.418's repel; by_damage fought
-- each gun to its end); answering fire by bursts, walking (below, answer_seconds), never in a lull's truce (k.lull).
send_home = function(k, units)
  local b = home_of(k)
  if b then
    k.home = b.id
    local n = ops.walk_home(b, units, true, nil, tun("home_gun_cost"))
    local r = ops.last_route
    if r and r.found and (r.turrets or 0) > 0 then
      local s = st()
      s.strike_routed = (s.strike_routed or 0) + 1
      k.routed, k.exposed = true, r.exposed
      s.strike_exposed = r.exposed  -- (the last way's cells in a gun's reach: tests)
    end
    return n
  end
  -- (Stranded: no camp of its corporation standing. They go to where they landed and stay there till lift_at.)
  k.home = nil
  local n = 0
  for _, u in ipairs(units) do
    if u.valid then
      n = n + 1
      u.commandable.set_command{type = defines.command.go_to_location, destination = k.landed_at, radius = 8,
        distraction = defines.distraction.none}
    end
  end
  return n
end
local function walk_back(k, tick, truce)
  if truce then k.truce = true end
  -- (Out of its group first: its command would hold them.)
  if k.group and k.group.valid then k.group.destroy() end
  k.lift_at = k.lift_at or tick + tun("home_minutes") * 3600
  return send_home(k, k.units)
end

-- Its strike forces' morale, every 5 s: one that has lost strike_break of those landed breaks, walks back without
-- fighting (walk_back's truce: distraction none) and is lifted out where it landed; repelled, the player's win short of
-- killing them all (4 of 38 were, against a base nobody defended: railbase_end, 0.2.394).
-- Its forces walking home, every second: within its camp's claim (its walls and gates the camp's own returning units',
-- pool.give), into its garrison while it has room, else off on its pad's rocket (its lander's with none: an export's
-- beam); a unit the engine set to flee (by_enemy) sent on again. (Landed by its target since 0.2.418, a broken
-- force's tank fled among the player's guns and razed 4 of them, scenario director repel. Home within 40 of the lander
-- at first: the camp's walls held them off it, and none were home in 8 minutes, scenario director home.)
-- What is hitting a unit walking home, by a guess (no damage event for every unit: the handler's filter would take every
-- bullet in the game): the nearest of `owner`'s guns whose reach covers it, else the nearest of its units, cars or
-- characters within answer_reach.
local ANSWER_TYPES = {"ammo-turret", "electric-turret", "fluid-turret", "unit", "character", "car", "spider-vehicle"}
local function attacker_of(u, owner)
  local best, bd
  for _, e in ipairs(u.surface.find_entities_filtered{position = u.position, radius = 40, force = owner, type = ANSWER_TYPES}) do
    local d = (e.position.x - u.position.x) ^ 2 + (e.position.y - u.position.y) ^ 2
    local reach
    if e.type == "ammo-turret" or e.type == "electric-turret" or e.type == "fluid-turret" then
      local r = REACH[e.name]
      if not r then
        r = e.prototype.turret_range or (e.prototype.attack_parameters and e.prototype.attack_parameters.range) or 0
        REACH[e.name] = r
      end
      reach = r + 2
    else reach = tun("answer_reach") end
    if d <= reach * reach and (not bd or d < bd) then best, bd = e, d end
  end
  return best
end
walking = function(s)
  for _, k in pairs(s.strikes or {}) do
    if k.lift_at and k.landed_at then
      local b = k.home and storage.bases[k.home]
      if b and (b.fallen or not (b.lander and b.lander.valid)) then b = nil; send_home(k, k.units) end
      local back = {}
      for _, u in ipairs(k.units) do
        if u.valid then
          local c = u.commandable and u.commandable.command
          local r = b and math.max(60, b.claim_radius or 0)
          if not b then
            back[#back + 1] = u  -- (Stranded: held where it landed.)
          elseif (u.position.x - b.lander.position.x) ^ 2 + (u.position.y - b.lander.position.y) ^ 2 <= r * r then
            s.strike_unit[u.unit_number] = nil
            if pool.strength(b) < army.cap(b) then
              pool.enlist(b, u)
              pool.give_one(b, u)
              s.strike_joined = (s.strike_joined or 0) + 1
              k.joined = (k.joined or 0) + 1
            else
              local pad
              for _, x in ipairs(b.launchpads or {}) do if x.valid then pad = x; break end end
              pad = pad or b.lander
              rendering.draw_line{from = pad, to = {pad.position.x, pad.position.y - 60}, surface = pad.surface,
                color = {0.6, 0.85, 1, 0.8}, width = 6, time_to_live = 90}
              s.strike_shipped = (s.strike_shipped or 0) + 1
              k.shipped = (k.shipped or 0) + 1
              u.destroy()
            end
          else
            back[#back + 1] = u
            local un = u.unit_number
            k.hp, k.answer = k.hp or {}, k.answer or {}
            local hit = k.hp[un] and u.health < k.hp[un] - 1
            k.hp[un] = u.health
            local burst = k.answer[un] and game.tick < k.answer[un].till
            -- Hit on its way (not in a lull's truce), at most once each answer_gap: a burst at what is hitting it.
            if hit and not k.lull and not burst and game.tick >= ((k.answer[un] or {}).next or 0) then
              local att = attacker_of(u, k.owner)
              if att then
                u.commandable.set_command{type = defines.command.attack, target = att, distraction = defines.distraction.none}
                k.answer[un] = {till = game.tick + tun("answer_seconds") * 60, next = game.tick + tun("answer_gap") * 60}
                s.strike_answers = (s.strike_answers or 0) + 1
                burst = true
              end
            end
            if not burst and not (c and (c.type == defines.command.compound or c.type == defines.command.go_to_location)) then
              ops.walk_home(b, {u}, true, nil, tun("home_gun_cost"))
            end
          end
        end
      end
      k.units = back
    end
  end
end

morale = function(s, tick)
  for key, k in pairs(s.strikes or {}) do
    if k.at and k.landed_at and not k.lift_at and not k.broken and (k.landed_n or 0) > 0 then
      local live = 0
      for _, u in ipairs(k.units) do if u.valid then live = live + 1 end end
      if live > 0 and live <= k.landed_n * (1 - tun("strike_break")) then
        k.broken, k.broken_at = true, tick
        s.strikes_repelled = (s.strikes_repelled or 0) + 1
        walk_back(k, tick, true)
        shared.event("strike_broken", {key = key, live = live, landed = k.landed_n})
        trace(string.format("strike force %d broke: %d of %d left, walking home", key, live, k.landed_n))
      end
    end
  end
end

-- Its mix: the camp's composition, tilted against the guards of its target (shared.DIRECTOR's strike_guard).
local COUNTERS = require("__landing-party__.counters")
local GUARD_TYPES = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "unit", "car", "spider-vehicle"}
strike_mix = function(b, k)
  local m = army.composition(b, army.mix(b))
  local mind = (shared.CORPS[b.corp] or {}).mind or {}
  local w = (mind.counter or 0) * tun("strike_counter")
  if w <= 0 or not k.target then return m end
  local surface = b.lander.surface
  local seen, n = {}, 0
  for _, e in ipairs(surface.find_entities_filtered{position = k.target, radius = tun("strike_guard"), force = k.owner,
    type = GUARD_TYPES}) do
    seen[e.name] = (seen[e.name] or 0) + 1
    n = n + 1
  end
  if n == 0 then return m end
  local out = {}
  for name, x in pairs(m) do
    local row = COUNTERS[shared.variant(b.corp, name)] or COUNTERS[name]
    local sc = 0
    if row then for key, c in pairs(seen) do sc = sc + (row[key] or 0) * c / n end end
    out[name] = x * math.max(0.1, 1 + w * sc)
  end
  k.mix, k.mix_raw, k.guards = out, m, n
  return out
end

-- A strike force's pods seen coming (k.spot, set as it is sent): told, tagged and marked seen, k.spot.at.
function director.spot(s, k)
  local f, c, surface = game.forces[k.owner], shared.CORPS[k.corp], game.surfaces[k.spot.surface]
  if k.seen or not (f and c and surface) then return end
  k.seen = true
  s.strike_seen = (s.strike_seen or 0) + 1
  local secs = math.max(0, math.floor((k.pods_at - game.tick) / 60 + 0.5))
  k.seen_lead = secs
  local gps = string.format("[gps=%.0f,%.0f,%s]", k.spot.x, k.spot.y, surface.name)
  k.tag = f.add_chart_tag(surface, {position = {k.spot.x, k.spot.y}, text = c.name .. " pods inbound",
    icon = {type = "virtual", name = c.icon}})
  tell(k.owner, "lp.director-strike-seen", c.name, k.sent, gps, secs)
  -- (An alert on the radar that saw them, as the landing's is on its first unit: with chat notices off, the warning was a
  -- map tag alone, and the playtest of 2026-11-18 did not see it. Gone when they land.)
  local eye = k.spot.radar
  if eye and eye.valid then
    f.add_custom_alert(eye, {type = "virtual", name = c.icon}, {"lp.director-strike-seen", c.name, k.sent, gps, secs}, true) -- notice-ok: a seen threat, the radar's warning
    k.spot_alert = eye
  end
  shared.event("strike_seen", {key = k.spot.key, lead = secs})
end

local function strike_over(s, key, k, why)
  local b, mine = storage.bases[k.base], {}
  local live = {}
  for _, u in ipairs(k.units) do if u.valid then live[#live + 1] = u end end
  for _, u in ipairs(live) do mine[u.unit_number] = true end
  -- (Its units counted in the lead camp's garrison, if any were: a team that joined it, scenario director's check.)
  for _, g in ipairs(b and b.garrison or {}) do
    if g.valid and mine[g.unit_number] then s.strike_enlisted = (s.strike_enlisted or 0) + 1 end
  end
  s.strikes_over = (s.strikes_over or 0) + 1
  if why == "finished" then s.strikes_finished = (s.strikes_finished or 0) + 1 end
  -- (Those still out at its end: its camp's where they stand, on their way back (pool.give); stranded, gone.)
  local hb = k.home and storage.bases[k.home]
  if hb and not hb.fallen and hb.lander and hb.lander.valid then
    for _, u in ipairs(live) do pool.enlist(hb, u) end
    pool.give(hb, live)
    s.strike_joined = (s.strike_joined or 0) + #live
    k.joined = (k.joined or 0) + #live
  else
    s.strike_lifted = (s.strike_lifted or 0) + #live
    for _, u in ipairs(live) do u.destroy() end
  end
  if k.tag and k.tag.valid then k.tag.destroy() end
  if k.ttag and k.ttag.valid then k.ttag.destroy() end
  if k.group and k.group.valid then k.group.destroy() end
  local f = game.forces[k.owner]
  if f and k.alert and k.alert.valid then f.remove_alert{entity = k.alert} end
  if f and k.spot_alert and k.spot_alert.valid then f.remove_alert{entity = k.spot_alert, type = defines.alert_type.custom} end
  local left = (k.joined or 0) + (k.shipped or 0) + (k.lifted or 0) + (hb and 0 or #live)
  trace(string.format("strike force %d over (%s): %d of %d home (%d joined camp %s, %d shipped off)", key, why, left,
    k.sent, k.joined or 0, tostring(k.home), k.shipped or 0))
  shared.event("strike_over", {key = key, left = left, sent = k.sent, why = why, joined = k.joined, shipped = k.shipped})
  s.strikes[key] = nil
  for un, kk in pairs(s.strike_unit or {}) do if kk == key then s.strike_unit[un] = nil end end
end
function director.strikes(s, tick)
  for key, k in pairs(s.strikes or {}) do
    if k.spot and not k.seen and tick >= k.spot.at then director.spot(s, k) end
    if not k.at then
      if tick >= k.pods_at then
        local b = storage.bases[k.base]
        local pods_sent = b and war.strike_team(b, k.owner, k.sent, key, k.land, strike_mix(b, k)) or 0
        if pods_sent == 0 then strike_over(s, key, k, "no camp")
        else
          k.at, k.till = tick, tick + tun("strike_minutes") * 3600
          trace(string.format("strike force %d: %d pods behind camp %d, %d minutes in the field", key, pods_sent, k.base,
            tun("strike_minutes")))
        end
      end
    else
      local live, cx, cy = {}, 0, 0
      for _, u in ipairs(k.units) do if u.valid then live[#live + 1] = u; cx, cy = cx + u.position.x, cy + u.position.y end end
      k.units = live
      local landed = tick - k.at > 2 * 3600
      if landed and #live == 0 then strike_over(s, key, k, k.broken and "repelled" or k.lift_at and "lifted" or "finished")
      elseif k.lift_at then
        -- Walking home (walking, every second): over once all are home or at lift_at, the rest the camp's where they
        -- stand. Stranded: lifted where they landed.
        if tick >= k.lift_at or (k.home and #live == 0) then strike_over(s, key, k, k.broken and "repelled" or "lifted")
        elseif k.home then
        else
          local back = {}
          for _, u in ipairs(live) do
            if (u.position.x - k.landed_at[1]) ^ 2 + (u.position.y - k.landed_at[2]) ^ 2 <= 16 * 16 then
              s.strike_lifted = (s.strike_lifted or 0) + 1
              k.lifted = (k.lifted or 0) + 1
              u.destroy()
            else back[#back + 1] = u end
          end
          k.units = back
          if #back == 0 then strike_over(s, key, k, k.broken and "repelled" or "lifted") end
        end
      elseif tick >= k.till and k.landed_at then
        local n = walk_back(k, tick)
        trace(string.format("strike force %d: %d walking home to camp %s", key, n, tostring(k.home)))
      elseif tick >= k.till then strike_over(s, key, k, "lifted")
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
        -- (Hunting the engineer: at their character wherever it is on this surface, every minute.)
        local hunting = k.hunt and k.hunt.valid and k.hunt.surface == surface
        if hunting then dest = {k.hunt.position.x, k.hunt.position.y} end
        -- (Its group re-aimed as one when it is done with its last; members out of it on their own.)
        local g = k.group and k.group.valid and k.group
        if g and (hunting or not g.command or g.state == defines.group_state.finished) then
          g.set_command{type = defines.command.attack_area, destination = dest, radius = 32,
            distraction = defines.distraction.by_enemy}
        end
        for _, u in ipairs(live) do
          local cmd = u.commandable and u.commandable.command
          if not (g and u.commandable.parent_group == g) and (not cmd or cmd.type ~= defines.command.attack_area) then
            u.commandable.set_command{type = defines.command.attack_area, destination = dest, radius = 32,
              distraction = defines.distraction.by_enemy}
          end
        end
      end
    end
  end
end

-- A surge now: every corporation at war with `owner` (its camps standing, Synthexis apart) spree_factor times as often
-- and the cap on operations against it at once surge_add higher (ops' budget), surge_minutes; with `focused`, a focus
-- strike: targets within focus_radius of the place their camps know best focus_weight times as relevant to every camp
-- (ops' relevance), so they converge on it from their own directions.
function director.start_surge(s, owner, tick, focused, why, at, climax)
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
  at = focused and (at or focus_point(owner)) or nil
  if focused and not at then focused = false end
  s.focus = at and {owner = owner, pos = at, radius = tun("focus_radius"), weight = tun("focus_weight"), till = till} or nil
  -- Its strike force, at the focus if it has one (threat points: strike_units; a climax's climax_points times, told
  -- climax_warn ahead). (Sent before the focus was set until 0.2.393: a focus strike's team went for the last focus's
  -- point or the camp's own target.)
  local sent = strike(s, owner, corps, tick, climax and tun("climax_points") or 1, climax and tun("climax_warn") or nil)
  -- (No tag on the focus's area since 0.2.405: the director's intent, not a thing in the world.)
  shared.event("beat", {kind = climax and "climax" or focused and "focus" or "surge", corps = corps, minutes = minutes,
    strike = sent, lead = s.strike_lead, focus = s.focus and s.focus.pos or nil})
  s.climax_beat = climax or nil
  s.phase, s.phase_till = "surge", till
  s.beat_from, s.beat_corps = tick, corps
  s.next_beat, s.next_corp, s.told_at = nil, nil, nil
  s.beats = s.beats + 1
  if climax then
    s.climaxes = (s.climaxes or 0) + 1
    s.climax_log = s.climax_log or {}
    table.insert(s.climax_log, {tick = tick, strike = sent, focus = at})
  end
  if focused then s.focuses = (s.focuses or 0) + 1 else s.surges = (s.surges or 0) + 1 end
  trace(string.format("%s: %s against %s %dx as often, %d more at once, for %d minutes%s (budget %.2f left; %s)",
    climax and "climax" or focused and "focus strike" or "surge", table.concat(corps, ", "), owner, factor, tun("surge_add"), minutes,
    at and string.format(", on %.0f,%.0f", at[1], at[2]) or "", s.budget, why or "forced"))
  return true
end

-- A lull now: every corporation's operations against `owner` held lull_minutes (the truce standing).
-- `corps`: the corporations held, those of the beat that earned it (the user, 2026-11-14, agreed): the others keep
-- their own pace. Held all, on the start save the lulls took more of Kessler-Hayashi's own pressure than its sprees
-- added (the player's buildings lost: off 1,155, steady 607, chaotic 352). None given (the panel's "Lull now"): all.
-- A lull's reward, salvage_chance of them (or `forced`): a rival shuttle crashed salvage_distance from the player's
-- spawn, the vanilla crash site's wrecks, its cargo by the player's era; a tag and an alert on it (a thing in the world,
-- RimWorld's blue letter; no message), the alert gone once it is emptied.
function director.salvage(s, owner, tick, forced)
  -- (Its own stream: drawn from the beats' it would shift every beat after the first lull.)
  if not s.salvage_rng then
    s.salvage_rng = {s = rng.new((game.surfaces[1] and game.surfaces[1].map_gen_settings.seed or 1) + 104729).s}
  end
  local r = s.salvage_rng
  local f = game.forces[owner]
  local surface = game.surfaces[1]
  if not (f and surface) then return nil end
  if not forced then
    -- (One at a time: none while a wreck lies uncollected.)
    if s.salvage and #s.salvage > 0 then return nil end
    -- (A player there in person, a character on this surface and not in the remote view.)
    local here = false
    for _, p in pairs(f.connected_players) do
      if p.character and p.physical_surface == surface and p.controller_type == defines.controllers.character then here = true end
    end
    if not here and not storage.trace then return nil end
    local era = math.max(1, (s.read and s.read.era) or 1)
    if rng.next(r) >= tun("salvage_chance") / era then return nil end
  end
  local sp = f.get_spawn_position(surface)
  local a = rng.next(r) * 2 * math.pi
  local d = tun("salvage_distance")
  local p = surface.find_non_colliding_position("crash-site-spaceship-wreck-big-1", {sp.x + math.cos(a) * d,
    sp.y + math.sin(a) * d}, 40, 1)
  local wreck = p and surface.create_entity{name = "crash-site-spaceship-wreck-big-1", position = p, force = "neutral"}
  if not wreck then return nil end
  -- (From 1: the readings' era is 0 early, and a wreck then had no gear, two guards and its claim no parts.)
  local era = math.max(1, (s.read and s.read.era) or 1)
  local cargo = era >= 3 and {{"processing-unit", 50}, {"low-density-structure", 20}}
    or era >= 2 and {{"advanced-circuit", 60}, {"steel-plate", 100}} or {{"electronic-circuit", 60}, {"iron-gear-wheel", 60}}
  for _, it in ipairs(cargo) do wreck.insert{name = it[1], count = it[2]} end
  -- The loot box: one piece of gear from the era's pool, its quality rolled (prototypes present only: a mod off, its
  -- piece or its quality left out).
  local pool = {}
  for _, name in ipairs(tun("salvage_gear")[math.min(3, era)] or {}) do
    if prototypes.item[name] then pool[#pool + 1] = name end
  end
  local gear, quality
  if #pool > 0 then
    gear = pool[math.floor(rng.next(r) * #pool) + 1]
    local x, q = rng.next(r), "normal"
    for _, qs in ipairs(tun("salvage_quality")) do
      x = x - qs[2]
      if x < 0 then q = qs[1]; break end
    end
    quality = prototypes.quality[q] and q or "normal"
    wreck.insert{name = gear, count = 1, quality = quality}
  end
  for k = 1, 3 do
    local q = surface.find_non_colliding_position("crash-site-spaceship-wreck-small-" .. k, {p.x + 4 * k - 8, p.y + 3}, 8, 1)
    if q then surface.create_entity{name = "crash-site-spaceship-wreck-small-" .. k, position = q, force = "neutral"} end
  end
  -- Its survivors guard it (RimWorld's ship parts come guarded): 2 + 2 per era of a corporation at war's infantry, a tank
  -- from era 2, standing by the wreck (stopped: they fight what comes, they do not go looking).
  local guards, guard_units = 0, {}
  -- (Its corporation: one at war, else the lull's own, held: a wreck in a lull, the held at war with nobody, had none.)
  local corp = pick(s, owner, tick)
  if not corp then
    for _, c in ipairs(s.lull_corps or {}) do if c ~= "biotech" and faction.alive(c) > 0 then corp = c; break end end
  end
  if corp and corp ~= "biotech" and shared.CORPS[corp] then
    local names = {}
    for _ = 1, 2 + 2 * era do names[#names + 1] = rd.unit(corp, "lp-infantry") end
    if era >= 2 then names[#names + 1] = rd.unit(corp, "lp-tank") end
    for k, name in ipairs(names) do
      local a2 = k / #names * 2 * math.pi
      local q = prototypes.entity[name] and surface.find_non_colliding_position(name, {p.x + 7 * math.cos(a2),
        p.y + 7 * math.sin(a2)}, 8, 0.5)
      local u = q and surface.create_entity{name = name, position = q, force = shared.CORPS[corp].force}
      if u then
        guards = guards + 1
        guard_units[#guard_units + 1] = u
        u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.by_enemy}
      end
    end
  end
  f.chart(surface, {{p.x - 16, p.y - 16}, {p.x + 16, p.y + 16}})
  local tag = f.add_chart_tag(surface, {position = p, text = "Crashed shuttle", icon = {type = "item", name = cargo[1][1]}})
  f.add_custom_alert(wreck, {type = "item", name = cargo[1][1]}, {"lp.salvage-crashed"}, true) -- notice-ok: an alert on a thing in the world, not a message
  s.salvage = s.salvage or {}
  -- (Its data core: datacore_chance, the transmission intercepted once the wreck is emptied.)
  local core = rng.next(r) < tun("datacore_chance") or forced == "core"
  table.insert(s.salvage, {wreck = wreck, tag = tag, owner = owner, at = tick, corp = corp, guards = guard_units, era = era,
    core = core})
  s.salvaged = (s.salvaged or 0) + 1
  s.salvage_guards = guards
  s.salvage_gear = gear and {name = gear, quality = quality} or nil
  shared.event("salvage", {pos = {p.x, p.y}, cargo = cargo[1][1], gear = gear, quality = quality, guards = guards, corp = corp})
  trace(string.format("salvage: a shuttle crashed at %.0f,%.0f with %d %s and a %s %s, %d of %s's guarding it", p.x, p.y,
    cargo[1][2], cargo[1][1], tostring(quality), tostring(gear), guards, tostring(corp)))
  return wreck
end

-- Its wrecks: emptied, taken (tag and alert gone); uncollected salvage_claim minutes with a guard standing, claimed by
-- its corporation (parts to its nearest camp, the guards walk home there); unguarded and uncollected salvage_expire, gone.
local function salvage_tick(s)
  local tick = game.tick
  for i = #(s.salvage or {}), 1, -1 do
    local w = s.salvage[i]
    local empty = not w.wreck.valid or w.wreck.get_inventory(defines.inventory.chest).is_empty()
    local alive = {}
    for _, u in ipairs(w.guards or {}) do if u.valid then alive[#alive + 1] = u end end
    local how = empty and "taken"
      or (#alive > 0 and tick - (w.at or tick) >= tun("salvage_claim") * 3600 and "claimed")
      or (#alive == 0 and tick - (w.at or tick) >= tun("salvage_expire") * 3600 and "expired") or nil
    if how then
      if w.tag and w.tag.valid then w.tag.destroy() end
      local f = game.forces[w.owner]
      if f and w.wreck.valid then f.remove_alert{entity = w.wreck} end
      if how == "claimed" then
        local best, bd
        for _, b in pairs(storage.bases or {}) do
          if b.corp == w.corp and not b.fallen and b.lander and b.lander.valid then
            local d = (b.lander.position.x - w.wreck.position.x) ^ 2 + (b.lander.position.y - w.wreck.position.y) ^ 2
            if not bd or d < bd then best, bd = b, d end
          end
        end
        local parts = tun("salvage_parts") * (w.era or 1)
        if best then
          best.parts = best.parts + parts
          s.salvage_parts = (s.salvage_parts or 0) + parts
          for _, u in ipairs(alive) do pool.enlist(best, u) end
          pool.give(best, alive)
          ops.walk_home(best, alive, true)
        end
        s.salvage_claimed = (s.salvage_claimed or 0) + 1
        trace(string.format("salvage claimed by %s: %d parts to camp %s, %d guards home", tostring(w.corp), parts,
          tostring(best and best.id), #alive))
      end
      if how ~= "taken" and w.wreck.valid then w.wreck.destroy() end
      if how == "taken" then s.salvage_taken = (s.salvage_taken or 0) + 1 end
      -- (Its data core read: the next strike force's target tagged as it is chosen.)
      if how == "taken" and w.core then s.intercept = true; s.intercepts = (s.intercepts or 0) + 1 end
      if how == "expired" then s.salvage_expired = (s.salvage_expired or 0) + 1 end
      shared.event("salvage_over", {why = how})
      table.remove(s.salvage, i)
    end
  end
end
director.salvage_tick = salvage_tick

function director.start_lull(s, owner, tick, corps, base_minutes)
  local minutes = math.floor((base_minutes or tun("lull_minutes")) * ((tun("lull_scale") or {})[director.personality()] or 1))
  -- (Its truce on the camps truce_max at most, the rest of the lull the director's alone, no beat: a truce of 30 minutes
  -- held the camps' own operations too, the pressure they make with the director off, and in the campaign steady fell
  -- from twice off to 1.1 to 1.4 times; 0.2.394.)
  local truce = math.min(minutes, tun("truce_max"))
  storage.truces = storage.truces or {}
  local held = {}
  if corps and #corps > 0 then held = corps else for corp in pairs(shared.CORPS) do held[#held + 1] = corp end; table.sort(held) end
  for _, corp in ipairs(held) do storage.truces[corp .. "|" .. owner] = tick + truce * 3600 end
  -- Its operations out against the player recalled (ops' b.recall), and its own strike teams sent home: a
  -- truce held launches only, and the player told of a hold lost 398 buildings in it to sieges already out.
  local set = {}
  for _, corp in ipairs(held) do set[corp] = true end
  local recalled = 0
  for _, b in pairs(storage.bases or {}) do
    if set[b.corp] and not b.fallen then
      b.recall = {owner = owner, at = tick}
      if b.op then recalled = recalled + 1 end
    end
  end
  for key, k in pairs(s.strikes or {}) do
    if k.owner == owner and set[k.corp] and not k.at then strike_over(s, key, k, "called off") end
  end
  -- Those in the field sent back now, not at the next minute's pass, and without fighting on the way.
  for key, k in pairs(s.strikes or {}) do
    if k.owner == owner and set[k.corp] and k.at then
      k.till, k.truce, k.lull = math.min(k.till or tick, tick), true, true
      if k.landed_at then
        trace(string.format("strike force %d: %d recalled, walking home", key, walk_back(k, tick, true)))
      end
    end
  end
  s.recalls = (s.recalls or 0) + recalled
  s.phase, s.phase_till = "lull", tick + minutes * 3600
  s.lull_from, s.lull_owner, s.lull_corps = tick, owner, held
  s.lulls = (s.lulls or 0) + 1
  shared.event("beat", {kind = "lull", minutes = minutes, truce = truce, corps = held})
  director.salvage(s, owner, tick)
  trace(string.format("lull: %s's operations against %s held %d minutes (no beat for %d)", table.concat(held, ", "), owner,
    truce, minutes))
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
  s.next_beat, s.next_corp, s.told_at = nil, nil, nil
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
  elseif action == "joint" or action == "contract" or action == "rotation" then
    return director["start_" .. action](s, owner, tick, "forced") and action or ("no " .. action .. " possible")
  elseif action == "strike" then
    -- (A strike force alone, `arg` its kind of target or any: tests, the panel; or a position, its target there: films,
    -- a strike on the building a camera waits on.)
    local aim = type(arg) == "table" and {arg[1] or arg.x, arg[2] or arg.y} or nil
    local sent = strike(s, owner, at_war(owner), tick, nil, nil, aim, aim and "aimed" or arg)
    return sent > 0 and ("strike: " .. tostring(s.strikes[s.strike_n].kind)) or "no target of that kind"
  elseif action == "research" then
    local id = director.start_research(s, owner, tick, "forced")
    return id and ("research: " .. id) or "no node to buy"
  elseif action == "salvage" then
    -- (`arg` "core": its data core sure, tests.)
    return director.salvage(s, owner, tick, arg == "core" and "core" or true) and "salvage" or "no place for a wreck"
  elseif action == "bounty" then
    if s.bounty then return "a bounty is up" end
    return director.start_bounty(s, owner, tick, "forced") and "bounty" or "no target of the player's known"
  elseif MASTS[action] then
    if s.masts and s.masts[action] then return action .. " is up" end
    return director.start_mast(s, action, owner, tick, "forced") and action or ("no " .. MASTS[action].corp
      .. " camp at war near a " .. MASTS[action].type)
  elseif action == "climax" then
    -- Steady's climax now (the panel's "Climax now"): a focus surge whose strike force is climax_points strong, told
    -- climax_warn ahead, lull_max after it.
    local at = type(arg) == "table" and {arg[1] or arg.x, arg[2] or arg.y} or nil
    if not director.start_surge(s, owner, tick, true, "forced", at, true) then return "no corporation at war with a camp standing" end
    return s.focus and "climax" or "climax (no focus known)"
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
