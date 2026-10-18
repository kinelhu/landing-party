-- Standing (the rivals consult, slice 2; docs/arc.md: the corporations are rivals who become enemies). Toward each
-- player force a corporation is a rival or an enemy (a truce comes later), shown in notices and the incidents list:
-- enemy once provoked (ops.provoke: its buildings or units hurt, its claim encroached; and, the user: "even a tolerant
-- rival should not accept turrets in firing range. That's an aggression": a player turret within RANGE of its ground).
-- A rival Grubstake still steals (soft raids, prospects, taps) but does not climb its ladder (ops.ladder: no flares,
-- rigs, reliefs, larger army); standing down after a quiet hour makes it a rival again. Serenity never forgets.
-- Incidents: the last COUNT things the corporations did to the player, who, what, where (/lp incidents).
local shared = require("__landing-party__.shared")
local ops = require("__landing-party__.scripts.ops")

local standing = {}

local RANGE = 26                  -- a turret this near a corporation's building has it in reach (a laser's 24, a margin)
local COUNT = 20

local function corp_state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  return storage.corps[corp]
end

function standing.get(corp, owner)
  if standing.truce and standing.truce(corp, owner) then return "truce" end
  local d = corp_state(corp)
  if d.provoked and d.provoked[owner] then return "enemy" end
  return "rival"
end

local function corp_of_force(force)
  for corp, c in pairs(shared.CORPS) do if c.force == force then return corp end end
end
standing.corp_of_force = corp_of_force

local function players()
  return shared.player_forces()
end

-- An incident; merged into the last one when it is the same corporation and kind, near, within a minute (a raid's
-- razes are one incident).
function standing.incident(corp, kind, pos, detail)
  storage.incidents = storage.incidents or {}
  local x, y = pos.x or pos[1], pos.y or pos[2]
  local last = storage.incidents[#storage.incidents]
  if last and last.corp == corp and last.kind == kind and game.tick - last.tick < 3600
    and (last.x - x) ^ 2 + (last.y - y) ^ 2 < 60 * 60 then
    last.count, last.tick = last.count + 1, game.tick
    return
  end
  table.insert(storage.incidents, {tick = game.tick, corp = corp, kind = kind, x = x, y = y, detail = detail, count = 1})
  while #storage.incidents > COUNT do table.remove(storage.incidents, 1) end
end

-- Grubstake back to a rival: a camp that stood down (war.lua) forgives.
function standing.forgive(corp)
  if (shared.CORPS[corp].temper or {}).provoked_only then return end
  corp_state(corp).provoked = {}
end

local function tell(f, key, corp, detail)
  shared.notice(f, {key, shared.corp_label(corp), detail or ""})
end

-- Once a minute: turrets in reach of a rival's ground provoke it; a change of standing is told.
function standing.tick(tick)
  if tick % 3600 ~= 2900 then return end
  storage.standing_seen = storage.standing_seen or {}
  for _, b in pairs(storage.bases or {}) do
    if not b.fallen and b.lander and b.lander.valid then
      local s = game.surfaces[b.surface]
      for _, f in ipairs(players()) do
        if standing.get(b.corp, f.name) == "rival" then
          local where = {b.lander.position}
          for _, m in ipairs(b.modules or {}) do if m.center then table.insert(where, {x = m.center[1], y = m.center[2]}) end end
          for _, p in ipairs(where) do
            local t = s.find_entities_filtered{position = p, radius = RANGE, force = f,
              type = {"ammo-turret", "electric-turret", "fluid-turret"}, limit = 1}[1]
            if t then
              ops.provoke(b.lander.force.name, f.name, t, "trespass")
              standing.incident(b.corp, "turret", t.position, "a turret on its ground")
              b.provoked_by_turret = true
              break
            end
          end
        end
      end
    end
  end
  for corp in pairs(shared.CORPS) do
    for _, f in ipairs(players()) do
      local k = corp .. "|" .. f.name
      local now = standing.get(corp, f.name)
      if storage.standing_seen[k] and storage.standing_seen[k] ~= now then
        tell(f, now == "enemy" and "lp.standing-enemy" or "lp.standing-rival", corp)
        standing.incident(corp, "standing-" .. now, {0, 0})
      end
      storage.standing_seen[k] = now
    end
  end
end

-- What /lp incidents prints: newest first.
function standing.list(player)
  local list = storage.incidents or {}
  if #list == 0 then return player.print("no incidents") end -- notice-ok: /lp incidents
  for i = #list, math.max(1, #list - 9), -1 do
    local e = list[i]
    -- notice-ok: /lp incidents (the reply to a command, below)
    player.print(string.format("%d min ago  %s  %s%s  %s  [gps=%d,%d]", math.floor((game.tick - e.tick) / 3600),
      shared.CORPS[e.corp] and shared.CORPS[e.corp].name or e.corp, e.kind, e.count > 1 and (" x" .. e.count) or "",
      e.detail or "", e.x, e.y))
  end
end

return standing
