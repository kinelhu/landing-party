-- The units' weapon sounds, a proposal (the user, 2026-11-09: "we start work on sound (especially tank shots, machine
-- guns, etc)"). Every unit borrowed one vanilla weapon's sound unchanged: all bullets the submachine gun's, all hulls the
-- tank cannon's; the Tesla, the breacher, the sapper and the dozer silent. Here each its own, from the game's recordings
-- played at a pitch and volume of its own (the Sound prototype's speed and volume: no copies of the files), Grubstake's
-- heavier and rougher, Kessler-Hayashi's tighter; the player's units keep vanilla's. Read by scripts/sound_board.py (a
-- board to listen to) and, once chosen, by the mod's data stage.
--   units: the prototypes it goes to (and their plated variants); files: paths under the game's data (base, space-age), variations; speed: pitch and pace; volume; every: ticks
--   between shots as the unit fires (the board plays shots that far apart); shots: how many the board plays; was: what
--   it plays now when not its files at speed 1 ("none": silent); layers: more sounds laid over each shot ({files, speed,
--   volume, offset in ticks}); rounds, gap: a burst of that many rounds that many ticks apart, each attack; round: the
--   board's round it was put in; was_every: the rate it fires at now, when not every; decided: the user's verdict, once given (the sheet, docs/sound: round 1, 2026-11-09).
-- Round 1: six kept; the Tesla quieter; the slug buggy "Deeper, think double barrel"; the rifle "Can we make them fire
-- in bursts?". Round 2: slug A kept (B and C dropped), the quieter Tesla kept, the rifle's burst kept. Round 3: the
-- trooper fires a laser beam, not a rifle (the board's "now" had it wrong, and the laser drone "silent": both beams hum).
-- Round 3: the trooper's laser in bursts kept. All nine decided.
return {
  {id = "gs-mg", units = {"lp-buggy", "lp-grubstake-buggy", "lp-scorcher", "lp-grubstake-scorcher"}, decided = "keep", label = "Grubstake machine-gun buggy, Scorcher's gun", files = {"base/sound/fight/heavy-gunshot-1.ogg",
    "base/sound/fight/heavy-gunshot-2.ogg", "base/sound/fight/heavy-gunshot-3.ogg", "base/sound/fight/heavy-gunshot-4.ogg"},
    speed = 0.9, volume = 0.6, every = 10, shots = 14, was = "base/sound/fight/submachine-gunshot-1.ogg"},
  {id = "gs-slug-a", units = {"lp-slug", "lp-grubstake-slug"}, decided = "keep", label = "Grubstake slug buggy, A", round = 2, detail = "two barrels: two deep pump blasts 3 ticks apart",
    files = {"base/sound/fight/pump-shotgun-1.ogg", "base/sound/fight/pump-shotgun-2.ogg", "base/sound/fight/pump-shotgun-3.ogg"}, speed = 0.7, volume = 0.7, every = 50, shots = 4,
    layers = {{files = {"base/sound/fight/pump-shotgun-4.ogg", "base/sound/fight/pump-shotgun-5.ogg", "base/sound/fight/pump-shotgun-6.ogg"}, speed = 0.66, volume = 0.6, offset = 3}}, was = "base/sound/fight/pump-shotgun-1.ogg"},
  {id = "gs-cannon", units = {"lp-grubstake-tank"}, decided = "keep", label = "Grubstake tank cannon", files = {"base/sound/fight/tank-cannon-1.ogg", "base/sound/fight/tank-cannon-2.ogg",
    "base/sound/fight/tank-cannon-3.ogg"}, speed = 0.85, volume = 0.8, every = 90, shots = 3},
  {id = "gs-harrier", units = {"lp-grubstake-harrier"}, decided = "keep", label = "Grubstake harrier's gun", files = {"base/sound/fight/light-gunshot-1.ogg", "base/sound/fight/light-gunshot-2.ogg",
    "base/sound/fight/light-gunshot-3.ogg"}, speed = 1.1, volume = 0.5, every = 20, shots = 8, was = "base/sound/fight/submachine-gunshot-1.ogg"},
  -- (Round two put a gunshot burst on it, the trooper heard as a rifle: it fires a laser beam, the beam's own hum its
  -- sound. Kept by the user, unfit to its weapon: round three, its laser in bursts.)
  {id = "kh-trooper", decided = "keep", units = {"lp-infantry"}, label = "Kessler-Hayashi trooper's laser", round = 3,
    detail = "three short laser pulses, 5 ticks apart, a burst every 66 ticks (its beam's damage a second)", rounds = 3, gap = 5,
    files = {"base/sound/fight/laser-1.ogg", "base/sound/fight/laser-2.ogg", "base/sound/fight/laser-3.ogg"},
    speed = 1.3, volume = 0.4, every = 66, shots = 4, was = "base/sound/fight/laser-beam.ogg", was_every = 25},
  {id = "kh-cannon", units = {"lp-tank"}, decided = "keep", label = "Kessler-Hayashi tank cannon", files = {"base/sound/fight/tank-cannon-4.ogg", "base/sound/fight/tank-cannon-5.ogg",
    "base/sound/fight/tank-cannon.ogg"}, speed = 1.1, volume = 0.7, every = 90, shots = 3},
  {id = "kh-tesla", units = {"lp-tesla", "lp-grubstake-tesla"}, decided = "keep", label = "Kessler-Hayashi Tesla's lightning", files = {"space-age/sound/entity/tesla-turret/tesla-turret-chain-beam.ogg"},
    speed = 1.0, volume = 0.35, every = 75, shots = 3, was = "none", round = 2,
    detail = "quieter: volume 0.6 to 0.35"},
  {id = "kh-laser-drone", units = {"lp-laser-drone", "lp-grubstake-laser-drone"}, decided = "keep", label = "Kessler-Hayashi laser drone", files = {"base/sound/fight/laser-1.ogg", "base/sound/fight/laser-2.ogg",
    "base/sound/fight/laser-3.ogg"}, speed = 1.2, volume = 0.45, every = 20, shots = 8, was = "base/sound/fight/laser-beam.ogg", was_every = 20},
  {id = "kh-rail", units = {"lp-aegis", "lp-grubstake-aegis", "lp-railgunner", "lp-grubstake-railgunner"}, decided = "keep", label = "Kessler-Hayashi Aegis and railgunner", files = {"space-age/sound/entity/railgun/railgun-gunshot-1.ogg",
    "space-age/sound/entity/railgun/railgun-gunshot-2.ogg"}, speed = 1.0, volume = 0.7, every = 120, shots = 2},
  -- Round four (2026-11-15, the Sound Sheet): the dozer's ram, A kept (B, a crash over stone, dropped). Its three impacts
  -- picked at random a hit, once a second (its cooldown).
  {id = "dozer-ram-a", units = {"lp-dozer", "lp-grubstake-dozer"}, decided = "keep", label = "Dozer's ram", round = 4,
    files = {"base/sound/car-metal-large-impact-1.ogg", "base/sound/car-metal-large-impact-2.ogg",
      "base/sound/car-metal-large-impact-3.ogg"}, speed = 0.75, volume = 0.7, every = 60, shots = 4, was = "none"},
  -- Round five: the sapper's throw, louder, before the blast its charge already makes (A kept; the board's gap of two
  -- thirds of a second before the blast is not had: the charge's damage and blast land on the attack's tick).
  {id = "sapper-a", units = {"lp-sapper", "lp-grubstake-sapper"}, decided = "keep", label = "Sapper's throw", round = 5,
    files = {"base/sound/fight/throw-grenade-1.ogg", "base/sound/fight/throw-grenade-2.ogg"}, speed = 0.8, volume = 1.0,
    every = 180, shots = 3},
}
