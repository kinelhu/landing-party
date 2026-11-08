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
-- many more pieces beside the gap, each the nearest left within WIDEN of it (the user, on the third takes: "the dozers keep
-- working on the walls"), where without it it drives on through.
local WIDEN = 6
function ram.order(u, wall, opts)
  if not (u and u.valid and wall and wall.valid) then return false end
  local dx, dy = wall.position.x - u.position.x, wall.position.y - u.position.y
  local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
  local d = {dx / len, dy / len}
  local face = {wall.position.x - d[1] * 1.6, wall.position.y - d[2] * 1.6}
  local old = st()[u.unit_number]
  st()[u.unit_number] = {unit = u, dir = d, wall = {wall.position.x, wall.position.y}, phase = "approach", at = game.tick,
    force = wall.force.name, widen = opts and opts.widen or old and old.widen}
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

local function release(lead, at, dir)
  for i = #(storage.ram_followers or {}), 1, -1 do
    local f = storage.ram_followers[i]
    if f.lead == lead then
      -- In through the gap, the ground inside it, then deeper (the user, on the third takes: "the buggy could go deeper
      -- into the base ... once the turrets are dead").
      for _, v in ipairs(f.units) do
        if v.valid then
          v.commandable.set_command{type = defines.command.compound, structure_type = defines.compound_command.return_last,
            commands = {{type = defines.command.go_to_location, destination = {at[1] + dir[1] * 3, at[2] + dir[2] * 3}, radius = 2,
              distraction = defines.distraction.by_damage},
              {type = defines.command.attack_area, destination = {at[1] + dir[1] * 10, at[2] + dir[2] * 10}, radius = 10,
                distraction = defines.distraction.by_enemy},
              {type = defines.command.attack_area, destination = {at[1] + dir[1] * 20, at[2] + dir[2] * 20}, radius = 14,
                distraction = defines.distraction.by_enemy}}}
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
            local off = (i - (#f.units + 1) / 2) * 3
            v.commandable.set_command{type = defines.command.go_to_location, radius = 1.5, distraction = defines.distraction.none,
              destination = {u.position.x - r.dir[1] * ESCORT - r.dir[2] * off, u.position.y - r.dir[2] * ESCORT + r.dir[1] * off}}
          end
          local d = (r.wall[1] - v.position.x) * r.dir[1] + (r.wall[2] - v.position.y) * r.dir[2]
          if d < lead - 1 then storage.ram_early = (storage.ram_early or 0) + 1 end
        end
      end
    end
  end
end

function ram.tick(tick)
  if tick % STEP ~= 0 or not storage.rams then return end
  for k, r in pairs(storage.rams) do
    local u = r.unit
    if not u.valid then
      -- Its lead lost before a breach: its followers go at the wall themselves.
      release(k, r.wall, {0, 0})
      storage.rams[k] = nil
    elseif r.phase == "approach" then
      local dx, dy = r.wall[1] - u.position.x, r.wall[2] - u.position.y
      if dx * dx + dy * dy <= CLOSE * CLOSE or not u.commandable.has_command then
        r.phase = "ram"
        -- Square to the wall: the last of its turn, its blade along the wall.
        u.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
      elseif tick - r.at > GIVE_UP then
        r.phase = "done"
        release(k, r.wall, {0, 0})
      end
      if r.phase == "approach" then escort(k, r, tick) end
    elseif r.phase == "ram" then
      escort(k, r, tick)
      local hit = ahead(r)
      if #hit > 0 then
        for _, e in ipairs(hit) do
          if e.valid then e.damage(DAMAGE, u.force, "physical", u) end
        end
        storage.ram_crushed = (storage.ram_crushed or 0) + 1
      else
        storage.ram_breaches = (storage.ram_breaches or 0) + 1
        release(k, {u.position.x, u.position.y}, r.dir)
        -- Widening: the next piece beside the gap, rammed from where it stands.
        local next_piece
        if (r.widen or 0) > 0 then
          local best
          for _, e in ipairs(u.surface.find_entities_filtered{position = u.position, radius = WIDEN, type = {"wall", "gate"}}) do
            local dd = (u.position.x - e.position.x) ^ 2 + (u.position.y - e.position.y) ^ 2
            if e.force ~= u.force and u.force.is_enemy(e.force) and (not best or dd < best) then next_piece, best = e, dd end
          end
        end
        if next_piece then
          r.widen = r.widen - 1
          ram.order(u, next_piece)
        else
          -- Clear: on through, its followers behind it.
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
