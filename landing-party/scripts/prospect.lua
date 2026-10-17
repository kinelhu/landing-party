-- Prospecting (the rivals consult, docs/reviews/2026-10-16-rivals-consult.md; the user took the plan, 2026-10-16):
-- Grubstake takes what you are not using. A camp picks, within its reach (RADIUS), the charted ore patch nearest the
-- player's base that no player drill works: the player's expansion frontier (the nearest to the camp once: on
-- deathworld10x the camp had landed where the only ore was its own, 2,380 tiles within 500, and took nothing). It tags it on the player's map ("Mineral rights reassigned") and says so; WINDOW later, unless the player has
-- drilled it or staked it (a claim marker, ops.marked), its truck builds a claim there: a generator, a pylon, three
-- drills with their bins, a mining module of the camp (rebuilt, capturable), marked on the map. One patch at a time,
-- the nearest first, PACE between (tagging everything undrilled at chemical science would be harsh).
local shared = require("__landing-party__.shared")
local chart = require("__landing-party__.scripts.chart")
local base = require("__landing-party__.scripts.base")
local ops = require("__landing-party__.scripts.ops")
local standing = require("__landing-party__.scripts.standing")

local prospect = {}

local RADIUS = 700               -- its reach; among what is in reach, the patch nearest the player's base first
local WINDOW = 10 * 3600
local PACE = 10 * 3600
local CHUNK = 32
local MIN_ORE = 20                -- ore tiles a chunk needs (a count capped here) to be a patch (at 40 a 13 x 13 patch
                                  -- across chunk borders counted in none)
local CLEAR = 40                  -- no player drill, nor camp module, this near
local DRILLS = 3
local GIVE_UP = 10 * 3600         -- a claim not built by then is abandoned (its truck turned back each time)

-- Inside another corporation's claim, or held by a force at war with the camp: not a candidate (the second pick once
-- fell inside Serenity's camp, and its truck turned back "occupied" for the rest of the run).
local function taken(b, s, pos)
  for _, o in pairs(storage.bases or {}) do
    if o ~= b and not o.fallen and o.surface == b.surface and o.origin
      and (o.origin.x - pos[1]) ^ 2 + (o.origin.y - pos[2]) ^ 2 <= (o.claim_radius or 60) ^ 2 then
      return true
    end
  end
  return base.occupied(b, s, pos)
end

local function tell(b, key, at)
  local s = game.surfaces[b.surface]
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then
      shared.notice(f, {key, shared.corp_label(b.corp), string.format("[gps=%d,%d,%s]", at[1], at[2], s.name)})
    end
  end
end

local function player_forces()
  local out = {}
  for _, f in pairs(game.forces) do
    if f.name == "player" or (#f.players > 0 and not shared.is_corp(f.name)) then table.insert(out, f) end
  end
  return out
end

local function worked(s, pos)
  for _, f in ipairs(player_forces()) do
    if s.count_entities_filtered{position = pos, radius = CLEAR, type = "mining-drill", force = f, limit = 1} > 0 then
      return true
    end
  end
  return false
end

-- The nearest charted, unworked patch: chunk by chunk, a capped count each.
local function find(b)
  local s = game.surfaces[b.surface]
  local ox, oy = b.origin.x, b.origin.y
  local players = player_forces()
  local best, bd
  local why = {inside = 0, uncharted = 0, ore = 0, fluid = 0, worked = 0, staked = 0, taken = 0}
  local radius = storage.prospect_radius or RADIUS
  -- The player's base: their spawn (the first player force's).
  local home = storage.prospect_home or (players[1] and players[1].get_spawn_position(s)) or {x = 0, y = 0}
  local n = math.ceil(radius / CHUNK)
  for i = -n, n do
    for j = -n, n do
      local cx, cy = math.floor(ox / CHUNK) + i, math.floor(oy / CHUNK) + j
      local x, y = cx * CHUNK + CHUNK / 2, cy * CHUNK + CHUNK / 2
      local d = (x - ox) ^ 2 + (y - oy) ^ 2
      local dp = (x - home.x) ^ 2 + (y - home.y) ^ 2
      local key = cx .. "," .. cy
      -- Not where it already mines (a module of its own within CLEAR). Not "beyond its claim": a sprawl's claim covered
      -- 123 of the 278 chunks within 300 on deathworld10x, and it prospected nothing in 3 hours.
      local own = false
      if d <= radius * radius then
        for _, m in ipairs(b.modules or {}) do
          if m.center and (m.center[1] - x) ^ 2 + (m.center[2] - y) ^ 2 <= CLEAR * CLEAR then own = true; break end
        end
        if own then why.inside = why.inside + 1 end
      end
      if d <= radius * radius and not own and (not bd or dp < bd) and not (b.prospected or {})[key]
        and not (storage.prospect_failed or {})[key] then
        -- Charted by the player (a patch they know of). Headless runs chart nothing (force.chart never lands there):
        -- tests waive it (debug_tune prospect_uncharted).
        local charted = storage.prospect_uncharted or false
        for _, f in ipairs(players) do if f.is_chunk_charted(s, {cx, cy}) then charted = true end end
        if not charted then why.uncharted = why.uncharted + 1 end
        local n_ore = charted and s.count_entities_filtered{area = {{cx * CHUNK, cy * CHUNK}, {cx * CHUNK + CHUNK, cy * CHUNK + CHUNK}},
          type = "resource", limit = MIN_ORE} or 0
        if charted and n_ore < MIN_ORE then why.ore = why.ore + 1 end
        if charted and n_ore >= MIN_ORE then
          local ore = s.find_entities_filtered{area = {{cx * CHUNK, cy * CHUNK}, {cx * CHUNK + CHUNK, cy * CHUNK + CHUNK}},
            type = "resource", limit = 1}[1]
          if not (ore and ore.prototype.resource_category == "basic-solid") then why.fluid = why.fluid + 1
          elseif worked(s, {x, y}) then why.worked = why.worked + 1
          elseif ops.marked(b, {x, y}) then why.staked = why.staked + 1
          elseif taken(b, s, {x, y}) then why.taken = why.taken + 1
          else best, bd = {x = x, y = y, key = key, ore = ore.name}, dp end
        end
      end
    end
  end
  b.prospect_why = why
  return best
end

local function tag(b, p)
  local s = game.surfaces[b.surface]
  local tags = {}
  for _, f in ipairs(player_forces()) do
    local t = f.add_chart_tag(s, {position = {p.x, p.y}, icon = {type = "virtual", name = shared.CORPS[b.corp].icon},
      text = "Mineral rights reassigned"})
    if t then table.insert(tags, t) end
  end
  return tags
end

local function untag(p) for _, t in ipairs(p.tags or {}) do if t.valid then t.destroy() end end end

-- The claim's jobs, a module of the camp: drills on the patch's ore tiles (spaced), their bins north of them, a
-- generator and a pylon beside.
local function claim(b, p)
  local s = game.surfaces[b.surface]
  local m = {kind = "mining", center = {p.x, p.y}, entities = {}, claim = true, prospect = true}
  table.insert(b.modules, m)
  -- Within the pylon's supply (9 a side): drills 14 out stood unpowered and mined 2 ore in 15 minutes.
  local ores = s.find_entities_filtered{position = {p.x, p.y}, radius = 8, type = "resource"}
  table.sort(ores, function(a, c)
    return (a.position.x - p.x) ^ 2 + (a.position.y - p.y) ^ 2 < (c.position.x - p.x) ^ 2 + (c.position.y - p.y) ^ 2
  end)
  local spots = {}
  for _, o in ipairs(ores) do
    if #spots >= DRILLS then break end
    local far = true
    for _, q in ipairs(spots) do if math.abs(q[1] - o.position.x) < 4 and math.abs(q[2] - o.position.y) < 4 then far = false end end
    local clear = math.abs(o.position.x - p.x) > 2.5 or math.abs(o.position.y - p.y) > 2.5
    if far and clear then table.insert(spots, {math.floor(o.position.x) + 0.5, math.floor(o.position.y) + 0.5}) end
  end
  local jobs = {{name = "lp-pylon", pos = {math.floor(p.x) + 0.5, math.floor(p.y) + 0.5}, module = m},
    {name = "lp-generator", pos = {p.x - 5, p.y + 6}, module = m, loose = true}}
  for _, q in ipairs(spots) do
    table.insert(jobs, {name = "lp-drill", pos = q, module = m})
    table.insert(jobs, {name = "lp-bin", pos = {q[1], q[2] - 2}, module = m, loose = true})
  end
  -- First in the queue: its truck (crew.lua) takes them out.
  for i = #jobs, 1, -1 do table.insert(b.queue, 1, jobs[i]) end
  local c = shared.CORPS[b.corp].color
  -- The claimed patch's chunks, dashed: held, not settled ground (scripts/chart.lua).
  m.marks = chart.territory(s, m.center, 24, c, {dashed = true})
  b.claims_settled = (b.claims_settled or 0) + 1
  return m
end

local function step(b)
  local p = b.prospect
  local s = game.surfaces[b.surface]
  if p.phase == "tagged" then
    -- Answered: drilled or staked within the window. The claim is called off and the camp looks elsewhere.
    if worked(s, {p.x, p.y}) or ops.marked(b, {p.x, p.y}) then
      untag(p)
      b.prospects_answered = (b.prospects_answered or 0) + 1
      base.trace(b, string.format("prospect: the patch at %.0f,%.0f was answered (drilled or staked)", p.x, p.y))
      b.prospect = nil
      return
    end
    if game.tick - p.tagged >= (storage.prospect_window or WINDOW) then
      p.module = claim(b, p)
      p.phase, p.claimed_at = "claimed", game.tick
      b.prospects_claimed = (b.prospects_claimed or 0) + 1
      tell(b, "lp.prospect-claimed", {p.x, p.y})
      standing.incident(b.corp, "claim", {p.x, p.y}, p.ore)
      base.trace(b, string.format("prospect: claiming the %s at %.0f,%.0f", p.ore, p.x, p.y))
    end
  elseif p.phase == "claimed" then
    if not p.module.built and game.tick - p.claimed_at > GIVE_UP then
      -- Abandoned: its jobs dropped, its tag gone, the camp looks elsewhere after its pace.
      local j = 1
      while b.queue[j] do if b.queue[j].module == p.module then table.remove(b.queue, j) else j = j + 1 end end
      p.module.failed = true
      untag(p)
      -- Remembered by every camp: two camps tried the same patch by the player's base, one after the other (visit).
      storage.prospect_failed = storage.prospect_failed or {}
      storage.prospect_failed[p.key] = true
      b.prospects_abandoned = (b.prospects_abandoned or 0) + 1
      base.trace(b, string.format("prospect: the claim at %.0f,%.0f is abandoned (not built in %d s)", p.x, p.y, GIVE_UP / 60))
      b.prospect = nil
      b.next_prospect = game.tick + (storage.prospect_pace or PACE)
      return
    end
    if p.module.built then
      base.trace(b, string.format("prospect: the claim at %.0f,%.0f stands", p.x, p.y))
      b.prospect = nil
      b.next_prospect = game.tick + (storage.prospect_pace or PACE)
    end
  end
end

local function consider(b)
  if storage.prospect_off or not (shared.CORPS[b.corp].temper or {}).prospects then return end
  if b.fallen or b.quiescent or not b.mature or game.tick < (b.next_prospect or 0) then return end
  local p = find(b)
  if not p then
    if game.tick >= (b.prospect_said or 0) then
      b.prospect_said = game.tick + 30 * 3600
      base.trace(b, string.format("prospect: no unworked patch charted within %d (chunks: %s)", storage.prospect_radius or RADIUS,
        serpent.line(b.prospect_why or {})))
    end
    b.next_prospect = game.tick + 5 * 3600
    return
  end
  b.prospected = b.prospected or {}
  b.prospected[p.key] = true
  p.phase, p.tagged, p.tags = "tagged", game.tick, tag(b, p)
  b.prospect = p
  b.prospects = (b.prospects or 0) + 1
  tell(b, "lp.prospect", {p.x, p.y})
  standing.incident(b.corp, "prospect", {p.x, p.y}, p.ore)
  base.trace(b, string.format("prospect: mineral rights to the %s at %.0f,%.0f reassigned (claim in %d s unless answered)",
    p.ore, p.x, p.y, (storage.prospect_window or WINDOW) / 60))
end

function prospect.tick(tick)
  if tick % 60 ~= 29 then return end
  for _, b in pairs(storage.bases or {}) do
    if b.prospect then step(b)
    elseif tick % 3600 == 29 + 60 * 17 then consider(b) end
  end
end

prospect.claim = claim
prospect.worked = worked

function prospect.stats(b)
  return {prospects = b.prospects or 0, claimed = b.prospects_claimed or 0, answered = b.prospects_answered or 0,
    phase = b.prospect and b.prospect.phase, at = b.prospect and {b.prospect.x, b.prospect.y}}
end

return prospect
