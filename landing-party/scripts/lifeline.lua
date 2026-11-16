-- A starving camp's way back, then its way out (shared.LIFELINE). A camp that made no part for a while and holds next
-- to none is stuck for good: its crews killed at every mine (nwa seed 1, the night of 2026-11-16: both sites given up,
-- its last mine cut from the lander's power, 201 rebuilds it could not pay for). Its corporation drops it a crate of
-- parts the player sees coming and may destroy first; if that does not save it, the camp departs, as a director's
-- expedition does (base.depart: no fall, no ruins). A headquarters never departs: it is sent another drop instead.
-- Dormant in a camp that makes parts: every check below starts with it starving.
local shared = require("__landing-party__.shared")
local base = require("__landing-party__.scripts.base")
local pods = require("__landing-party__.scripts.pods")
local threat = require("__landing-party__.scripts.threat")

local lifeline = {}
local L = shared.LIFELINE

local function players()
  local out = {}
  for _, f in pairs(game.forces) do
    if #f.players > 0 and not shared.is_corp(f.name) then out[#out + 1] = f end
  end
  return out
end

local function tell(key, ...)
  for _, f in ipairs(players()) do shared.notice(f, {key, ...}) end
end

local function where(surface, pos) return string.format("[gps=%.0f,%.0f,%s]", pos[1], pos[2], surface.name) end

local function starving(b, tick)
  if b.fallen or b.expedition or not (b.lander and b.lander.valid) then return false end
  if tick - (b.landed or 0) < L.grace * 3600 then return false end
  return (b.parts or 0) < L.poor and b.starve_since and tick - b.starve_since >= L.minutes * 3600
end

local function crate(b, surface, pos)
  local d = b.lifeline
  if not d or d.crate then return end
  local p = surface.find_non_colliding_position("iron-chest", pos, 12, 0.5)
  if not p then return end
  local c = surface.create_entity{name = "iron-chest", position = p, force = b.force}
  if not c then return end
  c.insert{name = "iron-plate", count = math.max(1, math.floor(L.parts / 2))}
  d.crate, d.at, d.pos = c, game.tick, {p.x, p.y}
  d.tags = {}
  for _, f in ipairs(players()) do
    d.tags[#d.tags + 1] = f.add_chart_tag(surface, {position = p, text = "Supply drop", icon = {type = "item", name = "iron-chest"}})
  end
end
pods.handlers.lifeline = function(p, surface, pos)
  local b = storage.bases and storage.bases[p.base]
  if b and not b.fallen then crate(b, surface, {pos.x, pos.y}) end
end

local function send(b, tick)
  local surface = game.surfaces[b.surface]
  local lp = b.lander.position
  local f = players()[1]
  local sp = f and f.get_spawn_position(surface) or {x = 0, y = 0}
  local dx, dy = sp.x - lp.x, sp.y - lp.y
  local l = math.max(1, math.sqrt(dx * dx + dy * dy))
  local at = {lp.x + dx / l * L.out, lp.y + dy / l * L.out}
  b.lifeline = {sent = tick}
  b.lifelines = (b.lifelines or 0) + 1
  local sent = not storage.pods_off and pods.send(surface, at, b.force, {kind = "lifeline", base = b.id})
  if not sent then crate(b, surface, at) end
  base.trace(b, string.format("starving (no part made for %d min, %d parts): a supply drop of %d parts by %s at %.0f,%.0f",
    (tick - b.starve_since) / 3600, b.parts or 0, L.parts, sent and "pod" or "crate", at[1], at[2]))
  shared.event("lifeline", {base = b.id, corp = b.corp, n = b.lifelines})
  tell("lp.lifeline", shared.corp_label(b.corp), where(surface, at))
end

local function retry(b, surface)
  local queue, n = {}, 0
  if shared.CORPS[b.corp].clears_nests then
    local seen = {}
    for _, p in ipairs(b.mine_danger) do
      for _, e in ipairs(surface.find_entities_filtered{position = p, radius = L.sweep, type = {"unit-spawner", "turret"},
        force = shared.NEST_FORCES}) do
        if not seen[e.unit_number] then
          seen[e.unit_number] = true
          n = n + 1
          for _ = 1, threat.shells_for("lp-orbital-projectile", e) do queue[#queue + 1] = e end
        end
      end
    end
    if #queue > 0 then
      storage.orbitals = storage.orbitals or {}
      table.insert(storage.orbitals, {base = b.id, surface = surface.index, force = b.force, queue = queue, i = 1})
    end
  end
  base.trace(b, string.format("starving, no ore further out: its %d given-up mines' ground tried again%s", #b.mine_danger,
    #queue > 0 and string.format(", %d nests and worms swept from orbit first (%d shells)", n, #queue) or ""))
  b.mine_danger, b.no_far_site = nil, nil
  b.retries = (b.retries or 0) + 1
  b.retry_swept = (b.retry_swept or 0) + n
end

local function collect(b, tick)
  local d = b.lifeline
  if not d or d.done then return end
  -- (A pod that left no crate, no ground free where it fell: lost, not waited on for ever.)
  if not d.at and tick - d.sent > (L.wait + 2) * 3600 then d.done = tick; b.lifelines_lost = (b.lifelines_lost or 0) + 1; return end
  if not d.at or tick - d.at < L.wait * 3600 then return end
  d.done = tick
  local surface = game.surfaces[b.surface]
  for _, t in ipairs(d.tags or {}) do if t.valid then t.destroy() end end
  if d.crate and d.crate.valid then
    d.crate.destroy()
    b.parts = (b.parts or 0) + L.parts
    b.lifeline_parts = (b.lifeline_parts or 0) + L.parts
    base.trace(b, string.format("supply drop reached the camp: %d parts", L.parts))
    tell("lp.lifeline-in", shared.corp_label(b.corp), where(surface, d.pos))
    -- No ore further out either (planner: b.no_far_site): the given-up ground again, with the parts just come, swept
    -- from orbit first by a corporation that clears nests.
    if b.no_far_site and b.mine_danger then retry(b, surface) end
  else
    b.lifelines_lost = (b.lifelines_lost or 0) + 1
    base.trace(b, "supply drop lost: its crate gone before the camp took it")
    tell("lp.lifeline-lost", shared.corp_label(b.corp), where(surface, d.pos))
  end
end

function lifeline.tick(tick)
  if tick % 3600 ~= 1800 then return end
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen then
      -- (Starving since the last minute it made a part.)
      if (b.made or 0) ~= b.starve_made then b.starve_made, b.starve_since = b.made or 0, tick end
      collect(b, tick)
      local d = b.lifeline
      if d and d.done and b.starve_since > d.sent then
        -- Making parts again since its drop: saved; a later starving is a new one.
        b.lifeline = nil
      elseif not d then
        if starving(b, tick) then send(b, tick) end
      elseif d.done then
        -- Nothing made since its drop (whatever it holds: parts it cannot turn into a mine are no way back).
        if b.hq then
          if starving(b, tick) and tick - d.sent >= L.hq_gap * 3600 then send(b, tick) end
        -- (Not while the player fights it: a camp being taken apart is the player's to finish, its fall and its cores
        -- theirs; the director's replaced camps wait the same, fought_minutes.)
        elseif tick - d.done >= L.leave * 3600 and not (b.player_hit_at and tick - b.player_hit_at < L.leave * 3600) then
          local surface = game.surfaces[b.surface]
          local at = {b.origin.x, b.origin.y}
          if base.depart(b, "starved") then
            tell("lp.starved-out", shared.corp_label(b.corp), where(surface, at))
          end
        end
      end
    end
  end
end

return lifeline
