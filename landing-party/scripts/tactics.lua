-- How an attacker chooses, the same for every faction (the user, 2026-10-31: lessons from Synthexis for the others, "so
-- we don't have to do all this work again from scratch"). Its attempt memory, by foe, place and method: what each attempt
-- sent, spent and got, whether it got in, the defence it met (attempt.sig) and where it broke in; read faded, voided when
-- the defence has been reinforced since, and shared between places whose breaches lie near. And its menu: each way it
-- could go scored alike, what it would get for what it would lose, nearer first, with what its attempts there did in
-- place of what it reckoned, less for each tried lately, picked by chance in proportion. Built for Synthexis (farm.lua's
-- menu and herd.lua's memory, the siege AI design consult, 2026-10-30); a faction registers its own methods and fills
-- its own records. Kept in its knowledge (know.of(faction).attempts). (Not planner.lua: that one builds settlements.)
local know = require("__landing-party__.scripts.know")
local rng = require("__landing-party__.scripts.rng")

local tactics = {}

tactics.SIG_CHANGE = 0.3   -- a defence this much stronger (guns or walls) than an attempt met voids that attempt
tactics.NEAR_BREACH = 32   -- attempts that broke in within this of a breach speak for it, wherever they were kept
tactics.HISTORY = 5        -- attempts kept at a place, by method
tactics.REPEAT = 0.3       -- what each attempt lately made at a place takes off what it expects there
tactics.FADE = 40 * 3600   -- an attempt this old says e^-1 of what it did

local function name_of(foe) return type(foe) == "string" and foe or foe.name end

-- Its place: the foe and the 64-tile cell. (By place, not breach cell: Synthexis's probes' breaches moved a cell or two
-- each time, every one read as untried, and none grew into a siege sized on what had worked; the siege lab, 2026-10-30.)
function tactics.key(foe, pos)
  local x, y = pos.x or pos[1], pos.y or pos[2]
  return string.format("%s|%d,%d", name_of(foe), math.floor(x / 64), math.floor(y / 64))
end

-- Its record by method at a place, and how much it still says (faded).
function tactics.attempt(faction, foe, pos, method, fade)
  local a = know.of(faction).attempts
  local r = a and a[tactics.key(foe, pos) .. "|" .. method]
  if not r then return nil, 0 end
  return r, math.exp(-(game.tick - r.tick) / (fade or tactics.FADE))
end

-- An attempt made: e = {sent, spent, got, inside, sig, rams, breach, probe, reached}, its last HISTORY kept at its place
-- (reached false: it never got to the place, what met it on the way is not the place's defence).
function tactics.record(faction, foe, at, method, e)
  local k = know.of(faction)
  k.attempts = k.attempts or {}
  local key = tactics.key(foe, at) .. "|" .. method
  local r = k.attempts[key] or {n = 0, spent = 0, got = 0, inside = 0}
  r.n, r.spent, r.got = r.n + 1, r.spent + e.spent, r.got + e.got
  if e.inside then r.inside = r.inside + 1 end
  r.tick, r.last = game.tick, {spent = e.spent, got = e.got, inside = e.inside, probe = e.probe}
  r.hist = r.hist or {}
  table.insert(r.hist, {sent = e.sent, spent = e.spent, got = e.got, inside = e.inside, sig = e.sig, tick = game.tick,
    rams = e.rams or 0, breach = e.breach, reached = e.reached})
  while #r.hist > tactics.HISTORY do table.remove(r.hist, 1) end
  k.attempts[key] = r
end

-- Whether a defence stands stronger now than an attempt met it: more guns or more walls by over SIG_CHANGE. (Weaker, the
-- attempt holds: a hole left open is its to come back through. The user, 2026-10-30: "are we not at risk of perpetual
-- identical actions?"; a record of a siege that razed 45 outlived the guns put there after.)
function tactics.stronger(now, was)
  if not (now and was) then return false end
  return now.guns > was.guns + tactics.SIG_CHANGE * math.max(was.guns, 3)
    or now.walls > was.walls + tactics.SIG_CHANGE * math.max(was.walls, 10)
end

-- Its attempts at a place that still speak for it: against a defence no stronger than it stands now (sig).
function tactics.history(r, sig)
  local out = {}
  for _, a in ipairs(r and r.hist or {}) do
    if not tactics.stronger(sig, a.sig) then out[#out + 1] = a end
  end
  return out
end

-- Of attempts that got in and got `least` or more, the one that got most for what it spent: what it sent, and the
-- specialists it brought (rams).
function tactics.best_size(r, least, sig)
  local best, bv
  for _, a in ipairs(tactics.history(r, sig)) do
    if a.inside and a.got >= least then
      local v = a.got / math.max(1, a.spent)
      if not bv or v > bv then best, bv = a, v end
    end
  end
  return best and best.sent, best and best.rams
end

-- Its attempts by `method` at `foe` that broke in within NEAR_BREACH of `breach`, wherever kept, not faded nor against a
-- defence since reinforced. (Kept by its target's cell alone, a siege through two walls on 4 rams at y 0 was not copied
-- at y -6, a cell over; the lane, 2026-10-31.)
function tactics.history_near(faction, foe, breach, method, sig, fade)
  local out = {}
  local a = know.of(faction).attempts
  if not (a and breach) then return out end
  local bx, by = breach.x or breach[1], breach.y or breach[2]
  local head, tail = name_of(foe) .. "|", "|" .. method
  for key, r in pairs(a) do
    if key:sub(1, #head) == head and key:sub(-#tail) == tail then
      for _, h in ipairs(r.hist or {}) do
        if h.breach and (h.breach[1] - bx) ^ 2 + (h.breach[2] - by) ^ 2 <= tactics.NEAR_BREACH ^ 2
          and math.exp(-(game.tick - (h.tick or 0)) / (fade or tactics.FADE)) > 0.1 and not tactics.stronger(sig, h.sig) then
          out[#out + 1] = h
        end
      end
    end
  end
  return out
end

-- What its attempts by `method` at `foe` have done on the mean over every place (got, spent; nil: none yet).
function tactics.foe_record(faction, foe, method)
  local a = know.of(faction).attempts or {}
  local pre, suf = name_of(foe) .. "|", "|" .. method
  local got, spent, n = 0, 0, 0
  for key, r in pairs(a) do
    if key:sub(1, #pre) == pre and key:sub(-#suf) == suf then
      for _, h in ipairs(r.hist or {}) do got, spent, n = got + h.got, spent + h.spent, n + 1 end
    end
  end
  if n == 0 then return nil end
  return got / n, spent / n
end

-- The ladder (the siege AI design consult, F: escalation as a ladder of methods, not of numbers): a method that failed at
-- a place lately (not in, nothing got), against a defence no stronger than it met, is worth less there by 1 over 1 + its
-- failures (faded), so the next method up has its turn. (Kessler-Hayashi raided a laser wall three times with 4, 7 and
-- 14, lost every one, razed nothing, and never weighed its mortar; the lane, 2026-10-31.)
function tactics.ladder(faction, foe, pos, method, sig, fade)
  local r = tactics.attempt(faction, foe, pos, method, fade)
  if not r then return 1 end
  local failed = 0
  for _, a in ipairs(tactics.history(r, sig)) do
    -- (Only where it got there: Kessler-Hayashi's raids on an assembler died to the wild nests on their way, its
    -- clearances working through them, and its raid there was set aside as failed; the clear test, worms.)
    if not a.inside and (a.got or 0) <= 0 and a.reached ~= false then
      failed = failed + math.exp(-(game.tick - (a.tick or 0)) / (fade or tactics.FADE))
    end
  end
  return 1 / (1 + failed)
end

-- The most specialists (rams, mortars' tier) its failures at a place lately brought, against a defence no stronger (nil:
-- none failed there): the caller brings more. Synthexis's rams doubled when every one set off and its wave still stood
-- at a wall (herd.learn_reach); a corporation's siege goes a tier up where its shells broke nothing.
function tactics.failed_specialists(faction, foe, pos, method, sig, fade)
  local r = tactics.attempt(faction, foe, pos, method, fade)
  if not r then return nil end
  local most
  for _, a in ipairs(tactics.history(r, sig)) do
    if not a.inside and (a.got or 0) <= 0 and math.exp(-(game.tick - (a.tick or 0)) / (fade or tactics.FADE)) > 0.1 then
      most = math.max(most or 0, a.rams or 0)
    end
  end
  return most
end

-- Below this the method is set aside there for now (about 44 minutes after one fresh failure, 72 after two; at 0.6, 16
-- minutes, its raids came back before it could save for a siege): with
-- nothing better on offer it holds and grows, as Synthexis holds when nothing pays, and saves for the next method up.
-- (Discounted alone, a failing raid that was its only option still went: Kessler-Hayashi's raids took every unit and
-- every part, and its siege, 6 guards and 100 parts, never came within reach; the lane, 2026-10-31.)
tactics.LADDER_HOLD = 0.75

-- One option weighed: op = {method, at, gain, lost, sent, dist, specialists}; what its attempts there did in place of
-- what it reckoned (the one that got most for what it spent, among those with as many specialists or more), less REPEAT
-- for each lately; its score, what it gets for what it loses as a share of what it sends, nearer first. Returns whether
-- it is worth weighing (its gain at `mind.min_gain` or more). (Over 1 + what it lost alone, a cut that razed 7 and lost
-- nothing scored 40 times a strike that razed 11 for 77 of 700; the fed lab fort, 2026-10-30.)
function tactics.expect(faction, op, foe, sig, mind, strength, faded)
  local fade = mind.fade or tactics.FADE
  local mem, wt = tactics.attempt(faction, foe, op.at, op.method, fade)
  if mem and wt > faded then
    local hist = tactics.history(mem, sig)
    -- (An option with more specialists than those it tried there is another option: those say nothing of it. Two sieges
    -- of 1 and 2 rams at the square lab fort, both killed short, read as all a siege there could do; 2026-10-31.)
    if (op.specialists or 0) > 0 then
      local kept = {}
      for _, a in ipairs(hist) do if (a.rams or 0) >= op.specialists then kept[#kept + 1] = a end end
      hist = kept
    end
    local best, bv, lately = nil, nil, 0
    for _, a in ipairs(hist) do
      local v = a.got / math.max(1, a.spent)
      if not bv or v > bv then best, bv = a, v end
      if a.tick then lately = lately + math.exp(-(game.tick - a.tick) / fade) end
    end
    if best then op.gain, op.lost, op.sent, op.known = best.got / (1 + tactics.REPEAT * lately), best.spent, best.sent, true end
    op.voided = #hist < #(mem.hist or {}) and #(mem.hist or {}) - #hist or nil
  end
  op.score = op.gain / (1 + op.lost / math.max(1, op.sent or strength or 1)) / (1 + (op.dist or 0) / mind.far)
  return op.gain >= (mind.min_gain or 0)
end

-- Its pick of the options weighed, by chance in proportion to their scores (`state`: its seeded random source, rng.lua),
-- the options sorted best first (ties by `tie`), and their total.
function tactics.pick(ops, state, tie)
  table.sort(ops, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return (tie and tie(a) or "") < (tie and tie(b) or "")
  end)
  local total = 0
  for _, o in ipairs(ops) do total = total + o.score end
  if #ops == 0 then return nil, 0 end
  local pick, r = ops[1], rng.next(state) * total
  for _, o in ipairs(ops) do
    r = r - o.score
    if r <= 0 then pick = o; break end
  end
  return pick, total
end

return tactics
