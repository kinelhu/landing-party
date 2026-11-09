-- The units' weapon sounds, a proposal (the user, 2026-11-09: "we start work on sound (especially tank shots, machine
-- guns, etc)"). Every unit borrowed one vanilla weapon's sound unchanged: all bullets the submachine gun's, all hulls the
-- tank cannon's; the Tesla, the breacher, the sapper and the dozer silent. Here each its own, from the game's recordings
-- played at a pitch and volume of its own (the Sound prototype's speed and volume: no copies of the files), Grubstake's
-- heavier and rougher, Kessler-Hayashi's tighter; the player's units keep vanilla's. Read by scripts/sound_board.py (a
-- board to listen to) and, once chosen, by the mod's data stage.
--   files: paths under the game's data (base, space-age), variations; speed: pitch and pace; volume; every: ticks
--   between shots as the unit fires (the board plays shots that far apart); shots: how many the board plays; was: what
--   it plays now when not its files at speed 1 ("none": silent).
return {
  {id = "gs-mg", label = "Grubstake machine-gun buggy, Scorcher's gun", files = {"base/sound/fight/heavy-gunshot-1.ogg",
    "base/sound/fight/heavy-gunshot-2.ogg", "base/sound/fight/heavy-gunshot-3.ogg", "base/sound/fight/heavy-gunshot-4.ogg"},
    speed = 0.9, volume = 0.6, every = 10, shots = 14, was = "base/sound/fight/submachine-gunshot-1.ogg"},
  {id = "gs-slug", label = "Grubstake slug buggy", files = {"base/sound/fight/pump-shotgun-1.ogg", "base/sound/fight/pump-shotgun-2.ogg",
    "base/sound/fight/pump-shotgun-3.ogg"}, speed = 0.8, volume = 0.8, every = 50, shots = 4},
  {id = "gs-cannon", label = "Grubstake tank cannon", files = {"base/sound/fight/tank-cannon-1.ogg", "base/sound/fight/tank-cannon-2.ogg",
    "base/sound/fight/tank-cannon-3.ogg"}, speed = 0.85, volume = 0.8, every = 90, shots = 3},
  {id = "gs-harrier", label = "Grubstake harrier's gun", files = {"base/sound/fight/light-gunshot-1.ogg", "base/sound/fight/light-gunshot-2.ogg",
    "base/sound/fight/light-gunshot-3.ogg"}, speed = 1.1, volume = 0.5, every = 20, shots = 8, was = "base/sound/fight/submachine-gunshot-1.ogg"},
  {id = "kh-rifle", label = "Kessler-Hayashi trooper's rifle", files = {"base/sound/fight/light-gunshot-4.ogg", "base/sound/fight/light-gunshot-5.ogg",
    "base/sound/fight/light-gunshot-6.ogg"}, speed = 1.15, volume = 0.45, every = 20, shots = 8, was = "base/sound/fight/submachine-gunshot-1.ogg"},
  {id = "kh-cannon", label = "Kessler-Hayashi tank cannon", files = {"base/sound/fight/tank-cannon-4.ogg", "base/sound/fight/tank-cannon-5.ogg",
    "base/sound/fight/tank-cannon.ogg"}, speed = 1.1, volume = 0.7, every = 90, shots = 3},
  {id = "kh-tesla", label = "Kessler-Hayashi Tesla's lightning", files = {"space-age/sound/entity/tesla-turret/tesla-turret-chain-beam.ogg"},
    speed = 1.0, volume = 0.6, every = 75, shots = 3, was = "none"},
  {id = "kh-laser-drone", label = "Kessler-Hayashi laser drone", files = {"base/sound/fight/laser-1.ogg", "base/sound/fight/laser-2.ogg",
    "base/sound/fight/laser-3.ogg"}, speed = 1.2, volume = 0.45, every = 20, shots = 8, was = "none"},
  {id = "kh-rail", label = "Kessler-Hayashi Aegis and railgunner", files = {"space-age/sound/entity/railgun/railgun-gunshot-1.ogg",
    "space-age/sound/entity/railgun/railgun-gunshot-2.ogg"}, speed = 1.0, volume = 0.7, every = 120, shots = 2},
}
