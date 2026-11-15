-- Sound pass, round six (2026-11-15): the orbital strike's call alone. Round five's A was kept in shape, but "the whine
-- is a little cartoonish (too simple)": a clean sine sweep. Here three with a richer whine: voices layered and detuned
-- against each other, an exponential climb that wavers (tremolo, a flanger), noise through a band, and a recording of
-- the game's under each. Fields as round5.lua's (synth: sox's arguments after "sox -n out.wav"; several tones in one
-- synth are channels, mixed down). Loudness measured on the board.
return {
  {id = "orbital-d", label = "An orbital strike's call, D", kind = "cue", now = "the railgun turret's activation",
    was = "space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg",
    files = {"space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg"}, speed = 0.8, volume = 1.0, every = 240, shots = 1,
    layers = {{synth = "synth 3.5 sawtooth 110/680 sawtooth 113/697 sine 55/340 vol 0.22 lowpass 1600 tremolo 6 20 fade 0.3 3.5 0.7",
      volume = 1.0, offset = 0},
      {files = {"space-age/sound/entity/railgun-turret/railgun-turret-rotation-loop.ogg"}, speed = 0.55, volume = 0.8, offset = 0}},
    detail = "the charge slower; two saws a fraction apart climbing with a low sine under them, the turret's slowed whirr below"},
  {id = "orbital-e", label = "An orbital strike's call, E", kind = "cue", now = "the railgun turret's activation",
    was = "space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg",
    files = {"space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg"}, speed = 0.9, volume = 1.0, every = 240, shots = 1, dur = 4,
    layers = {{files = {"base/sound/silo-raise-rocket.ogg"}, speed = 0.7, volume = 0.45, offset = 0},
      {synth = "synth 3.5 square 80/460 square 81.5/468 vol 0.08 lowpass 1100 flanger fade 0.4 3.5 0.6", volume = 1.0, offset = 10},
      {synth = "synth 3.5 pinknoise vol 0.12 band 700 500 tremolo 3 40 fade 1.2 3.5 0.8", volume = 1.0, offset = 0}},
    detail = "the silo's rocket rising, slowed, under a flanged pair of tones and a band of noise swelling as it climbs"},
  {id = "orbital-f", label = "An orbital strike's call, F", kind = "cue", now = "the railgun turret's activation",
    was = "space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg",
    files = {"space-age/sound/entity/tesla-turret/tesla-turret-activate.ogg"}, speed = 0.6, volume = 0.9, every = 240, shots = 1,
    layers = {{synth = "synth 3.2 triangle 180/900 triangle 186/930 triangle 90/450 vol 0.11 tremolo 9 30 lowpass 2400 fade 0.2 3.2 0.5",
      volume = 1.0, offset = 0},
      {synth = "synth 3.5 brownnoise vol 0.35 lowpass 300 fade 1.5 3.5 1", volume = 1.0, offset = 0},
      {files = {"space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg"}, speed = 1.0, volume = 0.9, offset = 140}},
    detail = "the Tesla's power-up, slowed, a detuned triangle chord rising and wavering, a rumble, then the gun's charge"},
}
