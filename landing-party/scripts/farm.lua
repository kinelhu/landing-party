-- The biotech's farms (docs/biotech.md; Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md, "Home").
-- It comes once the wild biters' evolution on a surface reaches ARRIVE_EVO (there are mediums to breed by then): a cargo
-- pod comes down on the nearest nest field NEAR to FAR tiles from the player's factory (to FARTHEST if none), and up to
-- PENS of its spawners become pens, each with START bred and WORMS bred worms. The farm is charted for the player, with a
-- map tag; its first landing is told in chat, as a corporation's is. Far out on purpose: hunting it down along its
-- trails is the answer to it, and its waves have the long walk to make (a bred medium covers 14 tiles a second).
-- Its waves (scripts/herd.lua): one at a time, WAVE_GAP apart at the least, from its pens' stock but a home guard, at
-- most WAVE_MAX, sent from the pen nearest the target. A pen attacked recalls the wave on its way (the fight moves to the trail).
-- Every pen dead: the farm is gone (its tag too), and it lands again on another field RELAND later.
-- Creep (scripts/creep.lua): a tumor by each incubator; the creep spreads to the wild nests near, and each it reaches
-- becomes an incubator (up to PENS_MAX). An incubator left off creep (its tumors killed) starves for STARVE and goes
-- back to the wild, its stock with it.
-- The break with Grubstake: when Grubstake's ground meets its creep (a Grubstake building or unit within BREAK_NEAR of a
-- tumor: a claim or strip mine on its edge, a convoy across it) or Grubstake hurts an incubator or a tumor, they are at
-- war (herd.break_grubstake); its waves may then go for Grubstake's camps as for the player's factory.
-- Biomass: an incubator breeds only while its culture can pay (shared.BREEDS, the arena's prices): a culture earns what
-- its creep drinks of the pollution (creep.drink), TRICKLE an incubator a minute whatever the air, and START_BIOMASS its
-- pod brought. Spent at each birth (on_entity_spawned); at nothing left its incubators stop (inactive) until it earns.
local shared = require("__landing-party__.shared")
local herd = require("__landing-party__.scripts.herd")
local pods = require("__landing-party__.scripts.pods")
local creep = require("__landing-party__.scripts.creep")
local cell = require("__landing-party__.scripts.cell")
local know = require("__landing-party__.scripts.know")
local COUNTERS = require("__landing-party__.counters")
local tune = require("__landing-party__.scripts.tune")

local farm = {}

local B = shared.BIOTECH
local ARRIVE_EVO = 0.25
local NEAR, FAR, FARTHEST = 600, 1000, 1500
local SEARCH = 2500           -- nests looked at round the player's spawn, nearest first
local CANDIDATES = 80         -- of those, how many are weighed
local FIELD, FIELD_MIN = 40, 3
local PENS = 4
local PENS_MAX = 12           -- a culture's incubators at most, taken by its creep
local STARVE = 3 * 3600       -- off creep this long, an incubator goes wild
-- Its feed (the identity consult's weak point; scripts/cell.lua): an incubator whose biochamber is dead (or stopped,
-- no technician having come for five minutes) breeds nothing,
-- keeps FED_CAP of its stock (the rest goes feral: the wild's), and after UNFED_WILD goes back to the wild. A biochamber
-- hit calls no wave home (a pen hit does): the quiet kill, a raid on the feed while the herd is out.
local FED_CAP = 12
-- Its clinic (scripts/cell.lua; the consult's third weak point): Synthexis's evolution is its own (the culture's
-- learned value, f.evo). While the clinic stands it climbs CLIMB a minute, never behind the wild's; destroyed, it stops,
-- and the incubators breed at STOCK_EVO at the most (small and medium biters) until a new clinic lands.
local CLIMB = 0.004
local STOCK_EVO = 0.3
local UNFED_WILD = 10 * 3600
local BREAK_NEAR = 12          -- a Grubstake building or unit this near a tumor breaks the truce
local TRICKLE = 3             -- biomass an incubator earns a minute, clean air or not
local START_BIOMASS = 200     -- what its pod brought (its first wave, ten minutes on)
local START = 6
local WORMS = 2
local HOME_GUARD = 6          -- per pen, kept at the gate when a wave goes
-- A wave's most (the consult: waves of 20 to 60; the mega wave is an event at the top of its ladder, not the default).
-- Four full pens sent 135 in the first farm run.
local WAVE_MAX = 60
local ESCALATE_WAIT = 10 * 3600   -- at most this much longer for a bigger wave at a defence that held
local UNFIT = -0.5                -- a breed scoring under this against a defence's killers is not sent at it
local WAVE_GAP = 20 * 3600
local FIRST_WAVE = 10 * 3600  -- after landing
local RELAND = 60 * 3600
local RETRY = 10 * 3600       -- a surface with no field for it is looked at again after this
local APART = 200             -- from a corporation's camp
local POD_WAIT = 2 * 3600
-- Breeding to order (the user, 2026-10-25: "if we don't make Synthexis breed on purpose, we are kinda missing the point of
-- making it the smart biters"). For its next wave at the place its last went: bursters, where a wall held its last wave
-- (nothing broken past it). Each incubator makes two ordered units a minute; while an order is short its culture keeps
-- the biomass for it (chance breeding waits), and the wave waits for it up to ORDER_WAIT. Sized by its last wave there.
-- It ordered the breed that best beat its killers too (counters.lua), and broke no more for it: in four 3-hour runs 347
-- against 462 where it ordered after every wave, 452 against 462 where only after a defence held, its waves fewer for
-- the wait; the counters' turret columns then told no breed from another, and a wave's make-up is hard for a player to
-- see. Its cleverness is in how it attacks (the user, 2026-10-25: "let the smartness reside in attack staging"); the
-- burster stays, the one breed a wall calls for, and seen (it glows).
local ORDER_BREACH = 0.12   -- of its units, bursters (the arena's breach, 2026-10-25: 3 or 4 among 25 to 35 mediums broke
                            -- 10 to 20 of a double wall and up to a third of the guns behind it; 40 mediums broke 1 to 3)
local ORDER_WAIT = 5 * 3600

local function st()
  storage.farms = storage.farms or {list = {}, next = 1}
  return storage.farms
end

local function d2(a, b)
  local ax, ay = a.x or a[1], a.y or a[2]
  local bx, by = b.x or b[1], b.y or b[2]
  return (ax - bx) ^ 2 + (ay - by) ^ 2
end

local function players() return shared.player_forces() end

local function corp_forces()
  local out = {}
  for _, c in pairs(shared.CORPS) do if game.forces[c.force] then table.insert(out, c.force) end end
  return out
end

local function trace(text)
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d %s  %s\n", game.tick, "biotech", text), true)
  end
end

-- The nearest nest field NEAR to `far` from the player's factory (none of its buildings within NEAR, some within far):
-- its middle and its spawners.
local function site(surface, far)
  local forces = players()
  if #forces == 0 then return nil end
  local origin = forces[1].get_spawn_position(surface)
  local nests = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = origin, radius = SEARCH}
  table.sort(nests, function(a, b) return d2(a.position, origin) < d2(b.position, origin) end)
  local weighed = 0
  local corps = corp_forces()
  for _, sp in ipairs(nests) do
    if weighed >= CANDIDATES then break end
    local p = sp.position
    if surface.count_entities_filtered{position = p, radius = NEAR, force = forces, limit = 1} == 0 then
      weighed = weighed + 1
      if surface.count_entities_filtered{position = p, radius = far, force = forces, limit = 1} > 0
        and (#corps == 0 or surface.count_entities_filtered{position = p, radius = APART, force = corps, limit = 1} == 0) then
        local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = p, radius = FIELD}
        if #field >= FIELD_MIN then
          local x, y = 0, 0
          for _, f in ipairs(field) do x, y = x + f.position.x, y + f.position.y end
          return {x = x / #field, y = y / #field}, field
        end
      end
    end
  end
end

local function bred_stock(surface, pen, n)
  local evo = game.forces[B.force].get_evolution_factor(surface)
  local name = evo >= 0.3 and "lp-bred-medium-biter" or "lp-bred-small-biter"
  local rec = herd.pen(pen.unit_number)
  for _ = 1, n do
    local q = surface.find_non_colliding_position(name, pen.position, 16, 0.5)
    local u = q and surface.create_entity{name = name, position = q, force = B.force}
    if u and rec then table.insert(rec.stock, u) end
  end
end

local function tag(f)
  local s = game.surfaces[f.surface]
  local all = true
  for _, pf in ipairs(players()) do
    if not (f.tags[pf.name] and f.tags[pf.name].valid) then
      pf.chart(s, {{f.pos.x - 64, f.pos.y - 64}, {f.pos.x + 64, f.pos.y + 64}})
      local t = pf.add_chart_tag(s, {position = f.pos, icon = {type = "item", name = "biter-egg"}, text = f.id == 1 and "Synthexis culture" or ("Synthexis culture " .. f.id)})
      if t then f.tags[pf.name] = t else all = false end
    end
  end
  f.tagged = all
end

-- The pod touched down: the field's spawners nearest it become pens.
function farm.land(surface, pos)
  local s = st()
  s.landing = nil
  local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = pos, radius = FIELD + 10}
  table.sort(field, function(a, b) return d2(a.position, pos) < d2(b.position, pos) end)
  if #field == 0 then
    s.next_arrival = game.tick + RETRY
    trace("its pod came down on no nests; looks again later")
    return
  end
  local bf = game.forces[B.force]
  local enemy = game.forces.enemy
  if bf and enemy then bf.set_evolution_factor(enemy.get_evolution_factor(surface), surface) end
  local f = {id = s.next, surface = surface.index, pos = {x = pos.x, y = pos.y}, pens = {}, tags = {},
    evo = enemy and enemy.get_evolution_factor(surface) or 0,
    last_wave = game.tick - tune.sooner("biotech", WAVE_GAP) + tune.sooner("biotech", FIRST_WAVE), landed = game.tick}
  s.next = s.next + 1
  for i = 1, math.min(PENS, #field) do
    local id = herd.capture(field[i])
    local rec = id and herd.pen(id)
    if rec then
      rec.farm = f.id
      table.insert(f.pens, id)
      bred_stock(surface, rec.pen, START)
      for _ = 1, WORMS do
        local q = surface.find_non_colliding_position("lp-bred-worm", {rec.pen.position.x + 6, rec.pen.position.y + 6}, 12, 1)
        if q then surface.create_entity{name = "lp-bred-worm", position = q, force = B.force} end
      end
      -- Its tumor, beside it: the creep grows from there (scripts/creep.lua).
      creep.plant(surface, rec.pen.position, f.id)
      -- Its cell: pad, biochamber, lamp (scripts/cell.lua).
      cell.build(id, rec.pen, f.id, f.pos)
    end
  end
  s.list[f.id] = f
  creep.culture(f.id, surface, pos)
  -- Its substrate and technicians (scripts/cell.lua).
  cell.site(f.id, surface, f.pos)
  creep.of(f.id).biomass = START_BIOMASS * tune.strength("biotech")
  tag(f)
  trace(string.format("farm %d landed at %.0f,%.0f: %d pens", f.id, pos.x, pos.y, #f.pens))
  if not s.told then
    s.told = true
    for _, pf in ipairs(players()) do
      -- Its first landing is told, as a corporation's is (the user: the last resort, "pointing the first landing").
      pf.print({"lp.biotech-landed", string.format("[gps=%d,%d,%s]", pos.x, pos.y, surface.name)}) -- notice-ok: first landing
    end
  end
end

pods.handlers["biotech-farm"] = function(_, surface, position) farm.land(surface, position) end

local function arrive(surface, far)
  local c = site(surface, far)
  if not c then return false end
  local s = st()
  local pod = pods.send(surface, c, B.force, {kind = "biotech-farm"})
  s.landing = {surface = surface.index, at = c, sent = game.tick}
  trace(string.format("its pod comes down on the nests at %.0f,%.0f", c.x, c.y))
  if not pod then farm.land(surface, c) end
  return true
end

-- Tests: an arrival now, whatever the evolution.
function farm.arrive_now(surface) return arrive(surface, FAR) or arrive(surface, FARTHEST) end

local function gone(f, why)
  for _, t in pairs(f.tags) do if t.valid then t.destroy() end end
  st().list[f.id] = nil
  creep.forget(f.id)
  cell.forget_site(f.id)
  st().next_arrival = game.tick + RELAND
  trace(string.format("farm %d gone (%s); lands again in %d minutes", f.id, why, RELAND / 3600))
end

-- Where a wave goes (the faction AI's one picker, Synthexis's part; docs/reviews/2026-10-23-faction-ai-audit.md). It is
-- a test range, not a hungry animal (the user, 2026-10-23: "what that faction would target if not pollution, lore wise.
-- Maybe any defended base as a way to 'test' their bioengineered weapons?"; the identity consult: it "never retaliates
-- in anger, it samples, records, adjusts"). Pollution is its food (creep.drink), not its target. A wave is a trial:
-- every force it is at war with (the players, Kessler-Hayashi, Grubstake once broken with it), their defended places
-- in reach by 64-tile cell, each scored by what there is to test (its defence: turrets by kind, walls), how much the
-- trial would teach (its odds against that defence, p, the most when uncertain: 4p(1 - p)), whether it was tried
-- lately (novelty, coming back as the trial fades or the defence changes) and distance. Kessler-Hayashi's walls draw
-- trials as the player's do, on their merits. Its last trials (cell, defence, when) are kept in know.lua's record.
local DEFENCE = {["ammo-turret"] = 1, ["electric-turret"] = 1.5, ["fluid-turret"] = 2.5}
local WALL_TYPES = {"wall", "gate"}
-- A place's defenders that move count too, a fifth of a gun turret each, within GARRISON_REACH of it: weighed by its
-- turrets and walls alone, a Kessler-Hayashi camp with a few guns on its edge and a hundred units inside read as soft,
-- and in four-faction runs 15 of 19 waves came blind (the scout killed by its tanks, troopers and outposts) and lost half
-- their number to it (2026-10-25; alone against the stand-in, 1 of 24).
local UNIT_DEFENCE = 0.2
local GARRISON_REACH = 96
-- And by what its waves there cost: the share that came home, with KEEP_PRIOR units' benefit of the doubt (a wave wiped
-- out leaves a quarter of the score; its odds model alone kept a Kessler-Hayashi outpost "worth learning from", and it
-- sent waves of 60 and 90 there in turn, none home, 2026-10-25).
local KEEP_PRIOR = 20

local function foes()
  local out = {}
  for _, f in ipairs(players()) do out[#out + 1] = f end
  if herd.grubstake_broken() and game.forces[shared.CORPS.grubstake.force] then
    out[#out + 1] = game.forces[shared.CORPS.grubstake.force]
  end
  if game.forces[shared.CORPS.serenity.force] then out[#out + 1] = game.forces[shared.CORPS.serenity.force] end
  return out
end

local NOVELTY_REACH = 192   -- a trial counts for the same force's ground this near (three cells)
local function trials()
  local k = know.of("biotech")
  k.trials = k.trials or {}
  return k.trials
end

local function target_from(surface, pos, f, n)
  local mind = B.mind
  local cells = {}
  for _, force in ipairs(foes()) do
    for _, e in ipairs(surface.find_entities_filtered{position = pos, radius = mind.reach, force = force, type = herd.DRAW}) do
      local cx, cy = math.floor(e.position.x / 64), math.floor(e.position.y / 64)
      local key = string.format("%s|%d,%d", force.name, cx, cy)
      local c = cells[key]
      if not c then
        c = {key = key, force = force.name, cx = cx, cy = cy, defence = 0, n = 0}
        cells[key] = c
      end
      c.n = c.n + 1
      c.defence = c.defence + (DEFENCE[e.type] or 0)
      local d = d2(e.position, pos)
      if not c.d or d < c.d then c.d, c.at = d, {x = e.position.x, y = e.position.y} end
    end
  end
  local tried = trials()
  local ranked, soft = {}, nil
  for _, c in pairs(cells) do
    if c.defence > 0 then
      c.walls = surface.count_entities_filtered{area = {{c.cx * 64, c.cy * 64}, {c.cx * 64 + 64, c.cy * 64 + 64}},
        type = WALL_TYPES, force = c.force}
      c.defence = c.defence + c.walls / mind.per_wall
      c.units = surface.count_entities_filtered{position = {c.cx * 64 + 32, c.cy * 64 + 32}, radius = GARRISON_REACH,
        type = {"unit", "spider-unit"}, force = c.force}
      c.defence = c.defence + c.units * UNIT_DEFENCE
      local r = (n or shared.WAVE_MIN) / (1 + mind.per_turret * c.defence)
      local p = r * r / (1 + r * r)
      c.odds, c.teach = p, 4 * p * (1 - p)
      local t = tried[c.key]
      c.novelty = 1
      if t and math.abs(c.defence - t.defence) <= 0.3 * math.max(t.defence, 1) then
        c.novelty = 1 - math.exp(-(game.tick - t.tick) / mind.fade)
      end
      -- And a trial beside it on the same force's ground (within NOVELTY_REACH): each corner of one camp read as untried,
      -- and five waves in a row went at Kessler-Hayashi's sprawling camp, every one lost (system 12345, 2026-10-24).
      for key, o in pairs(tried) do
        local f2, ox, oy = key:match("^(.-)|(-?%d+),(-?%d+)$")
        if f2 == c.force and key ~= c.key and ((tonumber(ox) - c.cx) ^ 2 + (tonumber(oy) - c.cy) ^ 2) * 64 * 64 <= NOVELTY_REACH ^ 2 then
          c.novelty = math.min(c.novelty, 1 - math.exp(-(game.tick - o.tick) / mind.fade))
        end
      end
      c.dist = math.sqrt(c.d)
      local l = herd.lesson_near(c.at, 128)
      c.kept = (((l and l.home) or 0) + KEEP_PRIOR) / (((l and l.sent) or 0) + KEEP_PRIOR)
      c.score = (1 + c.defence) * c.teach * c.novelty * c.kept / (1 + c.dist / mind.far)
      ranked[#ranked + 1] = c
    elseif not soft or c.d < soft.d then
      soft = c
    end
  end
  table.sort(ranked, function(a, b) return a.score > b.score end)
  local why = {}
  for k = 1, math.min(3, #ranked) do
    local c = ranked[k]
    why[#why + 1] = string.format("%s at %.0f,%.0f: defence %.1f (%d walls, %d units), odds %.2f, teaches %.2f, novelty %.2f, kept %.2f, %.0f tiles, score %.2f",
      c.force, c.at.x, c.at.y, c.defence, c.walls, c.units or 0, c.odds, c.teach, c.novelty, c.kept, c.dist, c.score)
  end
  -- Nothing defended in reach: the nearest of what stands, a trial against nothing (it calibrates).
  local best = ranked[1] or soft
  if not best then return end
  if not ranked[1] then why[1] = string.format("nothing defended; %s at %.0f,%.0f, %.0f tiles", best.force, best.at.x,
    best.at.y, math.sqrt(best.d)) end
  local rival = not shared.is_player_force(game.forces[best.force]) and {best.force} or nil
  -- The trial is recorded, and the weighing traced, when a wave goes (send): waiting for a bigger wave or its order it
  -- weighs again every ten seconds, and each weighing marked its choice tried, until every place read as just tried
  -- (novelty 0.01 everywhere) and the place it went was all but chance (0.2.14 to 0.2.18).
  return best.at, rival, {key = best.key, defence = best.defence, why = table.concat(why, "; ")}
end

-- What a breed scores against a lesson's killers (counters.lua: +1 wins, -1 loses), weighed by how many each killed.
local function fit_of(name, killers, total)
  if total == 0 then return 0 end
  local row, v = COUNTERS[name] or COUNTERS[shared.kind_of(name)] or {}, 0
  for k, n in pairs(killers) do v = v + n / total * (row[k] or 0) end
  return v
end

-- A burster glows inside: lit at night, acid green, the one light in the herd.
local function glow(u)
  rendering.draw_light{sprite = "utility/light_small", surface = u.surface, target = u,
    color = {0.35, 1, 0.2}, scale = 1.2, intensity = 0.8, minimum_darkness = 0.3}
end

local breeds_at, unlocked

-- Its order for the next wave (nil: none, it sends what it bred): by breed, how many it wants in its stock.
local function order(f, surface)
  if B.mind.orders == false or storage.biotech_no_orders or not f.aim then return nil end
  local l = herd.lesson_near(f.aim, 128)
  if not l then return nil end
  -- Only where a wall held: what worked elsewhere is sent again.
  if (l.walled_held or 0) == 0 then return nil end
  if not unlocked(game.forces[B.force].get_evolution_factor(surface))["lp-bred-cinder"] then return nil end
  return {["lp-bred-cinder"] = math.ceil((f.last_size or WAVE_MAX) * ORDER_BREACH)}
end

-- What its order still lacks: the price of the dearest breed short (nil: filled), what its culture keeps back (kept to the
-- cheapest, chance breeding spent the biomass between it and a burster's price: 2 of 4 bursters ordered were made).
local function short(want, have)
  local p
  for name, n in pairs(want or {}) do
    if (have[name] or 0) < n and (not p or shared.BREEDS[name].cost > p) then p = shared.BREEDS[name].cost end
  end
  return p
end

-- One ordered unit at an incubator, paid from its culture's biomass; true if one was made.
local function fulfil(f, rec, surface, want, have)
  local cul = creep.of(f.id)
  if not cul then return false end
  for name, n in pairs(want) do
    local price = shared.BREEDS[name].cost
    if (have[name] or 0) < n and cul.biomass >= price then
      local p = surface.find_non_colliding_position(name, rec.pen.position, 12, 0.5)
      local u = p and surface.create_entity{name = name, position = p, force = B.force}
      if u then
        cul.biomass, cul.spent, cul.bred = cul.biomass - price, (cul.spent or 0) + price, (cul.bred or 0) + 1
        table.insert(rec.stock, u)
        have[name] = (have[name] or 0) + 1
        f.made_to_order = f.made_to_order or {}
        f.made_to_order[name] = (f.made_to_order[name] or 0) + 1
        if name == "lp-bred-cinder" then glow(u) end
        return true
      end
    end
  end
  return false
end

local function send(f, tick)
  -- (Waiting for a bigger wave: looked at again every ten seconds, not every tick.)
  if f.escalate_retry and tick < f.escalate_retry then return end
  f.escalate_retry = nil
  local s = game.surfaces[f.surface]
  local units, origin = {}, nil
  -- What it could send (its odds are weighed with it): every pen's stock over its guard, at most WAVE_MAX.
  local avail = 0
  for _, id in ipairs(f.pens) do
    local rec = herd.pen(id)
    if rec and rec.pen.valid then avail = avail + math.max(0, #herd.stock(rec) - HOME_GUARD) end
  end
  local target, rival, choice = target_from(s, f.pos, f, math.min(avail, WAVE_MAX))
  if not target then return end
  local bd
  -- What killed its last wave there (herd.lesson_near): the breeds that beat those killers go first, the rest keep the
  -- gate (counters.lua, the arena's matrix; the user, 2026-10-24: learning that shows). With no lesson, the nearest go.
  local lesson = herd.lesson_near(target, 128)
  -- Escalation (the user, 2026-10-24): a defence that held draws a bigger wave, half as many again for each that broke
  -- nothing there (at most twice WAVE_MAX), and it waits for its stock to reach it (at most ESCALATE_WAIT longer).
  local held = 0
  for _, fc in pairs(lesson and lesson.faces or {}) do held = held + (fc.tried - fc.broke) end
  local cap = math.floor(WAVE_MAX * math.min(2, 1 + 0.5 * held))
  if cap > WAVE_MAX and avail < cap then
    f.escalate_since = f.escalate_since or tick
    if tick - f.escalate_since < ESCALATE_WAIT then f.escalate_retry = tick + 600; return end
  end
  f.escalate_since = nil
  -- Its order not yet filled: the wave waits for it, ORDER_WAIT at the most.
  if f.short then
    f.order_since = f.order_since or tick
    if tick - f.order_since < ORDER_WAIT then f.escalate_retry = tick + 600; return end
  end
  f.order_since = nil
  local total = 0
  for _, n in pairs(lesson and lesson.killers or {}) do total = total + n end
  -- What it bred to order goes first and is never held back (the bursters it made for a wall).
  local want = f.want or {}
  local function fit(u)
    if want[u.name] then return 2 end
    return fit_of(u.name, lesson and lesson.killers or {}, total)
  end
  for _, id in ipairs(f.pens) do
    local rec = herd.pen(id)
    if rec and rec.pen.valid then
      local stock = herd.stock(rec)
      if total > 0 or next(want) then
        local fits = {}
        for _, u in ipairs(stock) do fits[u.unit_number] = fit(u) end
        table.sort(stock, function(a, b) return fits[a.unit_number] > fits[b.unit_number] end)
        -- The least fit keep the gate (the loop below keeps the first HOME_GUARD at home), the fittest go first.
        local guard = {}
        for i = #stock, math.max(1, #stock - HOME_GUARD + 1), -1 do table.insert(guard, 1, table.remove(stock, i)) end
        for i = #guard, 1, -1 do table.insert(stock, 1, guard[i]) end
      else
        table.sort(stock, function(a, b) return d2(a.position, rec.pen.position) < d2(b.position, rec.pen.position) end)
      end
      local home = {}
      for i, u in ipairs(stock) do
        -- (With a lesson, a breed that loses to what killed the last wave stays at the gate too: small biters, -1 against
        -- gun turrets, were half of a wave sent against them.)
        local unfit = total > 0 and fit(u) < UNFIT
        if i <= HOME_GUARD or #units >= cap or unfit then table.insert(home, u) else table.insert(units, u) end
      end
      rec.stock = home
      local d = d2(rec.pen.position, target)
      if not bd or d < bd then origin, bd = rec, d end
    end
  end
  if cap > WAVE_MAX then
    trace(string.format("farm %d: the defence there held %d times; a wave of %d (at most %d)", f.id, held, #units, cap))
  end
  if total > 0 and #units > 0 then
    local by = {}
    for _, u in ipairs(units) do local n = u.name:gsub("^lp%-bred%-", ""); by[n] = (by[n] or 0) + 1 end
    trace(string.format("farm %d: its wave made up against what killed the last (%s): %s", f.id, serpent.line(lesson.killers),
      serpent.line(by)))
  end
  if #units < shared.WAVE_MIN or not origin then
    -- Not enough yet: back into the pens' stock.
    for _, u in ipairs(units) do table.insert(origin and origin.stock or herd.pen(f.pens[1]).stock, u) end
    return
  end
  f.last_wave = tick
  f.waves = (f.waves or 0) + 1
  f.aim = {x = target.x, y = target.y}
  f.last_size = #units
  local made = {}
  if f.want then
    for _, u in ipairs(units) do if f.want[u.name] then made[u.name] = (made[u.name] or 0) + 1 end end
    trace(string.format("farm %d: its wave carries of its order %s (ordered %s)", f.id, serpent.line(made), serpent.line(f.want)))
  end
  -- Its probe's runts, if it will throw them (herd.lua), at their price.
  -- Only what it can pay for (it was charged into debt; the faction AI audit, 2026-10-23).
  local cul = creep.of(f.id)
  local no_probe = false
  if cul and game.forces[B.force].get_evolution_factor(s) >= herd.PROBE_EVO then
    local price = herd.PROBE_N * shared.BREEDS["lp-runt"].cost
    if cul.biomass >= price then
      cul.biomass, cul.spent = cul.biomass - price, (cul.spent or 0) + price
    else
      no_probe = true
    end
  end
  trace(string.format("farm %d weighs: %s", f.id, choice.why))
  trials()[choice.key] = {tick = tick, defence = choice.defence}
  herd.launch(origin, target, {units = units, farm = f.id, forces = rival, no_probe = no_probe})
  trace(string.format("farm %d sends %d at %.0f,%.0f", f.id, #units, target.x, target.y))
end

-- Its incubators breed while it has biomass, and stop when it has none.
local function breeding(f, on)
  for _, pid in ipairs(f.pens) do
    local rec = herd.pen(pid)
    local want = on and not (rec and rec.unfed)
    if rec and rec.pen.valid and rec.pen.disabled_by_script ~= not want then rec.pen.disabled_by_script = not want end
  end
end

-- An incubator whose biochamber is dead: its stock over FED_CAP goes feral (the wild's force, out of the incubator's
-- hold); true once it has been unfed UNFED_WILD.
local function unfed(rec, tick)
  rec.unfed = rec.unfed or tick
  local all = herd.stock(rec)
  local feral = 0
  for i = FED_CAP + 1, #all do
    local u = all[i]
    if u.valid then
      if u.commandable and u.commandable.spawner then u.commandable.release_from_spawner() end
      u.force = "enemy"
      feral = feral + 1
    end
  end
  if feral > 0 then
    local keep = {}
    for i = 1, math.min(FED_CAP, #all) do keep[#keep + 1] = all[i] end
    rec.stock = keep
    rec.feral = (rec.feral or 0) + feral
  end
  return tick - rec.unfed >= UNFED_WILD
end

-- Its evolution: learned while its clinic stands, held at the stock's without it.
local function evolve(f, surface)
  local bf, enemy = game.forces[B.force], game.forces.enemy
  if not bf then return end
  f.evo = f.evo or bf.get_evolution_factor(surface)
  local up = cell.clinic_up(f.id)
  if up then
    f.evo = math.min(1, math.max(enemy and enemy.get_evolution_factor(surface) or 0, f.evo + CLIMB / 6))
  end
  bf.set_evolution_factor(up and f.evo or math.min(f.evo, STOCK_EVO), surface)
end

-- Obsolete stock recycled (2026-10-25): an incubator holds at most 40, and full of the small biters of its first
-- evolution it bred nothing newer (at 0.65 it breeds no small biter, yet its waves were half small biters, sent at gun
-- turrets that beat them). Once a minute a full incubator turns one unit its evolution no longer breeds back into
-- biomass (half its price), and breeds a current one in its place.
local RECYCLE_FULL = 0.9   -- of its capacity
breeds_at = function(evo)
  local out = {}
  for _, r in ipairs(prototypes.entity["lp-pen"].result_units or {}) do
    local pts, w = r.spawn_points, 0
    if evo <= pts[1].evolution_factor then w = evo == pts[1].evolution_factor and pts[1].weight or 0
    else
      w = pts[#pts].weight
      for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if evo <= b.evolution_factor then
          w = a.weight + (b.weight - a.weight) * (evo - a.evolution_factor) / math.max(1e-9, b.evolution_factor - a.evolution_factor)
          break
        end
      end
    end
    out[r.unit] = w
  end
  return out
end
-- The breeds whose evolution has come (past their first spawn point): what it can breed to order.
unlocked = function(evo)
  local out = {}
  for _, r in ipairs(prototypes.entity["lp-pen"].result_units or {}) do
    if evo > r.spawn_points[1].evolution_factor then out[r.unit] = true end
  end
  return out
end
local function recycle(f, rec, surface)
  local cap = prototypes.entity["lp-pen"].max_count_of_owned_units or 40
  local stock = herd.stock(rec)
  if #stock < cap * RECYCLE_FULL then return end
  local now = breeds_at(game.forces[B.force].get_evolution_factor(surface))
  for _, u in ipairs(stock) do
    if u.valid and (now[u.name] or 0) <= 0 and shared.BREEDS[u.name] then
      local cul = creep.of(f.id)
      if cul then cul.biomass = cul.biomass + math.floor(shared.BREEDS[u.name].cost / 2) end
      f.recycled = (f.recycled or 0) + 1
      u.destroy()
      return
    end
  end
end

function farm.tick(tick)
  if tick % 600 ~= 300 then return end
  local s = st()
  creep.drink(10)
  for id, f in pairs(s.list) do
    local left = {}
    local surface = game.surfaces[f.surface]
    -- Its substrate (older saves: built now) and its technicians' rounds.
    cell.site(id, surface, f.pos)
    cell.tick(id, surface, f.pens, tick)
    evolve(f, surface)
    -- Its order, once a minute: what it wants for the next wave, against what its incubators hold.
    local want, have
    if tick % 3600 == 300 then
      want = order(f, surface)
      local key = want and serpent.line(want) or nil
      if key ~= f.want_key then
        f.want_key = key
        if want then trace(string.format("farm %d: breeds to order for its next wave at %.0f,%.0f: %s", f.id, f.aim.x, f.aim.y, key)) end
      end
      f.want = want
      if want then
        have = {}
        for _, pid in ipairs(f.pens) do
          local rec = herd.pen(pid)
          if rec and rec.pen.valid then for _, u in ipairs(herd.stock(rec)) do have[u.name] = (have[u.name] or 0) + 1 end end
        end
      end
    end
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.pen.valid then
        -- Its cell (old saves had none: built now); its biochamber dead, it is unfed and goes wild in time.
        local c = cell.of(pid) or cell.build(pid, rec.pen, f.id, f.pos)
        -- Unfed: its biochamber dead, or stopped for want of a technician's visit.
        local hungry = c and (not (c.chamber and c.chamber.valid) or cell.hungry(c, tick))
        if not hungry and rec.unfed then rec.unfed = nil end
        if not hungry and tick % 3600 == 300 then
          recycle(f, rec, surface)
          if want then fulfil(f, rec, surface, want, have) end
          if want then fulfil(f, rec, surface, want, have) end
        end
        if hungry and unfed(rec, tick) then
          cell.forget(pid)
          herd.release(pid)
          f.lost_to_feed = (f.lost_to_feed or 0) + 1
          trace(string.format("farm %d: an incubator unfed for %d minutes went wild", f.id, UNFED_WILD / 3600))
        -- Off creep it starves, then goes wild.
        elseif creep.covered(surface, rec.pen.position) then
          rec.starving = nil
          table.insert(left, pid)
        else
          rec.starving = rec.starving or tick
          if tick - rec.starving >= STARVE then
            cell.forget(pid)
            herd.release(pid)
            f.lost_to_starving = (f.lost_to_starving or 0) + 1
            trace(string.format("farm %d: an incubator starved off its creep and went wild", f.id))
          else
            table.insert(left, pid)
          end
        end
      else
        cell.forget(pid)
      end
    end
    f.pens = left
    if have then f.short = short(want, have) elseif tick % 3600 == 300 then f.short = nil end
    local cul = creep.of(id)
    if cul then
      local t = #f.pens * TRICKLE / 6 * tune.strength("biotech")
      cul.biomass, cul.trickled = cul.biomass + t, (cul.trickled or 0) + t
      -- An order short: chance breeding waits while the biomass is kept for it.
      breeding(f, cul.biomass > (f.short or 0))
    end
    -- Grubstake on its creep: the truce is over.
    if not herd.grubstake_broken() then
      local g = shared.CORPS.grubstake.force
      for _, t in ipairs(creep.tumors_of(id)) do
        if surface.count_entities_filtered{position = t.position, radius = BREAK_NEAR, force = g, limit = 1} > 0 then
          herd.break_grubstake(string.format("Grubstake at its tumor at %.0f,%.0f", t.position.x, t.position.y))
          break
        end
      end
    end
    -- The creep takes the wild nest it reaches.
    local take = #left < PENS_MAX and creep.bud(id, tick)
    if take then
      local pid = herd.capture(take)
      local rec = pid and herd.pen(pid)
      if rec then
        rec.farm = f.id
        table.insert(f.pens, pid)
        creep.plant(surface, rec.pen.position, f.id)
        cell.build(pid, rec.pen, f.id, f.pos)
        f.taken = (f.taken or 0) + 1
        trace(string.format("farm %d: its creep took the nest at %.0f,%.0f (%d incubators)", f.id, rec.pen.position.x,
          rec.pen.position.y, #f.pens))
      end
    end
    if #left == 0 then
      gone(f, "every pen dead")
    else
      if not f.tagged then tag(f) end
      if not storage.herd_off and not herd.out(id) and tick - f.last_wave >= tune.sooner("biotech", WAVE_GAP) then send(f, tick) end
    end
  end
  if s.landing and tick - s.landing.sent > POD_WAIT then
    farm.land(game.surfaces[s.landing.surface], s.landing.at)
  end
  if next(s.list) == nil and not s.landing and not storage.biotech_off and tick >= (s.next_arrival or 0) then
    local enemy = game.forces.enemy
    local came = false
    for _, surface in pairs(game.surfaces) do
      if not came and enemy and enemy.get_evolution_factor(surface) >= ARRIVE_EVO then
        came = arrive(surface, FAR) or arrive(surface, FARTHEST)
      end
    end
    if not came then s.next_arrival = tick + RETRY end
  end
end

-- A birth at an incubator: its breed's price off its culture's biomass; at nothing left, its incubators stop.
function farm.on_spawned(e)
  local sp = e.spawner
  if not (sp and sp.valid and sp.name == "lp-pen") then return end
  local rec = herd.pen(sp.unit_number)
  local f = rec and rec.farm and st().list[rec.farm]
  local cul = f and creep.of(f.id)
  if not cul then return end
  local price = shared.BREEDS[e.entity.name] and shared.BREEDS[e.entity.name].cost or 7
  if e.entity.name == "lp-bred-cinder" then glow(e.entity) end
  cul.biomass, cul.spent, cul.bred = cul.biomass - price, (cul.spent or 0) + price, (cul.bred or 0) + 1
  if cul.biomass <= 0 then breeding(f, false) end
end

-- A pen hit by anyone at war with it: its farm's wave on its way comes home.
function farm.on_damaged(e)
  local ent = e.entity
  if e.force and e.force.name == shared.CORPS.grubstake.force then
    herd.break_grubstake(string.format("Grubstake hit its %s at %.0f,%.0f", ent.name, ent.position.x, ent.position.y))
  end
  if ent.name == "lp-tumor" then return end
  if ent.name ~= "lp-pen" or not e.force or e.force.name == B.force or shared.is_biters(e.force.name) then return end
  local rec = herd.pen(ent.unit_number)
  if rec and rec.farm and herd.out(rec.farm) then herd.recall(rec.farm, "its farm is attacked") end
end

-- Dev: every farm sends a wave at its next check, its pens topped up to send one.
function farm.debug_wave()
  local any = false
  for _, f in pairs(st().list) do
    local s = game.surfaces[f.surface]
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then bred_stock(s, rec.pen, math.max(0, HOME_GUARD + 10 - #herd.stock(rec))) end
    end
    f.last_wave = -WAVE_GAP
    any = true
  end
  return any
end

function farm.state()
  local s = st()
  local out = {next_arrival = s.next_arrival, landing = s.landing, farms = {}}
  for id, f in pairs(s.list) do
    local tags = 0
    for _, t in pairs(f.tags) do if t.valid then tags = tags + 1 end end
    local unfed, feral = {}, 0
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.unfed then unfed[#unfed + 1] = {id = pid, since = rec.unfed, active = rec.pen.valid and rec.pen.active,
        stock = #herd.stock(rec)} end
      feral = feral + (rec and rec.feral or 0)
    end
    table.insert(out.farms, {id = id, pos = f.pos, pens = #f.pens, pen_ids = f.pens, tags = tags, last_wave = f.last_wave,
      landed = f.landed, taken = f.taken or 0, recycled = f.recycled or 0, starved = f.lost_to_starving or 0, unfed = unfed, feral = feral,
      lost_to_feed = f.lost_to_feed or 0, evo = f.evo, clinic = cell.clinic_up(id),
      bred_evo = game.forces[B.force] and game.forces[B.force].get_evolution_factor(f.surface), biomass = creep.of(id) and {
        now = creep.of(id).biomass, drunk = creep.of(id).drunk, trickled = creep.of(id).trickled,
        spent = creep.of(id).spent or 0, bred = creep.of(id).bred or 0}})
  end
  return out
end

return farm
