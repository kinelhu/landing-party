"""Kessler-Hayashi's jamming mast (scripts/jammer.lua: arcs that strike robots entering its radius), modelled and
rendered for Factorio: a slender lattice mast on a 2x2 footing, three emitter nodes at its crown with arcs jumping
between them, new each frame.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/jammer_mast.py -- <out_dir> [frames=16]
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/serenity/jammer
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES = int(args[1]) if len(args) > 1 else 16
scene = lpkit.reset()
# (Worn, as the guns: its first render, on the clean palette, read as a toy beside them; the user, 2026-11-03.)
P = lpkit.palette_worn()
H = 4.6                                   # mast height, tiles

# Footing: a pad, a squat base housing with panels and hazard trim.
lpkit.feet(1.9, P["dark"])
lpkit.box(1.1, 1.1, 0.5, 0, 0, 0.1, P["paint"])
lpkit.box(1.16, 1.16, 0.06, 0, 0, 0.6, P["steel"])
for k in range(4):
    a = k * math.pi / 2
    lpkit.box(0.4, 0.06, 0.25, math.cos(a) * 0.56, math.sin(a) * 0.56, 0.2, P["dark"], rot=a + math.pi / 2)
    lpkit.box(0.22, 0.22, 0.06, math.cos(a + math.pi / 4) * 0.82, math.sin(a + math.pi / 4) * 0.82, 0.1, P["dark"], rot=a)
    lpkit.box(0.18, 0.03, 0.04, math.cos(a + math.pi / 4) * 0.82, math.sin(a + math.pi / 4) * 0.82, 0.16, P["hazard"], rot=a)
# The lattice: three legs tapering to the crown, braced every 0.6 tiles.
legs = []
for k in range(3):
    a = k * 2 * math.pi / 3 + math.pi / 6
    legs.append((math.cos(a), math.sin(a)))
def leg_at(i, z):
    w = 0.42 - 0.3 * (z / H)
    return (legs[i][0] * w, legs[i][1] * w, z)
for i in range(3):
    lpkit.rod(leg_at(i, 0.65), leg_at(i, H), 0.035, P["steel"])
z = 0.65
while z < H - 0.3:
    for i in range(3):
        j = (i + 1) % 3
        lpkit.rod(leg_at(i, z), leg_at(j, z + 0.6), 0.016, P["steel"])
        lpkit.rod(leg_at(i, z), leg_at(j, z), 0.018, P["dark"])
    z += 0.6
# A cable run up one leg, an equipment box halfway.
lpkit.box(0.22, 0.18, 0.4, leg_at(0, 2.0)[0] * 1.4, leg_at(0, 2.0)[1] * 1.4, 1.8, P["paint"])
# The crown: a collar, three arms, three emitter nodes.
lpkit.cyl(0.2, 0.1, 0, 0, H, P["steel"], verts=16)
lpkit.torus(0.16, 0.035, 0, 0, H + 0.14, P["copper"])
nodes = []
for k in range(3):
    a = k * 2 * math.pi / 3 - math.pi / 2
    tip = (math.cos(a) * 0.45, math.sin(a) * 0.45, H + 0.25)
    lpkit.rod((0, 0, H + 0.08), tip, 0.025, P["steel"])
    lpkit.sphere(0.08, *tip, P["glow"])
    nodes.append(tip)
model = [o for o in scene.objects]
lpkit.bevel_all(model)
ground, sun, world = lpkit.stage(scene, 2, 3.0)

rng = random.Random(11)
arcs = []
import bpy
def set_frame(f):
    t = f / FRAMES
    lpkit.emission(P["glow"], 1.6 + 0.8 * math.sin(t * 2 * math.pi * 2))
    for o in arcs: bpy.data.objects.remove(o, do_unlink=True)
    arcs.clear()
    for _ in range(rng.choice((1, 2, 2, 3))):
        i, j = rng.sample(range(3), 2)
        arcs.append(lpkit.arc(nodes[i], nodes[j], P["glow"], rng, kinks=3, jitter=0.07))
    if rng.random() < 0.5:
        i = rng.randrange(3)
        down = (nodes[i][0] * 0.6, nodes[i][1] * 0.6, H - 0.35)
        arcs.append(lpkit.arc(nodes[i], down, P["glow"], rng, kinks=2, jitter=0.06))
lpkit.passes(scene, out, FRAMES, set_frame, model, {P["glow"]}, ground, sun, world)
print("rendered", out)
