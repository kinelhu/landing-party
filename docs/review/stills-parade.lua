-- Infantry facings (the user, 2026-11-08: troopers "moonskating"). /lp parade ring <kind>: eight of a kind walking straight
-- out of a ring round the call, a still a second in: every body should face away from the middle.
--   scripts/film.sh gallery fresh.zip docs/review/stills-parade.lua
local KINDS = {"lp-trooper", "lp-infantry", "lp-breacher", "lp-railgunner"}
local dev, shots = {}, {}
for i, k in ipairs(KINDS) do
  local at = {(i - 1) * 60, 0}
  dev[#dev + 1] = {tick = 200, args = {"parade", "ring", k}, at = at}
  shots[#shots + 1] = {name = "ring-" .. k, tick = 260 + i, pos = at, zoom = 1.8, daytime = 0.05}
end
return {name = "parade", pad = {-20, -20, 220, 20}, tile = "grass-1", resolution = {1920, 1080}, dev = dev, shots = shots}
