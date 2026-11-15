-- Sound pass, round six, redone (2026-11-15; the user: "How do your proposed sounds articulate with the first
-- explosion?"): the orbital strike's whole sequence, not its call alone. The timeline, scripts/orbital.lua:
-- Kessler-Hayashi's spotter paints PAINT (12 s, 720 ticks; silent today), then its first shell, 30 tiles up at speed 3
-- (FALL, so 10 ticks falling: its impact 730 ticks after the call), then a pair every PACE (20 ticks) outward; each a
-- massive-explosion (large-explosion-1 and -2, unchanged). The player's cannon paints CANNON_PAINT (5 s, 300 ticks)
-- with lp-cannon-charge at its call. The user's choice: the build rises over the paint and ends on the first impact.
-- Each card: the call at 0, the uplink's hum (radar.ogg) swelling under the paint, its own voices (round six's D, E and
-- F, kept in character, stretched over the paint), a descending rush in the last half second, then the first six
-- impacts at their ticks (730, two at 750, two at 770, 790). now_layers: what plays today, the explosions alone after
-- the silent paint. Wiring, once kept: the build started with the paint, timed to the strike's fire_at.
local function impacts(t0, extra)
  local out = {}
  for i, t in ipairs({t0, t0 + 20, t0 + 20, t0 + 40, t0 + 40, t0 + 60}) do
    -- (At 0.4 on the board, now and proposed alike: pairs on one tick clipped at full scale; the game's own capped at 3 by
    -- the explosion's aggregation and unchanged.)
    out[#out + 1] = {files = {"base/sound/fight/large-explosion-" .. (i % 2 == 1 and 1 or 2) .. ".ogg"}, speed = 1.0,
      volume = 0.4, offset = t}
  end
  for _, l in ipairs(extra or {}) do table.insert(out, 1, l) end
  return out
end
local function rush(t)
  return {{synth = "synth 0.5 pinknoise vol 0.35 lowpass 3000 fade 0.1 0.5 0.02", volume = 1.0, offset = t},
    {synth = "synth 0.5 sine 1500/200 vol 0.15 fade 0 0.5 0.02", volume = 1.0, offset = t}}
end
local function hum(d) return {files = {"base/sound/radar.ogg"}, speed = 0.8, volume = 0.5, offset = 0,
  af = string.format("afade=t=in:st=0:d=%.1f:curve=exp", d)} end
local function join(...)
  local out = {}
  for _, t in ipairs({...}) do for _, v in ipairs(t) do out[#out + 1] = v end end
  return out
end
local KH_NOW = impacts(730)
local CHARGE = "space-age/sound/entity/railgun-turret/railgun-turret-activate-1.ogg"
return {
  {id = "strike-d", label = "Kessler-Hayashi's strike, D", kind = "cue", now = "12 s of silent paint, then the explosions",
    now_layers = KH_NOW, dur = 17,
    files = {CHARGE}, speed = 0.8, volume = 1.0, every = 240, shots = 1,
    layers = join({hum(11)},
      {{synth = "synth 11.7 sawtooth 110/680 sawtooth 113/697 sine 55/340 vol 0.22 lowpass 1600 tremolo 6 20 fade 3 11.7 0.2",
        volume = 1.0, offset = 0},
       {files = {"space-age/sound/entity/railgun-turret/railgun-turret-rotation-loop.ogg"}, speed = 0.55, volume = 0.4, offset = 240},
       {files = {"space-age/sound/entity/railgun-turret/railgun-turret-rotation-loop.ogg"}, speed = 0.55, volume = 0.6, offset = 480}},
      rush(700), impacts(730)),
    detail = "the charge slowed; the hum and two detuned saws over a low sine climbing all paint long, the turret's whirr twice, the rush, the impacts"},
  {id = "strike-e", label = "Kessler-Hayashi's strike, E", kind = "cue", now = "12 s of silent paint, then the explosions",
    now_layers = KH_NOW, dur = 17,
    files = {CHARGE}, speed = 0.9, volume = 1.0, every = 240, shots = 1,
    layers = join({hum(11)},
      {{files = {"base/sound/silo-raise-rocket.ogg"}, speed = 0.9, volume = 0.45, offset = 0},
       {synth = "synth 11.5 square 80/460 square 81.5/468 vol 0.08 lowpass 1100 flanger fade 2 11.5 0.3", volume = 1.0, offset = 10},
       {synth = "synth 11.7 pinknoise vol 0.14 band 700 500 tremolo 3 40 fade 6 11.7 0.2", volume = 1.0, offset = 0}},
      rush(700), impacts(730)),
    detail = "the silo's rocket rising under the hum all paint long, flanged tones climbing, a band of noise swelling in its last half, the rush, the impacts"},
  {id = "strike-f", label = "Kessler-Hayashi's strike, F", kind = "cue", now = "12 s of silent paint, then the explosions",
    now_layers = KH_NOW, dur = 17,
    files = {"space-age/sound/entity/tesla-turret/tesla-turret-activate.ogg"}, speed = 0.6, volume = 0.9, every = 240, shots = 1,
    layers = join({hum(11)},
      {{synth = "synth 11.5 triangle 180/900 triangle 186/930 triangle 90/450 vol 0.11 tremolo 9 30 lowpass 2400 fade 2 11.5 0.3",
        volume = 1.0, offset = 0},
       {synth = "synth 11.7 brownnoise vol 0.35 lowpass 300 fade 5 11.7 0.2", volume = 1.0, offset = 0},
       {files = {CHARGE}, speed = 1.0, volume = 0.9, offset = 600}},
      rush(700), impacts(730)),
    detail = "the Tesla's power-up slowed; a detuned triangle chord rising and wavering under the hum, a rumble growing, the gun's charge at 10 s, the rush, the impacts"},
  {id = "cannon-5s", label = "Your cannon's strike, 5 s", kind = "cue",
    now = "its charge at the call, 5 s of paint, then the explosions",
    now_layers = impacts(310, {{files = {CHARGE}, speed = 1.0, volume = 1.0, offset = 0}}), dur = 10,
    files = {CHARGE}, speed = 1.0, volume = 1.0, every = 240, shots = 1,
    layers = join({hum(4.5)},
      {{synth = "synth 4.8 sawtooth 110/680 sawtooth 113/697 vol 0.18 lowpass 1600 tremolo 6 20 fade 1 4.8 0.2", volume = 1.0, offset = 0}},
      rush(280), impacts(310)),
    detail = "the same idea in 5 s, following whichever Kessler-Hayashi sequence you keep (shown here with D's saws): the charge it has, the hum and saws, the rush, the impacts"},
}
