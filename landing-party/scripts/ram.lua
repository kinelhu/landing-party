-- The Killdozer's ram (the user, 2026-11-08, on the trailer's dozer siege: "Dozers are really stupid… they stop in front
-- of the wall and attack it from afar.. they should align with the wall, and ram through!"): a dozer told at a wall drives
-- to its face, its blade crushes every wall and gate in a strip BLADE wide ahead of it, and once the strip is clear it
-- drives on through THROUGH tiles. Its gun (units.lua: a ram of 60 at 2 tiles) had made it stop and shoot like any gun.
-- Followers (buggies behind it) hold until a breach opens, then go through it and attack inside. Raids use it in their
-- breach phase (ops.lua); the dev tool /lp dozers too.
local ram = {}

local BLADE = 3.2                  -- the strip's width: a lane of three, what a tank needs (scenario wayout)
local REACH = 1.9                  -- how far ahead of its centre the blade bites
local DAMAGE = 60                  -- a piece, each step: a stone wall (350) in six steps, a second
local STEP = 10
local THROUGH = 9
local CLOSE = 2.4                  -- at the wall: its centre this near the face
local GIVE_UP = 60 * 60            -- an approach that never gets there
local ESCORT = 9                   -- followers this far behind their lead until its breach
local ESCORT_EVERY = 30

local function st()
  storage.rams = storage.rams or {}
  storage.ram_followers = storage.ram_followers or {}
  return storage.rams
end

-- Order u to ram through the wall piece `wall`, along the line from u to it. opts.widen: after its breach, it rams that
-- many more strips beside the gap, a blade's width along the wall each, alternately either side, straight on as the first
-- (the user, on the third takes: "the dozers keep working on the walls"), where without it it drives on through.
-- (Sent at the nearest piece from inside the gap, it turned to each and its blade caught one at a time: "last time they
-- razed multiple at once", the sixth takes.)
function ram.order(u, wall, opts)
  if not (u and u.valid and wall and wall.valid) then return false end
  opts = opts or {}
  local d = opts.dir
  if not d then
    local dx, dy = wall.position.x - u.position.x, wall.position.y - u.position.y
    local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    d = {dx / len, dy / len}
  end
  local face = {wall.position.x - d[1] * 1.6, wall.position.y - d[2] * 1.6}
  st()[u.unit_number] = {unit = u, dir = d, wall = {wall.position.x, wall.position.y}, piece = wall, phase = "approach", at = game.tick,
    force = wall.force.name, widen = opts.widen, base = opts.base or {wall.position.x, wall.position.y}, pass = opts.pass or 0}
  u.commandable.set_command{type = defines.command.go_to_location, destination = face, radius = 0.6,
    distraction = defines.distraction.none}
  return true
end

-- Units that keep ESCORT behind u, abreast, until its breach, then go in through it (the user, on the second takes:
-- "the buggies rush to the wall and wait under fire before the dozers even appear").
function ram.follow(units, u)
  local f = storage.ram_followers or {}
  storage.ram_followers = f
  f[#f + 1] = {lead = u.unit_number, units = units}
end

function ram.busy(u)
  local r = storage.rams and storage.rams[u.unit_number]
  return r ~= nil and r.phase ~= "done"
end

-- What the blade has ahead of it, its owner's enemies' walls and gates in the strip.
local function ahead(r)
  local u = r.unit
  local cx, cy = u.position.x + r.dir[1] * REACH, u.position.y + r.dir[2] * REACH
  local h = BLADE / 2
  local out = {}
  for _, e in ipairs(u.surface.find_entities_filtered{position = {cx, cy}, radius = h + 0.6, type = {"wall", "gate"}}) do
    if e.force ~= u.force and u.force.is_enemy(e.force) then
      -- Within the strip: its offset across the ram's line under h, along it under 1.5.
      local ox, oy = e.position.x - cx, e.position.y - cy
      local across = math.abs(ox * -r.dir[2] + oy * r.dir[1])
      local along = math.abs(ox * r.dir[1] + oy * r.dir[2])
      if across <= h and along <= 1.5 then out[#out + 1] = e end
    end
  end
  return out
end

-- What to take inside a breach, in order: the guns nearest the gap, then the rest of what stands there, never a wall (an
-- area attack takes the nearest enemy, and inside a breach that is the wall: the buggies turned round on it, the fourth
-- takes). Up to TAKE of them, nearest first, within REACH of the ground inside.
local TURRETS = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}
local REACH, TAKE = 22, 10
local function targets(surface, force, at, inside, no_guns)
  local guns, rest = {}, {}
  for _, e in ipairs(surface.find_entities_filtered{position = inside, radius = REACH, force = force}) do
    if e.valid and e.destructible and e.type ~= "wall" and e.type ~= "gate" and e.prototype.is_building then
      local list = rest
      for _, t in ipairs(TURRETS) do if e.type == t then list = no_guns and {} or guns end end
      list[#list + 1] = e
    end
  end
  local function d(e) return (e.position.x - at[1]) ^ 2 + (e.position.y - at[2]) ^ 2 end
  table.sort(guns, function(a, b) return d(a) < d(b) end)
  table.sort(rest, function(a, b) return d(a) < d(b) end)
  for _, e in ipairs(rest) do guns[#guns + 1] = e end
  local out = {}
  for k = 1, math.min(TAKE, #guns) do out[k] = guns[k] end
  return out
end
ram.targets = targets

-- An order to take what is inside, one target after another (each a direct attack, so nothing else draws its fire).
local function take(surface, force, at, dir, first, no_guns)
  local inside = {at[1] + dir[1] * 10, at[2] + dir[2] * 10}
  local cmds = {}
  if first then cmds[1] = first end
  for _, e in ipairs(targets(surface, force, at, inside, no_guns)) do
    cmds[#cmds + 1] = {type = defines.command.attack, target = e, distraction = defines.distraction.none}
  end
  -- (It ended on an area attack 20 tiles past the gap: in a small compound that is the far wall, 1,456 of the buggies'
  -- fire on walls in scenario dev. Done, they stand where they are; a raid's own orders take them on.)
  -- (A wander ran out and, idle, a buggy shot the far wall, 350 in scenario dev: it holds, answering only fire.)
  cmds[#cmds + 1] = {type = defines.command.stop, ticks_to_wait = 36000, distraction = defines.distraction.by_damage}
  return {type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds}
end

local function release(lead, at, dir, force)
  for i = #(storage.ram_followers or {}), 1, -1 do
    local f = storage.ram_followers[i]
    if f.lead == lead then
      -- In through the gap, then what stands inside, guns first, then deeper (the user, on the third takes: "the buggy
      -- could go deeper into the base ... once the turrets are dead").
      for _, v in ipairs(f.units) do
        if v.valid then
          -- (Undistracted on the way in: hit by a turret from outside, a buggy turned on it through the wall, 414 of its
          -- fire on walls with six.)
          v.commandable.set_command(take(v.surface, force, at, dir, {type = defines.command.go_to_location,
            destination = {at[1] + dir[1] * 3, at[2] + dir[2] * 3}, radius = 2, distraction = defines.distraction.none}))
        end
      end
      table.remove(storage.ram_followers, i)
    end
  end
end

-- Its followers behind it, abreast across its line; one nearer the wall than its lead is counted (ram.stats().early: a
-- follower that got there first, the second takes' fault).
local function escort(k, r, tick)
  local u = r.unit
  local lead = (r.wall[1] - u.position.x) * r.dir[1] + (r.wall[2] - u.position.y) * r.dir[2]
  for _, f in ipairs(storage.ram_followers or {}) do
    if f.lead == k then
      for i, v in ipairs(f.units) do
        if v.valid then
          if tick % ESCORT_EVERY == 0 then
            -- (Ordered afresh each half second, each twitch of the dozer's was the buggies' too: "dancing around giving
            -- everybody epilepsis", the sixth takes. Ordered again only when its spot has moved 3 tiles.)
            local off = (i - (#f.units + 1) / 2) * 3
            local to = {u.position.x - r.dir[1] * ESCORT - r.dir[2] * off, u.position.y - r.dir[2] * ESCORT + r.dir[1] * off}
            f.spots = f.spots or {}
            local was = f.spots[i]
            if not was or (was[1] - to[1]) ^ 2 + (was[2] - to[2]) ^ 2 > 9 then
              f.spots[i] = to
              -- (Then held there undistracted: arrived and idle, a buggy shot the wall in front of it, 26 in scenario dev.)
              v.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
                commands = {{type = defines.command.go_to_location, radius = 2, distraction = defines.distraction.none, destination = to},
                  {type = defines.command.stop, ticks_to_wait = 36000, distraction = defines.distraction.none}}}
            end
          end
          local d = (r.wall[1] - v.position.x) * r.dir[1] + (r.wall[2] - v.position.y) * r.dir[2]
          -- (Before its first strip falls: after, the lead backs off the wall between strips.)
          if d < lead - 1 and (r.pass or 0) == 0 then storage.ram_early = (storage.ram_early or 0) + 1 end
        end
      end
    end
  end
end

-- A dozer's phases logged when storage.ram_trace is set (/lp dozers sets it): where it is, the piece it was sent at.
local function trace(k, r, what)
  if not storage.ram_trace or not r.unit.valid then return end
  local u = r.unit
  log(string.format("ram %d %s: at %.1f,%.1f, piece %s at %.1f,%.1f, pass %d", k, what, u.position.x, u.position.y,
    tostring(r.piece and r.piece.valid), r.wall[1], r.wall[2], r.pass or 0))
end

function ram.tick(tick)
  if tick % STEP ~= 0 or not storage.rams then return end
  for k, r in pairs(storage.rams) do
    local u = r.unit
    if not u.valid then
      -- Its lead lost before a breach: its followers go at the wall themselves.
      release(k, r.wall, {0, 0}, r.force)
      storage.rams[k] = nil
    elseif r.phase == "approach" then
      local dx, dy = r.wall[1] - u.position.x, r.wall[2] - u.position.y
      -- Its blade on any wall: it rams there (jostled by the others, two dozers slid 6 and 18 tiles along the wall from
      -- their pieces, never within CLOSE of them, and circled: the sixth takes' night outpost).
      -- (Stuck only: still moving, it brushed walls at an angle on its way and counted one piece a strip, 8 strips for 11
      -- pieces in scenario dev.)
      local was = r.last
      r.last = {u.position.x, u.position.y}
      local still = was and (was[1] - u.position.x) ^ 2 + (was[2] - u.position.y) ^ 2 < 0.01
      local touching = {}
      -- (Its own stretch of wall only: through its gap and stuck on the far wall, the lead took that for its piece and
      -- never let its followers go, scenario dev.)
      for _, e in ipairs(still and ahead(r) or {}) do
        if (e.position.x - r.wall[1]) ^ 2 + (e.position.y - r.wall[2]) ^ 2 <= 16 then touching[#touching + 1] = e end
      end
      if #touching > 0 and dx * dx + dy * dy > CLOSE * CLOSE then
        r.piece, r.wall = touching[1], {touching[1].position.x, touching[1].position.y}
        dx, dy = 0, 0
      end
      -- (Its piece already down, another's blade on it: it goes on to its next strip. The second of two dozers side by
      -- side drove at the gap its neighbour had made and never got there, once vehicles passed through each other.)
      if r.piece and not r.piece.valid then dx, dy = 0, 0 end
      -- Past the wall's line (in through another's gap, the second of two dozers wandered inside, driving at the outer
      -- face of a piece it stood behind): it turns and rams its piece from where it is.
      local p = r.piece
      if p and p.valid and not r.turned and (u.position.x - r.wall[1]) * r.dir[1] + (u.position.y - r.wall[2]) * r.dir[2] > 0.5 then
        local ex, ey = p.position.x - u.position.x, p.position.y - u.position.y
        local len = math.max(0.01, math.sqrt(ex * ex + ey * ey))
        r.dir, r.turned = {ex / len, ey / len}, true
        u.commandable.set_command{type = defines.command.go_to_location, radius = 0.6, distraction = defines.distraction.none,
          destination = {p.position.x - r.dir[1] * 1.6, p.position.y - r.dir[2] * 1.6}}
        trace(k, r, "turned")
      end
      if dx * dx + dy * dy <= CLOSE * CLOSE or not u.commandable.has_command then
        r.phase = "ram"
        trace(k, r, dx * dx + dy * dy <= CLOSE * CLOSE and "at the wall" or "stopped short")
        -- Square to the wall: the last of its turn, its blade along the wall.
        u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      elseif tick - r.at > GIVE_UP then
        r.phase = "done"
        release(k, r.wall, {0, 0}, r.force)
      end
      if r.phase == "approach" then escort(k, r, tick) end
    elseif r.phase == "ram" then
      escort(k, r, tick)
      local hit = ahead(r)
      -- Its piece still standing: rammed itself if the blade is at it, else driven up to again. (Stopped short, jostled
      -- by the others, a dozer found nothing under its blade and counted the wall breached: it stood, the dozer wheeled
      -- about under fire, the sixth takes. A strip is clear when the piece it was sent at is gone.)
      local p = r.piece
      if #hit == 0 and p and p.valid then
        local dx, dy = p.position.x - u.position.x, p.position.y - u.position.y
        if dx * dx + dy * dy <= 3.6 * 3.6 then
          hit = {p}
        elseif tick - r.at <= GIVE_UP then
          r.phase = "approach"
          trace(k, r, "again")
          u.commandable.set_command{type = defines.command.go_to_location, radius = 0.6, distraction = defines.distraction.none,
            destination = {p.position.x - r.dir[1] * 1.6, p.position.y - r.dir[2] * 1.6}}
          hit = nil
        end
      end
      if hit == nil then
        -- (Back to its approach: nothing more this step.)
      elseif #hit > 0 then
        for _, e in ipairs(hit) do
          if e.valid then e.damage(DAMAGE, u.force, "physical", u) end
        end
        storage.ram_crushed = (storage.ram_crushed or 0) + 1
      else
        storage.ram_breaches = (storage.ram_breaches or 0) + 1
        trace(k, r, "clear")
        -- Widening: the next strip along the wall, a blade's width from the last on alternate sides, rammed straight on.
        local next_piece, pass
        local tx, ty = -r.dir[2], r.dir[1]
        for p = r.pass + 1, (r.widen or 0) do
          -- (A blade's width less a little: at the full width a piece on the strips' edge stood between them.)
          local off = math.ceil(p / 2) * (BLADE - 0.7) * (p % 2 == 1 and 1 or -1)
          local at = {r.base[1] + tx * off, r.base[2] + ty * off}
          for _, e in ipairs(u.surface.find_entities_filtered{position = at, radius = 1.6, type = {"wall", "gate"}}) do
            if e.force ~= u.force and u.force.is_enemy(e.force) then next_piece, pass = e, p; break end
          end
          if next_piece then break end
        end
        if next_piece then
          ram.order(u, next_piece, {dir = r.dir, base = r.base, pass = pass, widen = r.widen})
        else
          -- Clear: on through, its followers behind it, let go only now: let go at the first strip, they crowded into
          -- a gap three wide that the dozer still stood in (the user, 2026-11-09: "they are blocking the way for the
          -- buggies once the 3 sections are broken").
          release(k, r.base or {u.position.x, u.position.y}, r.dir, r.force)
          r.phase = "through"
          local to = {u.position.x + r.dir[1] * THROUGH, u.position.y + r.dir[2] * THROUGH}
          u.commandable.set_command{type = defines.command.go_to_location, destination = to, radius = 1.5,
            distraction = defines.distraction.none}
          r.at = tick
        end
      end
    elseif r.phase == "through" then
      if not u.commandable.has_command or tick - r.at > 15 * 60 then
        r.phase = "done"
        storage.rams[k] = nil
        -- Then the buildings inside, never the guns: its followers take those (it sat facing a turret with no order, the
        -- fourth takes; sent at the guns, it left the walls, the user: "the dozer again focuses on the turrets").
        u.commandable.set_command(take(u.surface, r.force, {u.position.x, u.position.y}, r.dir, nil, true))
      end
    else
      storage.rams[k] = nil
    end
  end
end

function ram.stats()
  local n = 0
  for _ in pairs(storage.rams or {}) do n = n + 1 end
  return {active = n, crushed = storage.ram_crushed or 0, breaches = storage.ram_breaches or 0, early = storage.ram_early or 0}
end

return ram
