-- The field dome (0.2.202) as a clip: the `pdome` scenario from its start in a window, Kessler-Hayashi's mortar shells
-- falling on the turret under the dome, caught (a bolt from its crown, a burst, the wave over it). A frame every 2 ticks.
local shots = {}
for t = 340, 1540, 2 do
  shots[#shots + 1] = {name = string.format("f-%05d", t), tick = t, pos = {0, -12}, zoom = 0.7, daytime = 0.12}
end
return {name = "clip-pdome", resolution = {1280, 720}, anti_alias = false, shots = shots}
