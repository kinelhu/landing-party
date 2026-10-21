-- The arena's balance table (scripts/arena.sh): every matchup at once, each in its own pen, ROUNDS times with the sides'
-- spawn points moved a little each round; results to script-output/lp-arena/results.jsonl, one fight a line.
-- Squads are bought with BUDGET parts at the corporations' own prices (shared.units), so a row compares what a camp
-- gets for the same spend. Opponents: biter waves (WAVE biters at each evolution in EVOS), three of the player's
-- defence lines with no research, the other corporation's squads, and mixed squads against the same.
local arena = require("arena")
local params = require("params")

local batch = {}

local BUDGET = 420
local WAVE = 20
local EVOS = {0.2, 0.5, 0.8, 0.95}
local ROUNDS = params.rounds or 3
local SPACING = 220

-- Squads: a name and its entries, bought with BUDGET (a mix splits it as given).
local function buy(corp, kind, parts)
  return {corp, kind, math.floor(parts / arena.cost(kind))}
end
local SQUADS = {}
local function squad(name, corp, ...)
  local entries = {}
  for _, part in ipairs({...}) do table.insert(entries, buy(corp, part[1], part[2])) end
  table.insert(SQUADS, {name = name, corp = corp, entries = entries})
end
for _, k in ipairs({"lp-infantry", "lp-tank", "lp-lance", "lp-railgunner", "lp-walker", "lp-prism", "lp-tesla"}) do
  squad("serenity " .. k:sub(4), "serenity", {k, BUDGET})
end
for _, k in ipairs({"lp-infantry", "lp-tank", "lp-slug", "lp-sapper", "lp-scorcher"}) do
  squad("grubstake " .. k:sub(4), "grubstake", {k, BUDGET})
end
-- Mixes: a heavy with infantry or its partner, the same spend.
squad("serenity tank+infantry", "serenity", {"lp-tank", 180}, {"lp-infantry", 240})
squad("serenity tesla+infantry", "serenity", {"lp-tesla", 170}, {"lp-infantry", 250})
squad("serenity prism+lance", "serenity", {"lp-prism", 210}, {"lp-lance", 210})
squad("grubstake scorcher+infantry", "grubstake", {"lp-scorcher", 210}, {"lp-infantry", 210})

local function matchups()
  local out = {}
  for _, sq in ipairs(SQUADS) do
    for _, evo in ipairs(EVOS) do
      table.insert(out, {kind = "biters", squad = sq.name, against = string.format("biters %.2f", evo),
        a = sq.entries, b = {{"biters", "wave", WAVE, evo}}})
    end
    for _, ln in ipairs({{"guns", 6}, {"lasers", 4}, {"flamers", 3}}) do
      local def = {{"player", ln[1], ln[2]}, {"player", "walls", 14}}
      if ln[1] == "flamers" then table.insert(def, {"player", "guns", 2}) end
      table.insert(out, {kind = "defence", squad = sq.name, against = ln[1], a = sq.entries, b = def})
    end
  end
  -- Duels: each of Serenity's squads against each of Grubstake's (mixes included).
  for _, s in ipairs(SQUADS) do
    if s.corp == "serenity" then
      for _, g in ipairs(SQUADS) do
        if g.corp == "grubstake" then
          table.insert(out, {kind = "duel", squad = s.name, against = g.name, a = s.entries, b = g.entries})
        end
      end
    end
  end
  -- A trial (LP_ARENA_ONLY): only the matchups whose label holds that text.
  if params.only and params.only ~= "" then
    local kept = {}
    for _, m in ipairs(out) do if (m.squad .. " vs " .. m.against):find(params.only, 1, true) then table.insert(kept, m) end end
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
  local cols = 12
  for i, m in ipairs(B.list) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    -- Each round a little off the last (units placed by find_non_colliding_position round a moved point).
    local c = {col * SPACING + (B.round - 1) * 3, row * SPACING + (B.round - 1) * 2}
    local f = arena.start(c, m.a, m.b, m.squad .. " vs " .. m.against)
    f.m = {kind = m.kind, squad = m.squad, against = m.against, round = B.round}
    table.insert(B.live, f)
  end
end

-- Every second: step every live fight; write each one decided; the next round once all are.
function batch.tick()
  local B = storage.batch
  if not B or B.done or game.tick % 60 ~= 0 then return end
  local open = 0
  for _, f in ipairs(B.live) do
    if not f.written then
      if arena.step(f) then
        local r = f.result
        r.kind, r.squad, r.against, r.round = f.m.kind, f.m.squad, f.m.against, f.m.round
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
