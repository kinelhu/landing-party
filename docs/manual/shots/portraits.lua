-- The manual's unit portraits (docs/manual/media/portraits/<prototype>.png, cut by docs/manual/shots/portraits.py):
-- every unit of docs/manual/_generated/lp-data.json alone on a flat lab tile (lab-dark-2: one grey, no texture, so the
-- shadow is the only thing on it), on its own force, faced south-east (orientation 0.375, the card's three-quarter
-- view), at noon with the clouds hidden. Each unit at three zooms; the cutter keeps the closest that holds it whole.
--   scripts/film.sh gallery fresh.zip docs/manual/shots/portraits.lua docs/sim/film-portraits
local FORCE = {kh = "lp-serenity", gs = "lp-grubstake", sx = "lp-biotech", pl = "player"}
local units = {
  {"lp-infantry", "kh"}, {"lp-tank", "kh"}, {"lp-railgunner", "kh"}, {"lp-laser-drone", "kh"}, {"lp-skyguard", "kh"},
  {"lp-lance", "kh"}, {"lp-shock", "kh"}, {"lp-aegis", "kh"}, {"lp-prism", "kh"}, {"lp-tesla", "kh"},
  {"lp-howitzer-truck", "kh"}, {"lp-hauler", "kh"},
  {"lp-grubstake-buggy", "gs"}, {"lp-shotgun-hand", "gs"}, {"lp-grubstake-harrier", "gs"}, {"lp-grubstake-slug", "gs"},
  {"lp-grubstake-sapper", "gs"}, {"lp-grubstake-scavenger", "gs"}, {"lp-grubstake-dozer", "gs"},
  {"lp-grubstake-flak-buggy", "gs"}, {"lp-grubstake-scorcher", "gs"}, {"lp-grubstake-howitzer-truck", "gs"},
  {"lp-grubstake-hauler", "gs"},
  {"lp-bred-small-biter", "sx"}, {"lp-bred-medium-biter", "sx"}, {"lp-bred-spore", "sx"}, {"lp-bred-medium-spitter", "sx"},
  {"lp-bred-cinder", "sx"}, {"lp-bred-big-biter", "sx"}, {"lp-bred-behemoth-biter", "sx"},
  {"lp-bred-big-burster", "sx"}, {"lp-sweeper", "sx"}, {"lp-bred-scout", "sx"}, {"lp-bred-carrier", "sx"},
  {"lp-technician", "sx"},
  {"lp-breacher", "pl"}, {"lp-trooper", "pl"}, {"lp-rocket-trooper", "pl"}, {"lp-battle-tank", "pl"},
  {"lp-flame-trooper", "pl"},
}
local GAP, COLS = 20, 8
local build, shots = {}, {}
local t = 240
local function shoot(name, pos, zooms)
  for _, z in ipairs(zooms) do
    shots[#shots + 1] = {name = string.format("%s-z%s", name, tostring(z):gsub("%.", "p")), tick = t,
      pos = {pos[1], pos[2] - 0.5}, zoom = z, daytime = 0, hide_clouds = true}
    t = t + 2
  end
end
for i, u in ipairs(units) do
  local pos = {((i - 1) % COLS) * GAP, math.floor((i - 1) / COLS) * GAP}
  build[#build + 1] = {name = u[1], force = FORCE[u[2]], pos = pos, ground = "lab-dark-2", ground_r = 9}
  shoot(u[1], pos, {3, 5, 8})
end
-- The stomper (a spider-unit, legs some eight tiles across) alone, south of the grid.
local rows = math.ceil(#units / COLS)
local sp = {GAP * 2, rows * GAP + 20}
build[#build + 1] = {name = "lp-bred-stomper", force = FORCE.sx, pos = sp, ground = "lab-dark-2", ground_r = 18}
shoot("lp-bred-stomper", sp, {1.5, 2, 3})
-- The ground alone, its colour for the cutter.
shoot("ground", {sp[1] + 12, sp[2] + 12}, {3})
local function face()
  for _, e in ipairs(storage.built or {}) do
    if e.valid then pcall(function() e.orientation = 0.375 end) end
  end
end
return {name = "portraits", pad = {-12, -12, COLS * GAP, sp[2] + 20}, tile = "lab-dark-2", build = build, shots = shots,
  resolution = {1200, 1200}, each = function(tick) face() end}
