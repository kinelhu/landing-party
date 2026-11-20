-- The units cut out with their shadows (the user, 2026-11-10: "can we do something cute with a greenscreen?"): not a
-- green screen (green spills onto the units and a shadow cannot be keyed) but difference matting, the effects houses'
-- way: each unit filmed twice, alike, on a flat dark tile (lab-dark-2) and on a white one (lab-white); the difference of
-- the two is its alpha, its shadow a soft dark of its own (docs/manual/shots/matte.py cuts them). Each unit at eight
-- facings (a turntable), from the portraits' three-quarter view (orientation 0.375) round, each at three zooms (the
-- cutter keeps the closest that holds it whole). Two grids: dark at x 0, white at x WHITE_X, a unit a row, a facing a
-- column. The stomper (a spider-unit, which no script turns) alone, once.
--   scripts/film.sh gallery fresh.zip docs/manual/shots/portraits-matte.lua docs/sim/film-matte
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
  {"lp-flame-trooper", "pl"}, {"lp-gun-buggy", "pl"},
}
local GAP, FACINGS, ZOOMS = 20, 8, {3, 5, 8}
local WHITE_X = GAP * FACINGS + 60
local GROUNDS = {{"dark", "lab-dark-2", 0}, {"white", "lab-white", WHITE_X}}
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
  for f = 0, FACINGS - 1 do
    for _, g in ipairs(GROUNDS) do
      local pos = {g[3] + f * GAP, (i - 1) * GAP}
      build[#build + 1] = {name = u[1], force = FORCE[u[2]], pos = pos, ground = g[2], ground_r = 9}
    end
  end
  -- Shot in pairs, dark then white at once, so their animations are as near alike as the engine lets them.
  for f = 0, FACINGS - 1 do
    for _, g in ipairs(GROUNDS) do
      shoot(string.format("%s-f%d-%s", u[1], f, g[1]), {g[3] + f * GAP, (i - 1) * GAP}, ZOOMS)
    end
  end
end
local rows = #units
local sp = {GAP * 2, rows * GAP + 20}
for _, g in ipairs(GROUNDS) do
  local p = {g[3] + sp[1], sp[2]}
  build[#build + 1] = {name = "lp-bred-stomper", force = FORCE.sx, pos = p, ground = g[2], ground_r = 18}
  shoot("lp-bred-stomper-f0-" .. g[1], p, {1.5, 2, 3})
end
-- The grounds alone, their colours for the cutter.
for _, g in ipairs(GROUNDS) do shoot("ground-" .. g[1], {g[3] + sp[1] + 12, sp[2] + 12}, {3}) end
local function face()
  for _, e in ipairs(storage.built or {}) do
    if e.valid then
      -- (By its column, not its exact place: a unit set down is nudged off its tile.)
      local x = e.position.x
      local gx = x >= WHITE_X - GAP / 2 and x - WHITE_X or x
      local f = math.floor(gx / GAP + 0.5)
      if f >= 0 and f < FACINGS and e.position.y < rows * GAP then
        local o = (0.375 + f / FACINGS) % 1
        pcall(function() e.orientation = o end)
      end
    end
  end
end
return {name = "matte", pad = {-12, -12, WHITE_X + FACINGS * GAP, sp[2] + 20}, tile = "lab-dark-2", build = build,
  shots = shots, resolution = {1200, 1200}, each = function(tick) face() end}
