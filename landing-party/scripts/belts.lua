-- Belts in the corporations' districts (layout.belts; the user, 2026-10-21: "we did not incorporate any belts or
-- logistics of any kind inside the clusters"): parts ride each run from its first tile to its last, put on and taken off
-- by script, and only while a player is within SEE of the district (unseen, nothing moves: no cost in a large base).
-- The parts are the corporation's own (lp-part, hidden): a player who picks one up has nothing of use.
local shared = require("__landing-party__.shared")

local belts = {}

local SEE = 160
local TICKS = 60
local PER_LINE = 1                -- parts put on each lane of a run's first tile every TICKS
local LOOP_FILL = 2               -- a loop is filled once, to about this many a tile

local function watched(surface, pos, eyes)
  for _, p in ipairs(eyes) do
    if p.surface == surface and (p.position.x - pos[1]) ^ 2 + (p.position.y - pos[2]) ^ 2 <= SEE * SEE then return true end
  end
  return false
end

function belts.tick(tick)
  if tick % TICKS ~= 41 or not storage.bases then return end
  local eyes = {}
  for _, p in pairs(game.connected_players) do
    if p.character or p.controller_type == defines.controllers.remote or p.controller_type == defines.controllers.god
      or p.controller_type == defines.controllers.editor then
      table.insert(eyes, {surface = p.surface.index, position = p.position})
    end
  end
  if #eyes == 0 and not storage.belts_always then return end
  for _, b in pairs(storage.bases) do
    if not b.fallen then
      local s = game.surfaces[b.surface]
      local name = shared.variant(b.corp, "lp-belt")
      for _, block in ipairs(b.blocks or {}) do
        if block.belts and (storage.belts_always or watched(b.surface, block.center, eyes)) then
          for _, run in ipairs(block.belts) do
            local first = s.find_entity(name, run.first)
            if first then
              if run.loop then
                if (run.filled or 0) < run.n * LOOP_FILL then
                  for line = 1, 2 do
                    if first.get_transport_line(line).insert_at_back({name = "lp-part", count = 1}) then
                      run.filled = (run.filled or 0) + 1
                    end
                  end
                end
              else
                for line = 1, 2 do
                  local tl = first.get_transport_line(line)
                  for _ = 1, PER_LINE do tl.insert_at_back({name = "lp-part", count = 1}) end
                end
              end
              b.belt_moves = (b.belt_moves or 0) + 1
            end
            local last = not run.loop and s.find_entity(name, run.last)
            if last then
              for line = 1, 2 do
                local tl = last.get_transport_line(line)
                local n = tl.get_item_count("lp-part")
                if n > 0 then tl.remove_item({name = "lp-part", count = n}) end
              end
            end
          end
        end
      end
    end
  end
end

-- What is on its belts now (tests).
function belts.stats(b)
  local runs, carried = 0, 0
  local s = game.surfaces[b.surface]
  local name = shared.variant(b.corp, "lp-belt")
  for _, block in ipairs(b.blocks or {}) do
    for _ in ipairs(block.belts or {}) do runs = runs + 1 end
  end
  for _, e in pairs(s.find_entities_filtered{name = name, force = b.force}) do
    for line = 1, 2 do carried = carried + e.get_transport_line(line).get_item_count() end
  end
  return {runs = runs, belts = s.count_entities_filtered{name = name, force = b.force}, carried = carried,
    moves = b.belt_moves or 0}
end

return belts
