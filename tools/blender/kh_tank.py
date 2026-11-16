"""Kessler-Hayashi's tank (the unit pass, 2026-11-08: Grubstake's done, its tank family next; the agreed brief: a clean,
angular corporate-military hull, slate teal and dull hazard, worn but maintained, a contractor's kit against Grubstake's
scrap). One hull, the heads as modules on it, as the buggies share their chassis: the cannon turret first (lp-tank), the
Prism, Tesla and Aegis heads to follow. The hull: a sloped, faceted upper hull over the tracks, side skirts in panels
down over the top run, a beak glacis, a sensor mast and an IR lamp, smoke dischargers, stowage bins at the back, the
engine deck's grilles, tow cables; cyan running lights (its colour). The tracks an animated layer (vehicle.tracks).

    /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/kh_tank.py -- <out_dir> [N=64]
    then one sheet.py run a part: out/base, out/anim, out/<module>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import vehicle as V
from vehicle import M, box, rod, cyl, axle_cyl, bolt

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
N = int(args[1]) if len(args) > 1 else 64
V.setup()
V.kh_palette()

# Forward along +y. About vanilla's tank, 1.8 by 2.7.
# (A wide flat slab with a small turret, the second pass: narrower, taller, the turret bigger and central.)
TX, TW = 0.62, 0.34
IDL, SPR = (1.0, 0.24, 0.16), (-1.06, 0.26, 0.19)
ROAD = [(-0.76 + k * 0.3, 0.13, 0.12) for k in range(6)]
ZD = 0.62                                # the hull's deck

def hull():
    for sx in (-1, 1):
        x = sx * TX
        box(0.1, IDL[0] - SPR[0] - 0.1, 0.1, x, (IDL[0] + SPR[0]) / 2, 0.18, M["kdark"], bevel=0.01)
        for y, z, r in ROAD:
            axle_cyl(r, TW * 0.7, x, y, z, M["kdark"], bevel=0.012)
            axle_cyl(r * 0.5, TW * 0.72, x, y, z, M["steel"])
        for y, z, r in (IDL, SPR):
            axle_cyl(r, TW * 0.6, x, y, z, M["kdark"], bevel=0.012)
            axle_cyl(r * 0.45, TW * 0.62, x, y, z, M["steel"])
    # The lower hull between the tracks, and the upper hull over them: faceted, its sides sloping in to the deck.
    box(2 * TX - TW - 0.04, 2.0, 0.26, 0, 0.0, 0.16, M["kdark"], bevel=0.02)
    W0, W1, Y0, Y1 = 2 * TX + TW + 0.06, 1.28, -1.14, 0.86
    up = lambda pts: V.panel(pts, M["kpaint"], t=0.04, bevel=0.012)
    for sx in (-1, 1):
        up([(sx * W0 / 2, Y0 + 0.04, 0.42), (sx * W0 / 2, Y1, 0.42), (sx * W1 / 2, Y1 - 0.06, ZD), (sx * W1 / 2, Y0 + 0.1, ZD)])
    up([(-W1 / 2, Y0 + 0.1, ZD), (W1 / 2, Y0 + 0.1, ZD), (W1 / 2, Y1 - 0.06, ZD), (-W1 / 2, Y1 - 0.06, ZD)])     # deck
    up([(-W0 / 2, Y0 + 0.04, 0.42), (W0 / 2, Y0 + 0.04, 0.42), (W1 / 2, Y0 + 0.1, ZD), (-W1 / 2, Y0 + 0.1, ZD)])  # rear slope
    # The beak glacis: an upper plate down from the deck to a ridge, a lower one back under, the cheeks.
    YR, ZR = 1.22, 0.3
    upper = [(-W1 / 2, Y1 - 0.06, ZD), (W1 / 2, Y1 - 0.06, ZD), (W0 / 2 - 0.04, YR, ZR), (-W0 / 2 + 0.04, YR, ZR)]
    lower = [(-W0 / 2 + 0.04, YR, ZR), (W0 / 2 - 0.04, YR, ZR), (W0 / 2 - 0.1, 0.92, 0.08), (-W0 / 2 + 0.1, 0.92, 0.08)]
    V.panel(upper, M["kpaint"], t=0.05, bevel=0.012); V.panel(lower, M["kpaint2"], t=0.05, bevel=0.012)
    for sx in (-1, 1):
        V.panel([(sx * W0 / 2, Y1, 0.42), (sx * W1 / 2, Y1 - 0.06, ZD), (sx * (W0 / 2 - 0.04), YR, ZR)], M["kpaint"], t=0.04)
    rod((-W0 / 2 + 0.04, YR, ZR), (W0 / 2 - 0.04, YR, ZR), 0.025, M["kpaint2"])
    # Large smooth slabs and a few recessed panel lines, not tiles (tiled plates with bolt rows "look toy like", the user):
    # a second shade on a few big panels, the seams between them grooves.
    for x, y, w, h, m in ((-0.33, 0.25, 0.56, 0.95, M["kpaint3"]), (0.34, -0.2, 0.52, 0.6, M["kpaint2"])):
        box(w, h, 0.012, x, y, ZD + 0.04, m, bevel=0.006)
    for y in (-0.5, 0.52):
        box(W1 - 0.1, 0.014, 0.006, 0, y, ZD + 0.043, M["kdark"], bevel=0.0)
    for sx in (-1, 1):
        box(0.012, 1.8, 0.006, sx * 0.2, -0.12, ZD + 0.043, M["kdark"], bevel=0.0)
    # The engine deck raised at the back: a louvred box, its fans under grilles, exhausts out to each side.
    box(1.0, 0.62, 0.08, 0, -0.78, ZD + 0.03, M["kpaint2"], bevel=0.02)
    for sx in (-1, 1):
        cyl(0.17, 0.03, sx * 0.24, -0.8, ZD + 0.11, M["kdark"], bevel=0.006)
        for k in range(7):
            box(0.32, 0.014, 0.012, sx * 0.24, -0.92 + k * 0.04, ZD + 0.145, M["steel"], bevel=0.0)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.05, depth=0.14, location=(sx * 0.72, -0.92, 0.5), rotation=(0, math.pi / 2, 0))
        V.obj().data.materials.append(M["heat"])
    # Side skirts: panels hung over the top run, their lower edge a line of bolts, the front panel cut away.
    for sx in (-1, 1):
        for k in range(3):
            y = -0.78 + k * 0.64
            box(0.035, 0.62, 0.2, sx * (W0 / 2 + 0.01), y, 0.26, M["kgraph"], bevel=0.012)
            box(0.02, 0.6, 0.07, sx * (W0 / 2 + 0.015), y, 0.2, M["rubber"], bevel=0.004)          # rubber flaps
        rod((sx * (W0 / 2 + 0.02), -1.1, 0.46), (sx * (W0 / 2 + 0.02), 0.94, 0.46), 0.012, M["kdark"])
    # Hazard chevrons on the glacis' corners, the engine deck's grilles, stowage bins, tow cables, lights.
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (W0 / 2 - 0.14 - k * 0.06)
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 1.0, 0.47), rotation=(math.radians(35), 0, sx * 0.6))
            o = V.obj(); o.scale = (0.03, 0.16, 0.006); o.data.materials.append(M["khazard"])
    for sx in (-1, 1):
        box(0.26, 0.2, 0.14, sx * 0.48, -1.12, 0.46, M["kpaint2"], bevel=0.015)               # stowage bins
        box(0.24, 0.02, 0.1, sx * 0.48, -1.225, 0.48, M["kdark"], bevel=0.004)
        for k in range(10):                                                                     # a tow cable, coiled
            a = k * 0.6
            rod((sx * 0.62, -0.6 + k * 0.08, 0.47), (sx * 0.62, -0.56 + k * 0.08, 0.47), 0.014, M["steel"])
        cyl(0.03, 0.01, sx * 0.62, 1.12, 0.38, M["kglow"], rot=(math.pi / 2 - 0.9, 0, 0))     # running lights
        box(0.06, 0.012, 0.02, sx * 0.62, -1.165, 0.44, M["tail"], bevel=0.002)
    # Functional detail (plain slabs read "too plain", the user): the driver's hatch and periscopes on the glacis, headlamp
    # clusters in guards, tow hooks, grab rails, a tool rack (shovel, pick, bar), jerrycans, antenna bases, sensor boxes;
    # white corporate markings and hazard stripes. Colour from function: graphite, rubber, bright metal, wood, canvas.
    cyl(0.12, 0.025, 0.32, 0.72, ZD + 0.02, M["kgraph"], bevel=0.008)
    for k in range(3):
        box(0.06, 0.03, 0.035, 0.24 + k * 0.08, 0.86, ZD + 0.03, M["glass"], rot=0.0, bevel=0.004)
    for sx in (-1, 1):
        x = sx * (W0 / 2 - 0.16)
        box(0.18, 0.08, 0.08, x, 1.08, 0.44, M["kgraph"], bevel=0.01)
        for dx in (-0.045, 0.045):
            cyl(0.028, 0.006, x + dx, 1.125, 0.445, M["lamp"], rot=(math.pi / 2, 0, 0))
        for dx in (-0.08, 0.0, 0.08):
            rod((x + dx, 1.135, 0.4), (x + dx, 1.135, 0.49), 0.005, M["steel"])
        bpy.ops.mesh.primitive_torus_add(major_radius=0.04, minor_radius=0.013, location=(sx * 0.4, 1.2, 0.2), rotation=(0, math.pi / 2, 0),
                                         major_segments=24, minor_segments=8)
        V.obj().data.materials.append(M["kgraph"])
        rod((sx * 0.52, 0.5, ZD + 0.05), (sx * 0.52, 0.0, ZD + 0.05), 0.01, M["bright"])            # grab rails
    # The tool rack along the left deck edge: a shovel, a pick, a pry bar, in clamps.
    for k, (L, m) in enumerate(((0.62, M["kwood"]), (0.56, M["kwood"]), (0.7, M["steel"]))):
        rod((-0.55 + k * 0.035, 0.42, ZD + 0.05), (-0.55 + k * 0.035, 0.42 - L, ZD + 0.05), 0.012, m)
    box(0.07, 0.12, 0.02, -0.55, 0.47, ZD + 0.04, M["steel"], bevel=0.004)
    box(0.12, 0.05, 0.02, -0.517, -0.18, ZD + 0.04, M["bright"], bevel=0.004)
    for y in (0.3, -0.05):
        box(0.14, 0.03, 0.03, -0.52, y, ZD + 0.045, M["kgraph"], bevel=0.004)
    # Jerrycans on the right rear in a cradle, a white stencil (a corporate code) on the glacis, hazard stripes on the bins.
    for k in range(2):
        box(0.08, 0.16, 0.2, 0.56 - k * 0.1, -0.5, ZD + 0.02, M["kgraph"], bevel=0.015)
    for k, w in enumerate((0.1, 0.05, 0.12, 0.08)):
        x = -0.36 + sum((0.1, 0.05, 0.12, 0.08)[:k]) + k * 0.03
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x + w / 2, 1.0, 0.46), rotation=(math.radians(35), 0, 0))
        o = V.obj(); o.scale = (w, 0.06, 0.004); o.data.materials.append(M["kwhite"])
    for sx in (-1, 1):
        for k in range(4):
            box(0.03, 0.006, 0.12, sx * 0.48 - 0.09 + k * 0.06, -1.23, 0.48, M["khazard"], bevel=0.0)
        box(0.06, 0.06, 0.04, sx * 0.3, 0.2, ZD + 0.04, M["kgraph"], bevel=0.008)                   # antenna bases
    box(0.12, 0.08, 0.07, 0.4, -0.25, ZD + 0.04, M["kgraph"], bevel=0.012)                           # a sensor box
    cyl(0.02, 0.006, 0.4, -0.2, ZD + 0.11, M["kglow"])
    # Smoke dischargers on the rear corners, a sensor mast and its IR lamp at the left rear.
    for sx in (-1, 1):
        for k in range(3):
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.028, depth=0.12, location=(sx * (0.6 - k * 0.06), -0.84, ZD + 0.1),
                                                rotation=(math.radians(-40), 0, sx * 0.5))
            V.obj().data.materials.append(M["kdark"])
    rod((-0.55, -0.7, ZD + 0.04), (-0.55, -0.7, ZD + 0.75), 0.016, M["steel"])
    box(0.08, 0.05, 0.05, -0.55, -0.7, ZD + 0.75, M["kdark"], bevel=0.008)
    cyl(0.016, 0.008, -0.55, -0.67, ZD + 0.78, M["kglow"], rot=(math.pi / 2, 0, 0))
    rod((-0.55, -0.7, ZD + 0.79), (-0.6, -0.76, ZD + 1.25), 0.006, M["bright"])

def cannon():
    """The tank's own head (lp-tank): a low faceted turret, its front sloped, a long gun with a muzzle brake and an
    evacuator, a commander's cupola with vision blocks, a sight box, a hatch, an ammo bustle at its back."""
    TZ, TY = ZD + 0.04, 0.0
    k_ = 1.25
    pts = [(x * k_, y * k_) for x, y in ((-0.4, 0.4), (0.4, 0.4), (0.55, 0.05), (0.52, -0.42), (-0.52, -0.42), (-0.55, 0.05))]
    top = [(x * k_, y * k_) for x, y in ((-0.26, 0.24), (0.26, 0.24), (0.4, 0.02), (0.38, -0.34), (-0.38, -0.34), (-0.4, 0.02))]
    H = 0.34
    import bmesh
    me = bpy.data.meshes.new("turret"); bm = bmesh.new()
    lo = [bm.verts.new((x, TY + y, TZ)) for x, y in pts]; hi = [bm.verts.new((x, TY + y, TZ + H)) for x, y in top]
    bm.faces.new(lo[::-1]); bm.faces.new(hi)
    for k in range(len(pts)):
        bm.faces.new((lo[k], lo[(k + 1) % len(pts)], hi[(k + 1) % len(pts)], hi[k]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("turret", me); V.scene.collection.objects.link(o); me.materials.append(M["kpaint"])
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.015; md.segments = 2
    cyl(0.5, 0.03, 0, TY, TZ - 0.02, M["kdark"])                                                 # turret ring
    box(0.8, 0.28, 0.2, 0, TY - 0.62, TZ + 0.04, M["kpaint2"], bevel=0.025)                       # bustle
    # The gun: mantlet, barrel, evacuator, muzzle brake.
    # (Long and thin, the gun was lost at game scale: thicker, a thermal sleeve in segments with clamps, shorter.)
    box(0.3, 0.14, 0.22, 0, TY + 0.54, TZ + 0.06, M["kgraph"], bevel=0.025)
    # (A little longer, the user: "Maybe very slightly longer barrel?": +0.18.)
    rod((0, TY + 0.6, TZ + 0.17), (0, TY + 1.68, TZ + 0.19), 0.055, M["kpaint"])
    for k in range(3):
        y = TY + 0.72 + k * 0.24
        rod((0, y, TZ + 0.17 + k * 0.005), (0, y + 0.04, TZ + 0.172 + k * 0.005), 0.065, M["kdark"])
    rod((0, TY + 1.12, TZ + 0.18), (0, TY + 1.24, TZ + 0.182), 0.072, M["kpaint2"])
    # (A muzzle brake on it read "a little too stubby", the user: a modern gun's clean end instead, the barrel running to a
    # thin collar, a reference sensor over it.)
    rod((0, TY + 1.66, TZ + 0.19), (0, TY + 1.8, TZ + 0.192), 0.05, M["kpaint"])
    rod((0, TY + 1.78, TZ + 0.192), (0, TY + 1.82, TZ + 0.192), 0.058, M["kgraph"])
    box(0.03, 0.05, 0.03, 0, TY + 1.76, TZ + 0.25, M["kgraph"], bevel=0.004)
    # Cupola, vision blocks, sight box, hatch, a coaxial gun, its own lights, a hazard band round the bustle.
    cyl(0.13, 0.09, 0.2, TY - 0.14, TZ + H, M["kpaint2"], bevel=0.012)
    for k in range(6):
        a = k * math.pi / 3
        box(0.05, 0.03, 0.035, 0.2 + math.cos(a) * 0.125, TY - 0.14 + math.sin(a) * 0.125, TZ + H + 0.04, M["glass"], rot=a + math.pi / 2, bevel=0.004)
    box(0.12, 0.14, 0.1, -0.26, TY + 0.12, TZ + H, M["kdark"], bevel=0.012)
    box(0.08, 0.02, 0.05, -0.26, TY + 0.2, TZ + H + 0.03, M["glass"], bevel=0.004)
    cyl(0.1, 0.03, -0.18, TY - 0.24, TZ + H, M["kpaint"], bevel=0.008)
    rod((0.16, TY + 0.46, TZ + 0.12), (0.16, TY + 0.66, TZ + 0.12), 0.012, M["kdark"])
    box(0.82, 0.02, 0.03, 0, TY - 0.765, TZ + 0.2, M["khazard"], bevel=0.003)
    cyl(0.022, 0.006, 0.36, TY + 0.2, TZ + H + 0.004, M["kglow"])
    # Side armour on the turret's cheeks, stowage on its bustle, a sensor dome (round forms, the light's highlights).
    # The roof in graphite, a remote weapon station on it (a small gun and its sensor head), smoke launchers on the cheeks,
    # laser warning receivers, a white corporate panel on the bustle.
    box(0.62, 0.56, 0.02, 0, TY - 0.1, TZ + H, M["kgraph"], bevel=0.008)
    cyl(0.08, 0.06, -0.24, TY - 0.36, TZ + H + 0.02, M["kgraph"], bevel=0.008)
    box(0.12, 0.16, 0.09, -0.24, TY - 0.33, TZ + H + 0.08, M["kgraph"], bevel=0.015)
    box(0.07, 0.03, 0.05, -0.24, TY - 0.24, TZ + H + 0.1, M["glass"], bevel=0.005)
    rod((-0.17, TY - 0.3, TZ + H + 0.12), (-0.17, TY + 0.12, TZ + H + 0.12), 0.014, M["kdark"])
    for sx in (-1, 1):
        for k in range(4):
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.024, depth=0.1, location=(sx * (0.5 - k * 0.045), TY + 0.18, TZ + H - 0.04),
                                                rotation=(math.radians(-50), 0, sx * 0.4))
            V.obj().data.materials.append(M["kgraph"])
        box(0.05, 0.04, 0.03, sx * 0.44, TY - 0.42, TZ + H + 0.02, M["kdark"], bevel=0.005)
        cyl(0.012, 0.004, sx * 0.44, TY - 0.4, TZ + H + 0.045, M["kglow"])
    box(0.3, 0.006, 0.1, 0.12, TY - 0.765, TZ + 0.1, M["kwhite"], bevel=0.0)
    # Wedge armour on its front cheeks, angled out and forward, the modern tank's mark.
    for sx in (-1, 1):
        V.panel([(sx * 0.18, TY + 0.5, TZ + 0.02), (sx * 0.72, TY + 0.1, TZ + 0.02), (sx * 0.6, TY + 0.06, TZ + H - 0.02),
                 (sx * 0.17, TY + 0.36, TZ + H - 0.02)], M["kpaint3"], t=0.06, bevel=0.015)
        V.panel([(sx * 0.72, TY + 0.1, TZ + 0.02), (sx * 0.68, TY - 0.4, TZ + 0.02), (sx * 0.54, TY - 0.4, TZ + H - 0.02),
                 (sx * 0.6, TY + 0.06, TZ + H - 0.02)], M["kpaint"], t=0.04, bevel=0.012)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(-0.1, TY - 0.3, TZ + H + 0.04), segments=32, ring_count=16)
    o = V.obj(); o.scale = (1, 1, 0.6); o.data.materials.append(M["kwhite"])
    for k in range(2):
        box(0.28, 0.14, 0.1, -0.2 + k * 0.38, TY - 0.72, TZ + 0.24, M["canvas"], bevel=0.025)

def turret_body(TY, TZ, H):
    """The faceted turret shell (the cannon's), its ring, graphite roof, cupola and sights: the heads share it."""
    k_ = 1.25
    pts = [(x * k_, y * k_) for x, y in ((-0.4, 0.4), (0.4, 0.4), (0.55, 0.05), (0.52, -0.42), (-0.52, -0.42), (-0.55, 0.05))]
    top = [(x * k_, y * k_) for x, y in ((-0.26, 0.24), (0.26, 0.24), (0.4, 0.02), (0.38, -0.34), (-0.38, -0.34), (-0.4, 0.02))]
    import bmesh
    me = bpy.data.meshes.new("turret"); bm = bmesh.new()
    lo = [bm.verts.new((x, TY + y, TZ)) for x, y in pts]; hi = [bm.verts.new((x, TY + y, TZ + H)) for x, y in top]
    bm.faces.new(lo[::-1]); bm.faces.new(hi)
    for k in range(len(pts)):
        bm.faces.new((lo[k], lo[(k + 1) % len(pts)], hi[(k + 1) % len(pts)], hi[k]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("turret", me); V.scene.collection.objects.link(o); me.materials.append(M["kpaint"])
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.015; md.segments = 2
    cyl(0.5, 0.03, 0, TY, TZ - 0.02, M["kdark"])
    box(0.62, 0.56, 0.02, 0, TY - 0.1, TZ + H, M["kgraph"], bevel=0.008)
    cyl(0.13, 0.09, 0.2, TY - 0.14, TZ + H, M["kpaint2"], bevel=0.012)
    for k in range(6):
        a = k * math.pi / 3
        box(0.05, 0.03, 0.035, 0.2 + math.cos(a) * 0.125, TY - 0.14 + math.sin(a) * 0.125, TZ + H + 0.04, M["glass"], rot=a + math.pi / 2, bevel=0.004)
    box(0.12, 0.14, 0.1, -0.26, TY + 0.12, TZ + H, M["kdark"], bevel=0.012)
    box(0.08, 0.02, 0.05, -0.26, TY + 0.2, TZ + H + 0.03, M["glass"], bevel=0.004)

def prism():
    """The Prism (Kessler-Hayashi's Optics, a laser that splits to the ones round its target), after the genre's prism tank
    (the user, 2026-11-08: "take some inspiration from the prism tank in C&C RA2? To avoid having such similar designs";
    a turret with an emitter in its mantlet read as the cannon tank again): no turret, a raised tower carrying the crystal.
    A squat armoured plinth on the ring, capacitor banks on its flanks; a tapered four-sided pylon in graphite and teal,
    conduits up its edges; at its top a cluster of faceted violet crystals (its beam's colour, lp-prism-split) in a cage of
    claws, its core lit. Kept to about a tile over the deck (the flak's turret floated a tile up on screen)."""
    import bmesh
    TZ = ZD + 0.04
    def frustum(w0, d0, w1, d1, z0, z1, y, m):
        me = bpy.data.meshes.new("frustum"); bm = bmesh.new()
        lo = [bm.verts.new(v) for v in ((-w0, y - d0, z0), (w0, y - d0, z0), (w0, y + d0, z0), (-w0, y + d0, z0))]
        hi = [bm.verts.new(v) for v in ((-w1, y - d1, z1), (w1, y - d1, z1), (w1, y + d1, z1), (-w1, y + d1, z1))]
        bm.faces.new(lo[::-1]); bm.faces.new(hi)
        for k in range(4):
            bm.faces.new((lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]))
        bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new("frustum", me); V.scene.collection.objects.link(o); me.materials.append(m)
        md = o.modifiers.new("b", "BEVEL"); md.width = 0.012; md.segments = 2
        return o
    cyl(0.5, 0.03, 0, -0.05, TZ - 0.02, M["kdark"])
    frustum(0.46, 0.5, 0.34, 0.38, TZ, TZ + 0.18, -0.05, M["kpaint"])                              # the plinth
    box(0.6, 0.6, 0.02, 0, -0.05, TZ + 0.18, M["kgraph"], bevel=0.008)
    for sx in (-1, 1):                                                                           # capacitor banks
        box(0.12, 0.56, 0.16, sx * 0.48, -0.05, TZ + 0.02, M["kgraph"], bevel=0.02)
        for k in range(4):
            cyl(0.028, 0.02, sx * 0.48, -0.26 + k * 0.14, TZ + 0.18, M["kdark"], bevel=0.004)
            cyl(0.012, 0.004, sx * 0.48, -0.26 + k * 0.14, TZ + 0.2, M["kglow"])
    # The pylon, leaning a little forward, its faces two shades, conduits up its edges, a hazard band at its foot.
    P0, P1 = TZ + 0.2, TZ + 0.86
    frustum(0.2, 0.2, 0.09, 0.09, P0, P1, -0.05, M["kpaint2"])
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod((sx * 0.19, -0.05 + sy * 0.19, P0), (sx * 0.085, -0.05 + sy * 0.085, P1), 0.014, M["kdark"])
    box(0.42, 0.42, 0.03, 0, -0.05, P0 + 0.01, M["khazard"], bevel=0.004)
    for k in range(3):                                                                          # cooling fins round it
        z = P0 + 0.14 + k * 0.14; w = 0.2 - (z - P0) * 0.17
        box(w * 2 + 0.08, w * 2 + 0.08, 0.012, 0, -0.05, z, M["steel"], bevel=0.003)
    box(0.24, 0.24, 0.05, 0, -0.05, P1, M["kgraph"], bevel=0.01)                               # the crystal's seat
    # The crystals: a big one upright, three smaller leaning out round it, a lit core; claws round them.
    def crystal(x, y, z, r, tilt, spin):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=0, depth=r * 3.2, location=(x, y, z + r * 1.6),
                                        rotation=(tilt * math.cos(spin), tilt * math.sin(spin), spin))
        V.obj().data.materials.append(M["kcrystal"])
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=0, depth=r * 1.2, location=(x, y, z - r * 0.4),
                                        rotation=(math.pi + tilt * math.cos(spin), tilt * math.sin(spin), spin))
        V.obj().data.materials.append(M["kcrystal"])
    crystal(0, -0.05, P1 + 0.1, 0.11, 0.0, 0.3)
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.5
        crystal(math.cos(a) * 0.1, -0.05 + math.sin(a) * 0.1, P1 + 0.07, 0.055, 0.45, a)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.05, location=(0, -0.05, P1 + 0.2))
    V.obj().data.materials.append(M["kviolet"])
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        rod((math.cos(a) * 0.12, -0.05 + math.sin(a) * 0.12, P1 + 0.04), (math.cos(a) * 0.16, -0.05 + math.sin(a) * 0.16, P1 + 0.3),
            0.012, M["steel"])
    # A sensor on the plinth's front, white corporate panel on its back.
    box(0.14, 0.08, 0.08, 0, 0.36, TZ + 0.1, M["kgraph"], bevel=0.012)
    box(0.08, 0.02, 0.05, 0, 0.405, TZ + 0.12, M["glass"], bevel=0.004)
    box(0.3, 0.006, 0.08, 0.1, -0.56, TZ + 0.09, M["kwhite"], bevel=0.0)

def tesla():
    """The Tesla (Kessler-Hayashi's Siege: chain lightning that drains what it strikes), after the genre's tesla tank as
    the Prism after its prism tank: no gun, two coils on a low turret. Each coil a tower of copper windings on a ceramic
    stack of insulators, a toroid at its top glowing cyan (Kessler-Hayashi's colour); between their tops an arc; the
    turret's capacitor drums and cable runs, a hazard band, the cupola. Kept low, about a tile over the deck."""
    import random
    rnd = random.Random(17)
    TZ, TY, H = ZD + 0.04, 0.0, 0.22
    turret_body(TY, TZ, H)
    top = TZ + H
    # (Thin, they read as two smokestacks with white blobs, the first: fat conical coils, big dark toroids, a thin lit
    # ring under each, the glow low enough to stay cyan.)
    COIL = 1.2                     # (a little small at game scale, the Prism's crystal's size: a fifth larger, the user's go)
    for sx in (-1, 1):
        x, y = sx * 0.38, TY + 0.06          # (at 0.28 they merged into one stack facing north or south)
        _b4 = set(V.scene.objects)
        cyl(0.16, 0.05, x, y, top, M["kgraph"], bevel=0.012)                                     # its foot
        for k in range(3):                                                                       # insulators
            cyl(0.11 if k % 2 else 0.09, 0.045, x, y, top + 0.05 + k * 0.045, M["kwhite"], bevel=0.012)
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.13, radius2=0.07, depth=0.32, location=(x, y, top + 0.35))
        V.obj().data.materials.append(M["copper"])                                               # the winding's cone
        # (Twelve dark rings hid the copper, the second: four bands, the windings showing between.)
        for k in range(4):
            z = top + 0.22 + k * 0.08; r = 0.13 - (z - top - 0.19) * 0.19
            bpy.ops.mesh.primitive_torus_add(major_radius=r + 0.004, minor_radius=0.008, location=(x, y, z), major_segments=40, minor_segments=6)
            V.obj().data.materials.append(M["kgraph"])
        # Its top a crown (the shiny grey toroid and cap read badly, the user: "not a fan of the top of the Tesla coils"):
        # a graphite collar, six prongs curling up and in round a small cyan orb, the discharge's.
        cyl(0.085, 0.04, x, y, top + 0.5, M["kgraph"], bevel=0.01)
        for k in range(6):
            a = k * math.pi / 3
            p0 = (x + math.cos(a) * 0.07, y + math.sin(a) * 0.07, top + 0.54)
            p1 = (x + math.cos(a) * 0.1, y + math.sin(a) * 0.1, top + 0.62)
            p2 = (x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, top + 0.7)
            rod(p0, p1, 0.011, M["kgraph"]); rod(p1, p2, 0.009, M["kgraph"])
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(x, y, top + 0.62), segments=24, ring_count=12)
        V.obj().data.materials.append(M["kglow_soft"])
        for o in set(V.scene.objects) - _b4:                                                     # the coil scaled at its foot
            o.location = mathutils.Vector((x, y, top)) + (o.location - mathutils.Vector((x, y, top))) * COIL
            o.scale = o.scale * COIL
    import lpkit
    for k in range(2):
        lpkit.arc((-0.34, TY + 0.06, TZ + H + 0.75), (0.34, TY + 0.06, TZ + H + 0.75 + 0.02 * k), M["kglow_soft"], rnd, kinks=7, jitter=0.07, r=0.007)
    # Capacitor drums on the turret's back, cables to the coils' feet.
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.09, depth=0.3, location=(sx * 0.22, TY - 0.48, TZ + 0.14), rotation=(0, math.pi / 2, 0))
        V.obj().data.materials.append(M["kgraph"])
        for dx in (-0.1, 0.1):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.092, minor_radius=0.008, location=(sx * 0.22 + dx, TY - 0.48, TZ + 0.14),
                                             rotation=(0, math.pi / 2, 0), major_segments=32, minor_segments=6)
            V.obj().data.materials.append(M["khazard"])
        rod((sx * 0.22, TY - 0.4, TZ + 0.22), (sx * 0.36, TY + 0.02, top + 0.02), 0.018, M["rubber"])
    box(0.82, 0.02, 0.03, 0, TY - 0.6, TZ + 0.06, M["khazard"], bevel=0.003)
    box(0.3, 0.006, 0.08, 0.1, TY - 0.6, TZ + 0.12, M["kwhite"], bevel=0.0)

def aegis():
    """The Aegis (Kessler-Hayashi's heavy tank: a rail cannon, one slug no armour resists, its answer to armour): the
    heaviest gun on the field and none of the cannon's round barrel. A big flat-sided turret, a heavy wedge front; the
    rail cannon two flat rails with a gap between them, magnet collars along them, a cyan glow in the gap, a heavy breech;
    capacitor banks on the turret's back, cables to the breech."""
    import bmesh
    TZ, TY, H = ZD + 0.04, -0.05, 0.36
    pts = [(-0.5, 0.56), (0.5, 0.56), (0.7, 0.1), (0.66, -0.56), (-0.66, -0.56), (-0.7, 0.1)]
    top = [(-0.34, 0.36), (0.34, 0.36), (0.52, 0.06), (0.5, -0.44), (-0.5, -0.44), (-0.52, 0.06)]
    me = bpy.data.meshes.new("aegis"); bm = bmesh.new()
    lo = [bm.verts.new((x, TY + y, TZ)) for x, y in pts]; hi = [bm.verts.new((x, TY + y, TZ + H)) for x, y in top]
    bm.faces.new(lo[::-1]); bm.faces.new(hi)
    for k in range(len(pts)):
        bm.faces.new((lo[k], lo[(k + 1) % len(pts)], hi[(k + 1) % len(pts)], hi[k]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("aegis", me); V.scene.collection.objects.link(o); me.materials.append(M["kpaint"])
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.018; md.segments = 2
    cyl(0.56, 0.03, 0, TY, TZ - 0.02, M["kdark"])
    box(0.8, 0.64, 0.02, 0, TY - 0.05, TZ + H, M["kgraph"], bevel=0.008)
    # The wedge front: two thick plates angled forward to a point under the gun.
    for sx in (-1, 1):
        V.panel([(sx * 0.12, TY + 0.72, TZ + 0.02), (sx * 0.74, TY + 0.14, TZ + 0.02), (sx * 0.56, TY + 0.1, TZ + H - 0.03),
                 (sx * 0.12, TY + 0.5, TZ + H - 0.03)], M["kpaint3"], t=0.07, bevel=0.015)
    # Twin rail cannons (the user, 2026-11-08: "what do you think about doubling the cannon?", the heavy tank's read): a
    # wide breech block, two guns side by side, each two rails with its own glowing gap; magnet frames across both (one
    # weapon, not two lasers); the muzzles in one frame. A fifth shorter than the first single gun.
    box(0.56, 0.34, 0.26, 0, TY + 0.48, TZ + 0.08, M["kgraph"], bevel=0.03)
    GZ = TZ + 0.2
    for gx in (-0.15, 0.15):
        for sx in (-1, 1):
            box(0.045, 1.04, 0.1, gx + sx * 0.055, TY + 1.07, GZ, M["kpaint2"], bevel=0.01)
            box(0.018, 1.0, 0.05, gx + sx * 0.034, TY + 1.07, GZ + 0.025, M["steel"], bevel=0.004)
        box(0.034, 0.98, 0.03, gx, TY + 1.07, GZ + 0.035, M["kglow_soft"], bevel=0.0)
    for k in range(4):
        y = TY + 0.72 + k * 0.22
        for sx in (-1, 1):                                                                       # frames' outer posts
            box(0.07, 0.07, 0.17, sx * 0.25, y, GZ - 0.035, M["kgraph"], bevel=0.012)
        box(0.1, 0.07, 0.17, 0, y, GZ - 0.035, M["kgraph"], bevel=0.012)                        # its middle post
        for gx in (-0.15, 0.15):                                                                 # bridges under each gap
            box(0.2, 0.07, 0.03, gx, y, GZ - 0.06, M["kgraph"], bevel=0.006)
        for sx in (-1, 1):
            box(0.03, 0.06, 0.02, sx * 0.25, y, GZ + 0.135, M["copper"], bevel=0.003)
    box(0.58, 0.06, 0.18, 0, TY + 1.6, GZ - 0.04, M["kgraph"], bevel=0.015)                      # muzzle frame
    # Capacitors on the back, cables, the commander's cupola and sights.
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.1, depth=0.42, location=(sx * 0.3, TY - 0.66, TZ + 0.14), rotation=(0, math.pi / 2, 0))
        V.obj().data.materials.append(M["kgraph"])
        for dx in (-0.16, 0.0, 0.16):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.102, minor_radius=0.008, location=(sx * 0.3 + dx, TY - 0.66, TZ + 0.14),
                                             rotation=(0, math.pi / 2, 0), major_segments=32, minor_segments=6)
            V.obj().data.materials.append(M["khazard"] if dx == 0 else M["steel"])
        rod((sx * 0.3, TY - 0.56, TZ + 0.24), (sx * 0.2, TY + 0.36, TZ + 0.3), 0.022, M["rubber"])
    cyl(0.14, 0.09, 0.26, TY - 0.2, TZ + H, M["kpaint2"], bevel=0.012)
    for k in range(6):
        a = k * math.pi / 3
        box(0.05, 0.03, 0.035, 0.26 + math.cos(a) * 0.135, TY - 0.2 + math.sin(a) * 0.135, TZ + H + 0.04, M["glass"], rot=a + math.pi / 2, bevel=0.004)
    box(0.14, 0.16, 0.11, -0.3, TY + 0.14, TZ + H, M["kdark"], bevel=0.012)
    box(0.09, 0.02, 0.05, -0.3, TY + 0.23, TZ + H + 0.035, M["glass"], bevel=0.004)
    box(0.36, 0.006, 0.1, 0.0, TY - 0.57, TZ + 0.24, M["kwhite"], bevel=0.0)
    cyl(0.022, 0.006, 0.44, TY + 0.2, TZ + H + 0.004, M["kglow"])
    # Its roof dressed as the cannon tank's (plain, it was the family's plainest part): a remote weapon station, smoke
    # launchers on the cheeks, laser warning receivers, a hatch, a stowage basket, panel lines.
    cyl(0.08, 0.06, -0.12, TY - 0.32, TZ + H + 0.02, M["kgraph"], bevel=0.008)
    box(0.12, 0.16, 0.09, -0.12, TY - 0.29, TZ + H + 0.08, M["kgraph"], bevel=0.015)
    box(0.07, 0.03, 0.05, -0.12, TY - 0.2, TZ + H + 0.1, M["glass"], bevel=0.005)
    rod((-0.05, TY - 0.26, TZ + H + 0.12), (-0.05, TY + 0.16, TZ + H + 0.12), 0.014, M["kdark"])
    for sx in (-1, 1):
        for k in range(4):
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.024, depth=0.1, location=(sx * (0.58 - k * 0.045), TY + 0.16, TZ + H - 0.04),
                                                rotation=(math.radians(-50), 0, sx * 0.4))
            V.obj().data.materials.append(M["kgraph"])
        box(0.05, 0.04, 0.03, sx * 0.5, TY - 0.4, TZ + H + 0.02, M["kdark"], bevel=0.005)
        cyl(0.012, 0.004, sx * 0.5, TY - 0.38, TZ + H + 0.045, M["kglow"])
    cyl(0.1, 0.03, 0.04, TY + 0.1, TZ + H, M["kpaint"], bevel=0.008)
    for y in (TY - 0.05, TY + 0.25):
        box(0.7, 0.012, 0.006, 0, y, TZ + H + 0.012, M["kdark"], bevel=0.0)
    for k in range(5):                                                                          # stowage basket rails
        rod((-0.4 + k * 0.2, TY - 0.82, TZ + 0.3), (-0.4 + k * 0.2, TY - 0.82, TZ + 0.42), 0.008, M["steel"])
    rod((-0.42, TY - 0.82, TZ + 0.42), (0.42, TY - 0.82, TZ + 0.42), 0.01, M["steel"])
    box(0.6, 0.1, 0.08, 0, TY - 0.86, TZ + 0.32, M["canvas"], bevel=0.02)

def beacon(x, y, z, mast=0.0):
    """The convoy beacon (the hauler's one saturated element, Kessler-Hayashi's teal): a lamp in a cage on a short mast."""
    if mast:
        rod((x, y, z), (x, y, z + mast), 0.012, M["steel"])
    z += mast
    box(0.1, 0.1, 0.03, x, y, z, M["kdark"], bevel=0.006)
    # (Its own teal at a low strength: the running lights' cyan at 3 burnt out white, and the one saturated element read
    # as a white dot.)
    if "kbeacon" not in M:
        M["kbeacon"] = __import__("lpkit").mat("kbeacon", (0.05, 0.75, 0.7), emit=(0.05, 0.8, 0.72), strength=1.1, grime=0.0)
        V.GLOW_NAMES.add("kbeacon")
    cyl(0.04, 0.07, x, y, z + 0.05, M["kbeacon"])
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        rod((x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, z + 0.015), (x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, z + 0.1),
            0.006, M["steel"])

def hatch(x, y, z, w=0.22, d=0.22):
    box(w, d, 0.03, x, y, z, M["kgraph"], bevel=0.01)
    box(w * 0.6, 0.02, 0.025, x, y + d * 0.35, z + 0.03, M["steel"], bevel=0.004)

# The hauler (the user, 2026-11-16: "a tank chassis with no turret, like an APC"): Kessler-Hayashi's convoy truck on its
# tank's hull, candidates A to D (clay first, LP_CLAY=1), the one kept named "carrier".
def carrier_a():
    """A: a sealed armoured cargo box over the rear two thirds of the deck, its sides sloped in, ribbed; two roof
    hatches; the beacon at its front top."""
    import bmesh
    Z0, Z1, YA, YB = ZD + 0.03, ZD + 0.42, -1.0, 0.28
    me = bpy.data.meshes.new("box"); bm = bmesh.new()
    lo = [bm.verts.new(v) for v in ((-0.6, YA, Z0), (0.6, YA, Z0), (0.6, YB, Z0), (-0.6, YB, Z0))]
    hi = [bm.verts.new(v) for v in ((-0.5, YA + 0.06, Z1), (0.5, YA + 0.06, Z1), (0.5, YB - 0.1, Z1), (-0.5, YB - 0.1, Z1))]
    bm.faces.new(lo[::-1]); bm.faces.new(hi)
    for k in range(4): bm.faces.new((lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("box", me); V.scene.collection.objects.link(o); me.materials.append(M["kpaint2"])
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.015; md.segments = 2
    for k in range(5):
        y = YA + 0.15 + k * 0.24
        for sx in (-1, 1):
            rod((sx * 0.59, y, Z0 + 0.02), (sx * 0.5, y, Z1 - 0.02), 0.012, M["kgraph"])
    hatch(-0.22, -0.55, Z1); hatch(0.22, -0.2, Z1)
    box(0.5, 0.006, 0.08, 0, YA - 0.005, Z1 - 0.12, M["kwhite"], bevel=0.0)
    box(0.6, 0.006, 0.05, 0, YA - 0.006, Z0 + 0.06, M["khazard"], bevel=0.0)
    beacon(0.3, YB - 0.2, Z1)

def carrier_b():
    """B: a low commander's cupola forward, a cargo cage over the rear deck with strapped crates; the beacon on a mast."""
    cyl(0.22, 0.14, 0, 0.35, ZD + 0.1, M["kpaint"], bevel=0.02)
    cyl(0.16, 0.04, 0, 0.35, ZD + 0.19, M["kgraph"], bevel=0.01)
    box(0.12, 0.05, 0.05, 0, 0.55, ZD + 0.15, M["glass"], bevel=0.004)
    Z0, YA, YB = ZD + 0.03, -1.0, 0.05
    for (x, y, w, d, h, m) in ((-0.3, -0.75, 0.42, 0.38, 0.26, M["kgraph"]), (0.22, -0.72, 0.4, 0.42, 0.22, M["kpaint3"]),
                               (-0.25, -0.3, 0.4, 0.36, 0.2, M["kpaint3"]), (0.25, -0.28, 0.36, 0.34, 0.28, M["kgraph"])):
        box(w, d, h, x, y, Z0 + h / 2, m, bevel=0.02)
        rod((x - w / 2, y, Z0 + h + 0.005), (x + w / 2, y, Z0 + h + 0.005), 0.01, M["khazard"])
    for sx in (-1, 1):
        for y in (YA, (YA + YB) / 2, YB):
            rod((sx * 0.58, y, Z0), (sx * 0.58, y, Z0 + 0.36), 0.014, M["steel"])
        rod((sx * 0.58, YA, Z0 + 0.36), (sx * 0.58, YB, Z0 + 0.36), 0.014, M["steel"])
    for y in (YA, YB):
        rod((-0.58, y, Z0 + 0.36), (0.58, y, Z0 + 0.36), 0.014, M["steel"])
    beacon(-0.45, 0.2, ZD + 0.04, mast=0.25)

def carrier_c():
    """C: two long sealed export canisters lengthwise in cradles, a small remote gun cupola forward; the beacon between."""
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.2, depth=1.2, location=(sx * 0.27, -0.42, ZD + 0.25),
                                            rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["kpaint3"])
        for y in (-0.95, 0.11):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(sx * 0.27, y + (0.05 if y > 0 else -0.05), ZD + 0.25))
            o = V.obj(); o.scale = (1, 0.35, 1); o.data.materials.append(M["kpaint3"])
        for y in (-0.8, -0.42, -0.04):
            box(0.46, 0.06, 0.2, sx * 0.27, y, ZD + 0.12, M["kgraph"], bevel=0.01)
            rod((sx * 0.27 - 0.2, y, ZD + 0.26), (sx * 0.27 + 0.2, y, ZD + 0.26), 0.012, M["khazard"])
    box(0.22, 0.24, 0.12, 0, 0.45, ZD + 0.1, M["kpaint"], bevel=0.02)
    rod((0, 0.5, ZD + 0.16), (0, 0.8, ZD + 0.16), 0.02, M["kdark"])
    beacon(0, -0.42, ZD + 0.46)

def carrier_d():
    """D: a tall troop and cargo compartment along the hull, square-sided, a rear ramp, roof hatches and a light bar."""
    Z0, Z1, YA, YB = ZD + 0.03, ZD + 0.5, -1.1, 0.55
    box(1.18, YB - YA, Z1 - Z0, 0, (YA + YB) / 2, (Z0 + Z1) / 2, M["kpaint"], bevel=0.03)
    box(1.0, 0.06, 0.38, 0, YA - 0.04, Z0 + 0.2, M["kpaint2"], bevel=0.015)            # the ramp
    for sx in (-1, 1):
        box(0.02, YB - YA - 0.2, 0.08, sx * 0.6, (YA + YB) / 2, Z0 + 0.3, M["kgraph"], bevel=0.004)
    for y in (-0.7, -0.25):
        hatch(-0.25, y, Z1); hatch(0.25, y, Z1)
    box(0.6, 0.006, 0.08, 0, YB + 0.005, Z1 - 0.12, M["kwhite"], bevel=0.0)
    box(0.5, 0.08, 0.04, 0, YB - 0.1, Z1 + 0.02, M["kdark"], bevel=0.008)
    for x in (-0.18, 0.0, 0.18):
        cyl(0.03, 0.04, x, YB - 0.1, Z1 + 0.05, M["kglow"])

base = V.group(hull)
anim, pose = V.tracks(TX, TW, IDL, SPR, frames=4)
# The hauler's head, A of the four clay candidates (2026-11-16, picked: an APC's casemate continuing the hull's sloped
# facets; B's crate cage too busy at game scale, C's canisters a fuel tanker, D a plain box). The candidates kept, by name.
MODULES = {"cannon": cannon, "prism": prism, "tesla": tesla, "aegis": aegis, "carrier": carrier_a}
CANDIDATES = {"carrier-a": carrier_a, "carrier-b": carrier_b, "carrier-c": carrier_c, "carrier-d": carrier_d}
which = os.environ.get("LP_MODULES", ",".join(MODULES)).split(",")
MODULES.update(CANDIDATES)
modules = {n: V.group(MODULES[n]) for n in which if n}
V.finish(grime=0.6, mud=0.5, mud_top=0.4)             # maintained: less grime than Grubstake's; mud on the tracks
# LP_CLAY=1: every surface one grey clay (lamps kept lit), to judge a new module's silhouette before its materials.
if os.environ.get("LP_CLAY"):
    clay = __import__("lpkit").mat("clay", (0.42, 0.42, 0.4), rough=0.7, grime=0.0)
    for o in V.scene.objects:
        if o.type == "MESH":
            for sl in o.material_slots:
                if not (sl.material and sl.material.name in V.GLOW_NAMES):
                    sl.material = clay
# LP_WRECK=<module>: that head's wreck on the hull (4 directions, its shadow in the picture; the left track thrown), then
# stop (the user, 2026-11-08: "We didn't do KH wrecks also").
if os.environ.get("LP_WRECK"):
    left = set(anim[:len(anim) // 2])
    V.wreck(base + anim + modules[os.environ["LP_WRECK"]], out, seed=19, tiles=3, margin=1.2, strip=lambda o: o in left)
    print("kh tank wreck:", os.environ["LP_WRECK"], "to", out); sys.exit(0)
rig = V.light(3, 1.2)
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, animated=anim, frames=4, rebuild=pose, light_rig=rig)
print("kh tank:", N, "directions to", out)
