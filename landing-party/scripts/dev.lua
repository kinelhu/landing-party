-- Dev tools: /lp <what> [args], for looking at the mod in game without waiting on its clocks or its dice.
-- Admins only. The settlement acted on is the nearest standing one to the player (for strip, the nearest
-- strip-miner's), or the one whose id is given last (/lp list shows them).
--   list                     every settlement: id, corporation, where, garrison, parts, operation, perimeter, hull
--   raid|siege|strip [id]    that operation now, at your structure nearest you (ops.force: temper, budget,
--                            cadence and stock waived; the infantry it lacks are given)
--   perimeter [id]           Serenity's line steps out now (notice every third step, warning one step ahead)
--   land <corp> [tiles] [now]  a corporation arrives this far from you (default 200), with 2000 parts: as its own
--                            landings do, its pod first and its lander after (landfx.lua draws the descent); `now`
--                            lands it at once
--   parts <n> [id]           parts for a settlement (growth, units, operations)
--   fast                     short clocks on or off: perimeter, strip camps, phases, headquarters
--   grudge [id]              as if you had destroyed that settlement's lander: the grudge without the fall
--   rig [id]                 a claim jumper at the chests nearest you (a rig 40 to 60 out, hands up in 2.5 minutes)
--   tap [id]                 a power tap on the pole nearest you (a pylon line out of turret reach, then the clamp)
--   biotech                  the biotech's farm lands now on the nearest nest field 600 to 1,500 tiles from your factory
--   wave                     its farm sends a wave now (its pens topped up to send one)
--   spread | ranks           its farm's next pick a spread assault if its menu holds one (herd.spread_points), or a
--                            siege with twice the rams its share asks, in ranks (herd.rk); its siege laid, if any, dropped
--   strike [id]              an orbital strike now, centred where you stand: a spotter of that camp's (Kessler-Hayashi's
--                            nearest by default) paints it, then its shells fall (no siege, no cooldown)
--   burst [big]              a Synthexis burster (a big burster with `big`) set off 12 tiles east of you: its wind-up and
--                            its blast (scripts/burstfx.lua). The blast is real: stand clear
--   tesla [n]                n Kessler-Hayashi Teslas (default 1) set 20 tiles east of you, sent at your laser or tesla
--                            turret nearest you within 60: its lightning holds what it strikes (scorcher.hold, the status
--                            "Stunned by lightning"). They are real and stay: kill them or let them be
--   provoke | era <n> | trace
local shared = require("__landing-party__.shared")
local names = require("__landing-party__.scripts.names")
local ops = require("__landing-party__.scripts.ops")
local army = require("__landing-party__.scripts.army")
local base = require("__landing-party__.scripts.base")
local faction = require("__landing-party__.scripts.faction")
local jumper = require("__landing-party__.scripts.jumper")
local tap = require("__landing-party__.scripts.tap")
local standing = require("__landing-party__.scripts.standing")
local farm = require("__landing-party__.scripts.farm")
local burstfx = require("__landing-party__.scripts.burstfx")
local orbital = require("__landing-party__.scripts.orbital")

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
  elseif what == "strike" then
    local b = pick(player, id, function(b) return (shared.CORPS[b.corp] or {}).orbital_strike end)
    if not b then return player.print("no corporation with an orbital strike") end
    local why = orbital.force(b, player.position)
    player.print(why and ("strike: " .. why) or string.format("strike from %d %s: painted for 12 s, then it falls", b.id,
      shared.CORPS[b.corp].name))
  elseif what == "incidents" then
    standing.list(player)
  elseif what == "biotech" then
    player.print(farm.arrive_now(player.surface) and "the biotech's pod is coming down (a map tag marks its farm)"
      or "no nest field of three spawners 250 to 1,500 tiles from your factory")
  elseif what == "wave" then
    -- /lp wave [n] [deep]: a wave now; of n (past the caps); a deep strike, whatever it weighs at the breach.
    local n, deep
    for k = 2, #args do
      if tonumber(args[k]) then n = tonumber(args[k]) elseif args[k] == "deep" then deep = true end
    end
    player.print(farm.debug_wave(n, deep) and string.format("its culture sends %s%s within ten seconds",
      n and string.format("%d", n) or "a wave", deep and ", a deep strike for the heart," or "")
      or "no biotech farm (/lp biotech)")
  elseif what == "spread" or what == "ranks" then
    local k = farm.debug_method(what)
    player.print(k > 0 and string.format("its culture's next pick: %s, %s", what == "spread" and "a spread assault (if two points of the wall no flamethrower covers both)"
      or "a siege with twice the rams, in ranks", "/lp wave to send it now") or "no biotech farm (/lp biotech)")
  elseif what == "rig" or what == "tap" then
    -- Grubstake's discreet operations on demand (their own triggers wait on the ladder, the pact and intel).
    local temper = ({rig = "jumps", tap = "taps"})[what]
    local b = pick(player, id, function(b) return (shared.CORPS[b.corp].temper or {})[temper] end)
    if not b then return player.print("no settlement that does that (Grubstake: /lp land grubstake)") end
    local busy = ({rig = b.jump, tap = b.tap})[what]
    if busy then return player.print(string.format("%d already has a %s under way", b.id, what)) end
    local pos = {player.position.x, player.position.y}
    local why
    if what == "rig" then
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
    -- The real arrival (notice, map tag, the others hear it), on the ring this far from you: by pod, as the
    -- faction's own landings come (faction.request; the trailer's forced landing appeared at once, the user,
    -- 2026-11-04: "the lack of animation is a little jarring"); `now`, or pods off, at once.
    if args[3] == "now" or args[4] == "now" or storage.pods_off then
      local b = faction.arrive(player.surface, player.position, {corp = corp, distance = d}, false)
      if not b then return player.print("no site to land on at that distance") end
      b.parts = (b.parts or 0) + 2000
      return player.print(string.format("%s landed: %d %s", shared.CORPS[corp].name, b.id, gps(b)))
    end
    faction.request(player.surface, player.position, {corp = corp, distance = d}, false, "dev",
      {dev_player = player.index, dev_parts = 2000})
    player.print(string.format("%s is coming down about %d tiles from you (its pod, then its lander)", shared.CORPS[corp].name, d))
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
  elseif what == "burst" then
    -- (A big burster's blast is herd.lua's, set as burstfx.on_blast.big when herd loads.)
    local big = args[2] == "big"
    local name = big and "lp-bred-big-burster" or "lp-bred-cinder"
    local s = player.surface
    local at = s.find_non_colliding_position(name, {player.position.x + 12, player.position.y}, 10, 0.5)
    if not at then return player.print("no room for a burster east of you") end
    local u = s.create_entity{name = name, position = at, force = shared.BIOTECH.force}
    if not (u and burstfx.windup(u, big and "big" or "cinder")) then return player.print("the burster could not be set off") end
    player.print(string.format("a %s set off at %.0f,%.0f: it bursts in %.1f s", big and "big burster" or "burster", at.x, at.y,
      burstfx.KIND[big and "big" or "cinder"].windup / 60))
  elseif what == "tesla" then
    local s, n = player.surface, math.max(1, math.min(10, tonumber(args[2]) or 1))
    local name = shared.variant(shared.DEFAULT_CORP, "lp-tesla")
    local force = game.forces[shared.CORPS[shared.DEFAULT_CORP].force]
    if not force then return player.print("no Kessler-Hayashi force yet") end
    local t = s.find_entities_filtered{position = player.position, radius = 60, type = "electric-turret",
      force = player.force}
    local target
    for _, e in ipairs(t) do
      if not target or (e.position.x - player.position.x) ^ 2 + (e.position.y - player.position.y) ^ 2
        < (target.position.x - player.position.x) ^ 2 + (target.position.y - player.position.y) ^ 2 then target = e end
    end
    local made = 0
    for k = 1, n do
      local at = s.find_non_colliding_position(name, {player.position.x + 20, player.position.y + (k - 1) * 4}, 10, 0.5)
      local u = at and s.create_entity{name = name, position = at, force = force}
      if u then
        made = made + 1
        if target then
          u.commandable.set_command{type = defines.command.attack, target = target, distraction = defines.distraction.by_damage}
        end
      end
    end
    player.print(string.format("%d Tesla%s set east of you, %s", made, made == 1 and "" or "s",
      target and string.format("sent at the %s at %.0f,%.0f", target.name, target.position.x, target.position.y)
        or "no laser or tesla turret of yours within 60 to send them at"))
  elseif what == "trace" then
    storage.trace = not storage.trace
    player.print("trace to script-output/landing-party/decisions.txt: " .. tostring(storage.trace))
  else
    player.print("/lp list | raid | siege | strip | strike | perimeter [id] | land <corp> [tiles] [now] | parts <n> [id] | fast | grudge [id] | burst [big] | tesla [n] | spread | ranks | provoke | era <n> | trace")
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
