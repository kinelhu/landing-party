-- Kessler-Hayashi's drop siege in its formations (0.2.182 to 0.2.184): its escort in staggered ranks at its hold as its
-- guns deploy, in line through the barrage, moved up to its jump-off behind the strike, then the assault going in rank by
-- rank. From the `standsiege` scenario's fork at minute 8 (scripts/fork.sh standsiege 12345 14), its siege forced at
-- minute 8 on its way (the orbital scenario's fork had none running, and /lp siege found no mortar site there), fast until
-- it deploys; aimed
-- at its escort's centre or its strike (lp-film: pos = "escort" | "strike"; events "phase:<name>" when its
-- siege's phase turns to it).
--   scripts/film.sh standsiege-film fork.zip docs/trailer/stills-formations.lua
local shots = {}
local function at(name, after, dt, pos, zoom)
  shots[#shots + 1] = {name = name, after = after, dt = dt, pos = pos, zoom = zoom or 0.8, daytime = 0.1}
end
at("1-hold-deploy", "phase:deploy", 120, "escort")
at("2-hold-deploy-late", "phase:deploy", 600, "escort")
at("3-bombard", "phase:bombard", 300, "escort", 0.6)
at("4-paint-jumpoff", "paint", 400, "escort")
at("5-paint-jumpoff-wide", "paint", 650, "jump", 0.5)
for k, dt in ipairs({0, 60, 120, 180, 240, 360}) do
  at(string.format("6-assault-%d", k), "phase:assault", dt, "strike", 0.7)
end
return {name = "formations", base = "siege", fast_until = "phase:deploy", speed = 4, stop_after = 10 * 3600, resolution = {1280, 720},
  anti_alias = false, shots = shots}
