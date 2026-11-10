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
--                            "Stunned by lightning"). With none, at your units within 60: its lightning stuns them
--                            (scripts/stun.lua). They are real and stay: kill them or let them be
--   stun [r]                 your units within r (15) of you stunned at once, chance aside: the lightning's stun's look
--   kill <unit> [n]          n (1) of a unit set 8 tiles east of you, a tile apart, and killed there: how it dies (a
--                            hull's cook-off, a flier's fall, the Scorcher's fuel). Kessler-Hayashi's unless it is
--                            Grubstake's name
--   chartcheck               once: one of your troopers and one of your tanks set 600 tiles east of you, on ground you
--                            have not seen; again: whether that ground is charted and in sight, to script-output
--                            landing-party/chartcheck.txt (a benchmark run charts nothing: it needs a game)
--   clear [r]                every unit within r (30) of you removed, no wrecks (between staged scenes)
--   parade [ring <kind>]     each infantry kind walking each of the 8 ways, a row a kind east of you; or eight of one
--                            kind walking out of a ring round you (facings: all face away)
--   dozers | bombers | prism | flak [n]   staged scenes for the trailer, east of you (see dev.run)
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
local ram = require("__landing-party__.scripts.ram")
local stun = require("__landing-party__.scripts.stun")
local command = require("__landing-party__.scripts.command")
local cannon = require("__landing-party__.scripts.cannon")

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
  elseif what == "clear" then
    -- Every unit within r (30) of you gone, no wrecks (the user, 2026-11-09: a staged scene's survivors walked into the
    -- next one's shot): a film clears each stage once its shot is done.
    local r, n = tonumber(args[2]) or 30, 0
    for _, u in ipairs(player.surface.find_entities_filtered{position = player.position, radius = r, type = "unit"}) do
      u.destroy(); n = n + 1
    end
    player.print(string.format("%d units cleared within %d", n, r))
  elseif what == "parade" then
    -- Each infantry kind walking each of the 8 ways, a row a kind east of you, all yours (the user, 2026-11-08: troopers
    -- "moonskating ... their model is turned to the left"): a still mid-walk shows each body facing where it goes.
    local KINDS = {"lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "lp-infantry", "lp-railgunner",
      "lp-shotgun-hand", "lp-sapper", "lp-lance", "lp-shock"}
    local s, made = player.surface, 0
    if args[2] == "ring" then
      -- `parade ring <kind>`: eight of one kind in a ring 3 tiles out, each walking straight out: all face away.
      local kind = args[3] or "lp-trooper"
      for j = 0, 7 do
        local a = j * math.pi / 4
        local x, y = player.position.x + math.sin(a) * 3, player.position.y - math.cos(a) * 3
        local u = s.create_entity{name = kind, position = {x, y}, force = player.force}
        if u then
          u.commandable.set_command{type = defines.command.go_to_location, destination = {x + math.sin(a) * 30, y - math.cos(a) * 30},
            radius = 1, distraction = defines.distraction.none}
          made = made + 1
        end
      end
      return player.print(string.format("%d %s walking out of a ring", made, kind))
    end
    for r, kind in ipairs(KINDS) do
      for j = 0, 7 do
        local x, y = player.position.x + 10 + j * 7, player.position.y + (r - 1) * 5
        local u = s.create_entity{name = kind, position = {x, y}, force = player.force}
        if u then
          local a = j * math.pi / 4
          u.commandable.set_command{type = defines.command.go_to_location, destination = {x + math.sin(a) * 40, y - math.cos(a) * 40},
            radius = 1, distraction = defines.distraction.none}
          made = made + 1
        end
      end
    end
    player.print(string.format("%d on parade: each row a kind, its columns north, north-east ... north-west", made))
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
    -- None: at your units within 60, their middle (the stun's look, 2026-11-09).
    local troops = not target and s.find_entities_filtered{position = player.position, radius = 60, type = "unit",
      force = player.force} or {}
    local mid
    if #troops > 0 then
      local x, y = 0, 0
      for _, t in ipairs(troops) do x, y = x + t.position.x, y + t.position.y end
      mid = {x / #troops, y / #troops}
    end
    local made = 0
    for k = 1, n do
      local at = s.find_non_colliding_position(name, {player.position.x + 20, player.position.y + (k - 1) * 4}, 10, 0.5)
      local u = at and s.create_entity{name = name, position = at, force = force}
      if u then
        made = made + 1
        if target then
          u.commandable.set_command{type = defines.command.attack, target = target, distraction = defines.distraction.by_damage}
        elseif mid then
          u.commandable.set_command{type = defines.command.attack_area, destination = mid, radius = 20,
            distraction = defines.distraction.by_enemy}
        end
      end
    end
    player.print(string.format("%d Tesla%s set east of you, %s", made, made == 1 and "" or "s",
      target and string.format("sent at the %s at %.0f,%.0f", target.name, target.position.x, target.position.y)
        or mid and string.format("sent at your %d units round %.0f,%.0f", #troops, mid[1], mid[2])
        or "no laser, tesla turret or unit of yours within 60 to send them at"))
  elseif what == "stun" then
    local n = 0
    for _, u in ipairs(player.surface.find_entities_filtered{position = player.position, radius = tonumber(args[2]) or 15,
      type = "unit", force = player.force}) do
      stun.apply(u); n = n + 1
    end
    player.print(n .. " of your units stunned")
  elseif what == "kill" then
    local name, n = args[2], math.max(1, math.min(10, tonumber(args[3]) or 1))
    if not (name and prototypes.entity[name]) then return player.print("no unit " .. tostring(name)) end
    local id = name:find("grubstake", 1, true) and "grubstake" or shared.DEFAULT_CORP
    local force = game.forces[shared.CORPS[id].force] or game.forces.enemy
    local s, p, made = player.surface, player.position, 0
    for k = 1, n do
      local at = s.find_non_colliding_position(name, {p.x + 8 + (k - 1) * 3, p.y}, 6, 0.5)
      local u = at and s.create_entity{name = name, position = at, force = force}
      if u then u.die(player.force); made = made + 1 end
    end
    player.print(string.format("%d %s killed east of you", made, name))
  elseif what == "cannon" then
    -- /lp cannon [n]: a platform over Nauvis (made once, kept in storage.dev_platform) with a targeting array and n orbital
    -- cannons (4), each charged to its store and stocked; /lp cannon fire: a strike where the player stands (DESIGN.md,
    -- "Orbital cannons").
    local f = player.force
    if args[2] == "fire" then
      local n, why = cannon.fire(f, player.surface, player.position, player.valid ~= nil and player or nil)
      player.print(n and string.format("orbital strike: %d cannons fired", n) or ("no strike: " .. tostring(why)))
      return
    end
    local n = math.max(1, math.min(5, tonumber(args[2]) or 4))
    local t = f.technologies["lp-orbital-cannon"]
    if t then t.researched = true end
    local pl = storage.dev_platform
    if not (pl and pl.valid) then
      pl = f.create_space_platform{name = "Landing Party dev", planet = "nauvis", starter_pack = "space-platform-starter-pack"}
      if not pl then return player.print("no platform: Space Age's platforms unavailable") end
      pl.apply_starter_pack()
      storage.dev_platform = pl
    end
    local ps = pl.surface
    local tiles = {}
    for x = -36, 36 do for y = 8, 36 do tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}} end end
    ps.set_tiles(tiles)
    if ps.count_entities_filtered{name = "electric-energy-interface", limit = 1} == 0 then
      local e = ps.create_entity{name = "electric-energy-interface", position = {-30, 9}, force = f}
      if e then e.power_production, e.electric_buffer_size = 1e9 / 60, 1e9 end
      for x = -30, 30, 6 do ps.create_entity{name = "substation", position = {x + 1, 18}, force = f} end
    end
    if ps.count_entities_filtered{name = "lp-targeting-array", limit = 1} == 0 then
      ps.create_entity{name = "lp-targeting-array", position = {33.5, 12.5}, force = f}
    end
    local made = 0
    for k = 0, n - 1 do
      -- (Along the deck's south edge, barrels out over the void: 12 by 18 each, 13 apart.)
      local p = {-30 + k * 13, 28}
      local c = ps.find_entities_filtered{name = "lp-orbital-cannon", position = p, radius = 1, limit = 1}[1]
        or ps.create_entity{name = "lp-orbital-cannon", position = p, force = f, direction = defines.direction.south}
      if c then
        c.insert{name = "lp-orbital-shell", count = 4}
        c.insert_fluid{name = "thruster-fuel", amount = 1000}
        local out = c.get_inventory(defines.inventory.crafter_output)
        local want = shared.CANNON.STORE - out.get_item_count("lp-orbital-charge")
        if want > 0 then out.insert{name = "lp-orbital-charge", count = want} end
        made = made + 1
      end
    end
    cannon.store()
    storage.dev_cannon = {surface = ps.name, cannons = made}
    player.print(string.format("%d orbital cannons charged over Nauvis (surface %s); /lp cannon fire where you stand", made, ps.name))
  elseif what == "chartcheck" then
    local s, pf = player.surface, player.force
    local cc = storage.chartcheck
    if not cc then
      local x, y = player.position.x + 600, player.position.y
      s.request_to_generate_chunks({x, y}, 2)
      s.force_generate_chunk_requests()
      cc = {at = game.tick, spots = {}}
      for k, name in ipairs({"lp-trooper", "lp-tank"}) do
        local p = {x, y + (k - 1) * 200}
        local c = {math.floor(p[1] / 32), math.floor(p[2] / 32)}
        cc.spots[#cc.spots + 1] = {name = name, p = p, before = pf.is_chunk_charted(s, c)}
        -- (Enlisted as a trained one is: the army's map is read from the army's list, command.lua.)
        local u = s.create_entity{name = name, position = p, force = pf}
        if u then command.enlist(u) end
      end
      storage.chartcheck = cc
      return player.print("a trooper and a tank set 600 tiles east of you; /lp chartcheck again to read the map")
    end
    local lines = {}
    for _, sp in ipairs(cc.spots) do
      local c = {math.floor(sp.p[1] / 32), math.floor(sp.p[2] / 32)}
      lines[#lines + 1] = string.format("%d ticks on: %s at %.0f,%.0f: charted before %s, now %s, in sight %s", game.tick - cc.at,
        sp.name, sp.p[1], sp.p[2], tostring(sp.before), tostring(pf.is_chunk_charted(s, c)), tostring(pf.is_chunk_visible(s, c)))
    end
    helpers.write_file("landing-party/chartcheck.txt", table.concat(lines, "\n") .. "\n", true)
    player.print(table.concat(lines, "; "))
  elseif what == "dozers" or what == "bombers" or what == "prism" or what == "flak" then
    -- Staged scenes for the trailer (the user, 2026-11-08: "new scenes including a dozer siege and bomber drones diving on
    -- a mass of troopers"; and the Prism and Tesla in action, flak buggies on fliers), the same each take. The attackers
    -- start OFF (60) tiles east, out of a close shot, and come in (the first takes showed every unit appear in frame);
    -- the defenders are those already standing within 16 of the call (the stage's, LP_MIX=scenes), else made there:
    --   dozers [n]   n Killdozers (2) ram through your wall nearest you within 60 (scripts/ram.lua); three times as many
    --                buggies behind them go in through the breach (they had fired over the wall, then got there first)
    --   bombers [n]  your troopers march south and n bomb drones (8) dive on them from all round, a beat apart (all at
    --                once, one blast; the user: "attack from multiple angles", "have the soldiers actually be on the move")
    --   prism [n]    n Prisms (2), two of its tanks and a Tesla at your troops, fighting the whole area (on one trooper,
    --                one went home when it died; Prisms alone read staged, the user: "a mix of units on both sides")
    --   flak [n]     16 Kessler-Hayashi scout drones in two waves at Grubstake's flak buggies (n, 4)
    local s, n0 = player.surface, tonumber(args[2])
    local px, py = player.position.x, player.position.y
    -- Just out of a close shot's frame (half a 1080p frame is 30 tiles over the zoom: 1.4 gives 21): the slow ones closer
    -- (a dozer at 0.07 a tick takes 11 s for 45 tiles, a Prism 0.09), the fliers further.
    local OFF = ({dozers = 45, prism = 32, bombers = 60, flak = 60})[what]
    local MARCH = 24             -- (40: the squad was gone before the drones came, the third takes)
    local function corp(id) return game.forces[shared.CORPS[id].force] end
    local function put(name, force, x, y)
      local at = s.find_non_colliding_position(name, {x, y}, 8, 0.5)
      return at and s.create_entity{name = name, position = at, force = force}
    end
    local function standing(name, force)
      return s.find_entities_filtered{position = {px, py}, radius = 16, name = name, force = force}
    end
    local function troopers()
      local t = standing("lp-trooper", player.force)
      if #t >= 5 then return t end
      for k = 0, 14 do
        local u = put("lp-trooper", player.force, px + (k % 5) * 1.6, py + math.floor(k / 5) * 1.6 - 1.6)
        if u then t[#t + 1] = u end
      end
      return t
    end
    local function centre(list)
      local x, y = 0, 0
      for _, u in ipairs(list) do x, y = x + u.position.x, y + u.position.y end
      return {x / #list, y / #list}
    end
    local function fight(u, at, radius)
      u.commandable.set_command{type = defines.command.attack_area, destination = at, radius = radius or 10,
        distraction = defines.distraction.by_enemy}
    end
    if what == "dozers" then
      local g = corp("grubstake")
      if not g then return player.print("no Grubstake force yet") end
      local walls = s.find_entities_filtered{position = player.position, radius = 60, type = {"wall", "gate"}, force = player.force}
      local w
      for _, e in ipairs(walls) do
        if not w or (e.position.x - px) ^ 2 + (e.position.y - py) ^ 2 < (w.position.x - px) ^ 2 + (w.position.y - py) ^ 2 then w = e end
      end
      if not w then return player.print("no wall of yours within 60 to ram") end
      local n, made, first = math.max(1, math.min(6, n0 or 2)), 0, nil
      storage.ram_trace = true             -- (its dozers' phases to the log: scripts/ram.lua)
      for k = 1, n do
        local y = py + (k - 1) * 4 - (n - 1) * 2
        local u = put(shared.variant("grubstake", "lp-dozer"), g, w.position.x + OFF, y)
        local near = u and s.find_entities_filtered{position = {w.position.x, y}, radius = 3, type = {"wall", "gate"}, force = player.force}
        local piece = near and #near > 0 and s.get_closest({w.position.x, y}, near) or w
        -- Each widens its breach by one strip (six, after the user on the third takes, "the dozers keep working on the
        -- walls": in cut 23 that was most of the scene, two dozers turning along the wall strip by strip, the user,
        -- 2026-11-09: "dozers derping around their broken walls"). Two side by side open a gap of about ten.
        if u and ram.order(u, piece, {widen = 1}) then made = made + 1; first = first or u end
      end
      -- Behind the dozers, kept behind them until the breach (ram.follow).
      local buggies = {}
      for k = 1, 3 * n do
        local u = put(shared.variant("grubstake", "lp-buggy"), g, w.position.x + OFF + 10, py + (k - 1) * 3 - n * 2)
        if u then buggies[#buggies + 1] = u end
      end
      if first then ram.follow(buggies, first) end
      player.print(string.format("%d Killdozer%s ram the %s at %.0f,%.0f, %d buggies behind", made, made == 1 and "" or "s",
        w.name, w.position.x, w.position.y, #buggies))
    elseif what == "bombers" or what == "prism" then
      local troops = troopers()
      local c = centre(troops)
      local id, kind, nd = "grubstake", "lp-scavenger", 8
      if what == "prism" then id, kind, nd = shared.DEFAULT_CORP, "lp-prism", 2 end
      local f = corp(id)
      if not f then return player.print("no " .. shared.CORPS[id].name .. " force yet") end
      local n, made = math.max(1, math.min(12, n0 or nd)), 0
      if what == "bombers" then
        -- The squad on the march, MARCH tiles south in step (a trooper walks 7 a second: a tracking shot; the stage's next
        -- squad stands 60 south).
        for _, t in ipairs(troops) do
          t.commandable.set_command{type = defines.command.go_to_location, destination = {t.position.x, t.position.y + MARCH},
            radius = 1, distraction = defines.distraction.by_damage}
        end
      end
      for k = 1, n do
        local u
        if what == "bombers" then
          -- From all round the squad, each a few tiles further out than the last, so they arrive one after another; led
          -- by MARCH / 2 (the squad's middle on its march).
          local a, far = 0.4 + (k - 1) * 2 * math.pi / n, OFF + (k - 1) * 5
          u = put(shared.variant(id, kind), f, c[1] + math.cos(a) * far, c[2] + MARCH / 2 + math.sin(a) * far)
          if u then u.commandable.set_command{type = defines.command.attack, target = troops[(k - 1) % #troops + 1], distraction = defines.distraction.none} end
        else
          u = put(shared.variant(id, kind), f, c[1] + OFF, c[2] + (k - 1) * 3 - n * 1.5)
          if u then fight(u, c, 12) end
        end
        if u then made = made + 1 end
      end
      if what == "prism" then
        -- Your side holds where it stands and fights (idle, a trooper walked off and a tank chased it out of the shot, the
        -- sixth takes).
        for _, d in ipairs(s.find_entities_filtered{position = c, radius = 20, type = "unit", force = player.force}) do
          d.commandable.set_command{type = defines.command.attack_area, destination = d.position, radius = 20,
            distraction = defines.distraction.by_enemy}
        end
        -- Its company: two of its tanks on the flanks, a Tesla behind.
        for _, e in ipairs({{"lp-tank", 6, -8}, {"lp-tank", 6, 8}, {"lp-tesla", 10, 0}}) do
          local u = put(shared.variant(id, e[1]), f, c[1] + OFF + e[2], c[2] + e[3])
          if u then fight(u, c, 14) end
        end
      end
      player.print(string.format("%d troopers, %d %s coming at them", #troops, made, kind))
    else
      local g, k_ = corp("grubstake"), corp(shared.DEFAULT_CORP)
      if not (g and k_) then return player.print("flak needs both Grubstake and Kessler-Hayashi") end
      local flak = standing(shared.variant("grubstake", "lp-flak-buggy"), g)
      for k = #flak + 1, math.max(1, math.min(6, n0 or 4)) do
        local u = put(shared.variant("grubstake", "lp-flak-buggy"), g, px + (k % 2) * 5, py + math.floor(k / 2) * 5 - 4)
        if u then flak[#flak + 1] = u end
      end
      local c, made = centre(flak), 0
      -- Two waves of eight, the second 25 tiles behind the first.
      for k = 1, 16 do
        local w2 = k > 8 and 25 or 0
        local u = put(shared.variant(shared.DEFAULT_CORP, "lp-harrier"), k_, c[1] + OFF + w2 + (k % 4) * 4, c[2] + ((k - 1) % 8) * 2.8 - 10)
        if u then fight(u, c, 12); made = made + 1 end
      end
      player.print(string.format("%d flak buggies, %d scout drones coming at them%s", #flak, made,
        g.is_enemy(k_) and "" or " (the two are not at war: no fight)"))
    end
  elseif what == "trace" then
    storage.trace = not storage.trace
    player.print("trace to script-output/landing-party/decisions.txt: " .. tostring(storage.trace))
  else
    player.print("/lp list | raid | siege | strip | strike | perimeter [id] | land <corp> [tiles] [now] | parts <n> [id] | fast | grudge [id] | burst [big] | tesla [n] | stun [r] | kill <unit> [n] | chartcheck | clear [r] | parade | dozers [n] | bombers [n] | prism [n] | flak [n] | spread | ranks | provoke | era <n> | trace")
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
