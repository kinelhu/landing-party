"""Kessler-Hayashi's siege guns, modelled and rendered for Factorio's artillery turret (the user, 2026-11-03: "The mortar
and howitzer are also two candidates"): a static base, then for each of N directions (north first, clockwise) the barrel
and the cannon housing, each with the other a holdout (so they hide each other rightly whichever the engine draws first),
and their shadow together.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/kh_guns.py -- <mortar|howitzer> <out_dir> [N=64] [serenity|grubstake]
    then: uv run --with pillow python tools/blender/gun_sheet.py <out_dir> landing-party/graphics/serenity/<gun>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
GUN, out = args[0], args[1]
N = int(args[2]) if len(args) > 2 else 64
CORP = args[3] if len(args) > 3 else "serenity"
scene = lpkit.reset()
scene.cycles.samples = 48
P = lpkit.palette()
# Grubstake fields the same guns (its copies of the kinds): its rusty amber paint and warm steel, the same shapes (so the
# same crops and sizes: corps.lua points its copies at these files through the manifest).
if CORP == "grubstake":
    P["paint"] = lpkit.mat("paint_g", (0.55, 0.34, 0.14), metal=0.3, rough=0.6, grime=0.7)
    P["hazard"] = lpkit.mat("hazard_g", (0.7, 0.5, 0.1), metal=0.2, rough=0.6)

def group(fn):
    before = set(scene.objects)
    fn()
    return [o for o in scene.objects if o not in before]

def parent_all(objs, pivot):
    for o in objs:
        o.parent = pivot
        o.matrix_parent_inverse = pivot.matrix_world.inverted()

if GUN == "mortar":
    # The mortar, second pass (the user, 2026-11-03: "Both but howitzer is more toy like"): worn materials, the hazard ring
    # thin and dull, sandbags round the emplacement, ammo crates, a banded tube on a cradle with hydraulic arms.
    P = lpkit.palette_worn()
    if CORP == "grubstake":
        P["paint"] = lpkit.worn("paint_g", (0.4, 0.27, 0.13), metal=0.25, rough=0.65, seams=5)
    sand = lpkit.worn("sand", (0.36, 0.31, 0.22), metal=0.0, rough=0.9, seams=12, rivets=False, wear=0.2)
    TILES, MARGIN, Z = 2, 2.0, 0.4
    def base():
        lpkit.cyl(0.9, 0.1, 0, 0, 0, P["dark"], verts=8, bevel=0.03)
        lpkit.cyl(0.74, 0.24, 0, 0, 0.1, P["paint"], verts=8, bevel=0.03)
        for k in range(8):
            a = k * math.pi / 4 + math.pi / 8
            lpkit.box(0.2, 0.04, 0.14, math.cos(a) * 0.73, math.sin(a) * 0.73, 0.15, P["steel"], rot=a + math.pi / 2)
        lpkit.torus(0.6, 0.015, 0, 0, Z - 0.05, P["hazard"])
        for k in range(14):                                              # sandbags round it, leaving the front open
            a = k * 2 * math.pi / 14
            if math.sin(a) > 0.75:
                continue
            bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=12, ring_count=8,
                location=(math.cos(a) * 0.93, math.sin(a) * 0.93, 0.08), rotation=(0, 0, a + math.pi / 2))
            o = bpy.context.object; o.scale = (0.2, 0.1, 0.08); o.data.materials.append(sand)
        for x, y in ((-0.5, -0.62), (0.45, -0.66)):                      # ammo crates
            lpkit.box(0.24, 0.16, 0.13, x, y, 0.0, P["dark"]); lpkit.box(0.24, 0.16, 0.02, x, y, 0.13, P["steel"])
    def housing():
        lpkit.cyl(0.55, 0.1, 0, 0, Z, P["steel"], verts=32, bevel=0.02)
        for sx in (-0.28, 0.28):
            lpkit.box(0.08, 0.46, 0.38, sx, 0.0, Z + 0.1, P["paint"])          # cradle cheeks
            lpkit.rod((sx * 1.1, -0.18, Z + 0.12), (sx * 1.1, 0.12, Z + 0.42), 0.025, P["steel"])  # hydraulic arms
        lpkit.box(0.46, 0.26, 0.12, 0, -0.32, Z + 0.1, P["dark"])
        lpkit.box(0.1, 0.08, 0.1, 0.36, -0.2, Z + 0.1, P["steel"])               # a sight box
    def barrel():
        a = math.radians(55); L = 0.95; zc = Z + 0.42
        def along(d): return (0, math.cos(a) * d - 0.12, zc + math.sin(a) * d - 0.08)
        rot = (-(math.pi / 2 - a), 0, 0)
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.16, depth=L, location=along(L / 2), rotation=rot)
        bpy.context.object.data.materials.append(P["dark"])
        for dd in (0.15, 0.45, 0.75):                                    # reinforcing bands
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.175, depth=0.06, location=along(dd), rotation=rot)
            bpy.context.object.data.materials.append(P["steel"])
        bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.04, location=along(L), rotation=rot)
        bpy.context.object.data.materials.append(P["steel"])
        lpkit.rod((-0.24, 0, zc), (0.24, 0, zc), 0.06, P["steel"])
else:
    # The howitzer, second pass (the user, 2026-11-03: "howitzer is more toy like"): a carriage of plates, tyred wheels,
    # split trails to spades; an angular armoured housing of plates; a tapered tube with a fume extractor, recoil
    # cylinders and a slotted muzzle brake; worn, desaturated materials (lpkit.worn).
    P = lpkit.palette_worn()
    if CORP == "grubstake":
        P["paint"] = lpkit.worn("paint_g", (0.4, 0.27, 0.13), metal=0.25, rough=0.65, seams=5)
    TILES, MARGIN, Z = 3, 2.4, 0.62
    def tapered(sx, sy, sz, x, y, z, m, top=0.72, back=0.12, rot=0.0):
        """A box whose top face is shrunk and pushed back: sloped armour (the first pass's housing was a plain box)."""
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
        o = bpy.context.object
        for v in o.data.vertices:
            if v.co.z > 0:
                v.co.x *= top; v.co.y = v.co.y * top - back
        o.scale = (sx, sy, sz); o.location = (x, y, z + sz / 2); o.rotation_euler = (0, 0, rot)
        o.data.materials.append(m)
        return o
    def base():
        B, D, S, K = lpkit.box, P["dark"], P["steel"], P["paint"]
        B(1.5, 1.2, 0.22, 0, 0, 0.3, K)                                 # chassis
        for sy in (-0.63, 0.63):
            B(1.55, 0.06, 0.2, 0, sy, 0.28, S)                          # side skirts
        B(1.25, 1.0, 0.05, 0, 0, 0.52, S)                               # deck
        for sx in (-0.82, 0.82):                                        # wheels: tyre, hub
            for sy in (-0.32, 0.32):
                bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.085, location=(sx, sy, 0.29),
                                                 rotation=(0, math.pi / 2, 0))
                bpy.context.object.data.materials.append(P["rubber"])
                lpkit.cyl(0.13, 0.13, sx - 0.065 * (1 if sx > 0 else -1), sy, 0.29 - 0.065, S, verts=12, rot=(0, math.pi / 2, 0))
        # Feet on all sides (the user, 2026-11-03: "feet on all sides not just bottom"): four outriggers in an X, each a
        # boxed beam, a hydraulic ram above it, a jack and a spade on the ground.
        # (The far pair, north, splayed to 30 degrees off the axle and longer: at 45 their spades stood behind the housing, seen
        # from the camera, and read as stubs; the in-game stills, 2026-11-04.)
        for a, reach in ((math.radians(30), 1.15), (math.radians(150), 1.15), (math.radians(-135), 1.0), (math.radians(-45), 1.0)):
            c, sn = math.cos(a), math.sin(a)
            lpkit.rod((c * 0.55, sn * 0.45, 0.36), (c * 1.3 * reach, sn * 1.25 * reach, 0.12), 0.06, K)
            lpkit.rod((c * 0.45, sn * 0.38, 0.5), (c * 1.0 * reach, sn * 0.95 * reach, 0.24), 0.025, S)
            lpkit.cyl(0.05, 0.16, c * 1.32 * reach, sn * 1.27 * reach, 0.0, S, verts=10)
            B(0.3, 0.3, 0.05, c * 1.33 * reach, sn * 1.28 * reach, 0.0, D, rot=a)
            B(0.2, 0.03, 0.05, c * 1.33 * reach, sn * 1.28 * reach, 0.05, P["hazard"], rot=a)
        for x in (-0.48, 0.48):                                         # ammo boxes on the deck
            B(0.26, 0.2, 0.15, x, -0.38, 0.55, D); B(0.26, 0.2, 0.025, x, -0.38, 0.7, S)
        B(0.22, 0.14, 0.12, 0.5, 0.42, 0.55, D)                         # a generator box
        lpkit.cyl(0.05, 0.12, 0.5, 0.42, 0.67, S, verts=10)
    def housing():
        B, D, S, K = lpkit.box, P["dark"], P["steel"], P["paint"]
        lpkit.cyl(0.62, 0.07, 0, 0, Z - 0.05, S, verts=32)             # turntable
        lpkit.cyl(0.72, 0.03, 0, 0, Z - 0.06, D, verts=32)             # crew platform
        for k in range(10):                                             # its railing
            a = k * 2 * math.pi / 10 + math.pi / 10
            if abs(math.sin(a) - 1) < 0.35:
                continue                                                # (none where the barrel runs)
            lpkit.rod((math.cos(a) * 0.7, math.sin(a) * 0.7, Z - 0.03), (math.cos(a) * 0.7, math.sin(a) * 0.7, Z + 0.2), 0.012, S)
        tapered(0.9, 0.95, 0.42, 0, -0.05, Z + 0.02, K, top=0.7, back=0.1)    # sloped housing
        tapered(0.5, 0.36, 0.18, 0, -0.08, Z + 0.44, K, top=0.75, back=0.05)  # commander's cupola
        B(0.1, 0.08, 0.1, 0.12, -0.05, Z + 0.62, S)                      # its sight
        for side in (-1, 1):                                            # stowage bins on the flanks
            B(0.12, 0.5, 0.2, side * 0.5, -0.1, Z + 0.06, D)
            B(0.13, 0.48, 0.02, side * 0.5, -0.1, Z + 0.26, S)
        B(0.44, 0.22, 0.2, 0, -0.55, Z + 0.04, D)                        # breech housing at the rear
        lpkit.torus(0.05, 0.012, -0.47, 0.25, Z + 0.25, S)               # handwheel
        bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))     # a cable from the cupola down the back
        c = bpy.context.object; c.data.bevel_depth = 0.014
        pts = c.data.splines[0].bezier_points
        pts[0].co = (0.18, -0.2, Z + 0.5); pts[0].handle_right = (0.3, -0.45, Z + 0.5)
        pts[1].co = (0.3, -0.6, Z + 0.08); pts[1].handle_left = (0.35, -0.55, Z + 0.3)
        pts[0].handle_left = pts[0].co; pts[1].handle_right = pts[1].co
        c.data.materials.append(D)
    def barrel():
        a = math.radians(30); zc = Z + 0.38; y0 = 0.45
        def seg(r, L, start, m, verts=20):
            d = start + L / 2
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=L,
                location=(0, y0 + math.cos(a) * d, zc + math.sin(a) * d), rotation=(-(math.pi / 2 - a), 0, 0))
            bpy.context.object.data.materials.append(m)
        seg(0.1, 0.9, -0.2, P["dark"])                                   # the tube, thick at the breech
        seg(0.075, 1.25, 0.7, P["dark"])                                 # then thinner
        seg(0.105, 0.22, 1.05, P["steel"])                               # fume extractor
        for off in (0.11, -0.11):                                        # recoil cylinders above and below
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.04, depth=0.75,
                location=(0, y0 + math.cos(a) * 0.2 - math.sin(a) * off, zc + math.sin(a) * 0.2 + math.cos(a) * off),
                rotation=(-(math.pi / 2 - a), 0, 0))
            bpy.context.object.data.materials.append(P["steel"])
        d = 1.95                                                         # muzzle brake with its slots
        for k, w in enumerate((0.22, 0.16, 0.22)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y0 + math.cos(a) * (d + k * 0.06), zc + math.sin(a) * (d + k * 0.06)),
                rotation=(-(math.pi / 2 - a), 0, 0))
            o = bpy.context.object; o.scale = (w, 0.05, 0.14); o.data.materials.append(P["steel"])

base_objs = group(base)
house_objs = group(housing)
barrel_objs = group(barrel)
lpkit.bevel_all(base_objs + house_objs + barrel_objs)
bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
parent_all(house_objs + barrel_objs, pivot)
ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
for k in ("barrel", "housing", "cshadow"): os.makedirs(f"{out}/{k}", exist_ok=True)
bg = world.node_tree.nodes["Background"]

def show(objs, on):
    for o in objs: o.hide_render = not on

# The static base: alone, then its shadow.
show(house_objs + barrel_objs, False); ground.hide_render = True
lpkit.render(scene, f"{out}/base.png")
ground.hide_render = False
for o in base_objs: o.visible_camera = False
lpkit.render(scene, f"{out}/base_shadow.png")
for o in base_objs: o.visible_camera = True
show(base_objs, False)
show(house_objs + barrel_objs, True)
for d in range(N):
    pivot.rotation_euler = (0, 0, -2 * math.pi * d / N)      # north first, clockwise seen from above
    bpy.context.view_layer.update()
    ground.hide_render = True
    for o in barrel_objs: o.is_holdout = False
    for o in house_objs: o.is_holdout = True
    lpkit.render(scene, f"{out}/barrel/{d:03d}.png")
    for o in barrel_objs: o.is_holdout = True
    for o in house_objs: o.is_holdout = False
    lpkit.render(scene, f"{out}/housing/{d:03d}.png")
    for o in barrel_objs + house_objs: o.is_holdout = False; o.visible_camera = False
    ground.hide_render = False
    lpkit.render(scene, f"{out}/cshadow/{d:03d}.png")
    for o in barrel_objs + house_objs: o.visible_camera = True
print("rendered", GUN, out)
