"""Clay candidates for Grubstake's Workshop (lp-grubstake-siege-lab, its research building, 4x4; a recoloured Siege works
until now, Kessler-Hayashi's Space Age foundry): phase 1, four silhouettes to choose from, not wired into the mod. Grey
clay, a dark clay base, and the one saturated element each would carry tinted so its place reads (an amber lamp, a
painted sign board). One direction, the kit's camera and sun, one render a candidate with its shadow on the catcher.

Its brief: where a band of prospectors works out scrap arms, loot and wheels (its three branches): a workshop, not a
factory; patched scrap, ochre and amber in its real build. It must not read as its fabricator (an open scrap press, a
ram) or its depot (a pad on drum stilts, an A-frame hoist).

    Blender -b -P tools/blender/workshop_clay.py -- <out dir> [a b c d]
    then: uv run --with pillow python tools/blender/workshop_clay_sheet.py <out dir> <composite dir>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = set(args[1:])
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
lpkit.gpu(scene)
B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere


def clay(name, rgb, rough=0.65, emit=None, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = 3.0
    return m


CLAY = clay("clay", (0.26, 0.26, 0.26))
DARKC = clay("clay-dark", (0.06, 0.06, 0.065))
MIDC = clay("clay-mid", (0.13, 0.13, 0.13))
AMBER = clay("amber", (0.7, 0.45, 0.08), 0.3, emit=(1.0, 0.6, 0.15))
SIGN = clay("sign", (0.62, 0.2, 0.08), 0.5)


def tilt(o, rx=0.0, ry=0.0, rz=None):
    o.rotation_euler = (rx, ry, o.rotation_euler[2] if rz is None else rz)
    return o


def lamp(x, y, z, r=0.09):
    cyl(r * 1.1, 0.05, x, y, z, DARKC, verts=12)
    sph(r, x, y, z + 0.05 + r * 0.7, AMBER)
    cyl(r * 1.3, 0.03, x, y, z + 0.06 + r * 1.6, DARKC, verts=12)


def corrugated(w, d, x, y, z, slope, m=CLAY, ribs=None):
    """A sheet roof w wide (x) and d deep (y), its front edge at z, rising slope radians to the back: a slab and ribs."""
    rise = math.tan(slope) * d
    s = B(w, d / math.cos(slope), 0.05, x, y, z + rise / 2 - 0.025, m, bevel=0.0)
    tilt(s, rx=slope)
    n = ribs or int(w / 0.18)
    for k in range(n + 1):
        rx = x - w / 2 + w * k / n
        rod((rx, y - d / 2, z + 0.03), (rx, y + d / 2, z + rise + 0.03), 0.018, MIDC if k % 2 else m, verts=6)
    return rise


def drum(x, y, z=0.0, r=0.2, h=0.55, m=MIDC):
    cyl(r, h, x, y, z, m, verts=20)
    for zz in (z + h * 0.3, z + h * 0.7):
        lpkit.torus(r * 1.01, 0.014, x, y, zz, DARKC)
    cyl(r * 0.98, 0.02, x, y, z + h, DARKC, verts=20)


def crate(x, y, z, s, m=MIDC, rot=0.0):
    c = B(s, s, s * 0.8, x, y, z, m, rot=rot, bevel=0.02)
    B(s * 1.02, s * 0.12, s * 0.82, x, y, z, DARKC, rot=rot, bevel=0.0)
    return c


def bench(x, y, w=1.2, d=0.45):
    """A workbench: a dark top on four legs, a vice, a few tools as stubs."""
    B(w, d, 0.06, x, y, 0.62, DARKC, bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B(0.06, 0.06, 0.62, x + sx * (w / 2 - 0.06), y + sy * (d / 2 - 0.06), 0, MIDC, bevel=0.0)
    B(w * 0.95, d * 0.9, 0.04, x, y, 0.2, MIDC, bevel=0.0)
    B(0.14, 0.12, 0.12, x - w / 2 + 0.15, y - d / 2 + 0.08, 0.68, MIDC, bevel=0.01)
    for k in range(3):
        B(0.05, 0.25, 0.03, x + 0.1 + k * 0.14, y, 0.69, CLAY, bevel=0.0, rot=0.2 * k)


def gun_sign(x, y, z, w=1.1, h=0.42, face=-1):
    """A painted board on two posts: the Workshop's shotgun sign (the item icon's, shared.lua)."""
    for sx in (-1, 1):
        rod((x + sx * w * 0.4, y, 0), (x + sx * w * 0.4, y, z + h), 0.03, DARKC, verts=6)
    B(w, 0.05, h, x, y + face * 0.04, z, SIGN, bevel=0.01)
    # The gun in relief across it: stock, receiver, barrel.
    B(w * 0.22, 0.03, h * 0.35, x - w * 0.3, y + face * 0.075, z + h * 0.3, DARKC, bevel=0.0)
    B(w * 0.65, 0.03, h * 0.14, x + w * 0.1, y + face * 0.075, z + h * 0.5, DARKC, bevel=0.0)


# --- The candidates (4x4: x, y in -2..2; south, the camera's side, is -y) ---------------------------------------------

def a_leanto():
    # A lean-to forge shed: a scrap-sheet roof falling to the front over an open workshop, its back and sides a patched
    # wall, a brick forge chimney rising from the back corner, a workbench and an anvil under the eave, oil drums and a
    # quench barrel, the shotgun sign on posts at the front. Low at the front, tall at the back: a shed seen into.
    B(3.9, 3.9, 0.08, 0, 0, 0, DARKC, bevel=0.01)
    # Back wall and two side walls, patched panels of different heights.
    B(3.6, 0.18, 1.9, 0, 1.6, 0.08, CLAY)
    for sx in (-1, 1):
        B(0.18, 2.6, 1.3, sx * 1.72, 0.4, 0.08, CLAY)
        B(0.2, 0.9, 0.5, sx * 1.73, 0.9, 1.38, MIDC)
    for k, (px, pz) in enumerate(((-0.9, 0.6), (0.4, 1.1), (1.0, 0.4))):
        B(0.7, 0.2, 0.5, px, 1.5, pz, MIDC, bevel=0.01)
    # Front posts and the roof falling from 2.1 at the back to 1.35 at the front.
    for sx in (-1, 1):
        B(0.14, 0.14, 1.35, sx * 1.65, -0.9, 0.08, DARKC, bevel=0.0)
    corrugated(3.8, 2.8, 0, 0.35, 1.4, math.radians(14))
    # The forge: a brick chimney at the back-left, a hearth at its foot glowing.
    B(0.7, 0.7, 2.9, -1.35, 1.35, 0.08, MIDC)
    B(0.8, 0.8, 0.12, -1.35, 1.35, 2.98, DARKC)
    B(0.6, 0.45, 0.55, -1.2, 0.85, 0.08, DARKC)
    # Bench, anvil, quench barrel, drums.
    bench(0.45, 0.7)
    B(0.35, 0.18, 0.3, -0.45, -0.2, 0.3, DARKC, bevel=0.02); B(0.2, 0.2, 0.3, -0.45, -0.2, 0.08, MIDC, bevel=0.0)
    drum(1.3, -0.4); drum(1.65, -1.2, h=0.45); drum(-1.55, -1.45, r=0.24, h=0.4, m=CLAY)
    gun_sign(0.2, -1.65, 0.75)
    lamp(1.6, -0.95, 1.36)


def b_containers():
    # A container shop: two shipping containers set apart, a tarp roof stretched between them on poles, a workbench and
    # a buggy wheel hub on a stand under it, a gun rack on a container's wall, crates and a lamp on a container's roof, the
    # shotgun sign on the right container's front. Long flat blocks with a shade between: a yard roofed over.
    B(3.9, 3.9, 0.08, 0, 0, 0, DARKC, bevel=0.01)
    for sx, ln in ((-1, 3.4), (1, 2.6)):
        x = sx * 1.4
        c = B(1.0, ln, 1.25, x, (3.4 - ln) / 2 * (1 if sx > 0 else 0) + 0.1 * (sx > 0), 0.08, CLAY, bevel=0.02)
        for k in range(int(ln / 0.2)):
            yy = -ln / 2 + 0.1 + k * 0.2 + ((3.4 - ln) / 2 if sx > 0 else 0) + (0.1 if sx > 0 else 0)
            rod((x - sx * 0.51, yy, 0.12), (x - sx * 0.51, yy, 1.28), 0.012, MIDC, verts=5)
    # Tarp between them, sagging: two slabs meeting low in the middle.
    for s in (-1, 1):
        t = B(1.05, 3.0, 0.04, s * 0.45, 0.15, 1.45, MIDC, bevel=0.0)
        tilt(t, ry=s * math.radians(-9))
    for (px, py) in ((-0.85, -1.3), (0.85, -1.3), (-0.85, 1.5), (0.85, 1.5)):
        rod((px, py, 0.08), (px, py, 1.55), 0.035, DARKC, verts=6)
    bench(0, 0.9, w=1.1)
    # A wheel hub on a stand (its three branches: wheels).
    B(0.15, 0.15, 0.55, 0, -0.35, 0.08, DARKC, bevel=0.0)
    lpkit.torus(0.3, 0.1, 0, -0.35, 0.78, DARKC).rotation_euler = (math.pi / 2, 0, 0)
    # A gun rack on the left container's inner wall.
    for k in range(4):
        rod((-0.86, -0.6 + k * 0.25, 0.4), (-0.86, -0.55 + k * 0.25, 1.05), 0.025, DARKC, verts=5)
    crate(-1.35, 0.3, 1.33, 0.5); crate(-1.45, -0.6, 1.33, 0.4, rot=0.4)
    lamp(1.4, -0.6, 1.33)
    gun_sign(1.4, -1.25, 0.55, w=0.85, h=0.35)


def c_quonset():
    # A Quonset hut: a half-round corrugated shell along the north-south axis, its south end open on a lit bay, a stove
    # pipe through its crown, a lean-to on its east side stacked with scrap, the shotgun sign over the bay, drums and
    # crates out front. The round roof is the silhouette: unlike every boxy camp building.
    B(3.9, 3.9, 0.08, 0, 0, 0, DARKC, bevel=0.01)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=1.35, depth=3.3, location=(-0.3, 0.2, 0.08), rotation=(math.pi / 2, 0, 0))
    shell = bpy.context.object; shell.data.materials.append(CLAY)
    for k in range(9):
        y = -1.45 + k * 0.41
        bpy.ops.mesh.primitive_torus_add(major_radius=1.37, minor_radius=0.025, location=(-0.3, y, 0.08), rotation=(math.pi / 2, 0, 0),
                                         major_segments=40, minor_segments=6)
        bpy.context.object.data.materials.append(MIDC)
    # The open bay: a dark recess in the south end, a bench inside, its frame.
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.95, depth=0.3, location=(-0.3, -1.4, 0.08), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(DARKC)
    bench(-0.3, -1.0, w=1.0, d=0.35)
    gun_sign(-0.3, -1.55, 1.15, w=0.9, h=0.32)
    # Stove pipe through the crown, its cap.
    cyl(0.1, 1.0, -0.6, 0.6, 1.35, MIDC, verts=12); cyl(0.18, 0.06, -0.6, 0.6, 2.35, DARKC, verts=12)
    # East lean-to: a sloped sheet on posts, scrap under it.
    rise = corrugated(0.9, 2.6, 1.55, 0.3, 0.9, math.radians(-12))
    for py in (-0.9, 1.5):
        rod((1.95, py, 0.08), (1.95, py, 0.9), 0.03, DARKC, verts=6)
    crate(1.5, -0.3, 0.08, 0.45); crate(1.5, 0.4, 0.08, 0.5, rot=0.3); crate(1.55, 0.35, 0.48, 0.35, m=CLAY)
    drum(1.3, -1.45); drum(0.8, -1.65, r=0.18, h=0.45, m=CLAY)
    lamp(0.5, -1.3, 1.25, r=0.08)


def d_gantry():
    # A gantry yard: a low workshop hut at the back, an overhead travelling gantry on two portal frames spanning the open
    # yard in front, a buggy's chassis hanging from its hook over trestles, a tyre stack, a welding lamp, the shotgun sign
    # on the hut's front. A frame over open ground: the tallest lines are thin.
    B(3.9, 3.9, 0.08, 0, 0, 0, DARKC, bevel=0.01)
    B(3.4, 1.1, 1.05, 0, 1.35, 0.08, CLAY)
    corrugated(3.6, 1.3, 0, 1.35, 1.1, math.radians(10))
    B(0.6, 0.06, 0.6, -0.9, 0.77, 0.25, DARKC, bevel=0.0)
    gun_sign(0.7, 0.75, 0.55, w=0.95, h=0.35)
    # Two portal frames (east and west), a beam across their tops, a trolley and hook.
    for sx in (-1, 1):
        x = sx * 1.6
        rod((x, -1.6, 0.08), (x, -1.6, 2.2), 0.06, DARKC, verts=8)
        rod((x, 0.6, 0.08), (x, 0.6, 2.2), 0.06, DARKC, verts=8)
        rod((x, -1.6, 2.2), (x, 0.6, 2.2), 0.06, DARKC, verts=8)
        rod((x, -1.6, 1.2), (x, -0.9, 2.2), 0.03, MIDC, verts=6)
    B(3.4, 0.22, 0.2, 0, -0.5, 2.15, MIDC, bevel=0.01)
    B(0.35, 0.35, 0.18, 0.2, -0.5, 1.97, DARKC, bevel=0.01)
    rod((0.2, -0.5, 1.97), (0.2, -0.5, 1.1), 0.012, DARKC, verts=5)
    # The chassis: a ladder frame with two axles, slung under the hook over two trestles.
    for sy in (-1, 1):
        B(1.5, 0.08, 0.1, 0.2, -0.5 + sy * 0.3, 0.95, MIDC, bevel=0.0)
    for sx in (-1, 1):
        rod((0.2 + sx * 0.55, -0.9, 0.95), (0.2 + sx * 0.55, -0.1, 0.95), 0.03, DARKC, verts=6)
        for sy in (-1, 1):
            lpkit.torus(0.17, 0.07, 0.2 + sx * 0.55, -0.5 + sy * 0.42, 0.95, DARKC).rotation_euler = (math.pi / 2, 0, 0)
        B(0.5, 0.08, 0.7, 0.2 + sx * 0.6, -0.5, 0.08, MIDC, bevel=0.0)
    # A tyre stack and drums.
    for k in range(4):
        lpkit.torus(0.28, 0.1, -1.1, -1.35, 0.18 + k * 0.2, DARKC)
    drum(1.3, -1.5); drum(-0.4, -1.55, r=0.18, h=0.45, m=CLAY)
    lamp(-1.6, 0.6, 2.25)


LIGHTC = clay("clay-light", (0.3, 0.3, 0.29))
# (c2's own darker clays: the first pass beside the fabricator read pale and toy-like; its tones span these.)
# (Measured: the fabricator's body averages 47 of 255, 21 to 76; c2 at 0.17 averaged 80. These about 0.55 of that.)
CLAY2, MID2, DARK2 = clay("clay2", (0.07, 0.07, 0.07)), clay("mid2", (0.05, 0.05, 0.05)), clay("dark2", (0.02, 0.02, 0.022))
LIGHT2 = clay("light2", (0.16, 0.16, 0.155))


def arc_sheet(R, y0, y1, cx, z0, m, a0=0.0, a1=math.pi, n=40, t=0.03):
    """An open arc of sheet (a Quonset bay): radius R round the y axis at (cx, z0), from y0 to y1, angles a0..a1."""
    import bmesh
    bm = bmesh.new()
    rows = []
    for k in range(n + 1):
        a = a0 + (a1 - a0) * k / n
        rows.append([bm.verts.new((cx + R * math.cos(a), y, z0 + R * math.sin(a))) for y in (y0, y1)])
    for k in range(n):
        bm.faces.new((rows[k][0], rows[k + 1][0], rows[k + 1][1], rows[k][1]))
    me = bpy.data.meshes.new("arc"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("arc", me); scene.collection.objects.link(o)
    me.materials.append(m)
    sd = o.modifiers.new("s", "SOLIDIFY"); sd.thickness = t
    return o


def panel(x, y, z, w, l, t, ry, m, rz=0.0):
    """A sheet centred at (x, y, z), w across, l along y, t thick, turned ry about y (and rz about z)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=(0, ry, rz))
    o = bpy.context.object; o.scale = (w, l, t)
    md = o.modifiers.new("b", "BEVEL"); md.width = min(t * 0.4, 0.015); md.segments = 1
    o.data.materials.append(m)
    return o


def c2_quonset():
    # C again, denser (the user: "C is cool but improve the clay still. It looks childish next to the fabricator"): the
    # fabricator reads by many small parts at several scales, overlapping, nothing clean. Here the shell is patched
    # panels of three shades and two depths, some lifted, a tarp lashed over a hole; ribs uneven; the south end a framed
    # plank wall with a steel lintel, a half-raised roll shutter over a lit bay; the crown cluttered (a vent turbine, an
    # aerial, sandbags); the pad broken concrete under scrap: sheet stacks, rims, gas bottles, ammo boxes, a tyre stack, a
    # gun rack; the east lean-to over an engine block.
    import random
    rnd = random.Random(7)
    R, CX, Y0, Y1, Z0 = 1.2, -0.35, -1.25, 1.75, 0.06
    # The pad: broken slabs, not one block.
    for (px, py, w, d) in ((-0.9, 0.2, 2.2, 3.7), (1.05, 0.5, 1.6, 2.9), (0.5, -1.55, 2.9, 0.8)):
        B(w, d, 0.06, px, py, 0, rnd.choice((DARK2, MID2)), rot=rnd.uniform(-0.02, 0.02), bevel=0.02)
    # Shell: one curved sheet a bay, a shade a bay, corrugation ridges proud round the arch, patches bolted on. (Flat
    # sheets read as a faceted prism, and as stonework turned at random.)
    n_l = 7
    L = (Y1 - Y0) / n_l
    for j in range(n_l):
        bay = rnd.choice((CLAY2, CLAY2, MID2, LIGHT2))
        arc_sheet(R + rnd.uniform(-0.01, 0.012), Y0 + L * j, Y0 + L * (j + 1) + 0.01, CX, Z0, bay)
        for q in range(6):
            yr = Y0 + L * j + L * (q + 0.5) / 6
            bpy.ops.mesh.primitive_torus_add(major_radius=R + 0.02, minor_radius=0.011, location=(CX, yr, Z0),
                                             rotation=(math.pi / 2, 0, 0), major_segments=48, minor_segments=5)
            rib = bpy.context.object; rib.data.materials.append(DARK2 if q == 0 else MID2)
            # (Its lower half under the pad: cut, so it does not show through the catcher.)
            bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT"); bpy.ops.object.mode_set(mode="OBJECT")
            for v in rib.data.vertices: v.select = v.co.z < -0.02
            bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.delete(type="VERT"); bpy.ops.object.mode_set(mode="OBJECT")
    for _ in range(6):
        a = rnd.uniform(0.4, math.pi - 0.4); y = rnd.uniform(Y0 + 0.3, Y1 - 0.4); da = rnd.uniform(0.18, 0.32)
        arc_sheet(R + 0.04, y, y + rnd.uniform(0.25, 0.45), CX, Z0, rnd.choice((LIGHT2, MID2)), a0=a - da / 2, a1=a + da / 2, n=6, t=0.02)
    # A tarp lashed over a hole, west of the crown: a sheet laid on the arch, ropes round it. (A flat sheet at 28 degrees
    # stood off the shell like a board.)
    arc_sheet(R + 0.06, 0.15, 1.15, CX, Z0, DARK2, a0=math.radians(100), a1=math.radians(150), n=10, t=0.02)
    for yy in (0.25, 0.65, 1.05):
        arc_sheet(R + 0.085, yy, yy + 0.03, CX, Z0, MID2, a0=math.radians(95), a1=math.radians(155), n=10, t=0.015)
    # Crown: a vent turbine, an aerial on a guyed mast, a stove pipe with its cap, sandbags on the north crown.
    cyl(0.12, 0.18, CX + 0.25, 1.05, Z0 + R - 0.02, MID2, verts=12)
    sph(0.15, CX + 0.25, 1.05, Z0 + R + 0.24, LIGHT2).scale = (1, 1, 0.7)
    rod((CX + 0.55, 1.45, Z0 + R - 0.1), (CX + 0.55, 1.45, Z0 + R + 1.1), 0.012, DARK2, verts=5)
    for (gx, gy) in ((0.3, 0), (-0.25, 0.15), (0.0, -0.3)):
        rod((CX + 0.55, 1.45, Z0 + R + 0.9), (CX + 0.55 + gx, 1.45 + gy, Z0 + R - 0.05), 0.004, DARK2, verts=3)
    cyl(0.08, 0.9, CX - 0.5, -0.35, Z0 + R * 0.85, MID2, verts=10)
    cyl(0.14, 0.05, CX - 0.5, -0.35, Z0 + R * 0.85 + 0.9, DARK2, verts=10)
    cyl(0.1, 0.05, CX - 0.5, -0.35, Z0 + R * 0.85 + 0.6, DARK2, verts=10)
    for k in range(5):
        bag = B(0.28, 0.16, 0.1, CX - 0.6 + k * 0.3, 1.55, Z0 + R - 0.08, rnd.choice((MID2, CLAY2)), rot=rnd.uniform(-0.3, 0.3), bevel=0.04)
    # South end: a framed wall of planks under the arch, a steel lintel, the bay with its half-raised shutter.
    yS = Y0 - 0.02
    nplank = 13
    for k in range(nplank):
        x = -R + (k + 0.5) * 2 * R / nplank
        hgt = math.sqrt(max(0.0, R * R - x * x)) - 0.02
        if abs(x) < 0.55:
            hgt_top = hgt - 1.05
            B(2 * R / nplank * 0.96, 0.05, hgt_top, CX + x, yS, Z0 + 1.05, rnd.choice((MID2, CLAY2)), bevel=0.005)
        else:
            B(2 * R / nplank * 0.96, 0.05, hgt, CX + x, yS, Z0, rnd.choice((MID2, CLAY2, LIGHT2)), bevel=0.005)
    B(1.3, 0.1, 0.12, CX, yS - 0.03, Z0 + 1.0, DARK2, bevel=0.01)               # lintel
    for sx in (-1, 1):
        B(0.1, 0.1, 1.0, CX + sx * 0.6, yS - 0.03, Z0, DARK2, bevel=0.01)        # door posts
    # The bay: dark inside, a lit bench at its back, the shutter half up (ribbed slats), its drum under the lintel.
    B(1.1, 0.9, 0.95, CX, yS + 0.45, Z0, DARK2, bevel=0.0)
    for k in range(6):
        B(1.12, 0.03, 0.06, CX, yS - 0.05, Z0 + 0.62 + k * 0.065, MID2 if k % 2 else CLAY2, bevel=0.0)
    cyl(0.07, 1.2, CX - 0.6, yS - 0.07, Z0 + 1.0, DARK2, verts=10, rot=(0, math.pi / 2, 0))
    B(0.8, 0.25, 0.04, CX, yS + 0.75, Z0 + 0.5, CLAY2, bevel=0.0)
    sph(0.06, CX + 0.25, yS + 0.7, Z0 + 0.62, AMBER)
    # A jib hoist over the bay: a post at the east door post, a boom out south, a chain and hook, a crate on it.
    rod((CX + 0.68, yS - 0.12, Z0), (CX + 0.68, yS - 0.12, Z0 + 1.75), 0.04, DARK2, verts=8)
    rod((CX + 0.68, yS - 0.12, Z0 + 1.7), (CX + 0.1, yS - 0.75, Z0 + 1.6), 0.03, DARK2, verts=6)
    rod((CX + 0.68, yS - 0.12, Z0 + 1.2), (CX + 0.3, yS - 0.55, Z0 + 1.58), 0.018, MID2, verts=5)
    rod((CX + 0.1, yS - 0.75, Z0 + 1.6), (CX + 0.1, yS - 0.75, Z0 + 0.65), 0.008, DARK2, verts=4)
    crate(CX + 0.1, yS - 0.75, Z0 + 0.38, 0.3, m=MID2, rot=0.4)
    # Lit dormers along the arch, west side: a hood each over an amber pane.
    for yy in (-0.55, 0.45, 1.25):
        a = math.radians(150)
        x, z = CX + (R + 0.02) * math.cos(a), Z0 + (R + 0.02) * math.sin(a)
        d = B(0.3, 0.32, 0.22, x - 0.05, yy, z - 0.12, MID2, bevel=0.01)
        pane = B(0.03, 0.22, 0.13, x - 0.21, yy, z - 0.06, AMBER, bevel=0.0)
    # The sign: a big board bolted over the lintel, tilted out.
    s = B(1.15, 0.05, 0.36, CX, yS - 0.1, Z0 + 1.14, SIGN, bevel=0.012); tilt(s, rx=math.radians(-12))
    B(0.26, 0.03, 0.13, CX - 0.32, yS - 0.15, Z0 + 1.2, DARK2, bevel=0.0)
    B(0.72, 0.03, 0.05, CX + 0.08, yS - 0.15, Z0 + 1.29, DARK2, bevel=0.0)
    lamp(CX + 0.75, yS - 0.08, Z0 + 1.05, r=0.07)
    # East lean-to: a bent sheet on three posts, an engine block and scrap sheets under it.
    # (Three sheets, dark and uneven, a seam strip each: pale ones with ridge rods through them read as a slab
    # scribbled on.)
    # (The middle sheet gone: its purlins bare over the engine.)
    for (py, m) in ((-0.7, MID2), (1.15, MID2)):
        panel(1.42, py, 0.98, 1.0, 0.95, 0.03, math.radians(-14), m, rz=rnd.uniform(-0.03, 0.03))
        panel(1.42, py + 0.47, 1.0, 1.0, 0.05, 0.035, math.radians(-14), DARK2)
    for q in range(3):
        x = 1.05 + q * 0.38
        rod((x, -0.25, 1.07 - (x - 1.05) * 0.25), (x, 0.7, 1.07 - (x - 1.05) * 0.25), 0.018, DARK2, verts=5)
    for py in (-1.15, 0.25, 1.6):
        rod((1.9, py, 0.06), (1.9, py, 0.86), 0.03, DARK2, verts=6)
    eng = B(0.5, 0.42, 0.34, 1.25, 0.4, 0.06, MID2, bevel=0.03)
    for k in range(3):
        cyl(0.05, 0.12, 1.12 + k * 0.13, 0.4, 0.4, DARK2, verts=8)
    for k in range(5):
        B(0.75, 0.5, 0.03, 1.35, -0.55, 0.06 + k * 0.035, rnd.choice((CLAY2, MID2, LIGHT2)), rot=rnd.uniform(-0.25, 0.25), bevel=0.0)
    # Out front: a tyre stack, wheel rims, gas bottles, ammo boxes, a gun rack on the west wall, drums, crates.
    for k in range(3):
        lpkit.torus(0.22, 0.08, 1.55, -1.55, 0.14 + k * 0.16, DARK2)
    for (rx, ry_) in ((0.95, -1.35), (1.75, -0.95)):
        t = lpkit.torus(0.16, 0.04, rx, ry_, 0.2, MID2); t.rotation_euler = (math.radians(75), 0, rnd.uniform(0, 3))
    for k in range(3):
        cyl(0.065, 0.5, 0.55 + k * 0.15, -1.7, 0.06, rnd.choice((LIGHT2, CLAY2)), verts=12)
        sph(0.06, 0.55 + k * 0.15, -1.7, 0.58, DARK2)
    for (bx, by, rz) in ((-1.55, -1.55, 0.2), (-1.25, -1.7, -0.3), (-1.4, -1.6, 0.0)):
        B(0.26, 0.16, 0.14, bx, by, 0.06 if bx != -1.4 else 0.2, MID2, rot=rz, bevel=0.015)
    for k in range(5):
        rod((-1.72, -0.9 + k * 0.17, 0.12), (-1.74, -0.86 + k * 0.17, 0.85), 0.022, DARK2, verts=5)
    B(0.06, 0.95, 0.05, -1.71, -0.55, 0.55, MID2, bevel=0.0)
    drum(0.95, -0.75, r=0.17, h=0.45, m=MID2); drum(0.62, -0.55, r=0.17, h=0.45, m=CLAY2)
    crate(-1.0, 1.8, 0.06, 0.4); crate(-0.55, 1.85, 0.06, 0.35, m=CLAY2, rot=0.3); crate(-0.8, 1.8, 0.38, 0.3, rot=-0.2)


MODELS = {"a": a_leanto, "b": b_containers, "c": c_quonset, "d": d_gantry, "c2": c2_quonset}
ground, sun, world = lpkit.stage(scene, 4, 1)
sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.38
os.makedirs(out, exist_ok=True)
for name, fn in MODELS.items():
    if only and name not in only:
        continue
    before = set(scene.objects)
    fn()
    model = [o for o in scene.objects if o not in before]
    ground.hide_render = False
    lpkit.render(scene, f"{out}/{name}.png")
    print("rendered", name)
    for o in model:
        bpy.data.objects.remove(o, do_unlink=True)
