-- The arena (a development mod, never shipped): fights between the corporations' units, the player's units and lines,
-- and biters, in pens on their own surface. params.lua (written by the script that runs it) says how:
--   mode = "batch": every matchup headless, the balance table (scripts/arena.sh)
--   mode = "wall":  waves at a stretch of nw's north wall rebuilt (scripts/wall-lab.sh, nwwall.lua)
--   mode = "play":  a panel to set fights up by hand and watch them (scripts/play-arena.sh)
--   mode = "guitest": the panel driven through every pick, its text and a screenshot written (scripts/arena-gui.sh)
local params = require("params")
local shared = require("__landing-party__.shared")
local arena = require("arena")
arena.play = params.mode == "play" or params.mode == "guitest"
local batch = require("batch")
local gui = require("gui")
local wall = require("nwwall")

-- LP_ARENA_TECH=full (the power ladder's question, 2026-11-20): every force with every finite level of each damage and
-- shooting speed technology, read from the prototypes, so a late game's fights are fought at its research.
local function full_research(only)
  local by = {}
  for _, t in pairs(prototypes.technology) do
    if t.max_level < 1e9 then   -- (an infinite technology's max_level is 2^32 - 1)
      for _, e in ipairs(t.effects or {}) do
        if (e.type == "ammo-damage" or e.type == "gun-speed") and e.ammo_category then
          local k = e.type .. "|" .. e.ammo_category
          by[k] = (by[k] or 0) + e.modifier
        end
      end
    end
  end
  for _, f in pairs(game.forces) do
    if not only or f.name == only then
    for k, m in pairs(by) do
      local kind, cat = k:match("^(.-)|(.+)$")
      if kind == "ammo-damage" then f.set_ammo_damage_modifier(cat, m) else f.set_gun_speed_modifier(cat, m) end
    end
    end
  end
  log("[lp-arena] full research: " .. serpent.line(by))
end

script.on_init(function()
  if params.mode == "batch" or params.mode == "wall" then
    arena.surface()
  end
end)

script.on_event(defines.events.on_tick, function(e)
  if params.mode == "batch" then
    if e.tick == 59 and params.tech == "full" then full_research() end
    -- (Late: the player's force at full research, each corporation at the top of its own tree's damage tracks.)
    if e.tick == 59 and params.tech == "late" then
      full_research("player")
      for corp in pairs(shared.CORPS) do log("[lp-arena] " .. corp .. " tracks: " .. serpent.line(remote.call("landing-party", "debug_rd_max", corp))) end
    end
    if e.tick == 60 then batch.start() end
    batch.tick()
  elseif params.mode == "wall" then
    if e.tick == 60 then wall.start() end
    wall.tick()
  else
    gui.tick()
    if params.mode == "guitest" then gui.test_tick(e.tick) end
  end
end)

script.on_event(defines.events.on_player_created, function(e)
  if params.mode == "play" or params.mode == "guitest" then gui.welcome(game.get_player(e.player_index)) end
end)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_selection_state_changed, gui.on_selection)

commands.add_command("arena", "Open the arena panel again.", function(c)
  local p = game.get_player(c.player_index)
  if p then gui.welcome(p) end
end)
