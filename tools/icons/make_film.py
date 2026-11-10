"""The icon film's params (docs/release/icons-film.lua) from the data dump: each placeable item's entity built twice, on a
dark and a white lab tile (difference matting, docs/manual/shots/matte.py's way), and shot at the zoom that makes its
selection box about FILL of the frame (a tile is 32 px at zoom 1). The cannon and the targeting array are not here:
platform only, and the cannon's barrel is the script's; their icons come from the Blender renders.

    python3 tools/icons/make_film.py <data-raw-dump.json> docs/release/icons-film.lua
"""
import json, sys
d = json.load(open(sys.argv[1]))
ents = {}
for ty, ps in d.items():
    for n, p in ps.items():
        if isinstance(p, dict) and "selection_box" in p:
            ents[n] = p
SKIP = {"lp-orbital-cannon", "lp-targeting-array"}
items = []
for ty in ("item", "item-with-entity-data", "capsule", "ammo", "gun", "tool"):
    for n, p in d.get(ty, {}).items():
        pr = p.get("place_result")
        if n.startswith("lp-") and pr and pr in ents and pr not in SKIP:
            items.append((n, pr))
RES, FILL, GAP = 1024, 0.62, 40
lines = ["-- Written by tools/icons/make_film.py from the data dump: each placeable item's entity on a dark and a white",
         "-- lab tile, shot at a zoom that makes it about " + str(int(FILL * 100)) + "% of the frame (icons, docs/release).",
         "--   scripts/film.sh gallery fresh.zip docs/release/icons-film.lua <out>",
         "local build, shots, t = {}, {}, 240", "local G = {{\"dark\", \"lab-dark-2\", 0}, {\"white\", \"lab-white\", %d}}" % (GAP * (len(items) + 2))]
for i, (item, ent) in enumerate(items):
    sb = ents[ent]["selection_box"]
    lt, rb = sb[0] if isinstance(sb[0], list) else [sb[0]["x"], sb[0]["y"]], sb[1] if isinstance(sb[1], list) else [sb[1]["x"], sb[1]["y"]]
    size = max(rb[0] - lt[0], rb[1] - lt[1], 1)
    z = round(FILL * RES / (32 * size * 1.25), 2)       # (1.25: its sprite stands taller than its box)
    lines.append('for _, g in ipairs(G) do local p = {g[3] + %d, 0}; build[#build + 1] = {name = "%s", force = "player", pos = p,'
                 ' ground = g[2], ground_r = %d}; shots[#shots + 1] = {name = "%s-" .. g[1], tick = t, pos = {p[1], p[2] - %.2f},'
                 ' zoom = %s, daytime = 0, hide_clouds = true}; t = t + 2 end' % (i * GAP, ent, int(size + 8), item,
                                                                              size * 0.15, z))
lines += ['for _, g in ipairs(G) do shots[#shots + 1] = {name = "ground-" .. g[1], tick = t, pos = {g[3] - 20, 20}, zoom = 3,'
          ' daytime = 0, hide_clouds = true}; t = t + 2 end',
          'return {name = "icons", pad = {-30, -30, %d, 30}, tile = "lab-dark-2", build = build, shots = shots,'
          ' resolution = {%d, %d}}' % (GAP * (2 * len(items) + 4), RES, RES)]
open(sys.argv[2], "w").write("\n".join(lines) + "\n")
print(len(items), "items:", ", ".join(i for i, _ in items))
