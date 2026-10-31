-- The biotech's farms (docs/biotech.md; Fable's breeds consult, docs/reviews/2026-10-22-biotech-breeds-consult.md, "Home").
-- It comes once the wild biters' evolution on a surface reaches ARRIVE_EVO (there are mediums to breed by then): a cargo
-- pod comes down on the nest field with the most wild spawners in reach and pollution round it, FED_NEAR to FAR tiles
-- from the player's factory (to FARTHEST if none), and up to PENS of its spawners become
-- pens, each with START bred and WORMS bred worms. The farm is charted for the player, with a map tag; its first landing
-- is told in chat, as a corporation's is. It lives on the player's smoke: hunting it down along its trails, or starving
-- it, is the answer to it.
-- Its waves (scripts/herd.lua): one at a time, WAVE_GAP apart at the least, from its pens' stock but a home guard, at
-- most WAVE_MAX, sent from the pen nearest the target. A pen attacked recalls the wave on its way (the fight moves to the trail).
-- Every pen dead: the farm is gone (its tag too), and it lands again on another field RELAND later.
-- Creep (scripts/creep.lua): a tumor by each incubator; the creep spreads to the wild nests near, and each it reaches
-- becomes an incubator (up to PENS_MAX). An incubator left off creep (its tumors killed) starves for STARVE and goes
-- back to the wild, its stock with it.
-- Grubstake: a lasting truce (herd.init): it grows on the smoke Grubstake puts out.
-- Biomass: an incubator breeds only while its culture can pay (shared.BREEDS, the arena's prices): a culture earns what
-- its incubators and creep eat of the pollution (creep.drink), TRICKLE an incubator a minute whatever the air, and START_BIOMASS its
-- pod brought. Spent at each birth (on_entity_spawned); at nothing left its incubators stop (inactive) until it earns.
local shared = require("__landing-party__.shared")
local herd = require("__landing-party__.scripts.herd")
local pods = require("__landing-party__.scripts.pods")
local creep = require("__landing-party__.scripts.creep")
local cell = require("__landing-party__.scripts.cell")
local know = require("__landing-party__.scripts.know")
local firemap = require("__landing-party__.scripts.firemap")
local costmap = require("__landing-party__.scripts.costmap")
local feeds = require("__landing-party__.scripts.feeds")
local threat = require("__landing-party__.scripts.threat")
local valuemap = require("__landing-party__.scripts.valuemap")
local COUNTERS = require("__landing-party__.counters")
local tune = require("__landing-party__.scripts.tune")
local rng = require("__landing-party__.scripts.rng")

local farm = {}

local B = shared.BIOTECH
local ARRIVE_EVO = 0.25
local FAR, FARTHEST = 1000, 1500   -- NEAR (600) until 0.2.25: the pod now weighs every field FED_NEAR out
local SEARCH = 2500           -- nests looked at round the player's spawn, nearest first
local FED_NEAR = 250          -- a field in the cloud: none of the player's buildings within this
local FED_R, FED_MIN = 3, 2   -- the pollution in the 7 by 7 chunks round it (creep.food); a carrier's bare ground needs FED_MIN
local FOOD_K = 50             -- pollution round a field that doubles its worth to the pod
local ROOM_MAX = 30           -- wild spawners in a field's reach counted, at most
local CANDIDATES = 80         -- of those, how many are weighed
local REACH_HEARTS = 5        -- the base's soft hearts its landing weighs its way to
local REACH_CELL = 64         -- tiles a cell, for those (a megabase read once, on its landing)
local REACH_ENTRY = 400       -- (valuemap.hearts' own reach, unused: their way in is the cost map's)
local REACH_MARGIN = 150      -- the box its way is read in: out to its farthest field, this much more
local REACH_FLOOR = 0.25      -- a field with no way in still keeps this share of its score (room and air, for growth)
local FIELD, FIELD_MIN = 40, 3
local PENS = 4
local PENS_MAX = 16           -- a culture's incubators at most, taken by its creep (a safety: its food should stop it
                              -- first; 12 until 0.2.23, reached on a two-minute budding clock)
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
local TRICKLE = 3             -- biomass an incubator earns a minute, clean air or not
local START_BIOMASS = 200     -- what its pod brought (its first wave, ten minutes on)
local START = 6
local WORMS = 2
local HOME_GUARD = 6          -- per pen, kept at the gate when a wave goes, while the culture has PENS of them; past
local GUARD_TOTAL = PENS * HOME_GUARD   -- that the guard is shared out (twelve incubators kept 72 at home, and the
                                        -- player's nw farm sat at 20 ready of the 24 a wave needs for an hour)
local function guard_of(f) return math.ceil(GUARD_TOTAL / math.max(PENS, #f.pens)) end
-- A wave's most (the consult: waves of 20 to 60; the mega wave is an event at the top of its ladder, not the default).
-- Four full pens sent 135 in the first farm run.
local WAVE_MAX = shared.WAVE_MAX
-- A siege (a context-free review, 2026-10-28: with nothing it can field worth a wave, "change the mission, not go quiet"):
-- the way in to its best place becomes the job. It orders big bursters and a herd of big biters to cross the hole (the
-- wall lab: mediums behind them, 2 got in; big biters, 14), the cheapest mix its plan's way in pays for (siege_size). It
-- It ends on what happens, not on a clock (the user, 2026-10-28: "the clock is bad"; at an hour, a farm on a megabase gave
-- up every siege it laid, its bursters half bred): a wave of what it has paying somewhere better, its target gone, or its
-- plan, read again once its siege is bred, no longer paid by any siege it can field.
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
-- Big bursters on order: the wave waits for them longer (a nw visit, 2026-10-28: 3 ordered, none made in 5 minutes, and
-- waves of 90 big and medium biters went at a laser wall without them). 14 of them open a stretch of nw's north wall
-- (scripts/wall-lab.sh): a wave without them is lost there whatever its size.
local ORDER_WAIT_BIG = 30 * 3600

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

-- The nest field for its pod (the user, 2026-10-26: "shouldn't we tie this to pollution cloud coverage to ensure a new
-- culture can feed itself?"): of the fields with none of the player's buildings within FED_NEAR and some within `far`,
-- the one with the most room and air: the wild spawners its creep can reach (creep.HEDGE, ROOM_MAX at most), raised by
-- the pollution round it (creep.food, FED_R chunks; FOOD_K doubles it). Its growth is in nests to take, and its income
-- in its incubators (TRICKLE each) as much as in the air: on deathworld10x the cloud's edge held 6 of pollution, and a
-- pod sent for the air alone came down on three spawners and sent two waves in three hours (it had sent eleven from a
-- packed field 600 tiles out). Until 0.2.24, always the nearest field 600 to `far` out. Its middle and its spawners.
-- Whether a foe's artillery reaches pos (threat.artillery_reach: its pieces' range with its research, SHELL_SPARE more):
-- it shells every pen in reach until none is left (a culture landed 750 tiles from a base whose artillery reached it, and
-- all four of its pens were gone in seventy seconds, before a wave was bred; 2026-10-27).
local SHELL_SPARE = 40
local function shelled(surface, pos)
  for _, pf in ipairs(players()) do
    local r = threat.artillery_reach(pf)
    if r > 0 and surface.count_entities_filtered{position = pos, radius = r + SHELL_SPARE, force = pf,
      type = {"artillery-turret", "artillery-wagon"}, limit = 1} > 0 then return true end
  end
  return false
end

local function site(surface, far)
  local forces = players()
  if #forces == 0 then return nil end
  local origin = forces[1].get_spawn_position(surface)
  local nests = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = origin, radius = SEARCH}
  table.sort(nests, function(a, b) return d2(a.position, origin) < d2(b.position, origin) end)
  local weighed, best, bs, why = 0, nil, nil, nil
  local cands = {}
  local corps = corp_forces()
  for _, sp in ipairs(nests) do
    if weighed >= CANDIDATES then break end
    local p = sp.position
    if surface.count_entities_filtered{position = p, radius = FED_NEAR, force = forces, limit = 1} == 0 then
      weighed = weighed + 1
      if surface.count_entities_filtered{position = p, radius = far, force = forces, limit = 1} > 0
        and (#corps == 0 or surface.count_entities_filtered{position = p, radius = APART, force = corps, limit = 1} == 0) then
        local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = p, radius = FIELD}
        if #field >= FIELD_MIN then
          local x, y = 0, 0
          for _, f in ipairs(field) do x, y = x + f.position.x, y + f.position.y end
          local mid = {x = x / #field, y = y / #field}
          local room = math.min(ROOM_MAX, surface.count_entities_filtered{type = "unit-spawner", force = "enemy",
            position = mid, radius = creep.HEDGE})
          local food = creep.food(surface, mid, FED_R)
          local score = room * (1 + food / FOOD_K)
          if not shelled(surface, mid) then cands[#cands + 1] = {mid = mid, field = field, score = score, room = room, food = food} end
        end
      end
    end
  end
  -- And what its waves could take from there: a wave of WAVE_MAX's share kept reaching the base's soft hearts (REACH_HEARTS
  -- of them, valuemap.hearts), by one cost map read back from them (its fire, its walls, water). Landed for room and air
  -- alone, a culture came down across a lake from a megabase's open power fields, every way in round the lake through a
  -- mined gap and a laser line, and it razed nothing in three hours (2026-10-27).
  local reach = {}
  if #cands > 0 then
    local far_c = 0
    for _, c in ipairs(cands) do far_c = math.max(far_c, math.sqrt(d2(c.mid, origin))) end
    local radius = far_c + REACH_MARGIN
    local cell = radius > 1200 and costmap.CELL * 3 or costmap.CELL * 2
    -- (Everyone who would shoot its waves on the way, a corporation's camp and its army too.)
    local fmap = firemap.read(surface, origin, radius, herd.hostiles(), herd.price_of, threat.ARMED)
    -- Its soft hearts, worth against what getting in from the world outside costs (a cost map from the box's edge). By worth
    -- alone they were a megabase's core inside its laser ring; by rays 400 tiles out from each cell (firemap.entry_cost)
    -- that core read as open, the rays ending short of a perimeter 600 tiles off (2026-10-27).
    local outside = costmap.read(surface, origin, radius, forces, {fire = fmap, n = WAVE_MAX, cell = cell})
    local vmap = valuemap.read(surface, origin, far_c, forces, valuemap.CORE, REACH_CELL)
    local hearts = {}
    for _, h in ipairs(valuemap.hearts(vmap, fmap, WAVE_MAX, origin, REACH_ENTRY, {most = REACH_HEARTS,
      lost = function(mid) return costmap.cost(outside, mid) end})) do
      hearts[#hearts + 1] = h.cell.mid
      trace(string.format("its landing reads a soft heart at %.0f,%.0f: worth %.0f, its way in %.1f", h.cell.mid.x, h.cell.mid.y, h.worth, h.cost or -1))
    end
    if #hearts > 0 then
      local cm = costmap.read(surface, origin, radius, forces, {fire = fmap, n = WAVE_MAX, sources = hearts, cell = cell})
      for k, c in ipairs(cands) do reach[k] = costmap.cost(cm, c.mid) end
    end
  end
  for k, c in ipairs(cands) do
    local keeps = reach[k] and valuemap.keeps_lost(WAVE_MAX, reach[k]) or 0
    local score = c.score * (REACH_FLOOR + keeps)
    trace(string.format("its landing weighs the field at %.0f,%.0f: room %d, air %.0f, way %s, score %.1f", c.mid.x, c.mid.y,
      c.room, c.food, reach[k] and string.format("%.0f", reach[k]) or "none", score))
    if not bs or score > bs then best, bs, why = {c.mid, c.field}, score, {c.room, c.food, reach[k], keeps} end
  end
  if not best then return nil end
  trace(string.format("its landing: the field at %.0f,%.0f, %d wild spawners in reach, %.0f of pollution round it, its way to the base's soft hearts %s of its own (keeps %.2f)",
    best[1].x, best[1].y, why[1], why[2], why[3] and string.format("%.0f", why[3]) or "no way", why[4]))
  return best[1], best[2]
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
-- seeded: a culture founded by a carrier ({biomass = n}): one incubator, no worms, its clinic later, its biomass what the
-- carrier brought; told to no one (the first landing only is).
function farm.land(surface, pos, seeded)
  local s = st()
  if not seeded then s.landing = nil end
  local field = surface.find_entities_filtered{type = "unit-spawner", force = "enemy", position = pos, radius = FIELD + 10}
  table.sort(field, function(a, b) return d2(a.position, pos) < d2(b.position, pos) end)
  -- A carrier on bare ground (seed_site) founds an incubator of its own there.
  if #field == 0 and seeded then
    local q = surface.find_non_colliding_position("lp-pen", pos, 16, 1)
    local pen = q and surface.create_entity{name = "lp-pen", position = q, force = B.force}
    if pen then field = {pen} end
  end
  if #field == 0 then
    if seeded then return nil end
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
  for i = 1, math.min(seeded and 1 or PENS, #field) do
    local id = field[i].name == "lp-pen" and herd.add_pen(field[i]) or herd.capture(field[i])
    local rec = id and herd.pen(id)
    if rec then
      rec.farm = f.id
      table.insert(f.pens, id)
      bred_stock(surface, rec.pen, seeded and 2 or START)
      for _ = 1, seeded and 0 or WORMS do
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
  cell.site(f.id, surface, f.pos, seeded ~= nil)
  -- (Split as any income, young: its first buds from it, as when growth came first; creep.earn.)
  creep.earn(creep.of(f.id), seeded and seeded.biomass or START_BIOMASS * tune.strength("biotech"))
  f.seeded = seeded and game.tick or nil
  tag(f)
  trace(string.format("farm %d %s at %.0f,%.0f: %d pens", f.id, seeded and "seeded by a carrier" or "landed", pos.x, pos.y,
    #f.pens))
  if seeded then return f end
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
-- in reach by 64-tile cell, each scored by what there is to test (its defence, in its own: each turret at its price,
-- herd.price_of, learned per prototype; walls; the units there), how much the
-- trial would teach (its odds against that defence, p, the most when uncertain: 4p(1 - p)), whether it was tried
-- lately (novelty, coming back as the trial fades or the defence changes) and distance. Kessler-Hayashi's walls draw
-- trials as the player's do, on their merits. Its last trials (cell, defence, when) are kept in know.lua's record.
local STRUCK = 1              -- a grievance this big (value lost, fading) makes Kessler-Hayashi a target
local WALL_TYPES = {"wall", "gate"}
-- A place's defenders that move count too, a fifth of a turret's prior each, within GARRISON_REACH of it: weighed by its
-- turrets and walls alone, a Kessler-Hayashi camp with a few guns on its edge and a hundred units inside read as soft,
-- and in four-faction runs 15 of 19 waves came blind (the scout killed by its tanks, troopers and outposts) and lost half
-- their number to it (2026-10-25; alone against the stand-in, 1 of 24).
local UNIT_DEFENCE = 0.2
local WAYS_FOR = 5 * 3600   -- how long its reading of the ways in (ways_from) holds, a wave's end aside
local NO_WAY = 1e6           -- what a place with no way to it costs (water all round it in the box)
local WAYS_MARGIN = 150    -- the box it reads them in: round the places it weighs, this much more
local GARRISON_REACH = 96
-- And by what its waves there cost: the share that came home, with KEEP_PRIOR units' benefit of the doubt (a wave wiped
-- out leaves a quarter of the score; its odds model alone kept a Kessler-Hayashi outpost "worth learning from", and it
-- sent waves of 60 and 90 there in turn, none home, 2026-10-25).
local KEEP_PRIOR = 20

local function foes()
  local out = {}
  for _, f in ipairs(players()) do out[#out + 1] = f end
  -- Kessler-Hayashi only while it holds a grievance against it (the user, 2026-10-25: option 2): the player's enemy first,
  -- and an answer to Kessler-Hayashi when struck (an incubator, a tumor, a biochamber destroyed: its units lost on its
  -- own waves are no wrong done to it, know.lua). Its waves at Kessler-Hayashi's armies died to the last unit, 127 of
  -- 859 home in four-faction runs, while its pressure on the player was the point of it.
  local ks = shared.CORPS.serenity.force
  if game.forces[ks] and know.grievance("biotech", ks) >= STRUCK then out[#out + 1] = game.forces[ks] end
  return out
end

local NOVELTY_REACH = 192   -- a trial counts for the same force's ground this near (three cells)
local function trials()
  local k = know.of("biotech")
  k.trials = k.trials or {}
  return k.trials
end

-- What reaching each place costs it one way, in its own (costmap from `pos` over a box round it and them all): {[cell
-- key] = cost}. Kept on the farm (numbers only) WAYS_FOR, or until a wave ends.
local function ways_from(surface, pos, f, cells)
  local ended = storage.herd and storage.herd.log and #storage.herd.log or 0
  local kept = f.ways
  if kept and game.tick - kept.tick < WAYS_FOR and kept.ended == ended then return kept.by, kept.cover or {} end
  -- From where it is, in a box round it and them all (from the box's every edge, a place across a lake from its pens read
  -- as close, and its waves, unable to route there, broke in 1,200 tiles from it; 2026-10-27).
  local x0, y0, x1, y1 = pos.x, pos.y, pos.x, pos.y
  for _, c in pairs(cells) do
    x0, y0 = math.min(x0, c.at.x), math.min(y0, c.at.y)
    x1, y1 = math.max(x1, c.at.x), math.max(y1, c.at.y)
  end
  local by, cover = {}, {}
  if next(cells) then
    local mid = {x = (x0 + x1) / 2, y = (y0 + y1) / 2}
    local radius = math.max(x1 - x0, y1 - y0) / 2 + WAYS_MARGIN
    local forces = foes()
    -- (Its foes' hidden costs, the dearest: one reading for all of them.)
    local hidden = 0
    for _, fo in ipairs(forces) do hidden = math.max(hidden, herd.hidden_cost(fo.name)) end
    local fmap = firemap.read(surface, mid, radius * firemap.BOX, herd.hostiles(), herd.price_of, threat.ARMED)
    -- (Its fire scaled by what crossing has cost against what it expected, when its mind calibrates: know.scale.)
    local scale = 1
    if B.mind.calibrate then for _, fo in ipairs(forces) do scale = math.max(scale, know.scale("biotech", fo.name)) end end
    -- One reading, at its waves' own grain and with their plan's options (herd.plan), shared with the plans it makes this
    -- tick (herd.shared): its weighing and its waves' plans read the same map (the design consult, 2026-10-30, step 2:
    -- read at 32 and 48 tiles without walls, rams or screens, its weighing and its plans disagreed, and the farm wrote
    -- refusals back between them; at 16 tiles a weighing of the user's fort cost 100 ms, a plan already 116).
    local cm = costmap.read(surface, mid, radius, forces, {fire = fmap, n = WAVE_MAX, deaths = herd.deaths(), blocked = herd.blocked(), hidden = hidden, from = pos, scale = scale,
      cell = storage.biotech_ways_cell or herd.PLAN_CELL, margin = herd.spread(WAVE_MAX), ground_cost = costmap.GROUND_COST,
      wall_forces = herd.hostiles()})
    herd.shared = {tick = game.tick, from = {pos.x, pos.y}, cm = cm, fmap = fmap}
    -- (And how many guns cover where each way breaks in: what its bursters would be sent at, herd.way_cost.)
    local paths = storage.march_trace and {} or nil
    for key, c in pairs(cells) do
      by[key] = costmap.cost(cm, c.at)
      local way = by[key] and costmap.way_in(cm, c.at)
      cover[key] = way and #firemap.cover(fmap, way.breach) or 0
      if paths and by[key] then
        local pts = {}
        for _, q in ipairs(costmap.path(cm, c.at) or {}) do pts[#pts + 1] = {q.x, q.y} end
        paths[#paths + 1] = {at = {c.at.x, c.at.y}, cost = by[key], cover = cover[key], path = pts,
          breach = way and {way.breach.x, way.breach.y}}
      end
    end
    -- (Debugging, march_trace: its reading, for scripts/raidmap.py.)
    if paths then
      local cells_out = {}
      for k, v in pairs(cm.cost) do
        local p = cm.cell_cost[k]
        cells_out[#cells_out + 1] = {math.floor(k / cm.h), k % cm.h, v >= math.huge and -1 or v, p and (p >= math.huge and -1 or p) or 0}
      end
      helpers.write_file(string.format("landing-party/costmaps/farm%d-%d.json", f.id, game.tick), helpers.table_to_json({farm = f.id,
        tick = game.tick, from = {pos.x, pos.y}, x0 = cm.x0, y0 = cm.y0, size = cm.size, w = cm.w, cells = cells_out, ways = paths,
        hidden = hidden, scale = scale}))
    end
  end
  f.ways = {tick = game.tick, ended = ended, by = by, cover = cover, sieges = {}}
  return by, cover
end

-- opts: bursters (big bursters in its stock: its way in priced with them, herd.way_cost), field (the most it could field:
-- what a siege is sized for).
local siege_size   -- below: what a siege at a plan costs and holds
local ATTEMPT_FADED = 0.1   -- an attempt faded below this weight (herd.attempt) says nothing: tried long ago, not tried
local RAMS_SHARE = 0.5   -- of a siege, its big bursters at the most
local RAMS_MAX = 5       -- its big bursters at a walled breach, at the most
local CUT_LOOKS, CUT_R = 3, 200   -- cuts a fresh reading plans a way to, and how far round its best place it reads feeds
local SIEGE_LOOKS = 4   -- places a fresh reading sizes a siege at: its best that a wave of what it has does not win
local function target_from(surface, pos, f, n, opts)
  local mind = B.mind
  opts = opts or {}
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
      if threat.profile(e.name) and threat.profile(e.name).kind ~= "artillery" and threat.firing(e) then
        c.defence = c.defence + herd.price_of(e)
      end
      c.value = (c.value or 0) + valuemap.worth_of(e)
      -- An artillery piece reaching its incubators: worth SHELLS for each (herd.shelling).
      if e.type == "artillery-turret" or e.type == "artillery-wagon" then
        local shelled = herd.shelling(e)
        if shelled > 0 then c.value, c.shells = c.value + valuemap.SHELLS * shelled, (c.shells or 0) + shelled end
      end
      local d = d2(e.position, pos)
      if not c.d or d < c.d then c.d, c.at = d, {x = e.position.x, y = e.position.y} end
    end
  end
  local tried = trials()
  local ranked = {}
  -- The way in counts (there and back): a cell with no gun of its own inside a ring of them read as
  -- open, and every wave went at the factory through the ring and lost half its number there, in and out (2026-10-27).
  -- What reaching each place costs (costmap: its fire, its walls, the deaths its waves met there, and the walk from here to
  -- the base's edge), read over the base in one search and kept WAYS_FOR or until a wave ends (its rays read a megabase's
  -- way in as free over water and through minefields, and it sent waves of 25 to 42 that all died; 2026-10-27).
  local ways, covers = ways_from(surface, pos, f, cells)
  local field = math.max(n or 0, opts.field or 0)
  for _, c in pairs(cells) do
    c.entry = ways[c.key] or NO_WAY
    local openable = nil
    c.cover = covers[c.key] or 0
    local raw = c.entry
    c.entry = herd.way_cost(raw, c.cover, opts.bursters, openable, c.force)
    local guns = c.defence
    do
      c.walls = surface.count_entities_filtered{area = {{c.cx * 64, c.cy * 64}, {c.cx * 64 + 64, c.cy * 64 + 64}},
        type = WALL_TYPES, force = c.force}
      local extra = c.walls / mind.per_wall * mind.per_turret
      -- Its units, each at what that kind has cost it (know.price, learned at its breaches like a turret's), UNIT_DEFENCE of a
      -- turret before it knows: at a fifth of a turret each, a corporation's camp of railgunners and tanks read as cheap, and
      -- it sent three waves of 94 to 179 there that died nearly to the last (railgunners had cost it 40 each; 2026-10-27).
      c.units = 0
      for _, u in ipairs(surface.find_entities_filtered{position = {c.cx * 64 + 32, c.cy * 64 + 32}, radius = GARRISON_REACH,
        type = {"unit", "spider-unit"}, force = c.force}) do
        c.units = c.units + 1
        extra = extra + (know.price("biotech", c.force, u.name) or UNIT_DEFENCE * mind.per_turret)
      end
      -- (Its own guns too, opened in the share its bursters open the way's: the guns covering where it breaks in are its
      -- own where the place is the wall; counted whole, a siege's odds stayed nothing at every wall, and none was laid.)
      local function defence_at(entry, k) return math.max(guns * (1 - herd.opened(c.cover, k, openable, c.force)), 2 * entry) + extra end
      c.guns, c.extra = guns, extra
      c.defence = defence_at(c.entry, opts.bursters)
      -- Its odds: what a wave of n keeps there (valuemap.keeps_lost: its defence there and back, in its own).
      local p = valuemap.keeps_lost(n or shared.WAVE_MIN, c.defence / 2)
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
      -- What it would win (its odds times what stands there), and what it would learn (a close fight, and the harder the
      -- more it teaches). Learning alone, it went at a deathworld's turret ring, a 50/50 fight with nothing behind it, and
      -- never at the mining outpost north of it, 95 drills under 4 turrets: a sure win taught it nothing (2026-10-27).
      c.gain = c.odds * c.value
      c.learn = (1 + c.defence / mind.per_turret) * c.teach * c.novelty
      c.score = (c.gain + c.learn) * c.kept / (1 + c.dist / mind.far)
      -- Whether a wave of n goes in there at all (the wave's own test), and if not, how many big bursters would make the
      -- way in one a wave it could field takes and wins something past (a siege).
      c.passes = raw < NO_WAY and herd.affords(n or shared.WAVE_MIN, c.entry)
      c.raw = raw
      ranked[#ranked + 1] = c
    end
  end
  -- Those it can go into first; then by score; then, all scoring nothing, the cheapest way in (all at 0.00, the tie went
  -- by the order pairs() gave, the same wall corner 8 times of 10; a context-free review, 2026-10-28).
  table.sort(ranked, function(a, b)
    if a.passes ~= b.passes then return a.passes end
    if a.score ~= b.score then return a.score > b.score end
    if a.entry ~= b.entry then return a.entry < b.entry end
    return a.key < b.key
  end)
  local why = {}
  for k = 1, math.min(3, #ranked) do
    local c = ranked[k]
    why[#why + 1] = string.format("%s at %.0f,%.0f: defence %.1f (%d walls, %d units, the way in %.0f, %d guns covering it), odds %.2f, worth %d, wins %.1f, teaches %.2f, novelty %.2f, learns %.1f, kept %.2f, %.0f tiles, score %.2f%s%s",
      c.force, c.at.x, c.at.y, c.defence, c.walls, c.units or 0, c.entry, c.cover, c.odds, c.value or 0, c.gain, c.teach, c.novelty, c.learn,
      c.kept, c.dist, c.score, c.passes and "" or ", it cannot go in", c.siege and string.format(", a siege with %d big bursters", c.siege) or "")
  end
  local best = ranked[1]
  if not best then return end
  -- Its sieges, weighed as its waves will make them: on a fresh reading, at the SIEGE_LOOKS best places a wave of what it
  -- has does not win, each its plan on the same map (herd.plan, herd.shared) and its size (siege_size), kept with the
  -- reading (f.ways.sieges) until it is read again. One model: weighed apart from its plans, sieges it laid were refused
  -- by them and written back as refusals (the design consult, 2026-10-30).
  -- (Its places by what they are worth, for its sieges and its probes: by the weighing's score, all 0 at a fort no wave
  -- wins, its sieges went to a cell of the user's fort's wall worth 37 with little behind it, got in, and razed nothing
  -- five times running; the siege lab, 2026-10-30.)
  local by_worth = {}
  for _, c in ipairs(ranked) do by_worth[#by_worth + 1] = c end
  table.sort(by_worth, function(a, b)
    if (a.value or 0) ~= (b.value or 0) then return (a.value or 0) > (b.value or 0) end
    return a.key < b.key
  end)
  if f.ways and f.ways.tick == game.tick and f.ways.sieges and field > 0 then
    local looked, said = 0, {}
    for _, c in ipairs(by_worth) do
      if looked >= SIEGE_LOOKS then break end
      -- (Where a raid would win as well: its menu weighs them against each other, menu. Sized only where no raid won, a
      -- siege never met a raid in it.)
      if c.cover > 0 and (c.raw or NO_WAY) < NO_WAY then
        looked = looked + 1
        local rival = not shared.is_player_force(game.forces[c.force]) and {c.force} or nil
        local pl = herd.plan(surface, pos, c.at, rival or players(), WAVE_MAX)
        if not pl then said[#said + 1] = string.format("%.0f,%.0f no plan", c.at.x, c.at.y) end
        if pl then
          local k, n, price, breed, need, fodder, proven = siege_size(f, pl, {guns = c.guns, extra = c.extra, value = c.value, rival = rival})
          said[#said + 1] = string.format("%.0f,%.0f plan %.0f (%d guns, walled %s): %s", c.at.x, c.at.y, pl.cost, pl.cover,
            tostring(pl.walled), k and string.format("%d rams, %d, %d biomass", k, n, price) or "none fits")
          if k then
            f.ways.sieges[c.key] = {at = {x = c.at.x, y = c.at.y}, key = c.key, k = k, n = n, price = price, breed = breed,
              need = need, fodder = fodder, plan = pl, cover = pl.cover, defence = c.defence, value = c.value or 0,
              rival = rival, guns = c.guns, extra = c.extra, dist = c.dist, proven = proven}
          end
        end
      end
    end
    if #said > 0 then trace(string.format("farm %d sizes its sieges: %s", f.id, table.concat(said, "; "))) end
    -- Its cuts (the user, 2026-10-30: "a pipe that is free on the cost map is an undefended pipe"): what feeds the guns
    -- round its best place (feeds.lua: the pipe, pole or belt whose loss parts the most of them from their supply), by
    -- what the guns it parts cost it over what reaching it costs on the one reading; the CUT_LOOKS best planned, those
    -- past no wall kept with the reading (f.ways.cuts).
    local top = by_worth[1]
    local sm = herd.shared
    if top and sm and sm.tick == game.tick then
      local rival = not shared.is_player_force(game.forces[top.force]) and {top.force} or nil
      local list = {}
      for _, c in pairs(feeds.read(surface, top.at, CUT_R, rival or players(), herd.price_of)) do
        local reach = c.e.valid and costmap.cost(sm.cm, c.e.position)
        if reach and reach < NO_WAY then
          c.reach, c.v = reach, c.price / (1 + reach)
          list[#list + 1] = c
        end
      end
      table.sort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.e.unit_number < b.e.unit_number
      end)
      f.ways.cuts = {}
      local cut_said = {}
      for k = 1, math.min(CUT_LOOKS, #list) do
        local c = list[k]
        local at = {x = c.e.position.x, y = c.e.position.y}
        local pl = herd.plan(surface, pos, at, rival or players(), shared.WAVE_MIN)
        cut_said[#cut_said + 1] = string.format("%s at %.0f,%.0f parts %d guns (%.0f), reached for %.0f%s", c.e.name, at.x,
          at.y, c.starves, c.price, c.reach, pl and (pl.walled and ", past a wall" or "") or ", no plan")
        if pl and not pl.walled then
          -- (What it would win: its best place's worth, in the share of its guns the cut parts; credited with those guns'
          -- price, a cut scored 70 to a raid's 0.02 on the fed lab fort, the two in different units.)
          local share = math.min(1, c.price / math.max(1, top.guns or 0))
          f.ways.cuts[#f.ways.cuts + 1] = {e = c.e, at = at, starves = c.starves, price = c.price, held = c.held, plan = pl,
            gain = (top.value or 0) * share,
            strike = {at = {x = top.at.x, y = top.at.y}, value = top.value or 0, defence = top.defence or 0, force = top.force},
            rival = rival, dist = math.sqrt(d2(at, pos)), key = herd.attempt_key(rival and rival[1] or "player", at)}
        end
      end
      if #cut_said > 0 then trace(string.format("farm %d reads its cuts: %s", f.id, table.concat(cut_said, "; "))) end
    end
  end
  -- Its best siege: by what it wins for each burster, near first (by the fewest bursters alone it laid siege to a place
  -- worth 9).
  local sg, sv
  for _, s in pairs(f.ways and f.ways.sieges or {}) do
    local v = (s.value or 0) / (1 + s.k) / (1 + (s.dist or 0) / mind.far)
    if not sv or v > sv or (v == sv and s.key < sg.key) then sg, sv = s, v end
  end
  local rival = not shared.is_player_force(game.forces[best.force]) and {best.force} or nil
  -- The trial is recorded, and the weighing traced, when a wave goes (send): waiting for a bigger wave or its order it
  -- weighs again every ten seconds, and each weighing marked its choice tried, until every place read as just tried
  -- (novelty 0.01 everywhere) and the place it went was all but chance (0.2.14 to 0.2.18).
  -- Its three best, as numbers, for the wave's record (scripts/wavemap.py plots and tables them).
  local top = {}
  for k = 1, math.min(3, #ranked) do
    local c = ranked[k]
    top[k] = {at = {c.at.x, c.at.y}, force = c.force, worth = c.value or 0, entry = c.entry, defence = c.defence,
      odds = c.odds, score = c.score}
  end
  return best.at, rival, {key = best.key, defence = best.defence, why = table.concat(why, "; "), top = top, gain = best.gain,
    passes = best.passes, siege = sg, sieges = f.ways and f.ways.sieges or {}, cuts = f.ways and f.ways.cuts or {},
    odds = best.odds, dist = best.dist,
    value = best.value or 0, strength = n or shared.WAVE_MIN, places = (function()
      local out = {}
      for k = 1, math.min(SIEGE_LOOKS, #by_worth) do
        local c = by_worth[k]
        out[k] = {at = {c.at.x, c.at.y}, force = c.force, worth = c.value or 0, defence = c.defence}
      end
      return out
    end)()}
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

-- Hatched at launch (the faction consult, docs/reviews/2026-10-29-synthexis-faction-consult.md): its army is its biomass,
-- made units at its incubators when a wave goes, and the engine breeds each incubator's home guard alone. Bred by the
-- engine up to 40 an incubator and crowded by its neighbours (max_friends_around_to_spawn), a culture of 7 held 60 while
-- it weighed sieges as if it held 280, and sat on 13,000 biomass it could turn into nothing; five cultures kept 645 idle
-- units (nw, 2026-10-29). storage.biotech_old_stock (debug_tune old_stock): the old way, side by side.
local function hatching() return not storage.biotech_old_stock end
-- The evolution its incubators breed at: its own while its clinic stands, held at the stock's without (evolve).
local function evo_of(f, surface)
  local e = f.evo or game.forces[B.force].get_evolution_factor(surface)
  return cell.clinic_up(f.id) and e or math.min(e, STOCK_EVO)
end
-- Its incubators' chance breeds at that evolution, by name, and their mean price (and mean strength, herd.strength).
-- tilt(name): a breed's fit against what killed its last wave there (fit_of), its chance times 1 + that, held within
-- TILT: none left out, none more than doubled (the design consult, 2026-10-30, G: a breed under UNFIT had been left out
-- of raids, and a siege's herd, filtered so, was 270 cinders at the user's fort; sieges then took no lesson at all).
local TILT_LOW, TILT_HIGH = -0.9, 1
local function chance(f, surface, tilt)
  local list, total, sum, worth = {}, 0, 0, 0
  for name, w in pairs(breeds_at(evo_of(f, surface))) do
    if w > 0 and tilt and shared.BREEDS[name] then
      w = w * (1 + math.max(TILT_LOW, math.min(TILT_HIGH, tilt(name))))
    end
    if w > 0 and shared.BREEDS[name] then
      list[#list + 1] = {name = name, w = w}
      total, sum = total + w, sum + w * shared.BREEDS[name].cost
      worth = worth + w * herd.strength({name})
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list, total, total > 0 and sum / total or 7, total > 0 and worth / total or 1
end
-- How many it could hatch with what it holds over keep: its biomass over its chance breeds' mean price.
local function hatchable(f, surface, keep)
  local cul = creep.of(f.id)
  if not cul then return 0 end
  local _, _, mean = chance(f, surface)
  return math.max(0, math.floor((cul.biomass - (keep or 0)) / mean))
end
-- A wave's breeds to hatch, names only, within budget: its order first (want, less what it has), the dearest first, then
-- by chance at its evolution (tilted: chance).
-- strong: hatched by chance until its strength is that much (herd.strength), not n heads: a siege's herd drawn n heads of
-- the mix came short of the strength its plan asked, and was refused four times running (the user's fort, 2026-10-30).
local function compose(f, surface, n, want, have, tilt, budget, strong)
  local names, spent, order = {}, 0, {}
  for name in pairs(want or {}) do if shared.BREEDS[name] then order[#order + 1] = name end end
  table.sort(order, function(a, b)
    local ca, cb = shared.BREEDS[a].cost, shared.BREEDS[b].cost
    if ca ~= cb then return ca > cb end
    return a < b
  end)
  for _, name in ipairs(order) do
    local price = shared.BREEDS[name].cost
    for _ = 1, want[name] - ((have or {})[name] or 0) do
      if #names >= n or spent + price > budget then break end
      names[#names + 1], spent = name, spent + price
    end
  end
  local list, total = chance(f, surface, tilt)
  f.rng = f.rng or rng.new(f.id * 7919 + game.tick)
  local got = strong and herd.strength(names) + (strong.have or 0) or 0
  -- (Drawn to its strength, n heads at the most all the same: WAVE_MAX for a siege. And to strong.least heads at the least:
  -- its strength reached with 4 behemoths, a star fort siege came to 22 of the 24 it ever sends, and waited; 2026-10-31.)
  while total > 0 and #names < n and (not strong or got < strong.need or #names < (strong.least or 0)) do
    local r, pick = rng.next(f.rng) * total, list[#list].name
    for _, x in ipairs(list) do
      r = r - x.w
      if r <= 0 then pick = x.name; break end
    end
    local price = shared.BREEDS[pick].cost
    if spent + price > budget then break end
    names[#names + 1], spent = pick, spent + price
    if strong then got = got + herd.strength({pick}) end
  end
  return names, spent
end
-- A wave's list made units: each name hatched at its incubators in turn (or at one, at), paid from its biomass; units
-- kept as they are.
local function hatch(f, surface, units, at)
  local cul, pens = creep.of(f.id), {at}
  if not at then
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then pens[#pens + 1] = rec end
    end
  end
  local out, k = {}, 0
  for _, u in ipairs(units) do
    if type(u) == "string" then
      k = k + 1
      local rec = cul and pens[(k - 1) % math.max(1, #pens) + 1]
      local p = rec and surface.find_non_colliding_position(u, rec.pen.position, 32, 0.5)
      local e = p and surface.create_entity{name = u, position = p, force = B.force}
      if e then
        local price = shared.BREEDS[u].cost
        cul.biomass, cul.spent, cul.bred = cul.biomass - price, (cul.spent or 0) + price, (cul.bred or 0) + 1
        f.hatched = (f.hatched or 0) + 1
        if u == "lp-bred-cinder" then glow(e) end
        out[#out + 1] = e
      end
    elseif u.valid then out[#out + 1] = u end
  end
  return out
end
-- The name of a wave's member, hatched or still a name.
local function name_of(u) return type(u) == "string" and u or u.valid and u.name end
-- What it could field, how many and how strong (herd.strength): what stands over its guards and, hatching, what its
-- biomass hatches; else its incubators full. (And, hatching, the biomass that is: what stands over its guards at its
-- price, and what it holds.)
local function field_of(f, surface, guarded)
  local _, _, mean, worth = chance(f, surface)
  if hatching() then
    local over, strong, price = 0, 0, 0
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then
        local stock = herd.stock(rec)
        for i = guard_of(f) + 1, #stock do
          local u = stock[i]
          if u.valid then
            over, strong = over + 1, strong + herd.strength({u})
            price = price + (shared.BREEDS[u.name] and shared.BREEDS[u.name].cost or mean)
          end
        end
      end
    end
    local cul = creep.of(f.id)
    local more = hatchable(f, surface)
    return over + more, strong + more * worth, price + math.max(0, cul and cul.biomass or 0)
  end
  local n = #f.pens * ((prototypes.entity["lp-pen"].max_count_of_owned_units or 0) - (guarded and guard_of(f) or 0))
  return n, n * worth
end

-- Its order for the next wave (nil: none, it sends what it bred): by breed, how many it wants in its stock.
-- The siege a farm can field against a plan (herd.plan): the cheapest mix in biomass of big bursters (no more than the guns
-- they can reach take: herd.BURST_OPENS of one each) and a herd, that pays the plan's way in (herd.affords, the bursters'
-- work counted), within what its incubators hold (their count times an incubator's units). nil: none it can field. (The
-- user, 2026-10-28: "avoid hard coding": its waves were sized at a fixed 120 and its bursters at most 20, and at a
-- megabase's wall no siege could be laid.) Returns bursters, herd, its price.
-- Its siege (the user, 2026-10-30: in health): big bursters, rams at a walled breach and openers of the guns they reach,
-- and a herd of the culture's own mix as many as pay the way in (herd.strength), within what its incubators could hold
-- (in biomass, hatching). Returns bursters, herd, its price, "mixed".
siege_size = function(f, pl, place, floor)
  -- (What its incubators hold over their guard, each: what it can send; `floor`, the tests' least budget.)
  local s = game.surfaces[f.surface]
  local count, _, budget = field_of(f, s, true)
  if floor then budget = math.max(budget or 0, floor) end
  -- (Hatching, within the biomass its incubators could hold, full: what it waits for, not only what it has. Laid only
  -- on what it had, it refused the best place for want of an hour's biomass and laid siege to a worse one sooner.)
  if budget then
    local cap = prototypes.entity["lp-pen"].max_count_of_owned_units or 0
    budget = math.max(budget, #f.pens * math.max(0, cap - guard_of(f)) * select(3, chance(f, s)))
  end
  -- Its herd the culture's own mix, by chance at its evolution as any wave's (chance): its price and strength a unit the
  -- mix's means. (The breed with the most health for its biomass, a siege of the user's fort was 42 to 61 behemoths and
  -- its big bursters, nothing else: the user, 2026-10-30, "behemoth can't be the only unit besides bursters even if the
  -- culture would love to".)
  local _, _, hc, hw = chance(f, s)
  local breed = "mixed"
  local bc = shared.BREEDS["lp-bred-big-burster"].cost
  local reach = pl.openable or pl.cover or 0
  local best, least
  local foe = place and place.rival and place.rival[1] or "player"
  -- Its big bursters are rams (the user, 2026-10-30: "bursters should clearly be understood like siege rams that break
  -- heavily fortified walls"): at a walled breach, enough that one reaches the wall alive (herd.reach, learned), whatever
  -- guns they can reach. (Valued only for the guns their blast reached, it laid a siege of 45 behemoths and no burster at
  -- the user's fort, whose guns stand 6 to 16 tiles behind its wall; the siege lab.)
  -- A handful at the most (RAMS_MAX): they punch through the wall, nothing more (the user, 2026-10-31: "43 burster what
  -- the fuck. At most we shouldn't need more than a handful as it's all about punching through the wall"). Openers of the
  -- guns besides, each paying for itself where they had opened many, a siege of the square lab fort was 43 of them.
  local rams = pl.walled and math.min(RAMS_MAX, math.ceil(1 / herd.reach(foe))) or 0
  -- And with its rams a screen, the front of its herd, sent at the wall ahead of them while the rest waits out of reach
  -- (herd.lua sequence): the guns' fire on it, not on its rams, nor on its herd standing
  -- at the wall (screened by its whole herd, a siege of the user's fort got its ram to the wall, and its herd, at the wall
  -- under the flamethrowers meanwhile, lost 692 of 746; the user, 2026-10-30: "build the fodder screen").
  -- (One of its cheapest breed for each gun covering its breach. Sized as strong as those guns cost to cross, of its mix,
  -- and its herd behind it paying them no more, its sieges of the user's fort shrank to 22 and broke nothing; the siege
  -- lab, 2026-10-30.)
  local fodder = rams > 0 and (pl.cover or 0) or 0
  local fc = shared.BREEDS[herd.FODDER].cost
  -- (With its rams and its screen, its herd waits out of reach while the wall is blown: it pays the crossing, not the
  -- standing at the wall, pl.standing. Priced standing there, every siege of the user's fort asked more than 60 could pay,
  -- and its screen was never laid; the siege lab, 2026-10-30.)
  local base = pl.cost - (rams > 0 and (pl.standing or 0) or 0)
  local mem, wt = herd.attempt(foe, pl.target, "siege")
  -- (Proven by what it razed there, not by getting in: in and razing nothing, five sieges at one breach of the user's fort.
  -- Sized as the one that razed most for what it spent: sized on what a siege spent, its sieges of 34 to 38 lost 230 to 300
  -- and razed 3 to 24, where its probes of 24 had lost 110 and razed up to 41; the siege lab, 2026-10-30.)
  local proven, proven_rams
  if mem and wt > ATTEMPT_FADED then
    proven, proven_rams = herd.best_size(mem, B.mind.min_gain or 0, herd.place_sig(s, place and place.rival or players(), pl.target))
  end
  -- And as many rams as that siege brought, whatever its share since (one that got in with 4 drew its share up, the next
  -- brought 2 and stood at the inner of two walls; the lane, 2026-10-31).
  if proven_rams and rams > 0 then rams = math.min(RAMS_MAX, math.max(rams, proven_rams)) end
  for k = rams, rams do
    local lost = herd.way_cost(base, pl.cover, k, pl.openable, foe)
    -- Its herd pays its way in once and the place's guns once (what its rams leave of them), and is not to come back: a
    -- siege is a ram and the herd behind it, spent breaking in (the user, 2026-10-30). Sized to come back with half past
    -- every gun, its herd at the user's fort grew trial by trial as it learned their price, 122 units, then 334, then 516.
    -- (Twice its way in at the least: the wave's own test, herd.affords.)
    local need = 2 * lost
    if place and place.guns then
      need = math.max(need, lost + place.guns * (1 - herd.opened(pl.cover, k, pl.openable, foe)) + (place.extra or 0))
    end
    -- Where its sieges have got in at this breach, what they spent there, not what its prices add up to (herd.attempt,
    -- the design consult's step 3). (Priced from its guns alone, the user's fort read as more than 60 could take, though
    -- sieges of 42 to 60 had got in there four times.)
    if proven then need = proven end
    -- (No smaller than the least wave it sends, WAVE_MIN: a siege of 4 bursters and 11 at the star fort's cheap corner
    -- waited six trials for a wave it would never send, "13 ready, 24 the least it sends"; the siege lab, 2026-10-31.)
    local n = math.max(math.floor(need / hw) + 1, shared.WAVE_MIN - k - fodder)
    local price = k * bc + n * hc + fodder * fc
    if not least or price < least then least = price end
    -- (No bigger than any wave, WAVE_MAX: a place that asks more is not besieged, its farm weighs another.)
    -- (And no more than half of it bursters, RAMS_SHARE: each opener paying for itself where they had opened many, a siege
    -- of the square lab fort was 43 big bursters and 17 others; the user, 2026-10-30, mixed sieges, no floods.)
    if k <= RAMS_SHARE * (n + k + fodder) and n + k + fodder <= WAVE_MAX and ((budget and price <= budget) or (not budget and n + k + fodder <= count)) then
      if not best or price < best[3] then best = {k, n, price} end
    end
  end
  if best then return best[1], best[2], best[3], breed, best[2] * hw + fodder * herd.strength({herd.FODDER}), fodder, proven ~= nil end
  -- (None: what the cheapest would cost, hatching: the biomass it waits for before it weighs that siege again.)
  return nil, budget and least or nil
end

local function order(f, surface)
  if B.mind.orders == false or storage.biotech_no_orders or not f.aim then return nil end
  local can = unlocked(game.forces[B.force].get_evolution_factor(surface))
  local want = {}
  -- A siege laid (send): its big bursters, and the big biters its herd lacks (siege_size).
  if f.siege and can["lp-bred-big-burster"] then
    if f.siege.k > 0 then want["lp-bred-big-burster"] = f.siege.k end
    if (f.siege.fodder or 0) > 0 then want[herd.FODDER] = f.siege.fodder end
    local breed = f.siege.breed or "lp-bred-big-biter"
    if can[breed] and (f.siege.big or 0) > 0 then want[breed] = f.siege.big end
    return next(want) and want or nil
  end
  -- Where a wall held, bursters: what worked elsewhere is sent again.
  local l = herd.lesson_near(f.aim, 128)
  if l and (l.walled_held or 0) > 0 and can["lp-bred-cinder"] then
    want["lp-bred-cinder"] = math.ceil((f.last_size or WAVE_MAX) * ORDER_BREACH)
  end
  -- (Its own dying mostly to lasers and flamethrowers, big bursters and big biters were ordered for its next wave,
  -- tough_wanted: a siege's rams and its herd's mix do that now; the design consult, 2026-10-30.)
  return next(want) and want or nil
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
  -- The dearest breed still short first, and nothing else until it is paid for: by pairs(), 60 big biters at 28 took
  -- every minute's biomass before the 3 big bursters at 300 its siege waited on, and in three hours none was made (a
  -- megabase, 2026-10-28).
  local names = {}
  for name, n in pairs(want) do if (have[name] or 0) < n then names[#names + 1] = name end end
  table.sort(names, function(a, b)
    local ca, cb = shared.BREEDS[a].cost, shared.BREEDS[b].cost
    if ca ~= cb then return ca > cb end
    return a < b
  end)
  for _, name in ipairs({names[1]}) do
    local price = shared.BREEDS[name].cost
    if cul.biomass >= price then
      -- (Wide: a big burster stands as large as a behemoth, and round a crowded incubator 12 tiles held no room for one.)
      local p = surface.find_non_colliding_position(name, rec.pen.position, 32, 0.5)
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

-- Seeding's numbers (seed, below).
local SEED_AT, SEED_BANK, SEED_WAIT = 8, 300, 20 * 3600
local SEED_NEAR, SEED_FAR, SEED_APART, SEED_CLEAR = 300, 600, 300, 200
local SEED_FARTHEST = 1000
local SEED_WEIGHED = 40   -- fields weighed for their air, nearest first
local STUCK, REPLANS = 2 * 3600, 3   -- a carrier no nearer its field this long plans a new way, so many times at most
local ESCORT, CULTURE_CAP, YOUNG_WAVES = 12, 5, 3
local CARRY_LIMIT = 30 * 3600   -- a carrier still walking this long has lost its way
local FILLED_WAIT = 30 * 3600   -- no nest taken this long: its field is filled

-- Why a farm due a wave holds it, traced at most every ten minutes (on the player's nw it sent one wave in three hours
-- and the trace said nothing of why).
-- (Once in ten minutes, and whenever its reason changes, its words up to the first number or colon: throttled alone, two
-- refusals alternating at culture 2 on nw read as one steady state for five hours.)
-- A probe (the design consult, 2026-10-30, step 3): with no way in it can take and no siege it can lay, a small siege, a
-- wave's least (WAVE_MIN: its rams, its screen, its herd making up the rest), at the best of its places its siege has not
-- tried lately (herd.attempt), sent though its prices say it is too dear: what it costs there is learned by going.
-- (Held on its prices alone, it never went back to a fort it had got into four times running; the siege lab.)
-- Its menu (the design consult, 2026-10-30, B: methods scored, not a ladder of vetoes): each way it could go, by what
-- it would raze for what it would lose, nearer first. A raid at its best place, a siege at each it sized. What it expects
-- is what its attempts there did (herd.attempt: the one that razed most for what it spent) where it has tried, else its
-- reading: a raid wins its odds of the place's worth and loses the rest of its strength; a siege spends its herd breaking
-- in (siege_size: sized to pay once) and razes what stands there. One worth less than its mind's min_gain is no choice.
-- (A siege was weighed only when no raid was worth anything: on the user's fort a raid of 28 lost 710 and razed 33,
-- where sieges razed 45 for 296; the siege lab.)
-- Its attempts there count only against a defence no stronger than now (herd.history), and each lately made there takes
-- REPEAT off what it expects (the player answers what it did: it rebuilds, it reinforces), so a place that worked is not
-- gone at forever. It picks among its choices by chance, in proportion to their scores (f.rng, seeded: one game plays
-- the same): mostly the best, a close second its turn. (Always the best, the siege lab's trials 5 to 8 were one siege at
-- one breach, its defences rebuilt each time; the user, 2026-10-30.) REPEAT assumed, not tuned.
local REPEAT = 0.3
local function menu(f, choice, sieges_allowed, s)
  local mind = B.mind
  local ops, rejected = {}, {}
  local function expect(op, foe)
    local mem, wt = herd.attempt(foe, op.at, op.method)
    if mem and wt > ATTEMPT_FADED then
      local forces = foe == "player" and players() or {foe}
      local hist = herd.history(mem, herd.place_sig(s, forces, op.at))
      -- (A siege with more rams than those it tried there is another siege: those say nothing of it. Its two sieges of 1 and
      -- 2 rams at the square lab fort, both killed short, read as all a siege there could do, and it held; 2026-10-31.)
      if op.method == "siege" and op.siege and (op.siege.k or 0) > 0 then
        local kept = {}
        for _, a in ipairs(hist) do if (a.rams or 0) >= op.siege.k then kept[#kept + 1] = a end end
        hist = kept
      end
      local best, bv, lately = nil, nil, 0
      for _, a in ipairs(hist) do
        local v = a.got / math.max(1, a.spent)
        if not bv or v > bv then best, bv = a, v end
        if a.tick then lately = lately + math.exp(-(game.tick - a.tick) / (mind.fade or 40 * 3600)) end
      end
      if best then op.gain, op.lost, op.sent, op.known = best.got / (1 + REPEAT * lately), best.spent, best.sent, true end
      op.voided = #hist < #(mem.hist or {}) and #(mem.hist or {}) - #hist or nil
    end
    -- (Its losses as a share of what it sends: over 1 + what it lost alone, a cut that razed 7 and lost nothing scored 40
    -- times a strike that razed 11 for 77 of 700; the fed lab fort, 2026-10-30.)
    op.score = op.gain / (1 + op.lost / math.max(1, op.sent or choice.strength or 1)) / (1 + (op.dist or 0) / mind.far)
    if op.gain >= (mind.min_gain or 0) then ops[#ops + 1] = op
    else rejected[#rejected + 1] = string.format("%s at %.0f,%.0f razes %.1f for %.0f%s", op.method, op.at.x, op.at.y, op.gain,
      op.lost, op.known and " (as its attempts did)" or "") end
  end
  if choice.passes then
    local foe = choice.rival or "player"
    expect({method = "raid", at = choice.at, gain = choice.gain, lost = choice.strength * (1 - (choice.odds or 0)),
      dist = choice.dist}, foe)
  end
  -- A cut: what the guns it parts cost it, for its way there and back (its plan, past no wall).
  for _, c in ipairs(choice.cuts or {}) do
    if c.e.valid then
      expect({method = "cut", at = c.at, gain = c.gain or 0, lost = 2 * c.plan.cost, dist = c.dist, cut = c},
        c.rival and c.rival[1] or "player")
    end
  end
  -- A cut and a strike (the user, 2026-10-30: "should a smart adversary combine the power cut with an attack on
  -- unpowered defenses?"): its cutters at the feed, its herd staged out of reach of the place the cut darkens and sent in
  -- the moment the feed falls (herd.lua: the strike holds at its mark). What it would win there with the parted guns'
  -- price off its defence, for the cutters' way there and back and what the herd would lose.
  for _, c in ipairs(choice.cuts or {}) do
    if c.e.valid and c.strike then
      local st, n = c.strike, choice.strength
      local odds = valuemap.keeps_lost(n, math.max(0, st.defence - c.price) / 2)
      expect({method = "strike", at = st.at, gain = odds * st.value, lost = 2 * c.plan.cost + n * (1 - odds),
        dist = math.sqrt(d2(st.at, f.pos)), cut = c}, c.rival and c.rival[1] or "player")
    end
  end
  if sieges_allowed then
    for _, sg in pairs(choice.sieges or {}) do
      expect({method = "siege", at = sg.at, gain = sg.value or 0, lost = sg.need or 0, sent = sg.need, dist = sg.dist, siege = sg},
        sg.rival and sg.rival[1] or "player")
    end
    -- A probe at its best place not tried lately: what its sieges at this foe have done on the mean (herd.foe_record),
    -- once it has any. (A probe only when nothing fit, a siege proven at one place was the only choice there ever was,
    -- and it went there every time; the siege lab, 2026-10-30.)
    for _, top in ipairs(choice.places or {}) do
      local foe = not shared.is_player_force(game.forces[top.force]) and top.force or "player"
      local at = {x = top.at[1], y = top.at[2]}
      local _, wt = herd.attempt(foe, at, "siege")
      local got, spent = herd.foe_record(foe, "siege")
      if got and wt <= ATTEMPT_FADED then
        expect({method = "probe", at = at, gain = got, lost = spent, dist = math.sqrt(d2(at, f.pos)), place = top}, foe)
        break
      end
    end
  end
  table.sort(ops, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return (a.siege and a.siege.key or "") < (b.siege and b.siege.key or "")
  end)
  local total = 0
  for _, o in ipairs(ops) do total = total + o.score end
  local said = {}
  for k = 1, math.min(4, #ops) do
    local o = ops[k]
    said[#said + 1] = string.format("%s at %.0f,%.0f razes %.0f for %.0f%s%s, score %.3f (%.0f%%)", o.method, o.at.x, o.at.y,
      o.gain, o.lost, o.known and " (as its attempts did)" or "", o.voided and string.format(", %d attempts void: stronger now", o.voided) or "",
      o.score, total > 0 and 100 * o.score / total or 0)
  end
  if #ops == 0 then
    local ns = 0
    for _ in pairs(choice.sieges or {}) do ns = ns + 1 end
    if #rejected > 0 then trace(string.format("farm %d: no method worth it (sieges %s, %d sized): %s", f.id,
      sieges_allowed and "allowed" or "not allowed", ns, table.concat(rejected, "; "))) end
    return nil
  end
  f.rng = f.rng or rng.new(f.id * 7919 + game.tick)
  local pick, r = ops[1], rng.next(f.rng) * total
  for _, o in ipairs(ops) do
    r = r - o.score
    if r <= 0 then pick = o; break end
  end
  trace(string.format("farm %d weighs its methods: %s; picks %s at %.0f,%.0f", f.id, table.concat(said, "; "), pick.method,
    pick.at.x, pick.at.y))
  return pick
end

local function probe(f, s, choice, tick)
  if not herd.bursters_developed() or B.mind.orders == false or storage.biotech_no_orders then return false end
  local bc, fc = shared.BREEDS["lp-bred-big-burster"].cost, shared.BREEDS[herd.FODDER].cost
  local _, _, hc, hw = chance(f, s)
  for _, top in ipairs(choice.places or choice.top or {}) do
    local rival = not shared.is_player_force(game.forces[top.force]) and {top.force} or nil
    local at = {x = top.at[1], y = top.at[2]}
    local pl = herd.plan(s, f.pos, at, rival or players(), shared.WAVE_MIN)
    local foe = rival and rival[1] or "player"
    local _, wt = herd.attempt(foe, at, "siege")
    if pl and pl.walled and wt <= ATTEMPT_FADED then
      local k = math.min(RAMS_MAX, math.ceil(1 / herd.reach(foe)))
      local fodder = math.max(0, math.min(pl.cover or 0, shared.WAVE_MIN - k - 1))
      local n = math.max(1, shared.WAVE_MIN - k - fodder)
      local price = k * bc + fodder * fc + n * hc
      f.siege = {at = at, key = herd.attempt_key(foe, at), k = k, n = k + n + fodder, big = 0, breed = "mixed",
        need = n * hw + fodder * herd.strength({herd.FODDER}), fodder = fodder, price = price, cover = pl.cover,
        defence = top.defence, rival = rival, value = top.worth, tick = tick, mines = math.min(herd.SWEEP_MAX, pl.sappers or 0),
        trust = "probe"}
      f.aim = {x = at.x, y = at.y}
      f.want = order(f, s)
      f.want_key = f.want and serpent.line(f.want) or nil
      trace(string.format("farm %d: probes the way in at %.0f,%.0f (its plan: in at %.0f,%.0f costing %.0f, %d guns cover the breach; not tried there lately): %d big bursters, a screen of %d and a herd of %d (%d biomass)",
        f.id, at.x, at.y, pl.breach[1], pl.breach[2], pl.cost, pl.cover, k, fodder, n, price))
      f.escalate_retry = tick + 600
      return true
    end
  end
  return false
end

local function holds(f, tick, why)
  f.held_why = why
  local kind = why:match("^[^:%d]*")
  if tick - (f.held_said or -36000) >= 36000 or kind ~= f.held_kind then
    f.held_said, f.held_kind = tick, kind
    trace(string.format("farm %d holds its wave: %s", f.id, why))
  end
end

local function send(f, tick)
  -- A young culture grows first: no wave until it has YOUNG_WAVES incubators.
  if f.seeded and #f.pens < YOUNG_WAVES then return holds(f, tick, string.format("young: %d incubators of %d", #f.pens, YOUNG_WAVES)) end
  -- (Waiting for a bigger wave: looked at again every ten seconds, not every tick.)
  if f.escalate_retry and tick < f.escalate_retry then return end
  f.escalate_retry = nil
  local s = game.surfaces[f.surface]
  local units, origin = {}, nil
  -- What it could send (its odds are weighed with it): every pen's stock over its guard, at most WAVE_MAX.
  local avail, bursters, seen = 0, 0, {}
  for _, id in ipairs(f.pens) do
    local rec = herd.pen(id)
    if rec and rec.pen.valid then
      avail = avail + math.max(0, #herd.stock(rec) - guard_of(f))
      -- (Each once: a biter in two incubators' stock was counted twice, and a siege read 13 big bursters of the 10 it had.)
      for _, u in ipairs(herd.stock(rec)) do
        if u.valid and not seen[u.unit_number] then
          seen[u.unit_number] = true
          if u.name == "lp-bred-big-burster" then bursters = bursters + 1 end
        end
      end
    end
  end
  -- (What it can field is what it sends: it saves up for no bigger wave, its probes learn what a place takes; the design
  -- consult, 2026-10-30, step 2: SAVE_FOR, STALL, WORTH_WAIT, SAVE_WAIT and ESCALATE_WAIT, timers each, gone.)
  local can = math.min(avail, WAVE_MAX)
  -- (What it could field at the most, the bound of any siege it lays, siege_size.) Hatching, what its biomass hatches is
  -- ready as well.
  -- (Its weighing in strength, herd.strength: how strong a wave of n of what it could field would be.)
  local field_n, field, budget = field_of(f, s)
  if hatching() then avail = field_n end
  local per = field_n > 0 and field / field_n or 1
  local function ready(n) return n * per end
  local target, rival, choice = target_from(s, f.pos, f, ready(math.min(avail, WAVE_MAX)), {bursters = bursters, field = field,
    budget = budget})
  if not target then return holds(f, tick, string.format("nothing to go for within %d tiles (%d ready)", B.mind.reach, avail)) end
  -- A siege laid: it goes there once its bursters and herd are bred (order: f.siege). It ends when a wave of what it has
  -- pays somewhere (the weighing's best passes and wins something), or when nothing of its foe's stands where it aimed.
  if f.siege then
    -- (Its target gone. Not a wave of what it has paying elsewhere: read apart from the siege's own model, that ended sieges
    -- for waves its plans then refused; one reading now, the design consult, 2026-10-30.)
    local why
    if s.count_entities_filtered{position = f.siege.at, radius = 32, force = f.siege.rival or players(), type = herd.DRAW, limit = 1} == 0 then
      why = "nothing of its foe's stands there now"
    end
    if why then
      trace(string.format("farm %d: ends its siege at %.0f,%.0f (%d of %d big bursters bred): %s", f.id, f.siege.at.x,
        f.siege.at.y, bursters, f.siege.k, why))
      f.siege = nil
    end
  end
  local siege = f.siege
  if siege then
    local sweep_price = (siege.mines or 0) * shared.BREEDS["lp-sweeper"].cost
    local cul0 = creep.of(f.id)
    -- (Its bursters, its herd as its plan priced it, siege_size, and its sweep's price.)
    -- (Hatching: on the biomass that hatches its bursters, its herd and its sweep.)
    local need = sweep_price + (siege.price or siege.k * shared.BREEDS["lp-bred-big-burster"].cost
      + math.max(0, siege.n - siege.k) * select(3, chance(f, s)))
    local hatch_short = hatching() and cul0 and (budget or 0) < need
    if hatching() and not hatch_short then
    elseif hatch_short or not hatching() and (bursters < siege.k or avail < siege.n or (cul0 and cul0.biomass < sweep_price)) then
      f.escalate_retry = tick + 600
      if hatching() then
        return holds(f, tick, string.format("lays siege to the way in at %.0f,%.0f: waits for the biomass to hatch %d big bursters and %d in all, and its sweep of %d (%.0f of %.0f)",
          siege.at.x, siege.at.y, siege.k, siege.n, siege.mines or 0, budget or 0, need))
      end
      return holds(f, tick, string.format("lays siege to the way in at %.0f,%.0f: waits for %d big bursters (%d bred) and %d in all (%d ready), and %d biomass for its sweep of %d",
        siege.at.x, siege.at.y, siege.k, bursters, siege.n, avail, sweep_price, siege.mines or 0))
    end
    target, rival = siege.at, siege.rival
    choice = {key = siege.key, defence = siege.defence, why = string.format("its siege, %d big bursters at %d guns", bursters,
      siege.cover), top = {}, gain = siege.value, passes = true}
  end
  -- Nothing worth a wave of its size (the best it would win under its mind's min_gain): a siege, a probe, a raid probe or
  -- it holds. /lp wave <n> sends regardless.
  -- (A siege's bursters bred, it goes with what it has: its plan says whether that pays the way in. Saving up to its 120
  -- as well, it waited with 117 ready; the siege test, 2026-10-28.)
  local saving = siege and math.min(siege.n, avail)
  local raid_probe
  local op
  if not siege and not f.debug_size and not f.debug_now then
    local evo = game.forces[B.force].get_evolution_factor(s)
    choice.at, choice.rival = target, rival and rival[1] or nil
    op = menu(f, choice, B.mind.orders ~= false and not storage.biotech_no_orders and unlocked(evo)["lp-bred-big-burster"], s)
  end
  -- A cut: its wave goes for the feed (herd.lua targets: first), as many as pay its way there and back.
  local cut
  if op and op.method == "cut" then
    cut = op.cut
    target, rival = cut.at, cut.rival
    choice = {key = cut.key, defence = 0, top = {}, gain = cut.price, passes = true,
      why = string.format("a cut: %s at %.0f,%.0f parts %d guns from their supply", cut.e.name, cut.at.x, cut.at.y, cut.starves)}
    trace(string.format("farm %d: cuts the supply of %d guns at %.0f,%.0f (%s, its way there %.0f)", f.id, cut.starves, cut.at.x,
      cut.at.y, cut.e.name, cut.plan.cost))
  end
  if op and op.method == "probe" and probe(f, s, {places = {op.place}}, tick) then
    return holds(f, tick, "lays a probe")
  end
  local strike
  if op and op.method == "strike" then
    strike = op
    cut = op.cut
    target, rival = op.at, cut.rival
    choice = {key = herd.attempt_key(rival and rival[1] or "player", op.at), defence = 0, top = {}, gain = op.gain, passes = true,
      why = string.format("a strike at %.0f,%.0f once its cut at %.0f,%.0f (%s) parts %d guns", op.at.x, op.at.y, cut.at.x,
        cut.at.y, cut.e.name, cut.starves)}
    trace(string.format("farm %d: strikes at %.0f,%.0f, its cutters first at %.0f,%.0f (%s, %d guns parted)", f.id, op.at.x,
      op.at.y, cut.at.x, cut.at.y, cut.e.name, cut.starves))
  end
  if not siege and not f.debug_size and not f.debug_now and not (op and (op.method == "raid" or op.method == "cut" or op.method == "strike")) then
    local sg = op and op.siege
    local c2
    if sg then
      -- Nothing it can field wins anything: the way in to its best place is the job, as its weighing sized it (target_from:
      -- its plan and siege_size on the one reading).
      local pl, k, n, price, breed, need, fodder = sg.plan, sg.k, sg.n, sg.price, sg.breed, sg.need, sg.fodder
      local trust = sg.proven and "proven" or nil
      -- (Hatching, its herd ordered whole, hatched first: by chance, a herd of mediums was not the strength its plan asked.)
      -- (Its rams ordered; its herd hatched by chance, the culture's mix: big 0.)
      f.siege = {at = sg.at, key = sg.key, k = k, n = k + n + (fodder or 0), big = 0, breed = breed, need = need,
        fodder = fodder,
        price = price, guns = sg.guns, extra = sg.extra, cover = pl.cover, defence = sg.defence, rival = sg.rival, value = sg.value, tick = tick,
        trust = trust,
        mines = math.min(herd.SWEEP_MAX, pl.sappers or 0)}
      f.aim = {x = sg.at.x, y = sg.at.y}
      -- (Its order at once, not at the minute: sized to the biomass it has, a siege was ready at the next weighing, and its
      -- wave hatched by chance with none of the big bursters it was laid for; the siege test, four seeds, 2026-10-30.)
      f.want = order(f, s)
      f.want_key = f.want and serpent.line(f.want) or nil
      trace(string.format("farm %d: nothing it can field wins anything; lays siege to the way in at %.0f,%.0f (its plan: in at %.0f,%.0f costing %.0f, %d guns cover the breach, %d its bursters can reach; worth %.0f past them): %d big bursters and a herd of %d %s (%d biomass)",
        f.id, sg.at.x, sg.at.y, pl.breach[1], pl.breach[2], pl.cost, pl.cover, pl.openable or pl.cover, sg.value, k, n,
        breed, price))
      f.escalate_retry = tick + 600
      return holds(f, tick, "lays siege")
    elseif not choice.passes and probe(f, s, choice, tick) then
      return holds(f, tick, "lays a probe")
    elseif not choice.passes then
      -- No way in it can take and no siege: it does not send a wave to turn home at the wave's own test.
      herd.stopped("noway|" .. (choice.key or "?"))
      f.escalate_retry = tick + 600
      return holds(f, tick, string.format("no way in it can take with %d or %d, and no siege (%s)", math.min(avail, WAVE_MAX), can,
        (c2 or choice).why))
    else
      -- A raid probe: its best place not raided lately (herd.attempt), the least wave sent to learn what it takes, sent
      -- though nothing there reads as worth one; tried lately, it holds and grows. (A trial after WORTH_WAIT on a clock,
      -- held for good once it had learned any price, before: the design consult, 2026-10-30.)
      local _, wt = herd.attempt(rival and rival[1] or "player", target, "raid")
      if wt > ATTEMPT_FADED then
        f.escalate_retry = tick + 600
        herd.stopped("worthless|" .. (choice.key or "?"))
        return holds(f, tick, string.format("nothing worth a wave of %d (the best wins %.0f): it holds and grows",
          math.min(avail, WAVE_MAX), choice.gain))
      end
      raid_probe = true
      trace(string.format("farm %d: nothing worth a wave; probes its best place with a raid of %d", f.id, shared.WAVE_MIN))
    end
  end
  local bd
  -- What killed its last wave there (herd.lesson_near): the breeds that beat those killers go first, the rest keep the
  -- gate (counters.lua, the arena's matrix; the user, 2026-10-24: learning that shows). With no lesson, the nearest go.
  local lesson = herd.lesson_near(target, 128)
  -- (Escalation by method, not headcount: a wave of WAVE_MAX at most, a raid probe the least, a siege its own size. A
  -- defence that held drew waves up to twice WAVE_MAX, waited for: the design consult, 2026-10-30.)
  local cap = raid_probe and shared.WAVE_MIN or WAVE_MAX
  if cut and not strike then
    cap = shared.WAVE_MIN
    while cap < WAVE_MAX and not herd.affords(ready(cap), cut.plan.cost) do cap = cap + 1 end
  end
  if saving then cap = math.max(cap, saving) end
  -- /lp wave <n> (dev): a wave of that many, past the caps, once.
  local forced = f.debug_size
  if forced then cap, f.debug_size = forced, nil end
  -- Its order not yet filled: the wave waits for it, ORDER_WAIT at the most.
  if f.short and not hatching() then
    f.order_since = f.order_since or tick
    if tick - f.order_since < ((f.want or {})["lp-bred-big-burster"] and ORDER_WAIT_BIG or ORDER_WAIT) then
      f.escalate_retry = tick + 600
      return holds(f, tick, "waits for its bursters")
    end
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
  local taken = {}
  -- What it bred to order, from every incubator before any other (pen by pen, its cap of 120 was filled at the first
  -- pens and a siege's wave carried 8 of the 17 big bursters bred for it; its plan then said it could not pay the way in,
  -- a megabase, 2026-10-28).
  if next(want) then
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then
        for _, u in ipairs(herd.stock(rec)) do
          if u.valid and want[u.name] and not taken[u.unit_number] and #units < cap then
            taken[u.unit_number] = true
            units[#units + 1] = u
          end
        end
      end
    end
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
        for i = #stock, math.max(1, #stock - guard_of(f) + 1), -1 do table.insert(guard, 1, table.remove(stock, i)) end
        for i = #guard, 1, -1 do table.insert(stock, 1, guard[i]) end
      else
        table.sort(stock, function(a, b) return d2(a.position, rec.pen.position) < d2(b.position, rec.pen.position) end)
      end
      local home = {}
      -- (A biter in two incubators' stock is sent once: herd.launch.)
      local mine = {}
      for _, u in ipairs(stock) do if not taken[u.unit_number] then mine[#mine + 1] = u; taken[u.unit_number] = true end end
      stock = mine
      for i, u in ipairs(stock) do
        -- (With a lesson, a breed that loses to what killed the last wave stays at the gate too: small biters, -1 against
        -- gun turrets, were half of a wave sent against them.)
        local unfit = total > 0 and fit(u) < UNFIT
        if i <= guard_of(f) or #units >= cap or unfit then table.insert(home, u) else table.insert(units, u) end
      end
      rec.stock = home
      local d = d2(rec.pen.position, target)
      if not bd or d < bd then origin, bd = rec, d end
    end
  end
  -- Hatching: the rest of its wave, names to hatch once its plan says it goes (hatch): its order less what stood, then by
  -- chance, tilted by what killed its last wave there, within its biomass (less its probe's and its sweep's runts).
  if hatching() and #units < cap then
    local have = {}
    for _, u in ipairs(units) do local nm = name_of(u); if nm then have[nm] = (have[nm] or 0) + 1 end end
    local cul = creep.of(f.id)
    local keep = herd.PROBE_N * shared.BREEDS["lp-runt"].cost + (siege and siege.mines or 0) * shared.BREEDS["lp-sweeper"].cost
    -- (A siege's herd the culture's mix tilted as a raid's, chance: filtered by what beat the last wave there, the user's
    -- fort's lasers and flamethrowers left cinders alone, and its sieges were 270 of them; the siege lab.)
    local names = compose(f, s, (siege and WAVE_MAX or cap) - #units, want, have,
      total > 0 and function(name) return fit_of(name, lesson.killers, total) end or nil,
      math.max(0, (cul and cul.biomass or 0) - keep),
      siege and siege.need and {need = siege.need, have = herd.strength(units), least = shared.WAVE_MIN - #units} or nil)
    for _, name in ipairs(names) do units[#units + 1] = name end
    if not origin then
      for _, id in ipairs(f.pens) do
        local rec = herd.pen(id)
        if rec and rec.pen.valid then
          local d = d2(rec.pen.position, target)
          if not bd or d < bd then origin, bd = rec, d end
        end
      end
    end
  end
  if total > 0 and #units > 0 then
    local by = {}
    for _, u in ipairs(units) do local n = name_of(u):gsub("^lp%-bred%-", ""); by[n] = (by[n] or 0) + 1 end
    trace(string.format("farm %d: its wave made up against what killed the last (%s): %s", f.id, serpent.line(lesson.killers),
      serpent.line(by)))
  end
  if #units < shared.WAVE_MIN or not origin then
    holds(f, tick, string.format("%d ready, %d the least it sends", #units, shared.WAVE_MIN))
    -- Not enough yet: back into the pens' stock.
    for _, u in ipairs(units) do
      if type(u) ~= "string" then table.insert(origin and origin.stock or herd.pen(f.pens[1]).stock, u) end
    end
    return
  end
  -- Its plan (herd.plan: from here at its target, on one cost map, at the grain its waves read), and the wave's own test
  -- on it (herd.affords, its big bursters credited): one it cannot get in with is not sent, and the place is priced at what
  -- the plan found (know: dear) while it weighs again. Its waves follow the plan (herd.lua mark): read twice, by the farm
  -- and again by the wave from where its scout ended, 12 of 16 waves turned home at the gate (2026-10-28).
  local big = 0
  for _, u in ipairs(units) do if name_of(u) == "lp-bred-big-burster" then big = big + 1 end end
  -- (From the incubator it leaves from: planned from the farm's middle, a wave sent from an incubator 90 tiles off walked
  -- back there first, its first legs failed; the fed lab fort, 2026-10-30.)
  local from = origin and origin.pen and origin.pen.valid and origin.pen.position or f.pos
  local plan = herd.plan(s, from, target, rival or players(), #units)
  -- (A siege with its rams and screen pays the crossing, not the standing at the wall: siege_size.)
  local screened = siege and big > 0 and (siege.fodder or 0) > 0
  local base = plan and math.max(0, plan.cost - (screened and (plan.standing or 0) or 0))
  local lost = plan and herd.way_cost(base, plan.cover, big, plan.openable, rival and rival[1] or "player")
  local strength = herd.strength(units)
  -- (A probe, or a siege its attempts proved: sent on what it learns or knows there, not its prices.)
  local trust = siege and siege.trust or raid_probe and "probe" or strike and "strike" or nil
  if not forced and (not plan or not (trust or herd.affords(strength, lost))) then
    herd.stopped("dear|" .. (choice.key or "?"))
    for _, u in ipairs(units) do if type(u) ~= "string" then table.insert(origin.stock, u) end end
    -- A siege bred and still short of what its plan, read again now, asks: sized again from that plan (siege_size) and
    -- bred on, or, no siege it can field paying it, ended.
    if siege and plan then
      local k2, n2, price2, breed2, need2, fodder2 = siege_size(f, plan, siege)
      if k2 then
        siege.k, siege.n, siege.big = k2, k2 + n2 + (fodder2 or 0), 0
        siege.breed, siege.price, siege.need, siege.fodder = breed2, price2, need2, fodder2
        f.want = order(f, s)
        f.want_key = f.want and serpent.line(f.want) or nil
        siege.cover, siege.mines = plan.cover, math.min(herd.SWEEP_MAX, plan.sappers or 0)
        trace(string.format("farm %d: its siege at %.0f,%.0f read again: %d big bursters and a herd of %d (%d biomass)", f.id,
          target.x, target.y, k2, n2, price2))
      else
        trace(string.format("farm %d: ends its siege at %.0f,%.0f: its plan, read again, costs %.0f, more than it can field",
          f.id, target.x, target.y, plan.cost))
        f.siege = nil
      end
    elseif not siege then f.siege = nil end
    f.escalate_retry = tick + 600
    return holds(f, tick, plan and string.format("its plan for %.0f,%.0f costs %.0f, %.0f with its %d big bursters at the %d guns covering the breach: its %d (%.0f) cannot pay it",
      target.x, target.y, plan.cost, lost, big, plan.cover, #units, strength) or string.format("no way to %.0f,%.0f", target.x, target.y))
  end
  f.siege = nil
  -- It goes: what was a name is hatched now.
  units = hatch(f, s, units)
  -- A strike: its cutters, as many as pay the way to the feed, sent first; the rest the strike, held at its mark till the
  -- feed falls (wait_cut).
  local wait_cut
  if strike then
    local per_u = herd.strength(units) / math.max(1, #units)
    local k = shared.WAVE_MIN
    while k < #units - shared.WAVE_MIN and not herd.affords(k * per_u, cut.plan.cost) do k = k + 1 end
    local cutters = {}
    for i = 1, k do cutters[#cutters + 1] = table.remove(units, 1) end
    local cut_plan = herd.plan(s, from, cut.at, rival or players(), #cutters) or cut.plan
    local id = herd.launch(origin, cut.at, {units = cutters, farm = f.id, forces = rival, no_probe = true, plan = cut_plan,
      trust = "probe", cut = {e = cut.e, worth = 0, starves = cut.starves, for_strike = true},
      sig = herd.place_sig(s, rival or players(), cut.at)})
    wait_cut = {e = cut.e, wave = id}
    trace(string.format("farm %d sends %d cutters at %.0f,%.0f; its strike of %d waits at its mark", f.id, k, cut.at.x, cut.at.y, #units))
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
  local no_probe = not B.mind.probe
  if B.mind.probe and cul and game.forces[B.force].get_evolution_factor(s) >= herd.PROBE_EVO then
    local price = herd.PROBE_N * shared.BREEDS["lp-runt"].cost
    if cul.biomass >= price then
      cul.biomass, cul.spent = cul.biomass - price, (cul.spent or 0) + price
    else
      no_probe = true
    end
  end
  -- Its sweep's runts, one for each of its foe's mines on its plan's way in (herd.plan, herd.sweep), at their price, what it
  -- can pay for.
  local sweep_n = math.min(herd.SWEEP_MAX, plan and plan.sappers or 0)
  if sweep_n > 0 then
    sweep_n = math.min(sweep_n, cul and math.floor(cul.biomass / shared.BREEDS["lp-sweeper"].cost) or 0)
    local price = sweep_n * shared.BREEDS["lp-sweeper"].cost
    if cul then cul.biomass, cul.spent = cul.biomass - price, (cul.spent or 0) + price end
  end
  trace(string.format("farm %d weighs: %s", f.id, choice.why))
  trials()[choice.key] = {tick = tick, defence = choice.defence}
  herd.launch(origin, target, {units = units, farm = f.id, forces = rival, no_probe = no_probe, deep = f.debug_deep,
    choice = choice and choice.top, plan = plan, sweep = sweep_n,
    fodder = siege and (siege.fodder or 0) > 0 and {name = herd.FODDER, n = siege.fodder} or nil, trust = trust,
    cut = cut and not strike and {e = cut.e, worth = cut.price, starves = cut.starves} or nil, wait_cut = wait_cut,
    sig = herd.place_sig(s, rival or players(), plan and plan.target or target)})
  f.debug_deep, f.debug_now = nil, nil
  trace(string.format("farm %d sends %d at %.0f,%.0f%s", f.id, #units, target.x, target.y,
    plan and (plan.mines or 0) > 0 and string.format(", a sweep of %d for the %d mines on its way in", sweep_n, plan.mines) or ""))
end

-- Seeding (the Fable consult, docs/reviews/2026-10-25-synthexis-growth-research-consult.md; the user: multiple landings
-- "just like other factions", spread suited to space): a mature culture (SEED_AT incubators, two thirds fed, SEED_BANK
-- of biomass) sends a carrier (biotech.lua) with ESCORT of its stock to a wild nest field SEED_NEAR to SEED_FAR out,
-- with no culture within SEED_APART and nothing of the player's within SEED_CLEAR. It walks routed legs round turrets;
-- where it stops, a young culture begins (farm.land, seeded: one incubator, no worms, its clinic by pod later, no wave
-- until YOUNG_WAVES incubators). Killed on the way, the culture paid for nothing and tries again SEED_WAIT on. Orbit
-- brings only the first culture, and the next once every one is gone: an infestation, where the corporations invade.

-- Where its carrier goes (0.2.24, as its pod: the user, 2026-10-26, "to ensure a new culture can feed itself"): of the
-- wild fields SEED_NEAR to `far` out (no culture within SEED_APART, nothing of the player's within SEED_CLEAR), the one
-- with the most pollution round it (creep.food) if one has FED_MIN, else the nearest; with no field at all, the bare
-- ground there with the most, if it has FED_MIN (its carrier founds an incubator: farm.land).
local function clear_for_seed(s, p)
  for _, g in pairs(st().list) do if d2(g.pos, p) < SEED_APART * SEED_APART then return false end end
  return s.count_entities_filtered{position = p, radius = SEED_CLEAR, force = players(), limit = 1} == 0
    and not shelled(s, p)
end

local function seed_site(f, s, far)
  local near, nd, fed, ff = nil, nil, nil, nil
  local weighed = 0
  local spawners = s.find_entities_filtered{type = "unit-spawner", force = "enemy", position = f.pos, radius = far}
  table.sort(spawners, function(a, b) return d2(a.position, f.pos) < d2(b.position, f.pos) end)
  for _, sp in ipairs(spawners) do
    if weighed >= SEED_WEIGHED then break end
    local d = d2(sp.position, f.pos)
    if d >= SEED_NEAR * SEED_NEAR and clear_for_seed(s, sp.position)
      and s.count_entities_filtered{type = "unit-spawner", force = "enemy", position = sp.position, radius = FIELD} >= FIELD_MIN then
      weighed = weighed + 1
      local p = {x = sp.position.x, y = sp.position.y}
      if not nd then near, nd = p, d end
      local food = creep.food(s, p, FED_R)
      if food >= FED_MIN and (not ff or food > ff) then fed, ff = p, food end
    end
  end
  if fed or near then return fed or near, fed and ff or nil end
  -- No field: bare ground, sixteen ways at three distances.
  local best, bf
  for k = 0, 15 do
    local a = k * math.pi / 8
    for _, r in ipairs({SEED_NEAR, (SEED_NEAR + far) / 2, far}) do
      local p = {x = f.pos.x + math.cos(a) * r, y = f.pos.y + math.sin(a) * r}
      local t = s.is_chunk_generated({math.floor(p.x / 32), math.floor(p.y / 32)}) and s.get_tile(p.x, p.y)
      if t and not t.collides_with("water_tile") and t.name ~= "out-of-map" and clear_for_seed(s, p) then
        local food = creep.food(s, p, FED_R)
        if food >= FED_MIN and (not bf or food > bf) then best, bf = p, food end
      end
    end
  end
  if best then best.bare = true end
  return best, bf
end

local carrier_legs

local function seed(f, tick)
  local sl = st()
  -- Mature: SEED_AT incubators, or its field filled (PENS at least and no nest taken for FILLED_WAIT: on a fresh map's
  -- sparse fields a culture stopped at five, and never seeded in three hours).
  local filled = #f.pens >= PENS and (f.seed_forced or tick - (f.last_take or f.landed or 0) >= FILLED_WAIT)
  if f.carrier or (#f.pens < SEED_AT and not filled) or tick - (f.seed_tried or -SEED_WAIT) < SEED_WAIT then return end
  local n = 0
  for _, g in pairs(sl.list) do n = n + 1 + (g.carrier and 1 or 0) end
  local function why(text)
    if tick - (f.seed_said or -36000) >= 36000 then
      f.seed_said = tick
      trace(string.format("farm %d: mature (%d incubators), not seeding yet: %s", f.id, #f.pens, text))
    end
  end
  if n >= (B.mind.culture_cap or CULTURE_CAP) then f.saving = nil; return why(string.format("%d cultures, the most", n)) end
  local cul = creep.of(f.id)
  if not cul then return end
  if not cell.keeps_up(f.id, f.pens, tick) then return why("its cells hungry") end
  -- Its carrier from its growth's pool (creep.earn: breeding no longer spends what it saves).
  if (cul.growth or 0) < SEED_BANK then f.saving = true; return why(string.format("saving, %.0f of %d", cul.growth or 0, SEED_BANK)) end
  f.saving = nil
  f.seed_tried = tick
  local s = game.surfaces[f.surface]
  -- The nearest field SEED_NEAR to SEED_FAR out, else out to SEED_FARTHEST (a fresh map's nests are sparse: none within
  -- 600 of a culture on two seeds of three hours).
  local dest, food = seed_site(f, s, SEED_FAR)
  if not dest then dest, food = seed_site(f, s, SEED_FARTHEST) end
  if not dest then
    f.saving = nil
    return trace(string.format("farm %d: mature, but no wild field or fed ground to seed within %d", f.id, SEED_FARTHEST))
  end
  local rec, rd
  for _, id in ipairs(f.pens) do
    local r = herd.pen(id)
    if r and r.pen.valid and (not rd or d2(r.pen.position, dest) < rd) then rec, rd = r, d2(r.pen.position, dest) end
  end
  if not rec then return end
  local q = s.find_non_colliding_position("lp-bred-carrier", rec.pen.position, 12, 1)
  local carrier = q and s.create_entity{name = "lp-bred-carrier", position = q, force = B.force}
  if not carrier then return end
  rendering.draw_light{sprite = "utility/light_small", surface = s, target = carrier, color = {0.6, 0.25, 1},
    scale = 1.8, intensity = 0.9, minimum_darkness = 0.3}
  local g = s.create_unit_group{position = carrier.position, force = B.force}
  g.add_member(carrier)
  local stock, keep, escort = herd.stock(rec), {}, {}
  -- (Hatching: its escort hatched for it at that incubator, what its biomass pays; its guard stays at the gate.)
  if hatching() then
    for _, u in ipairs(hatch(f, s, compose(f, s, ESCORT, nil, nil, nil, cul.biomass), rec)) do
      g.add_member(u)
      escort[#escort + 1] = u
    end
    stock = {}
    keep = herd.stock(rec)
  end
  for _, u in ipairs(stock) do
    if #escort < ESCORT and u.valid then
      if u.commandable.spawner then u.commandable.release_from_spawner() end
      g.add_member(u)
      escort[#escort + 1] = u
    else
      keep[#keep + 1] = u
    end
  end
  rec.stock = keep
  creep.spend_growth(cul, SEED_BANK)
  local from = carrier.position
  local far = math.sqrt(d2(from, dest))
  local legs, way = carrier_legs(f, from, dest)
  f.carrier = {group = g, unit = carrier, escort = escort, legs = legs, leg = 1, dest = dest, t = tick,
    bank = SEED_BANK / 2}
  storage.carrying = storage.carrying or {}
  for _, u in ipairs(escort) do storage.carrying[u.unit_number] = true end
  if carrier.commandable and carrier.commandable.spawner then carrier.commandable.release_from_spawner() end
  trace(string.format("farm %d sends a carrier with %d escorts to %s at %.0f,%.0f (%.0f tiles, %s; %s)", f.id, #escort,
    dest.bare and "bare ground" or "the nests", dest.x, dest.y, far, way and "routed" or "straight",
    food and string.format("%.0f of pollution round it", food) or "clean air"))
end

-- Its way, from `from` to `dest`: round the turrets known to it and round cliffs and the player's buildings (solid; a
-- carrier stood 17 minutes at a line of cliffs, its every order ending at once: farm seedbare, 0.2.28), a leg at most
-- 60 tiles; failing that, straight in 60-tile legs. Returns its legs and whether it was routed.
carrier_legs = function(f, from, dest)
  local far = math.sqrt(d2(from, dest))
  local way = herd.route and herd.route({surface = f.surface, force = B.force}, {from.x, from.y}, {dest.x, dest.y},
    {turrets = true, nests = false, solid = players(), cell = far > 400 and 16 or 10}, true)
  local pts, legs = {}, {}
  for _, p in ipairs(way or {}) do pts[#pts + 1] = {x = p[1], y = p[2]} end
  pts[#pts + 1] = dest
  local a = {x = from.x, y = from.y}
  for _, p in ipairs(pts) do
    local d = math.sqrt(d2(a, p))
    for k = 1, math.floor(d / 60) do legs[#legs + 1] = {x = a.x + (p.x - a.x) * k * 60 / d, y = a.y + (p.y - a.y) * k * 60 / d} end
    legs[#legs + 1] = p
    a = p
  end
  return legs, way
end

-- The carrier on its way, every farm look: leg by leg; at its field, the new culture.
local function carry(f, tick)
  local c = f.carrier
  if not c then return end
  local s = game.surfaces[f.surface]
  if not c.unit.valid then
    if storage.carrying then for _, u in ipairs(c.escort or {}) do if u.valid then storage.carrying[u.unit_number] = nil end end end
    f.carrier = nil
    f.seed_tried = tick
    return trace(string.format("farm %d: its carrier killed on its way", f.id))
  end
  -- Arrived: the carrier at its field, or its group done there (a carrier lagging behind its escort, its big body caught
  -- on the way: the group stood 10 tiles from the field, finished, and the carrier 38 back, for good; seedbare, 0.2.28).
  local arrived = d2(c.unit.position, c.dest) < 24 * 24 or (c.group and c.group.valid
    and c.group.state == defines.group_state.finished and d2(c.group.position, c.dest) < 16 * 16)
  if arrived then
    local nf = farm.land(s, c.dest, {biomass = c.bank})
    local rec = nf and nf.pens[1] and herd.pen(nf.pens[1])
    for _, u in ipairs(c.escort) do if u.valid and rec then table.insert(rec.stock, u) end end
    if c.group.valid then c.group.destroy() end
    c.unit.destroy()
    if storage.carrying then for _, u in ipairs(c.escort or {}) do if u.valid then storage.carrying[u.unit_number] = nil end end end
    f.carrier = nil
    f.seeds = (f.seeds or 0) + 1
    if not nf then trace(string.format("farm %d: its carrier found no nests at its field", f.id)) end
    return
  end
  if tick - c.t > CARRY_LIMIT then
    if c.group.valid then c.group.destroy() end
    c.unit.die()
    if storage.carrying then for _, u in ipairs(c.escort or {}) do if u.valid then storage.carrying[u.unit_number] = nil end end end
    f.carrier = nil
    return trace(string.format("farm %d: its carrier lost its way", f.id))
  end
  if not (c.group and c.group.valid) then
    c.group = s.create_unit_group{position = c.unit.position, force = B.force}
    c.group.add_member(c.unit)
    for _, u in ipairs(c.escort) do if u.valid then c.group.add_member(u) end end
    c.ordered = nil
  end
  -- Its walk, for the trace: where it is every five minutes.
  if tick - (c.said or c.t) >= 5 * 3600 then
    c.said = tick
    local tg = c.legs[c.leg] or c.dest
    trace(string.format("farm %d: its carrier at %.0f,%.0f, leg %d of %d (to %.0f,%.0f; its field %.0f,%.0f), %d escorts",
      f.id, c.unit.position.x, c.unit.position.y, c.leg, #c.legs, tg.x, tg.y, c.dest.x, c.dest.y, #c.escort))
    local at = c.unit.position
    trace(string.format("farm %d: round its carrier (30 tiles): %d water tiles, %d cliffs, %d wild biters, command %s, group %s",
      f.id, s.count_tiles_filtered{position = at, radius = 30, collision_mask = "water_tile"},
      s.count_entities_filtered{position = at, radius = 30, type = "cliff"},
      s.count_entities_filtered{position = at, radius = 30, force = "enemy", type = "unit"},
      tostring(c.group.valid and c.group.command and c.group.command.type), tostring(c.group.valid and c.group.state)))
    local cm = c.unit.commandable
    trace(string.format("farm %d: its group at %s, %d members; the carrier %s it, its own command %s", f.id,
      c.group.valid and string.format("%.0f,%.0f", c.group.position.x, c.group.position.y) or "gone",
      c.group.valid and #c.group.members or 0, cm and cm.parent_group == c.group and "in" or "not in",
      tostring(cm and cm.command and cm.command.type)))
    local d = c.dest
    local q = s.find_non_colliding_position("lp-bred-carrier", d, 6, 1)
    trace(string.format("farm %d: round its field %.0f,%.0f (20 tiles): %d water tiles, %d cliffs, %d trees; a carrier fits %s",
      f.id, d.x, d.y, s.count_tiles_filtered{position = d, radius = 20, collision_mask = "water_tile"},
      s.count_entities_filtered{position = d, radius = 20, type = "cliff"},
      s.count_entities_filtered{position = d, radius = 20, type = "tree"},
      q and string.format("at %.0f,%.0f", q.x, q.y) or "nowhere"))
  end
  -- No nearer its field for STUCK: a new way from where it stands (REPLANS at most), its legs walked again.
  local dd = d2(c.unit.position, c.dest)
  if not c.best or dd < c.best - 100 then c.best, c.best_t = dd, tick
  elseif tick - c.best_t >= STUCK and (c.replans or 0) < REPLANS then
    c.replans = (c.replans or 0) + 1
    c.legs, c.leg, c.ordered, c.best_t = carrier_legs(f, c.unit.position, c.dest), 1, nil, tick
    trace(string.format("farm %d: its carrier stuck at %.0f,%.0f: a new way (%d legs, try %d)", f.id, c.unit.position.x,
      c.unit.position.y, #c.legs, c.replans))
  end
  local target = c.legs[c.leg]
  while target and d2(c.unit.position, target) < 15 * 15 and c.leg < #c.legs do
    c.leg = c.leg + 1
    target = c.legs[c.leg]
    c.ordered = nil
  end
  -- Its group idle (the leg walked, or an order that failed at once: an unreachable waypoint): on to the next leg. (It
  -- re-gave the same leg once a minute and walked 45 tiles in 40 minutes.)
  if c.ordered and c.group.valid and not c.group.command and c.leg < #c.legs then
    c.leg = c.leg + 1
    target = c.legs[c.leg]
    c.ordered = nil
  end
  if target and (not c.ordered or tick - c.ordered > 3600) then
    c.group.set_command{type = defines.command.go_to_location, destination = target, radius = 6,
      distraction = defines.distraction.by_enemy}
    c.ordered = tick
  end
end

-- Its incubators breed while it has biomass, and stop when it has none.
local function breeding(f, on)
  for _, pid in ipairs(f.pens) do
    local rec = herd.pen(pid)
    -- (Hatching: up to its home guard, no more.)
    local want = on and not (rec and rec.unfed) and not (hatching() and rec and #herd.stock(rec) >= guard_of(f))
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
-- With several cultures (seeding, 0.2.22) the force's evolution is one a surface: the most any culture there breeds at
-- (each culture's own, f.evo, climbing while its clinic stands, held at STOCK_EVO without one). Set by each in turn, a
-- young culture with no clinic yet held it at 0.3 for the old one too.
local function evolve(f, surface)
  local bf, enemy = game.forces[B.force], game.forces.enemy
  if not bf then return end
  f.evo = f.evo or bf.get_evolution_factor(surface)
  local up = cell.clinic_up(f.id)
  if up then
    f.evo = math.min(1, math.max(enemy and enemy.get_evolution_factor(surface) or 0, f.evo + CLIMB / 6))
  end
  local best = 0
  for id, g in pairs(st().list) do
    if g.surface == f.surface and g.evo then
      best = math.max(best, cell.clinic_up(id) and g.evo or math.min(g.evo, STOCK_EVO))
    end
  end
  bf.set_evolution_factor(best, surface)
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
  -- (Its big bursters: developed, not bred by chance, herd.develop_bursters.)
  if herd.bursters_developed() then out["lp-bred-big-burster"] = true end
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
  local eat = {}
  for id, f in pairs(s.list) do
    eat[id] = {}
    for _, pid in ipairs(f.pens) do
      local rec = herd.pen(pid)
      if rec and rec.pen.valid then table.insert(eat[id], rec.pen) end
    end
  end
  creep.drink(10, eat)
  for id, f in pairs(s.list) do
    local left = {}
    local surface = game.surfaces[f.surface]
    -- Its substrate (older saves: built now) and its technicians' rounds.
    cell.site(id, surface, f.pos)
    cell.tick(id, surface, f.pens, tick)
    local hired = cell.hire(id, surface, f.pens, tick, creep.of(id))
    if hired then trace(string.format("farm %d: buys a technician (%d now, %d incubators)", f.id, hired, #f.pens)) end
    evolve(f, surface)
    if tick % 36000 == 300 then trace(string.format("farm %d: %s", f.id, cell.summary(id, f.pens, tick))) end
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
        local seen = {}
        for _, pid in ipairs(f.pens) do
          local rec = herd.pen(pid)
          -- (Each once: a biter can stand in two incubators' stock, and counted twice its order read as filled.)
          if rec and rec.pen.valid then
            for _, u in ipairs(herd.stock(rec)) do
              if u.valid and not seen[u.unit_number] then seen[u.unit_number] = true; have[u.name] = (have[u.name] or 0) + 1 end
            end
          end
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
          -- (Hatching: its order is hatched with its wave, compose.)
          if want and not hatching() then fulfil(f, rec, surface, want, have) end
          if want and not hatching() then fulfil(f, rec, surface, want, have) end
        end
        if hungry and unfed(rec, tick) then
          cell.forget(pid)
          -- (Not taken again: one nest was taken, never reached, wild again seven times in five hours on nw, its stock
          -- over the fed cap let loose each time, 2026-10-29.)
          creep.block(creep.of(f.id), herd.release(pid))
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
            creep.block(creep.of(f.id), herd.release(pid))
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
    if hatching() then f.short = nil
    elseif have then f.short = short(want, have) elseif tick % 3600 == 300 then f.short = nil end
    local cul = creep.of(id)
    if cul then
      local t = #f.pens * TRICKLE / 6 * tune.strength("biotech") * creep.evo_rate(surface)
      creep.earn(cul, t)
      cul.trickled = (cul.trickled or 0) + t
      -- An order short: chance breeding waits while the biomass is kept for it, and a siege's sweep (its runts, one a mine on
      -- its way in) with it: kept for none, its 17 big bursters bred, its wave waited 20 minutes on 74 biomass for its sweep
      -- while chance breeding spent all it earned (farm siege, 2026-10-29). (Its growth and its carrier no longer: they
      -- spend their own pool, creep.earn.)
      f.reserve = (f.short or 0) + (f.siege and (f.siege.mines or 0) * shared.BREEDS["lp-sweeper"].cost or 0)
      -- Young (fewer than SEED_AT incubators), most of what it earns grows it (creep.YOUNG_SHARE); mature, a third.
      cul.share = #f.pens < SEED_AT and creep.YOUNG_SHARE or creep.GROWTH_SHARE
      -- And its incubators breed to its order alone till it is filled (by chance, mediums took all above one burster's
      -- price between its orders' minutes).
      if f.siege and f.short then f.reserve = math.huge end
      breeding(f, cul.biomass > f.reserve)
    end
    -- The creep takes the wild nest it reaches; with none near, it grows an incubator of its own (creep.bud).
    local take = #left < PENS_MAX and cell.keeps_up(id, f.pens, tick) and creep.bud(id, tick)
    if take then
      -- A wild spawner to take, or {found = position} (an engine object raises on an unknown key: asked by type).
      local spot = take.object_name == nil and take.found
      local pid
      if spot then
        local pen = surface.create_entity{name = "lp-pen", position = spot, force = B.force}
        pid = pen and herd.add_pen(pen)
      else
        pid = herd.capture(take)
      end
      local rec = pid and herd.pen(pid)
      if rec then
        rec.farm = f.id
        table.insert(f.pens, pid)
        if not spot then creep.plant(surface, rec.pen.position, f.id) end
        cell.build(pid, rec.pen, f.id, f.pos)
        f.taken = (f.taken or 0) + 1
        f.grown = spot and (f.grown or 0) + 1 or f.grown
        f.last_take = tick
        trace(string.format("farm %d: %s at %.0f,%.0f (%d incubators)", f.id,
          spot and "grew an incubator of its own" or "its creep took the nest", rec.pen.position.x,
          rec.pen.position.y, #f.pens))
      end
    end
    if #left == 0 then
      gone(f, "every pen dead")
    else
      if not f.tagged then tag(f) end
      if not storage.herd_off and not herd.out(id) and tick - f.last_wave >= tune.sooner("biotech", WAVE_GAP) then send(f, tick) end
      if not storage.seed_off then seed(f, tick); carry(f, tick) end
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
  -- Down to what it keeps back (f.reserve: its order's dearest breed, its seed bank), its incubators stop at once: checked
  -- on its tick alone, 16 incubators bred past it between checks, its biomass went below nothing, and the big bursters its
  -- siege waited on were never paid for (a megabase, 2026-10-28).
  if cul.biomass <= (f.reserve or 0) then breeding(f, false) end
end

-- An incubator killed: its share of its culture's biomass dies with it (what it holds over its incubators standing, this
-- one among them). Hatched at launch, its army is its biomass: a raid on its incubators killed the guard and the
-- incubator, and the army it would have hatched stood whole in the rest (the user, 2026-10-30).
function farm.on_pen_died(e)
  local rec = herd.pen(e.entity.unit_number)
  local f = rec and rec.farm and st().list[rec.farm]
  local cul = f and creep.of(f.id)
  if not cul then return end
  local standing = 0
  for _, id in ipairs(f.pens) do
    local r = herd.pen(id)
    if r and r.pen.valid then standing = standing + 1 end
  end
  local share = math.max(0, cul.biomass) / math.max(1, standing)
  cul.biomass, cul.lost = cul.biomass - share, (cul.lost or 0) + share
  f.pens_killed = (f.pens_killed or 0) + 1
  trace(string.format("farm %d: an incubator killed (by %s); %.0f of its biomass with it, %.0f left over %d", f.id,
    e.force and e.force.name or "?", share, cul.biomass, standing - 1))
end

-- A pen hit by anyone at war with it: its farm's wave on its way comes home.
function farm.on_damaged(e)
  local ent = e.entity
  if ent.name == "lp-tumor" then return end
  if ent.name ~= "lp-pen" or not e.force or e.force.name == B.force or shared.is_biters(e.force.name) then return end
  local rec = herd.pen(ent.unit_number)
  if rec and rec.farm and herd.out(rec.farm) then herd.recall(rec.farm, "its farm is attacked") end
end

-- The siege lab: one weighing (target_from, its reading of the ways in fresh) timed at `cell` tiles a cell, written to
-- landing-party/timing.txt (the design consult's step 2: one reading at its waves' grain, its cost not yet known).
-- Tests only: its chance breeds' weights, untilted and tilted by `killers` (what killed a wave: chance, fit_of).
function farm.debug_chance(id, killers)
  local f = st().list[id]
  if not f then return nil end
  local s = game.surfaces[f.surface]
  local total = 0
  for _, n in pairs(killers) do total = total + n end
  local out = {}
  for _, x in ipairs(chance(f, s)) do out[x.name] = {x.w} end
  for _, x in ipairs(chance(f, s, function(name) return fit_of(name, killers, total) end)) do
    out[x.name] = out[x.name] or {0}
    out[x.name][2] = x.w
  end
  return out
end

-- Tests only: the siege a farm would size against a plan (siege_size): its big bursters, herd and screen, or nil.
-- Tests only: its random source reseeded (the siege lab's replicates of one save, LAB_SEED).
function farm.debug_reseed(id, seed)
  local f = st().list[id]
  if f then f.rng = rng.new(seed) end
  return f ~= nil
end

function farm.debug_siege_size(id, pl, floor)
  local f = st().list[id]
  if not f then return nil end
  local k, n, _, _, _, fodder = siege_size(f, pl, nil, floor)
  return k and {k = k, n = n, fodder = fodder} or nil
end

function farm.debug_time_ways(id, cell)
  local f = st().list[id]
  if not f then return false end
  local s = game.surfaces[f.surface]
  storage.biotech_ways_cell, f.ways = cell, nil
  local p = helpers.create_profiler()
  local target, rival = target_from(s, f.pos, f, WAVE_MAX, {})
  p.stop()
  storage.biotech_ways_cell, f.ways = nil, nil
  helpers.write_file("landing-party/timing.txt", {"", "weighing, cell " .. cell .. ": ", p, "\n"}, true)
  -- (And one plan, as a wave's: what each wave already pays at its waves' grain.)
  if target and cell == 16 then
    local q = helpers.create_profiler()
    herd.plan(s, f.pos, target, rival or players(), WAVE_MAX)
    q.stop()
    helpers.write_file("landing-party/timing.txt", {"", "plan, cell 16: ", q, "\n"}, true)
  end
  return true
end

-- The siege lab (tests/lp-sim, mix lab; scripts/siegelab.sh): its culture holds `biomass` at least, and the farm weighs
-- its next wave now (its retries, its waits and its gap since the last wave cleared); what it decides is its own.
function farm.debug_lab_prime(id, biomass)
  local f = st().list[id]
  if not f then return false end
  local cul = creep.of(id)
  if cul and biomass then cul.biomass = math.max(cul.biomass, biomass) end
  f.escalate_retry, f.order_since = nil, nil
  f.last_wave = game.tick - tune.sooner("biotech", WAVE_GAP)
  return true
end

-- Dev and tests: a farm made ripe to seed at its next look (its field read as filled, its bank full, no wait).
function farm.debug_seed(id)
  local f = st().list[id]
  if not f then return false end
  -- Ripe now and for good (a nest its creep takes after this resets the field's clock: farm seed, 0.2.28).
  f.last_take, f.seed_tried, f.seed_forced = game.tick - FILLED_WAIT, nil, true
  local cul = creep.of(id)
  if cul then cul.growth = math.max(cul.growth or 0, 2 * SEED_BANK) end
  return true
end

-- Dev: every farm sends a wave at its next check, its pens topped up to send one.
-- A wave now (/lp wave; tests): each incubator's stock topped up past its guard. With n (/lp wave <n>, dev: the user,
-- 2026-10-26, to see a mega wave in play): the first culture's incubators bred n more between them, and its next wave
-- that big, past WAVE_MAX and its escalation.
-- (decide: stock topped up and a wave let go, what it goes for and whether it goes at all its own; tests.)
function farm.debug_wave(n, deep, decide)
  local any = false
  for _, f in pairs(st().list) do
    local s = game.surfaces[f.surface]
    local pens = {}
    for _, id in ipairs(f.pens) do
      local rec = herd.pen(id)
      if rec and rec.pen.valid then pens[#pens + 1] = rec end
    end
    if n and not any and #pens > 0 then
      for k, rec in ipairs(pens) do
        bred_stock(s, rec.pen, math.floor(n / #pens) + ((k <= n % #pens) and 1 or 0) + guard_of(f))
      end
      f.debug_size = n
    else
      for _, rec in ipairs(pens) do bred_stock(s, rec.pen, math.max(0, HOME_GUARD + 10 - #herd.stock(rec))) end
    end
    if deep and not f.debug_deep then f.debug_deep = true end
    if not decide then f.debug_now = true end
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
      lost_to_feed = f.lost_to_feed or 0, refused = f.refused or 0, repeats = f.repeats or 0, evo = f.evo, clinic = cell.clinic_up(id), seeds = f.seeds or 0, grown = f.grown or 0,
      seeded = f.seeded, carrier = f.carrier and f.carrier.unit.valid and {f.carrier.unit.position.x, f.carrier.unit.position.y} or nil,
      bred_evo = game.forces[B.force] and game.forces[B.force].get_evolution_factor(f.surface), biomass = creep.of(id) and {
        now = creep.of(id).biomass, growth = creep.of(id).growth, drunk = creep.of(id).drunk, trickled = creep.of(id).trickled, eaten = creep.of(id).eaten,
        spent = creep.of(id).spent or 0, bred = creep.of(id).bred or 0, wants = creep.of(id).wants,
        budded = creep.of(id).budded or 0, blocked = table_size(creep.of(id).blocked or {})}, short = f.short, saving = f.saving,
      reserve = f.reserve, siege = f.siege and {k = f.siege.k, at = {f.siege.at.x, f.siege.at.y}, cover = f.siege.cover,
        n = f.siege.n, breed = f.siege.breed, price = f.siege.price}, held = f.held_why})
  end
  return out
end

return farm
