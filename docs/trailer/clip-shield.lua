-- The player's shield projector (0.2.199) as a clip: the `shield` scenario run from its start in a window (its harness
-- brought by LP_FILM_SIM with a params file of its own), projector 1 behind its turret facing north, its arc on the
-- ground, medium biters coming at the turret: their bites caught, the dome's wave over it. A frame every 2 ticks; and a
-- wide still of all four (facing, facing away, unpowered, breaking).
local shots = {}
for t = 290, 1050, 2 do
  shots[#shots + 1] = {name = string.format("f-%05d", t), tick = t, pos = {0, -5}, zoom = 1.1, daytime = 0.1}
end
for k, t in ipairs({600, 800, 1000}) do
  shots[#shots + 1] = {name = "w-" .. k, tick = t + 1, pos = {90, -6}, zoom = 0.45, daytime = 0.1}
end
return {name = "clip-shield", resolution = {1280, 720}, anti_alias = false, shots = shots}
