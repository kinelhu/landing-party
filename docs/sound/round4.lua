-- Sound pass, round four (2026-11-15; the user: the sound pass "would increase the value of the mod greatly"): a
-- proposal on the board (scripts/sound_board.py --table docs/sound/round4.lua), nothing wired into the mod until the
-- user picks. Weapons were rounds 1 to 3 (landing-party/sounds.lua, nine decided). Fields as sounds.lua's, and:
--   was: what plays now, a file or a list ("none": silent), read from the prototype dump of 0.2.423, not guessed;
--   now: the card's words for it; synth: a voice made by sox (its arguments after "sox -n out.wav"), where the
--   game's recordings have nothing that fits; dur: the clip cut to this many seconds (an engine's loop).
-- Every voice the game's recordings at a speed and volume of their own (the Sound prototype's speed and volume: no
-- copies of the files) or synthesised; no CC0 library used this round.
-- Din, for when one is wired (vanilla's own limits, base/prototypes/entity/sounds.lua and enemies.lua): a unit's
-- walking_sound (footsteps, an engine's chug on its run cycle via running_sound_animation_positions, so it plays only
-- while moving) with aggregation {max_count = 3, remove = true, count_already_playing = true}, 2 for heavy vehicles;
-- dying_sound the same at 3; no working_sound on units (it would play standing still, and per prototype: forty idle
-- tanks humming). Faction cues played by script once per event (surface.play_sound) with aggregation max_count 1.
-- (The board's volumes are the proposal's: fliers and steps first set at 0.15 to 0.35 measured an RMS of 0.003 to
-- 0.009 against the deaths' 0.15, inaudible on the board; raised so each is heard and still sits under the guns.)
return {
  -- 1. The silent weapons. (The breacher is not silent: its grenade's throw and blast, throw-grenade and
  -- grenade-explosion; no card.)
  {id = "dozer-ram-a", label = "Dozer's ram, A", kind = "weapon", now = "silent (its hit's explosion has no sound)", was = "none",
    files = {"base/sound/car-metal-large-impact-1.ogg", "base/sound/car-metal-large-impact-2.ogg", "base/sound/car-metal-large-impact-3.ogg"},
    speed = 0.75, volume = 0.7, every = 60, shots = 4, detail = "a heavy blade striking metal, once a second"},
  {id = "dozer-ram-b", label = "Dozer's ram, B", kind = "weapon", now = "silent", was = "none",
    files = {"base/sound/car-crash.ogg"}, speed = 0.85, volume = 0.6, every = 60, shots = 4,
    layers = {{files = {"base/sound/car-stone-impact-1.ogg", "base/sound/car-stone-impact-2.ogg"}, speed = 0.7, volume = 0.5, offset = 2}},
    detail = "a crash with grinding stone under it"},
  {id = "sapper-throw", label = "Sapper's charge", kind = "weapon",
    now = "the blast alone, grenade-explosion (no throw)", was = {"base/sound/fight/medium-explosion-1.ogg", "base/sound/fight/medium-explosion-2.ogg"},
    files = {"base/sound/fight/throw-projectile-1.ogg", "base/sound/fight/throw-projectile-2.ogg"}, speed = 0.85, volume = 0.5,
    every = 180, shots = 3, layers = {{files = {"base/sound/fight/medium-explosion-1.ogg", "base/sound/fight/medium-explosion-2.ogg"},
    speed = 1.0, volume = 1.0, offset = 6}}, detail = "a lob a tenth of a second before the blast already there"},

  -- 2. Movement: engines on the run cycle, footsteps. All silent now (units.lua strips walking_sound from every unit).
  {id = "gs-light-engine-a", label = "Grubstake light engine, A", kind = "move",
    now = "silent", was = "none", files = {"base/sound/car-engine-driving.ogg"}, speed = 0.8, volume = 0.35, every = 240, shots = 1, dur = 4,
    detail = "buggy, slug, scorcher, flak, hauler: the car's engine, rougher"},
  {id = "gs-light-engine-b", label = "Grubstake light engine, B", kind = "move", now = "silent", was = "none",
    files = {"base/sound/car-engine-driving.ogg"}, speed = 0.7, volume = 0.3, every = 240, shots = 1, dur = 4,
    layers = {{files = {"base/sound/driving/vehicle-surface-sand.ogg"}, speed = 1.0, volume = 0.35, offset = 0}},
    detail = "lower still, with gravel under its wheels"},
  {id = "gs-heavy-engine", label = "Grubstake heavy engine", kind = "move", now = "silent", was = "none",
    files = {"base/sound/fight/tank-engine-driving.ogg"}, speed = 0.8, volume = 0.4, every = 240, shots = 1, dur = 4,
    layers = {{files = {"base/sound/fight/tank-tracks.ogg"}, speed = 0.85, volume = 0.3, offset = 0}}, detail = "tank, dozer, howitzer truck: the diesel lower, tracks under it"},
  {id = "kh-light-engine", label = "Kessler-Hayashi light drive", kind = "move", now = "silent", was = "none",
    files = {"base/sound/driving/vehicle-surface-concrete.ogg"}, speed = 1.1, volume = 0.3, every = 240, shots = 1, dur = 4,
    layers = {{synth = "synth 4 sine 180:220 sine 360 tremolo 9 30 vol 0.12 fade 0.3 4 0.6", volume = 1.0, offset = 0}},
    detail = "buggy, flak, hauler, howitzer truck: an electric hum over tyres"},
  {id = "kh-heavy-engine", label = "Kessler-Hayashi heavy drive", kind = "move", now = "silent", was = "none",
    files = {"base/sound/fight/tank-tracks.ogg"}, speed = 1.1, volume = 0.35, every = 240, shots = 1, dur = 4,
    layers = {{synth = "synth 4 sawtooth 70 lowpass 400 tremolo 6 20 vol 0.25 fade 0.3 4 0.6", volume = 1.0, offset = 0}},
    detail = "tank, dozer: tracks with a low electric drone, no diesel"},
  {id = "harrier-flight", label = "Harrier's flight", kind = "move", now = "silent", was = "none",
    files = {"base/sound/fight/defender-robot-loop.ogg"}, speed = 0.6, volume = 1.0, every = 240, shots = 1, dur = 4,
    detail = "a robot's loop slowed into a rotor's beat"},
  {id = "drone-flight", label = "Laser drone's flight", kind = "move", now = "silent", was = "none",
    files = {"base/sound/fight/distractor-robot-loop.ogg"}, speed = 0.9, volume = 0.9, every = 240, shots = 1, dur = 4,
    detail = "the distractor's whine, a little lower"},
  {id = "gs-feet", label = "Grubstake steps", kind = "move", now = "silent", was = "none",
    files = {"base/sound/walking/dirt-1-1.ogg", "base/sound/walking/dirt-1-2.ogg", "base/sound/walking/dirt-1-3.ogg", "base/sound/walking/dirt-1-4.ogg"},
    speed = 0.85, volume = 0.8, every = 20, shots = 12, detail = "boots on dirt, heavier"},
  {id = "kh-feet", label = "Kessler-Hayashi steps", kind = "move", now = "silent", was = "none",
    files = {"space-age/sound/entity/mech-armor/mech-armor-land-concrete-1.ogg", "space-age/sound/entity/mech-armor/mech-armor-land-concrete-2.ogg",
      "space-age/sound/entity/mech-armor/mech-armor-land-concrete-3.ogg"}, speed = 1.7, volume = 0.45, every = 18, shots = 12,
    detail = "the mech armour's landing, quick and small: armoured soles"},
  {id = "player-feet", label = "The player's troops' steps", kind = "move", now = "silent", was = "none",
    files = {"base/sound/walking/grass-1.ogg", "base/sound/walking/grass-2.ogg", "base/sound/walking/grass-3.ogg", "base/sound/walking/grass-4.ogg"},
    speed = 1.0, volume = 1.0, every = 20, shots = 12, detail = "the engineer's own steps on grass"},

  -- 3. Deaths, by class. Now: the dying explosion's sound only.
  {id = "death-foot", label = "Foot units' death", kind = "death", now = "small-explosion (the corporations'); silent (the player's troops)",
    was = {"base/sound/small-explosion-1.ogg", "base/sound/small-explosion-2.ogg"},
    files = {"base/sound/fight/robot-die-impact-1.ogg", "base/sound/fight/robot-die-impact-2.ogg", "base/sound/fight/robot-die-impact-3.ogg"},
    speed = 0.8, volume = 0.6, every = 50, shots = 4, layers = {{files = {"base/sound/small-explosion-1.ogg", "base/sound/small-explosion-2.ogg"}, speed = 1.0, volume = 0.5, offset = 0}},
    detail = "armour hitting the ground under the small blast it has"},
  {id = "death-light", label = "Light vehicles' death", kind = "death", now = "medium-explosion",
    was = {"base/sound/fight/medium-explosion-1.ogg", "base/sound/fight/medium-explosion-2.ogg"},
    files = {"base/sound/fight/car-explosion-1.ogg", "base/sound/fight/car-explosion-2.ogg", "base/sound/fight/car-explosion-3.ogg"},
    speed = 0.95, volume = 0.7, every = 70, shots = 3, detail = "the car's own death"},
  {id = "death-heavy", label = "Heavy vehicles' death", kind = "death", now = "medium-explosion (tanks), massive-explosion (the scorcher)",
    was = {"base/sound/fight/medium-explosion-3.ogg", "base/sound/fight/medium-explosion-4.ogg"},
    files = {"base/sound/fight/tank-explosion-1.ogg", "base/sound/fight/tank-explosion-2.ogg", "base/sound/fight/tank-explosion-3.ogg"},
    speed = 0.9, volume = 0.8, every = 90, shots = 3, detail = "the tank's own death, a little deeper"},
  {id = "death-drone", label = "Drones' death", kind = "death", now = "robot-explosion",
    was = {"base/sound/fight/robot-explosion-1.ogg", "base/sound/fight/robot-explosion-2.ogg"},
    files = {"base/sound/fight/robot-die-whoosh-1.ogg", "base/sound/fight/robot-die-whoosh-2.ogg"}, speed = 1.0, volume = 0.5, every = 70, shots = 3,
    layers = {{files = {"base/sound/fight/robot-explosion-1.ogg", "base/sound/fight/robot-explosion-2.ogg"}, speed = 1.0, volume = 0.6, offset = 12}},
    detail = "a falling whoosh, then the blast it has"},

  -- 4. Faction cues.
  {id = "pods-alarm", label = "Strike force pods landing", kind = "cue",
    now = "the engine's own pod sounds (not yet heard in a game window)",
    was = {"base/sound/procession/cargo-pod-thruster-burst-1.ogg", "base/sound/procession/cargo-pod-ground-land-1.ogg"},
    files = {"base/sound/silo-alarm-short.ogg"}, speed = 0.8, volume = 0.45, every = 120, shots = 1,
    layers = {{files = {"base/sound/procession/cargo-pod-thruster-burst-1.ogg"}, speed = 1.0, volume = 0.8, offset = 40},
      {files = {"base/sound/procession/cargo-pod-ground-land-1.ogg"}, speed = 1.0, volume = 0.9, offset = 70}},
    detail = "a slow klaxon at the landing point, before the pod's own"},
  {id = "siege-horn-a", label = "A siege starting, A", kind = "cue", now = "silent", was = "none",
    files = {"base/sound/silo-alarm.ogg"}, speed = 0.7, volume = 0.9, every = 240, shots = 1, dur = 4, detail = "the silo's alarm, slow and far"},
  {id = "siege-horn-b", label = "A siege starting, B", kind = "cue", now = "silent", was = "none",
    synth = "synth 3.5 sawtooth 73 sawtooth 110 lowpass 700 tremolo 4 15 vol 0.35 fade 0.4 3.5 1.2",
    files = {}, speed = 1.0, volume = 1.0, every = 240, shots = 1, detail = "a low war horn, synthesised"},
  {id = "orbital-call", label = "An orbital strike's call", kind = "cue", now = "lp-cannon-charge (the railgun turret's activation)",
    was = "space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg",
    files = {"space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg"}, speed = 1.0, volume = 1.0, every = 240, shots = 1,
    layers = {{synth = "synth 2.5 sine 300:1400 vol 0.18 fade 0.1 2.5 0.4", volume = 1.0, offset = 0}},
    detail = "the charge it has, with a rising whine from orbit"},
  {id = "dome-catch", label = "A dome catching a shell", kind = "cue", now = "the tesla beam's deflection (its bolt's own)",
    was = {"space-age/sound/entity/tesla-turret/tesla-turret-beam-deflection-1.ogg", "space-age/sound/entity/tesla-turret/tesla-turret-beam-deflection-2.ogg"},
    files = {"space-age/sound/entity/tesla-turret/tesla-turret-beam-deflection-1.ogg", "space-age/sound/entity/tesla-turret/tesla-turret-beam-deflection-2.ogg"},
    speed = 1.0, volume = 1.0, every = 90, shots = 3, layers = {{files = {"base/sound/fight/medium-explosion-5.ogg"}, speed = 1.3, volume = 0.5, offset = 4}},
    detail = "the bolt, then the airburst where the shell was"},
  {id = "mast-up", label = "A mast going up", kind = "cue", now = "silent", was = "none",
    files = {"base/sound/silo-clamps-on.ogg"}, speed = 0.8, volume = 0.6, every = 240, shots = 1,
    layers = {{files = {"base/sound/substation.ogg"}, speed = 0.7, volume = 0.5, offset = 50}}, dur = 4,
    detail = "clamps locking, then a substation's hum powering up"},
  {id = "landing-roar", label = "A camp's first landing", kind = "cue", now = "large-explosion at touchdown (landfx)",
    was = "base/sound/fight/large-explosion-1.ogg",
    files = {"base/sound/procession/cargo-pod-reentry-flame.ogg"}, speed = 0.7, volume = 0.6, every = 300, shots = 1,
    layers = {{files = {"base/sound/fight/large-explosion-1.ogg"}, speed = 1.0, volume = 0.8, offset = 150}}, dur = 5,
    detail = "a long re-entry roar, slowed, before the touchdown blast it has"},
}
