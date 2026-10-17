-- Dev tools: /lp <what> [args], for looking at the mod in game without waiting on its clocks or its dice.
-- Admins only. The settlement acted on is the nearest standing one to the player (for strip, the nearest
-- strip-miner's), or the one whose id is given last (/lp list shows them).
--   list                     every settlement: id, corporation, where, garrison, parts, operation, perimeter, hull
--   raid|siege|strip [id]    that operation now, at your structure nearest you (ops.force: temper, budget,
--                            cadence and stock waived; the infantry it lacks are given)
--   perimeter [id]           Serenity's line steps out now (notice every third step, warning one step ahead)
--   land <corp> [tiles]      a corporation arrives this far from you (default 200), with 2000 parts
--   parts <n> [id]           parts for a settlement (growth, units, operations)
--   fast                     short clocks on or off: perimeter, strip camps, phases, headquarters
--   grudge [id]              as if you had destroyed that settlement's lander: the grudge without the fall
--   flare [id]               Grubstake fires a pheromone flare at you: its canister out of your turrets' reach
--   rig [id]                 a claim jumper at the chests nearest you (a rig 40 to 60 out, hands up in a minute)
--   tap [id]                 a power tap on the pole nearest you (a pylon line out of turret reach, then the clamp)
--   provoke | era <n> | trace
local shared = require("__landing-party__.shared")
local names = require("__landing-party__.scripts.names")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local base = require("__landing-party__.scripts.base")
local faction = require("__landing-party__.scripts.faction")
local flare = require("__landing-party__.scripts.flare")
local jumper = require("__landing-party__.scripts.jumper")
local tap = require("__landing-party__.scripts.tap")
local standing = require("__landing-party__.scripts.standing")

local dev = {}

local function standing(b) return b and not b.fallen and b.lander and b.lander.valid end

local function pick(player, id, want)
  if id then
    local b = storage.bases[id]
    return standing(b) and b or nil
  end
  local best, bd
  for _, b in pairs(storage.bases) do
    if standing(b) and b.surface == player.surface.index and (not want or want(b)) then
      local d = (b.origin.x - player.position.x) ^ 2 + (b.origin.y - player.position.y) ^ 2
      if not bd or d < bd then best, bd = b, d end
    end
  end
  return best
end

local function gps(b)
  return string.format("[gps=%d,%d,%s]", b.origin.x, b.origin.y, game.surfaces[b.surface].name)
end

local function list(player)
  local ids = {}
  for id in pairs(storage.bases) do table.insert(ids, id) end
  table.sort(ids)
  if #ids == 0 then player.print("no settlements") end
  for _, id in ipairs(ids) do
    local b = storage.bases[id]
    local n = 0
    for _, u in ipairs(b.garrison or {}) do if u.valid then n = n + 1 end end
    player.print(string.format("%d  %s, %s %s  %s  garrison %d, parts %d, %s, perimeter %s, hull %s", id,
      names.of(b), shared.CORPS[b.corp].name, b.hq and "(HQ)" or "", gps(b), n, b.parts or 0,
      b.fallen and "fallen" or (b.op and (b.op.kind .. ":" .. b.op.phase) or "idle"),
      b.perimeter and string.format("%.0f", b.perimeter) or "-",
      (b.lander and b.lander.valid) and (b.lander.destructible and "down" or "up") or "-"))
  end
end

-- A depot beside the lander (a young settlement has none, and operations leave from one), and parts.
function dev.depot(b, parts)
  local s = b.lander.surface
  local p = s.find_non_colliding_position(shared.variant(b.corp, "lp-depot"), {b.lander.position.x, b.lander.position.y + 16}, 30, 1)
  local d = p and s.create_entity{name = shared.variant(b.corp, "lp-depot"), position = p, force = b.lander.force}
  if d then table.insert(b.depots, d) end
  b.parts = b.parts + (parts or 0)
  return d ~= nil
end

local function has_depot(b)
  for _, d in ipairs(b.depots) do if d.valid then return true end end
end

function dev.run(player, args)
  local what = args[1]
  local id = tonumber(args[#args])
  if what == "list" or what == nil then
    list(player)
  elseif what == "raid" or what == "siege" or what == "strip" then
    local b = pick(player, id, what == "strip" and function(b) return (shared.CORPS[b.corp].temper or {}).strips end)
    if not b then return player.print("no settlement for that") end
    if not has_depot(b) then dev.depot(b) end
    local why = ops.force(b, what, player.position, base.trace, army)
    player.print(why and string.format("%s from %d: %s", what, b.id, why)
      or string.format("%s launched from %d %s (%s)", what, b.id, shared.CORPS[b.corp].name, gps(b)))
  elseif what == "incidents" then
    standing.list(player)
  elseif what == "flare" or what == "rig" or what == "tap" then
    -- Grubstake's discreet operations on demand (their own triggers wait on the ladder, the pact and intel).
    local temper = ({flare = "flares", rig = "jumps", tap = "taps"})[what]
    local b = pick(player, id, function(b) return (shared.CORPS[b.corp].temper or {})[temper] end)
    if not b then return player.print("no settlement that does that (Grubstake: /lp land grubstake)") end
    local busy = ({flare = b.flare, rig = b.jump, tap = b.tap})[what]
    if busy then return player.print(string.format("%d already has a %s under way", b.id, what)) end
    local pos = {player.position.x, player.position.y}
    local why
    if what == "flare" then
      local has
      for _, u in ipairs(b.garrison) do if u.valid and shared.kind_of(u.name) == "lp-buggy" then has = true end end
      if not has and b.lander.valid then
        local s = b.lander.surface
        local name = shared.variant(b.corp, "lp-buggy")
        local p = s.find_non_colliding_position(name, b.lander.position, 20, 1)
        local u = p and s.create_entity{name = name, position = p, force = b.lander.force}
        if u then table.insert(b.garrison, u) end
      end
      why = flare.debug(b, pos)
    elseif what == "rig" then
      why = jumper.launch(b, pos)
    else
      why = tap.debug(b, pos)
    end
    player.print(string.format("%s from %d (%s): %s", what, b.id, gps(b), why))
  elseif what == "perimeter" then
    local b = pick(player, id, function(b) return (shared.CORPS[b.corp].temper or {}).provoked_only end)
    if not b then return player.print("no settlement that keeps a perimeter") end
    local landed, steps = b.landed, b.perimeter_steps or 0
    b.landed, b.perimeter_next = -10 ^ 9, 0
    -- At once, its cordon's posts skipped for this step (cordon.lua: a step otherwise waits for them).
    local was = storage.cordon_off
    storage.cordon_off = true
    ops.perimeter(b, game.tick)
    storage.cordon_off = was
    b.landed = landed or game.tick
    player.print(string.format("perimeter of %d: %s", b.id, (b.perimeter_steps or 0) > steps
      and string.format("%.0f tiles (step %d)", b.perimeter, b.perimeter_steps)
      or "held (at its cap: your nearest structure + 40, 450, or another corporation's claim)"))
  elseif what == "land" then
    local corp = args[2]
    if not shared.CORPS[corp] then
      local names = {}
      for c in pairs(shared.CORPS) do table.insert(names, c) end
      table.sort(names)
      return player.print("land which corporation: " .. table.concat(names, ", "))
    end
    local d = tonumber(args[3]) or 200
    -- The real arrival (notice, map tag, the others hear it), on the ring this far from you.
    local b = faction.arrive(player.surface, player.position, {corp = corp, distance = d}, false)
    if not b then return player.print("no site to land on at that distance") end
    b.parts = (b.parts or 0) + 2000
    player.print(string.format("%s landed: %d %s", shared.CORPS[corp].name, b.id, gps(b)))
  elseif what == "parts" then
    local b = pick(player, tonumber(args[3]))
    local n = tonumber(args[2])
    if not (b and n) then return player.print("/lp parts <n> [id]") end
    b.parts = (b.parts or 0) + n
    player.print(string.format("%d now has %d parts", b.id, b.parts))
  elseif what == "fast" then
    local on = not storage.perimeter_fast
    storage.perimeter_fast, storage.strip_fast, storage.phases_fast, storage.hq_fast = on, on, on, on
    player.print("short clocks " .. (on and "on" or "off"))
  elseif what == "grudge" then
    local b = pick(player, id)
    if not b then return player.print("no settlement for that") end
    faction.grudge(b, player.force.name)
    player.print(string.format("grudge: %s's next landing comes angry", shared.CORPS[b.corp].name))
  elseif what == "provoke" then
    for _, c in pairs(shared.CORPS) do ops.provoke(c.force, player.force.name) end
    player.print("every corporation is now provoked by " .. player.force.name)
  elseif what == "era" then
    storage.era_override = tonumber(args[2])
    player.print("era " .. tostring(storage.era_override or "from research"))
  elseif what == "trace" then
    storage.trace = not storage.trace
    player.print("trace to script-output/landing-party/decisions.txt: " .. tostring(storage.trace))
  else
    player.print("/lp list | raid | siege | strip | perimeter [id] | land <corp> [tiles] | parts <n> [id] | fast | grudge [id] | provoke | era <n> | trace")
  end
end

-- Tests: the same tools for a player that need not exist (prints go to the log).
function dev.remote(args, pos, surface_index)
  local s = game.surfaces[surface_index or 1]
  dev.run({print = function(m) log("lp dev: " .. tostring(m)) end, position = {x = pos[1] or pos.x, y = pos[2] or pos.y},
    surface = s, force = game.forces.player}, args)
end

function dev.command(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if not player then return end
  if not player.admin then return player.print("/lp is for admins") end
  local args = {}
  for w in string.gmatch(cmd.parameter or "", "%S+") do table.insert(args, w) end
  dev.run(player, args)
end

return dev
