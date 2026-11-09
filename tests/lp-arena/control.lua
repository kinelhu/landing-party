-- The arena (a development mod, never shipped): fights between the corporations' units, the player's units and lines,
-- and biters, in pens on their own surface. params.lua (written by the script that runs it) says how:
--   mode = "batch": every matchup headless, the balance table (scripts/arena.sh)
--   mode = "wall":  waves at a stretch of nw's north wall rebuilt (scripts/wall-lab.sh, nwwall.lua)
--   mode = "play":  a panel to set fights up by hand and watch them (scripts/play-arena.sh)
--   mode = "guitest": the panel driven through every pick, its text and a screenshot written (scripts/arena-gui.sh)
local params = require("params")
local arena = require("arena")
arena.play = params.mode == "play" or params.mode == "guitest"
local batch = require("batch")
local gui = require("gui")
local wall = require("nwwall")

script.on_init(function()
  if params.mode == "batch" or params.mode == "wall" then
    arena.surface()
  end
end)

script.on_event(defines.events.on_tick, function(e)
  if params.mode == "batch" then
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
