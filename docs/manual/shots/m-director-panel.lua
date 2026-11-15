-- The manual's director panel (/lp director, director_gui.lua) on m-director's set: a strike force and a mast out so its
-- lines have something to list, then the panel opened, the screen GUI shown, at 3840x2160 (the panel is placed by the
-- window's size: at 2560x1440 its right edge was cut off).
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-director-film-12345-13" \
--     scripts/film.sh director-film-film fork.zip docs/manual/shots/m-director-panel.lua docs/sim/film-m-director-panel
return {name = "m-director-panel", resolution = {3840, 2160}, speed = 1, stop_after = 900,
  director = {
    {at = 60, cmd = "jammer"}, {at = 70, cmd = "strike", arg = "research"}, {at = 600, cmd = "panel"},
  },
  shots = {{name = "panel", at_load = 720, pos = {-217, 135}, zoom = 0.6, daytime = 0.02, hide_clouds = true, gui = true}}}
