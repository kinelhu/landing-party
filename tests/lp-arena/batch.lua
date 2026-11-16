-- The arena's counter matrix (scripts/arena.sh): every unit kind against every other at equal spend, and against fixed
-- opponents (the player's lines, biter waves), each fight in its own pen, ROUNDS times with the spawn points moved a
-- little each round; results to script-output/lp-arena/results.jsonl, one fight a line (scripts/arena_report.py draws
-- the heatmap).
-- Kinds: every unit kind of the corporations; a Grubstake variant has its Serenity kind's stats but for infantry
-- (Grubstake's carry shotguns), so both infantries are kinds and the rest are fought as Serenity's prototype. Each
-- ordered pair is fought, the row's kind on Serenity's force from the west: (a, b) and (b, a) together cancel the side.
-- Spend: counts are picked so both sides spend as nearly the same parts as whole units allow, round BUDGET.
local arena = require("arena")
local params = require("params")
local shared = require("__landing-party__.shared")

local batch = {}

local BUDGET = 420
local WAVE = 20
local EVOS = {0.5, 0.8, 0.95}
local ROUNDS = params.rounds or 3
local SPACING = 220

-- {label, prototype}: the label is what the heatmap shows.
local KINDS = {
  {"infantry (Serenity)", "lp-infantry"}, {"infantry (Grubstake)", "lp-grubstake-infantry"},
  {"lance", "lp-lance"}, {"railgunner", "lp-railgunner"}, {"shock", "lp-shock"}, {"sapper", "lp-sapper"},
  {"buggy", "lp-buggy"}, {"slug", "lp-slug"}, {"scavenger", "lp-scavenger"}, {"harrier", "lp-harrier"}, {"laser drone", "lp-laser-drone"},
  {"tank", "lp-tank"}, {"prism", "lp-prism"}, {"tesla", "lp-tesla"}, {"scorcher", "lp-scorcher"},
  {"aegis", "lp-aegis"}, {"dozer", "lp-dozer"}, {"walker", "lp-walker"},
  -- Anti-air, one per side (2026-10-23).
  {"skyguard", "lp-skyguard"}, {"flak buggy", "lp-flak-buggy"},
  -- The player's, priced by command bandwidth (arena.PER_BANDWIDTH).
  {"trooper", "lp-trooper"}, {"breacher", "lp-breacher"}, {"rocket trooper", "lp-rocket-trooper"},
  {"flame trooper", "lp-flame-trooper"},
  {"battle tank", "lp-battle-tank"}, {"gun buggy", "lp-gun-buggy"},
  -- The biotech's (docs/biotech.md), at shared.BREEDS' price.
  {"bred small", "lp-bred-small-biter"}, {"bred behemoth", "lp-bred-behemoth-biter"},
  {"bred medium", "lp-bred-medium-biter"}, {"bred big", "lp-bred-big-biter"}, {"bred spitter", "lp-bred-medium-spitter"}, {"bred cinder", "lp-bred-cinder"},
  {"bred spore", "lp-bred-spore"}, {"bred stomper", "lp-bred-stomper"},
  -- On its creep (scripts/creep.lua): the same breeds with the haste and mend stickers renewed each second, as creep.tick
  -- gives them; the stickers are what the creep does to a unit (its tile alone does nothing to units).
  {"bred medium (creep)", "lp-bred-medium-biter", "creep"}, {"bred big (creep)", "lp-bred-big-biter", "creep"}, {"bred spitter (creep)", "lp-bred-medium-spitter", "creep"},
}

-- Mixed arms: {label, side x, side y}, each side a list of {prototype, count}; x is the ground army, y the same spend with
-- fliers in it.
local MIXES = {
  {"tanks / tanks + harriers", {{"lp-tank", 7}}, {{"lp-tank", 5}, {"lp-harrier", 3}}},
  {"prisms / prisms + harriers", {{"lp-prism", 4}}, {{"lp-prism", 3}, {"lp-harrier", 3}}},
  {"dozers / dozers + harriers", {{"lp-dozer", 5}}, {{"lp-dozer", 4}, {"lp-harrier", 2}}},
  {"tanks and rifles / with harriers", {{"lp-tank", 4}, {"lp-infantry", 18}},
    {{"lp-tank", 3}, {"lp-infantry", 12}, {"lp-harrier", 3}}},
}

-- The breach (the user, 2026-10-25: bursters as wall breakers "provided there are some meat shields to absorb turrets"):
-- the same spend sent at a walled gun line, as plain biters and with part of it in bursters. The line is one a plain
-- wave of mediums only just fails against, so what the bursters add shows. Its own family: LP_ARENA_ONLY=breach.
local BREACH_LINE = {{"player", "guns", 10}, {"player", "walls", 16, 2}}
local BREACH = {
  {"40 medium", {{"lp-bred-medium-biter", 40}}},
  {"34 medium + 1 burster", {{"lp-bred-medium-biter", 34}, {"lp-bred-cinder", 1}}},
  {"29 medium + 2 bursters", {{"lp-bred-medium-biter", 29}, {"lp-bred-cinder", 2}}},
  {"23 medium + 3 bursters", {{"lp-bred-medium-biter", 23}, {"lp-bred-cinder", 3}}},
  {"17 medium + 4 bursters", {{"lp-bred-medium-biter", 17}, {"lp-bred-cinder", 4}}},
  {"7 bursters", {{"lp-bred-cinder", 7}}},
  {"10 big", {{"lp-bred-big-biter", 10}}},
  {"6 big + 3 bursters", {{"lp-bred-big-biter", 6}, {"lp-bred-cinder", 3}}},
}

local function cost(proto) return arena.cost(shared.kind_of(proto), proto) end

-- Counts for a pair at equal spend: na of a, nb of b, both near BUDGET, the spends as close as whole units allow.
local function counts(ca, cb)
  local best
  for na = math.max(1, math.floor(0.7 * BUDGET / ca)), math.max(1, math.ceil(1.3 * BUDGET / ca)) do
    local nb = math.max(1, math.floor(na * ca / cb + 0.5))
    local sa, sb = na * ca, nb * cb
    local miss = math.abs(sa - sb) / math.max(sa, sb) + 0.1 * math.abs((sa + sb) / 2 - BUDGET) / BUDGET
    if not best or miss < best[3] then best = {na, nb, miss} end
  end
  return best[1], best[2]
end

local function matchups()
  local out = {}
  for _, a in ipairs(KINDS) do
    for _, b in ipairs(KINDS) do
      local na, nb = counts(cost(a[2]), cost(b[2]))
      table.insert(out, {kind = "pair", squad = a[1], against = b[1], creep_a = a[3] == "creep", creep_b = b[3] == "creep",
        a = {{"raw", a[2], na, "lp-serenity"}}, b = {{"raw", b[2], nb, "lp-grubstake"}}})
    end
    local n = math.max(1, math.floor(BUDGET / cost(a[2]) + 0.5))
    for _, evo in ipairs(EVOS) do
      table.insert(out, {kind = "fixed", squad = a[1], against = string.format("biters %.2f", evo), creep_a = a[3] == "creep",
        a = {{"raw", a[2], n, "lp-serenity"}}, b = {{"biters", "wave", WAVE, evo}}})
    end
    -- (teslas: Space Age's, its stun what counts against a biter; the counters table had no column for it, and a wave
    -- killed by teslas tilted no breed; the counters consult, 2026-10-31.)
    for _, ln in ipairs({{"guns", 6}, {"lasers", 4}, {"flamers", 3}, {"teslas", 3}}) do
      local def = {{"player", ln[1], ln[2]}, {"player", "walls", 14}}
      if ln[1] == "flamers" then table.insert(def, {"player", "guns", 2}) end
      table.insert(out, {kind = "fixed", squad = a[1], against = ln[1], creep_a = a[3] == "creep",
        a = {{"raw", a[2], n, "lp-serenity"}}, b = def})
    end
  end
  -- Mixed arms (the user, 2026-10-21: ground-only weapons "very problematic in mixed arms encounters?"): a ground army
  -- against the same army with part of its spend in fliers, both ways round. A flier that soaked the ground side's fire
  -- would turn these into routs; with each side's ground fire on ground targets they stay close.
  for _, mx in ipairs(MIXES) do
    for flip = 0, 1 do
      local x, y = mx[2], mx[3]
      if flip == 1 then x, y = y, x end
      local function side(list, force)
        local out = {}
        for _, e in ipairs(list) do table.insert(out, {"raw", e[1], e[2], force}) end
        return out
      end
      table.insert(out, {kind = "mix", squad = flip == 0 and mx[1] or mx[1] .. " (swapped)", against = mx[1],
        flip = flip, a = side(x, "lp-serenity"), b = side(y, "lp-grubstake")})
    end
  end
  for _, br in ipairs(BREACH) do
    local side = {}
    for _, e in ipairs(br[2]) do table.insert(side, {"raw", e[1], e[2], "lp-serenity"}) end
    table.insert(out, {kind = "breach", squad = br[1], against = "breach line", a = side, b = BREACH_LINE})
  end
  -- A trial (LP_ARENA_ONLY): only the matchups whose label holds that text.
  if params.only and params.only ~= "" then
    local kept = {}
    for _, m in ipairs(out) do if (m.squad .. " vs " .. m.against):find(params.only, 1, true) then table.insert(kept, m) end end
    out = kept
  end
  -- A shard (LP_ARENA_JOBS, scripts/arena.sh): every n-th matchup from the i-th, each shard its own game, in parallel
  -- (one game fought the matrix's 4,700 fights in 17 minutes on one core, 2026-11-10).
  if params.shard then
    local kept = {}
    for k, m in ipairs(out) do if (k - 1) % params.shard[2] == params.shard[1] then table.insert(kept, m) end end
    out = kept
  end
  return out
end

function batch.start()
  storage.batch = {round = 0, list = matchups(), live = {}}
  batch.next_round()
end

function batch.next_round()
  local B = storage.batch
  B.round = B.round + 1
  B.live = {}
  local cols = 20
  for i, m in ipairs(B.list) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    -- Each round a little off the last (units placed by find_non_colliding_position round a moved point).
    local c = {col * SPACING + (B.round - 1) * 3, row * SPACING + (B.round - 1) * 2}
    local f = arena.start(c, m.a, m.b, m.squad .. " vs " .. m.against)
    f.m = {kind = m.kind, squad = m.squad, against = m.against, round = B.round, flip = m.flip, creep_a = m.creep_a,
      creep_b = m.creep_b}
    table.insert(B.live, f)
  end
end

-- Every second: step every live fight; write each one decided; the next round once all are.
function batch.tick()
  local B = storage.batch
  if not B or B.done or game.tick % 60 ~= 0 then return end
  local open = 0
  for _, f in ipairs(B.live) do
    -- A side on creep: its units quicker and mending, renewed each second.
    for _, side in ipairs({f.m.creep_a and f.a or false, f.m.creep_b and f.b or false}) do
      if side and not f.written then
        for _, u in ipairs(side.units) do
          if u.valid and u.type == "unit" then
            u.surface.create_entity{name = "lp-creep-haste", position = u.position, target = u}
            if u.health < u.max_health then u.surface.create_entity{name = "lp-creep-mend", position = u.position, target = u} end
          end
        end
      end
    end
    if not f.written then
      if arena.step(f) then
        local r = f.result
        r.kind, r.squad, r.against, r.round, r.flip = f.m.kind, f.m.squad, f.m.against, f.m.round, f.m.flip
        helpers.write_file("lp-arena/results.jsonl", helpers.table_to_json(r) .. "\n", true)
        f.written = true
      else
        open = open + 1
      end
    end
  end
  if open == 0 then
    if B.round < ROUNDS then batch.next_round()
    else
      B.done = true
      local sc = remote.call("landing-party", "scorcher_stats")
      helpers.write_file("lp-arena/done.txt", string.format("%d fights in %d rounds, tick %d; Scorcher bursts %d, Tesla drains %d",
        #B.list * ROUNDS, ROUNDS, game.tick, sc.bursts, sc.drains))
    end
  end
end

return batch
