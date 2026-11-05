-- What Synthexis learns from a wave, split from herd.lua (the user, 2026-10-31: the refactor, herd.lua's 3,549 lines): what
-- crossing cost it against what it reckoned (learn_scale), the prices of its killers on the march and at the breach
-- (learn_march, learn_price), its attempt at a place (record_attempt, tactics.lua), its rams' reach (herd.learn_reach),
-- whether a wave was held back (herd.held_back), and the stops that develop its big bursters (herd.stopped, herd.held,
-- herd.develop_bursters). Installed by herd.lua with the locals it shares (K), as siege.lua is by ops.lua.
local attempt = require("__landing-party__.scripts.attempt")
local firemap = require("__landing-party__.scripts.firemap")
local know = require("__landing-party__.scripts.know")
local shared = require("__landing-party__.shared")
local tactics = require("__landing-party__.scripts.tactics")
local threat = require("__landing-party__.scripts.threat")

local herd_learn = {}

function herd_learn.install(herd, K)
local B, FIRE_NEAR, foe_name, foes, lessons, st = K.B, K.FIRE_NEAR, K.foe_name, K.foes, K.lessons, K.st

local function learn_scale(w)
  if not (w.breach and w.way_in and w.way_in.lost > 0) then return end
  local crossed = 0
  for key, n in pairs(w.lost_worth_by or w.lost_by or {}) do
    local stage = key:match("^(%a+) ")
    if stage == "march" or stage == "breach" or stage == "withdraw" then crossed = crossed + n end
  end
  w.crossed = crossed
  -- (Against what it expected with its big bursters' work counted, herd.way_cost: against the bare price, a siege that
  -- went as planned taught it every crossing was cheaper.)
  local expected = herd.way_cost(w.way_in.lost, w.way_in.cover, w.big_sent, w.way_in.openable, foe_name(w))
  w.scale_learned = know.learn_scale("biotech", foe_name(w), crossed / (2 * math.max(1, expected)))
end

-- What its march cost it, learned as its breaches are (the user, 2026-10-28): each killer on the march, its kills over how
-- many of its kind stood where they were (within FIRE_NEAR of their middle). Learned at the breach alone, a corporation's
-- flamethrower turrets its siege walked past killed 61 and stayed at their prior, 3.8, and the next siege went that way.
local function learn_march(w)
  local s = game.surfaces[w.surface]
  if not (s and w.march_killers) then return end
  local left = 0
  for _, u in ipairs(w.members) do if u.valid then left = left + 1 end end
  -- (Against the number that set out: w.size is what got through once it punches through, and a wave of 60 through with
  -- 3 and wiped out read as whole, and its laser price fell from 15 to 1.1; the fire consult, 2026-10-30.)
  local wiped = left <= 0.2 * (w.sent or w.size or 1)
  local base = B.mind.per_turret or firemap.AFFORD
  local weight = math.min(1, (w.sent or w.size or shared.WAVE_MAX) / shared.WAVE_MAX)
  w.price_learned = w.price_learned or {}
  for key, mk in pairs(w.march_killers) do
    local name = mk.name or key
    local at = {mk.x / mk.n, mk.y / mk.n}
    -- (Inside and on the way out, over the guns of its kind that killed: over all of its kind within reach, inside a
    -- square fort of 59 lasers, each sample read a laser at 8 and its price fell trial by trial, the siege lab, 2026-10-30.)
    local n = 0
    if mk.ids then for _ in pairs(mk.ids) do n = n + 1 end
    else n = s.count_entities_filtered{position = at, radius = FIRE_NEAR, name = name, force = mk.force} end
    if n > 0 then
      local killed = mk.worth or mk.n
      local per = know.learn_price("biotech", mk.force, name, killed / n, threat.prior_of(name, mk.force, base), wiped, weight)
      w.price_learned[(mk.name and key or "march " .. name)] = {sample = killed / n, per = per, n = n}
    end
  end
  -- (Each once: learned when it re-plans under fire, and again at its end from what came after.)
  w.march_killers = nil
end
herd.learn_march = learn_march

local function learn_price(w)
  learn_scale(w)
  learn_march(w)
  -- What its bursters opened: the guns its bursts broke over the big bursters it sent (herd.opens).
  -- (Of its rams those that went: held for ranks it never needed, they neither opened nor failed to reach anything.)
  local sent = (w.big_sent or 0) - (w.rams_unused or 0)
  if sent > 0 then
    local broke = 0
    for kind, n in pairs(w.bursts and w.bursts.broke or {}) do
      if kind == "ammo-turret" or kind == "electric-turret" or kind == "fluid-turret" then broke = broke + n end
    end
    local k, foe = know.of("biotech"), foe_name(w)
    k.opens = k.opens or {}
    local old = k.opens[foe] or herd.BURST_OPENS
    k.opens[foe] = math.max(herd.OPENS_MIN, old + (broke / sent - old) * know.PRICE_LEARN)
    w.opens_learned = {sample = broke / sent, now = k.opens[foe]}
    k.reach = k.reach or {}
    k.reach[foe] = herd.learn_reach(k.reach[foe] or 1, w.big_set_off or 0, sent, w.wall_stuck)
    k.reach_alive = k.reach_alive or {}
    k.reach_alive[foe] = herd.learn_reach(k.reach_alive[foe] or 1, w.big_set_off or 0, sent, false)
  end
  if not w.breach then return end
  local f = foes(w)[1]
  local foe = f and (type(f) == "string" and f or f.name) or "player"
  w.price_learned = w.price_learned or {}
  -- With no wall where it broke in (breach_by read at a wall only), what covered the ground where its own died breaking in,
  -- in the middle of them: on a megabase's laser line, 58 of its own killed at a breach with no wall taught it nothing of
  -- lasers, and its next wave priced them as before (2026-10-27).
  if not w.breach_by then
    local x, y, k = 0, 0, 0
    for _, d in ipairs(w.dead_at or {}) do
      if d[3] == "breach" then x, y, k = x + d[1], y + d[2], k + 1 end
    end
    local s = game.surfaces[w.surface]
    if k > 0 and s then
      local map = firemap.read(s, {x / k, y / k}, 0, foes(w), herd.price_of)
      w.breach_by = {}
      for _, t in ipairs(firemap.cover(map, {x / k, y / k})) do w.breach_by[t.name] = (w.breach_by[t.name] or 0) + 1 end
    end
  end
  -- Not where its big bursters broke the guns first: what the guns left standing then cost is no price of theirs (a siege's
  -- wave lost 4 to 11 lasers its bursters had opened, and learned a laser cost it 1.0, not 15; the siege test, 2026-10-28).
  -- (Most of it lost: what it lost is a least, the guns would have taken more of more; it raises a price only.)
  local left = 0
  for _, u in ipairs(w.members) do if u.valid then left = left + 1 end end
  -- (Against the number that set out: w.size is what got through once it punches through, and a wave of 60 through with
  -- 3 and wiped out read as whole, and its laser price fell from 15 to 1.1; the fire consult, 2026-10-30.)
  local wiped = left <= 0.2 * (w.sent or w.size or 1)
  local base = B.mind.per_turret or firemap.AFFORD
  local weight = math.min(1, (w.sent or w.size or shared.WAVE_MAX) / shared.WAVE_MAX)
  -- (A siege's: the guns still covering its breach once its bursters were spent, breach_after, sequence. Learned from
  -- none, its laser price never moved in four sieges that each lost 450 to 770 mediums to them; the siege lab, 2026-10-30.)
  for proto, n in pairs((w.big_sent or 0) == 0 and w.breach_by or w.breach_after or {}) do
    local killed = (w.lost_worth_by or w.lost_by or {})["breach " .. proto] or 0
    local per = know.learn_price("biotech", foe, proto, killed / n, threat.prior_of(proto, foe, base), wiped, weight)
    w.price_learned[proto] = {sample = killed / n, per = per, n = n}
  end
  do
    for key, killed in pairs(w.lost_worth_by or w.lost_by or {}) do
      local proto = key:match("^breach (.+)$")
      local prof = proto and threat.profile(proto)
      -- (Nor its own: a big burster's blast kills it, and it learned its own breed as a killer at 8.)
      if proto and proto ~= "none" and not proto:find("^lp%-bred%-") and not (w.breach_by and w.breach_by[proto])
        and not (prof and (prof.kind == "ammo" or prof.kind == "power" or prof.kind == "fluid")) then
        local per = know.learn_price("biotech", foe, proto, killed, nil, wiped, weight)
        w.price_learned[proto] = {sample = killed, per = per, n = 0}
      end
    end
  end
end

-- What it has tried, and how it reads it: tactics.lua, every attacker's (by foe, place and method; faded; voided against a
-- defence since reinforced; shared between breaches near). Its own wrappers, as Synthexis ("biotech").
herd.SIG_CHANGE, herd.NEAR_BREACH = tactics.SIG_CHANGE, tactics.NEAR_BREACH
herd.attempt_key = tactics.key
herd.history = tactics.history
herd.best_size = tactics.best_size
function herd.attempt(foe, pos, method) return tactics.attempt("biotech", foe, pos, method, B.mind.fade) end
function herd.history_near(foe, breach, method, sig) return tactics.history_near("biotech", foe, breach, method, sig, B.mind.fade) end
function herd.foe_record(foe, method) return tactics.foe_record("biotech", foe, method) end
herd.place_sig = attempt.sig   -- (one measure for every attacker: attempt.lua)
herd.SIG_REACH = attempt.SIG_REACH
-- The share of what a wave lost (in mediums) that died to area damage (shared.AREA_DAMAGE, by the event's damage type),
-- nil where it lost nothing.
function herd.area_of(w)
  local all, area = 0, 0
  for _, v in pairs(w.lost_worth_by or {}) do all = all + v end
  if all <= 0 then return nil end
  for dt, v in pairs(w.lost_dmg or {}) do if shared.AREA_DAMAGE[dt] then area = area + v end end
  return math.min(1, area / all)
end
local function record_attempt(w)
  local at = w.plan and w.plan.target or (w.goal and {w.goal.x, w.goal.y})
  if not at then return end
  local k = know.of("biotech")
  k.attempts = k.attempts or {}
  -- (A strike's cutters are the strike's: what they spent and razed waits for it, st().cutters, and is counted with its own.)
  if w.cut and w.cut.for_strike then
    local spent0 = 0
    for _, v in pairs(w.lost_worth_by or {}) do spent0 = spent0 + v end
    st().cutters = st().cutters or {}
    st().cutters[w.id] = {spent = spent0, got = w.razed_worth or 0, sent = w.worth or 0}
    return
  end
  local method = w.cut and "cut" or w.wait_cut and "strike" or w.spread and "spread"
    or ((w.big_sent or 0) > 0 or w.fodder_set) and "siege" or "raid"
  local spent = 0
  for _, v in pairs(w.lost_worth_by or {}) do spent = spent + v end
  -- (A cut got what it razed, as any wave: credited with the price of the guns it parted, its record was in other units
  -- than its raids'.)
  local got, sent = w.razed_worth or 0, (w.worth or 0) + (w.big_sent or 0) * herd.worth("lp-bred-big-burster")
  local cutters = w.wait_cut and st().cutters and st().cutters[w.wait_cut.wave]
  if cutters then
    spent, got, sent = spent + cutters.spent, got + cutters.got, sent + cutters.sent
    st().cutters[w.wait_cut.wave] = nil
  end
  -- (Its last attempts there, each what it sent, spent and razed: the size that razed most for what it spent is the one it
  -- sends again, farm.lua siege_size; tactics.record.)
  tactics.record("biotech", foe_name(w), at, method, {sent = sent, spent = spent, got = got, inside = w.t_inside ~= nil,
    sig = w.sig, rams = w.big_sent or 0,
    -- (A spread's: the point whose gap opened, or the plan's breach.)
    breach = w.spread and w.spread.opened and {w.breach.x, w.breach.y} or w.plan and w.plan.breach or (w.breach and {w.breach.x, w.breach.y}),
    probe = w.trust == "probe", area = herd.area_of(w)})
end

-- Its big bursters, developed (farm.lua unlocked) once it has been stopped DEVELOP_HELD times, wherever: walls that held
-- its waves, or a place it could not go at all (herd.stopped, the farm: its plan too dear, no way in, nothing worth a
-- wave). An answer it grows to what stopped it, as the corporations' research answers what turned them back
-- (shared.CORPS trees: turned_back = 2). Announced to the players. (On walls held alone, the user's fort held its first
-- wave and its farm held after it, sending none: no second wall held, no bursters, ever; the siege lab, 2026-10-30.)
-- The same stop at the same place counts again STOP_AGAIN on, not at each look (its farm looks every ten seconds): once
-- each ever, the user's fort held sixteen times at one place for one reason, counted once, and waited four trials for a
-- second stop elsewhere before it developed them (the siege lab, 2026-10-31).
-- The share of its rams that reach the wall, learned from a siege: `set_off` of `sent` (its rams a siege, 1 over it).
-- None reached it: twice as many rams next time (by its share alone, 1 ram then 2 then 3, each killed short in five
-- seconds by the square lab fort's lasers, and its record of those sieges kept it from a third; 2026-10-31). Every one
-- set off and still stopped at a wall (`stuck`): twice as many too, learned, not counted (the user: "should this really
-- be hard coded?"): two walls 4 tiles apart took its one ram's blast at the outer, its herd died at the inner, four
-- trials, then it held; a wall twice as thick, a maze or a wall researched the same.
function herd.learn_reach(r0, set_off, sent, stuck)
  local r = math.max(herd.OPENS_MIN, r0 + (set_off / sent - r0) * know.PRICE_LEARN)
  if set_off == 0 or stuck then r = math.max(herd.OPENS_MIN, math.min(r, 1 / (2 * sent))) end
  return r
end
-- A wave the foe held back: half of it or more lost, and not in, or not one gun broken. (Not in alone: with "in" counted
-- only past the wall, raids at a saw-toothed lane broke 12 guns a wave over it from outside, never got in, and no wall
-- had held them: no bursters, 16 raids of 16 thrown at it; the siege lab, 2026-10-31.)
function herd.held_back(alive_n, sent, guns_broke, inside)
  return alive_n * 2 <= sent and (guns_broke == 0 or not inside)
end
local DEVELOP_HELD = 2
local STOP_AGAIN = 15 * 3600
function herd.stopped(key, tick)
  tick = tick or game.tick
  local k = know.of("biotech")
  k.stopped = k.stopped or {}
  local was = k.stopped[key]
  if type(was) == "number" then was = {t = was, n = 1} end
  if was and tick - was.t < STOP_AGAIN then return end
  k.stopped[key] = {t = tick, n = (was and was.n or 0) + 1}
  herd.develop_bursters()
end
function herd.held()
  local k = know.of("biotech")
  local held = 0
  for _, l in pairs(lessons()) do held = held + (l.walled_held or 0) end
  for _, s in pairs(k.stopped or {}) do held = held + (type(s) == "table" and s.n or 1) end
  return held
end
function herd.develop_bursters()
  local k = know.of("biotech")
  if k.bursters then return end
  local held = herd.held()
  if held < DEVELOP_HELD then return end
  k.bursters = game.tick
  if storage.trace then
    helpers.write_file("landing-party/decisions.txt", string.format("%8d biotech  develops big bursters: walls held its waves %d times\n",
      game.tick, held), true)
  end
  for _, f in pairs(game.forces) do
    if #f.players > 0 and shared.is_player_force(f) then shared.notice(f, {"lp.biotech-bursters"}) end
  end
end
function herd.bursters_developed() return know.of("biotech").bursters ~= nil end

return {learn_scale = learn_scale, learn_march = learn_march, learn_price = learn_price, record_attempt = record_attempt}
end

return herd_learn
