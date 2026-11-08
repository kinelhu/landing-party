"""Shared pieces for rendered units (the unit pass, 2026-11-08): what buggy.py worked out with the user, for the next
vehicles (crawler.py first). Grubstake's worn materials, primitives that are not polygonal (tubes 16 sides and more,
cylinders 32, hex nuts 6; every mesh shaded smooth, edges past 35 degrees kept sharp: "too polygonal"), solids spun about
an axle, true coil springs, bolt rows, plates through points, grime on every material (lpkit.dirty: "vanilla reads far
more grimy"), the light measured against vanilla's sprites (little sky, a strong sun, the High Contrast look), and the
layered passes: a static base, modules over it with the base as a holdout, an animated layer of F frames a direction.

    import vehicle as V; V.setup(); ...build...; V.finish(); V.passes(out, N, base, modules, animated)
(buggy.py keeps its own copies until it is moved onto this.)
"""
import math, os
import bpy, mathutils
import lpkit

scene = None
M = {}
GLOWS = ("lamp", "tail", "pilot")
GLOW_NAMES = set(GLOWS)          # GLOWS and what palettes add (kh_palette's kglow)

def setup(samples=64):
    """A fresh scene, Grubstake's materials in M."""
    global scene
    scene = lpkit.reset(); scene.cycles.samples = samples
    P = lpkit.palette_worn()
    M.update(P)
    M["steel"] = lpkit.worn("steel_b", (0.55, 0.55, 0.52), metal=0.35, rough=0.3, seams=4, rivets=False, wear=0.6)
    M["tube"] = lpkit.worn("tube", (0.48, 0.47, 0.44), metal=0.35, rough=0.32, seams=3, rivets=False, wear=0.7)
    M["amber"] = lpkit.worn("amber", (0.55, 0.33, 0.1), metal=0.25, rough=0.62, seams=5, wear=0.8)
    M["cage"] = lpkit.worn("cage", (0.52, 0.31, 0.08), metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.85, streaks=0.6)
    M["rust"] = lpkit.worn("rust", (0.3, 0.13, 0.06), metal=0.15, rough=0.85, seams=7, wear=0.3, streaks=0.9)
    M["olive"] = lpkit.worn("olive", (0.17, 0.19, 0.1), metal=0.2, rough=0.7, seams=6, wear=0.6)
    M["canvas"] = lpkit.worn("canvas", (0.28, 0.25, 0.17), metal=0.0, rough=0.95, seams=10, rivets=False, wear=0.1)
    M["bright"] = lpkit.mat("bright", (0.85, 0.85, 0.8), metal=0.4, rough=0.2, grime=0.2)
    M["spring"] = lpkit.mat("spring", (0.7, 0.5, 0.08), metal=0.6, rough=0.4, grime=0.3)
    M["tread"] = lpkit.worn("tread", (0.12, 0.11, 0.1), metal=0.6, rough=0.55, seams=2, rivets=False, wear=0.9)
    M["plate"] = lpkit.worn("plate", (0.13, 0.13, 0.12), metal=0.55, rough=0.45, seams=2, rivets=False, wear=0.95, streaks=0.6)
    M["rust2"] = lpkit.worn("rust2", (0.22, 0.1, 0.05), metal=0.2, rough=0.8, seams=6, wear=0.4, streaks=0.9)
    M["amber_dull"] = lpkit.worn("amber_dull", (0.38, 0.24, 0.09), metal=0.25, rough=0.65, seams=5, wear=0.8)
    M["heat"] = lpkit.worn("heat", (0.18, 0.15, 0.22), metal=0.8, rough=0.3, seams=1.0, rivets=False, wear=0.5, streaks=0.8)
    M["rag"] = lpkit.mat("rag", (0.55, 0.12, 0.08), rough=0.95, grime=0.6)
    M["scraped"] = lpkit.worn("scraped", (0.42, 0.41, 0.38), metal=0.75, rough=0.32, seams=1.0, rivets=False, wear=0.4, streaks=0.9)
    M["tyre"] = lpkit.mat("tyre", (0.035, 0.034, 0.032), metal=0.0, rough=0.9, grime=0.4)
    M["dust"] = lpkit.mat("dust", (0.03, 0.029, 0.027), metal=0.0, rough=0.95, grime=0.5)
    for k in ("tyre", "dust"):
        M[k].node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.12
    M["rim"] = lpkit.worn("rim", (0.2, 0.2, 0.19), metal=0.6, rough=0.4, seams=3, rivets=False, wear=0.7)
    M["tarp"] = lpkit.worn("tarp", (0.14, 0.14, 0.09), metal=0.0, rough=0.95, seams=1.0, rivets=False, wear=0.2, streaks=0.7)
    M["glass"] = lpkit.mat("glass", (0.05, 0.07, 0.08), metal=0.2, rough=0.1, grime=0.2)
    M["lamp"] = lpkit.mat("lamp", (1.0, 0.85, 0.55), emit=(1.0, 0.8, 0.45), strength=4.0, grime=0.0)
    M["pilot"] = lpkit.mat("pilot", (1.0, 0.5, 0.15), emit=(1.0, 0.45, 0.1), strength=6.0, grime=0.0)
    M["tail"] = lpkit.mat("tail", (0.8, 0.1, 0.05), emit=(1.0, 0.12, 0.05), strength=3.0, grime=0.0)
    M["red"] = lpkit.worn("red", (0.36, 0.07, 0.04), metal=0.25, rough=0.6, seams=1.2, rivets=False, wear=0.8)
    M["yellow"] = lpkit.worn("yellow", (0.52, 0.38, 0.06), metal=0.2, rough=0.65, seams=1.2, rivets=False, wear=0.7)
    return scene

def obj():
    return bpy.context.object

def rod(p0, p1, r, m, verts=16):
    return lpkit.rod(p0, p1, r, m, verts=max(verts, 16))

def cyl(r, h, x, y, z, m, verts=32, bevel=0.0, rot=(0, 0, 0)):
    return lpkit.cyl(r, h, x, y, z, m, verts=verts if verts == 6 else max(verts, 32), bevel=bevel, rot=rot)

def box(sx, sy, sz, x, y, z, m, rot=0.0, bevel=0.01):
    return lpkit.box(sx, sy, sz, x, y, z, m, rot=rot, bevel=bevel)

def oriented(kind, loc, euler, scale, m, **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(location=loc, rotation=euler, **kw)
    o = obj(); o.scale = scale; o.data.materials.append(m); return o

def axle_cyl(r, w, x, y, z, m, verts=32, bevel=0.0, segs=2):
    """A cylinder on an axis across the vehicle (x), centred at (x, y, z)."""
    verts = verts if verts == 6 else max(verts, 32)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=w, location=(x, y, z), rotation=(0, math.pi / 2, 0))
    o = obj(); o.data.materials.append(m)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = segs
    return o

def spun(profile, x, y, z, m, steps=48, a0=None, a1=None):
    """A solid of revolution about an axle (x) at (y, z): profile is (axial offset, radius) points, a closed outline;
    all round, or from a0 to a1 (degrees from the front, +y, over the top) with its ends capped."""
    import bmesh
    me = bpy.data.meshes.new("spun"); bm = bmesh.new()
    t0 = 0.0 if a0 is None else math.radians(a0 - 90)
    vs = [bm.verts.new((a, -r * math.sin(t0), r * math.cos(t0))) for a, r in profile]
    for k in range(len(vs)):
        bm.edges.new((vs[k], vs[(k + 1) % len(vs)]))
    if a0 is not None:
        bm.faces.new(vs)
    sweep = 2 * math.pi if a0 is None else math.radians(a1 - a0)
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], cent=(0, 0, 0), axis=(1, 0, 0), angle=sweep,
                   steps=steps, use_merge=a0 is None)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("spun", me); scene.collection.objects.link(o); o.location = (x, y, z); me.materials.append(m)
    return o

def coil(p0, p1, r, turns, m, wire=0.012):
    """A coil spring from p0 to p1, a true helix, on its shaft."""
    a, b = mathutils.Vector(p0), mathutils.Vector(p1); d = b - a
    u = d.orthogonal().normalized(); v = d.normalized().cross(u)
    per = 20; n = turns * per
    cu = bpy.data.curves.new("coil", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = wire; cu.bevel_resolution = 3
    sp = cu.splines.new("POLY"); sp.points.add(n)
    for k in range(n + 1):
        t = k / n; ang = 2 * math.pi * k / per
        q = a + d * t + (u * math.cos(ang) + v * math.sin(ang)) * r
        sp.points[k].co = (q.x, q.y, q.z, 1)
    o = bpy.data.objects.new("coil", cu); scene.collection.objects.link(o); cu.materials.append(m)
    rod(p0, p1, r * 0.35, M["steel"])

def bolt(x, y, z, r=0.012, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=0.012, location=(x, y, z), rotation=rot)
    obj().data.materials.append(M["bright"])

def panel(pts, m, t=0.02, bevel=0.006):
    """A plate through the points (a polygon), t thick."""
    import bmesh
    me = bpy.data.meshes.new("panel"); bm = bmesh.new()
    bm.faces.new([bm.verts.new(v) for v in pts]); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("panel", me); scene.collection.objects.link(o); me.materials.append(m)
    sd = o.modifiers.new("s", "SOLIDIFY"); sd.thickness = t
    md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    return o

def group(fn):
    """The objects fn makes."""
    b4 = set(scene.objects); fn(); return [o for o in scene.objects if o not in b4]

def finish(grime=1.0, scale=13, mud=0.0, mud_top=0.5):
    """Grime on every material but the lamps; every mesh smooth, sharp past 35 degrees."""
    for m in bpy.data.materials:
        if m.name in GLOW_NAMES or not m.use_nodes:
            continue
        rubberish = m.name in ("tyre", "dust", "rubber")
        lpkit.dirty(m, dirt=(0.4 if rubberish else 0.8) * grime, dust=(0.0 if rubberish else 0.3) * grime,
                    rust=(0.0 if rubberish else 0.6) * grime, dirt_rgb=(0.035, 0.03, 0.02), scale=scale, mud=mud, mud_top=mud_top)
    for o in scene.objects:
        if o.type == "MESH":
            o.data.shade_smooth(); o.data.set_sharp_from_angle(angle=math.radians(35))

def light(tiles, margin):
    """Factorio's camera and sun, the light buggy.py measured against vanilla's car; returns (ground, sun, world)."""
    ground, sun, world = lpkit.stage(scene, tiles, margin)
    sun.data.energy = float(os.environ.get("LP_SUN", 5.5))
    scene.view_settings.look = os.environ.get("LP_LOOK", "High Contrast")
    return ground, sun, world

def rolling(wheels):
    """Wheels [(objects, hub)] each set on a hub of its own at its axle, for passes' rebuild to turn; returns
    (objects, hubs, rebuild). One turn forward over a cycle of F frames: rebuild(f, F)."""
    objs, hubs = [], []
    for wo, (hx, hy, hz) in wheels:
        hub = bpy.data.objects.new("hub", None); scene.collection.objects.link(hub); hub.location = (hx, hy, hz)
        bpy.context.view_layer.update()
        for o in wo:
            o.parent = hub; o.matrix_parent_inverse = hub.matrix_world.inverted()
        objs += wo; hubs.append(hub)
    def rebuild(f, F):
        for h in hubs: h.rotation_euler = (-2 * math.pi * f / F, 0, 0)
    return objs, hubs, rebuild

def passes(out, N, base, modules, animated=None, frames=1, rebuild=None, fill=0.04, light_rig=None, hubs=()):
    """Each direction: the base alone (body, glow); each module with the base a holdout (body, glow) and the shadow of base
    and module; the animated layer (rebuild(f) poses it for frame f) with the base a holdout, `frames` a direction.
    out/base, out/<module>, out/anim: one sheet.py run each. LP_ONLY=<part> renders that part alone."""
    ground, sun, world = light_rig
    bg = world.node_tree.nodes["Background"]
    only = os.environ.get("LP_ONLY")
    pivot = bpy.data.objects.new("pivot", None); scene.collection.objects.link(pivot)
    allobjs = base + [o for objs in modules.values() for o in objs] + (animated or [])
    on_hubs = {id(o) for o in allobjs if o.parent in hubs}
    for o in allobjs:
        if id(o) not in on_hubs:
            o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
    for h in hubs:                                                       # wheels on their hubs, the hubs on the pivot
        h.parent = pivot; h.matrix_parent_inverse = pivot.matrix_world.inverted()
    def lit(on):
        sun.hide_render = not on; bg.inputs[1].default_value = fill if on else 0.0
    def show(objs, on):
        for o in objs: o.hide_render = not on
    def glowing(o):
        return any(s.material and s.material.name in GLOW_NAMES for s in o.material_slots)
    parts = ["base"] + list(modules) + (["anim"] if animated else [])
    for p in parts:
        if not only or only == p:
            for k in ("body", "glow") + (("shadow",) if p in modules else ()):
                os.makedirs(f"{out}/{p}/{k}", exist_ok=True)
    for d in range(N):
        pivot.rotation_euler = (0, 0, -2 * math.pi * d / N)          # north first, clockwise seen from above
        ground.hide_render = True
        for objs in modules.values(): show(objs, False)
        if animated: show(animated, False)
        if not only or only == "base":
            for o in base: o.is_holdout = False
            lit(True); lpkit.render(scene, f"{out}/base/body/{d:03d}.png")
            for o in base: o.is_holdout = not glowing(o)
            lit(False); lpkit.render(scene, f"{out}/base/glow/{d:03d}.png")
        for name, objs in modules.items():
            if only and only != name:
                continue
            show(objs, True)
            for o in base: o.is_holdout = True
            for o in objs: o.is_holdout = False
            lit(True); lpkit.render(scene, f"{out}/{name}/body/{d:03d}.png")
            for o in objs: o.is_holdout = not glowing(o)
            lit(False); lpkit.render(scene, f"{out}/{name}/glow/{d:03d}.png")
            for o in base + objs: o.is_holdout = False; o.visible_camera = False
            if animated: show(animated, True); [setattr(o, "visible_camera", False) for o in animated]
            ground.hide_render = False; lit(True); lpkit.render(scene, f"{out}/{name}/shadow/{d:03d}.png")
            ground.hide_render = True
            for o in base + objs: o.visible_camera = True
            if animated: [setattr(o, "visible_camera", True) for o in animated]; show(animated, False)
            show(objs, False)
        if animated and (not only or only == "anim"):
            show(animated, True)
            for o in base: o.is_holdout = True
            for f in range(frames):
                rebuild(f)
                lit(True); lpkit.render(scene, f"{out}/anim/body/{d * frames + f:04d}.png")
                lit(False)
                for o in animated: o.is_holdout = True
                lpkit.render(scene, f"{out}/anim/glow/{d * frames + f:04d}.png")
                for o in animated: o.is_holdout = False
            show(animated, False)
    return pivot

def plated(p0, p1, p2, p3, mats, nx=3, ny=2, seed=1, layer=0.03, t=0.03, bolts_on=True, gap=0.014, inside=(0, 0, 0.6)):
    """A face (corners p0 bottom-left, p1 bottom-right, p2 top-right, p3 top-left) armoured with plates (the user,
    2026-11-08, on the first Killdozer: "Looks like a block of cheddar": six flat faces where vanilla's tank is a mosaic):
    an nx by ny grid of plates, each jittered in size and place, set out from the face in one of two layers so they
    overlap, a material drawn from mats (a list, repeats weighting it), bolt rows along their top and bottom edges, and a
    weld bead along each plate's top. Seeded: the same face renders the same."""
    import random
    rnd = random.Random(seed)
    P = [mathutils.Vector(p) for p in (p0, p1, p2, p3)]
    nrm = (P[1] - P[0]).cross(P[3] - P[0]).normalized()
    # Out of the solid whatever the corners' order (taken from it alone, half the faces' plates were built inside the
    # shell and never seen: the Killdozer's "dark and flat" sides). inside: a point inside the solid.
    if nrm.dot((P[0] + P[2]) / 2 - mathutils.Vector(inside)) < 0:
        nrm = -nrm
    def at(u, v, out):
        return (P[0].lerp(P[1], u)).lerp(P[3].lerp(P[2], u), v) + nrm * out
    for i in range(nx):
        for j in range(ny):
            u0 = (i + rnd.uniform(-0.12, 0.05)) / nx; u1 = (i + 1 + rnd.uniform(-0.05, 0.12)) / nx
            v0 = (j + rnd.uniform(-0.1, 0.05)) / ny; v1 = (j + 1 + rnd.uniform(-0.05, 0.1)) / ny
            u0, u1, v0, v1 = max(0, u0) + gap, min(1, u1) - gap, max(0, v0) + gap, min(1, v1) - gap
            # (Two heights alternating with the colours made a checkerboard, the user: "a little exaggerated": random.)
            out = layer * rnd.choice((1.0, 1.4, 1.9))
            m = mats[rnd.randrange(len(mats))]
            # (Standing a centimetre proud, the plates cast no lines and the face read as one mass, the second Killdozer:
            # proud by a plate's thickness and more, their edges bevelled to catch the light.)
            panel([tuple(at(u0, v0, out)), tuple(at(u1, v0, out)), tuple(at(u1, v1, out)), tuple(at(u0, v1, out))], m, t=t,
                  bevel=0.012)
            if bolts_on:
                for v in (v0 + 0.06, v1 - 0.06):
                    n = max(2, int((u1 - u0) * 8))
                    for k in range(n):
                        q = at(u0 + (u1 - u0) * (k + 0.5) / n, v, out + t + 0.004)
                        bolt(q.x, q.y, q.z, r=0.011, rot=nrm.to_track_quat("Z", "Y").to_euler())
            a, b = at(u0, v1, out + t * 0.5), at(u1, v1, out + t * 0.5)
            rod(tuple(a), tuple(b), 0.007, M["bright"])


def wheel(x, y, side, WR, WT):
    """A pneumatic wheel (buggy.py's, the user's "real pneumatic, with the metal rim and bolts"): a tyre spun from its
    section, tread blocks in two staggered rows, a rim barrel with flanges, a disc with vent holes, the hub with six
    nuts and a domed cap. Its axle across (x), at (x, y), the ground at z 0; side: which face is outward (-1, 1)."""
    h, RR = WT / 2, WR * 0.62
    sec = [(-h + 0.02, RR), (-h - 0.005, RR + 0.04), (-h - 0.012, RR + 0.1), (-h - 0.006, WR - 0.06), (-h + 0.02, WR - 0.015),
           (-h + 0.06, WR), (h - 0.06, WR), (h - 0.02, WR - 0.015), (h + 0.006, WR - 0.06), (h + 0.012, RR + 0.1),
           (h + 0.005, RR + 0.04), (h - 0.02, RR)]
    spun(sec, x, y, WR, M["tyre"])
    n = 24
    for row, off in ((-1, 0.0), (1, 0.5)):
        for k in range(n):
            a = (k + off) * 2 * math.pi / n
            loc = (x + row * WT * 0.16, y + math.cos(a) * (WR - 0.006), WR + math.sin(a) * (WR - 0.006))
            o = oriented("cube", loc, (a - math.pi / 2, 0, 0), (WT * 0.3, 0.05, 0.014), M["dust"], size=1)
            md = o.modifiers.new("b", "BEVEL"); md.width = 0.006; md.segments = 2
    spun([(-h + 0.02, RR - 0.03), (-h + 0.02, RR + 0.005), (h - 0.02, RR + 0.005), (h - 0.02, RR - 0.03)], x, y, WR, M["rim"])
    for sd in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=RR + 0.004, minor_radius=0.011, location=(x + sd * (h - 0.02), y, WR),
                                         rotation=(0, math.pi / 2, 0), major_segments=40, minor_segments=8)
        obj().data.materials.append(M["rim"])
    ox = x + side * (h - 0.06)
    axle_cyl(RR - 0.01, 0.012, ox, y, WR, M["rim"], verts=40)
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        axle_cyl(0.022, 0.014, ox + side * 0.001, y + math.cos(a) * RR * 0.66, WR + math.sin(a) * RR * 0.66, M["dark"])
    axle_cyl(RR * 0.42, 0.04, ox + side * 0.02, y, WR, M["rim"], bevel=0.006)
    for k in range(6):
        a = k * math.pi / 3
        axle_cyl(0.013, 0.03, ox + side * 0.045, y + math.cos(a) * RR * 0.28, WR + math.sin(a) * RR * 0.28, M["bright"], verts=6)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=RR * 0.18, location=(ox + side * 0.045, y, WR), segments=16, ring_count=8)
    o = obj(); o.scale = (0.6, 1, 1); o.data.materials.append(M["steel"])


def blur_mat(name, rgb, alpha, streaks=6.0):
    """(harrier.py's; its rotors.) A disc of motion blur: the colour at `alpha`, faint radial streaks (a wave texture round its centre)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]; L = nt.links.new
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = 0.6
    tc = nt.nodes.new("ShaderNodeTexCoord"); gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = "RADIAL"
    L(tc.outputs["Object"], gr.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMath"); mr.operation = "MULTIPLY"; mr.inputs[1].default_value = streaks; L(gr.outputs["Fac"], mr.inputs[0])
    fr = nt.nodes.new("ShaderNodeMath"); fr.operation = "FRACT"; L(mr.outputs[0], fr.inputs[0])
    rmp = nt.nodes.new("ShaderNodeMapRange"); rmp.inputs["From Min"].default_value = 0.0; rmp.inputs["From Max"].default_value = 0.25
    rmp.inputs["To Min"].default_value = alpha * 1.6; rmp.inputs["To Max"].default_value = alpha * 0.8
    L(fr.outputs[0], rmp.inputs["Value"])
    L(rmp.outputs["Result"], b.inputs["Alpha"])
    return m


def char(m, burn=0.78):
    """A material burnt: its colour pulled to soot in patches (noise), a little rust showing through, rougher."""
    if not m.use_nodes:
        return
    nt = m.node_tree; b = nt.nodes.get("Principled BSDF")
    if not b:
        return
    inp = b.inputs["Base Color"]; L = nt.links.new
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 7.0; n.inputs["Detail"].default_value = 8
    L(tc.outputs["Object"], n.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeMapRange"); r.inputs["From Min"].default_value = 0.35; r.inputs["From Max"].default_value = 0.6
    r.inputs["To Min"].default_value = burn; r.inputs["To Max"].default_value = burn * 0.55; L(n.outputs["Fac"], r.inputs["Value"])
    x = nt.nodes.new("ShaderNodeMix"); x.data_type = "RGBA"
    if inp.links:
        L(inp.links[0].from_socket, x.inputs["A"])
    else:
        x.inputs["A"].default_value = inp.default_value
    x.inputs["B"].default_value = (0.035, 0.028, 0.022, 1); L(r.outputs["Result"], x.inputs["Factor"])
    L(x.outputs["Result"], inp)
    b.inputs["Roughness"].default_value = 0.85; b.inputs["Metallic"].default_value = 0.2

def wreck(objs, out, seed=1, lose=0.35, thrown=0.35, keep=(), tilt=(4, -3), sink=0.06, N=4, tiles=3, margin=1.2,
          strip=None, scorch=1.8, soot=0.85, fade=0.18):
    """A unit's wreck (a corpse's picture, as vanilla's car and tank remnants: N directions, the shadow in the picture):
    every material charred, a share of the small parts lost and a share thrown onto the ground round it (seeded; the
    largest and those named in keep stay), thin uprights (whips, masts) gone, the objects strip(o) says gone (a run of
    track), the rest slumped (tilted, sunk), glows dark, a scorch on the ground under it; rendered with the ground's
    shadow, out/wreck/body/NNN.png, for sheet.py. (Charred alone, the first dozer's read as a dark dozer, not a wreck.)"""
    import random
    rnd = random.Random(seed)
    for m in bpy.data.materials:
        if m.name in GLOW_NAMES:
            m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.0
        char(m, burn=0.9)
    # Whatever glowed or held a charge is gone with its power (the Tesla's arc, a running light), and the Prism's crystals
    # shattered (on the first wrecks the arc still crackled and the crystals stood whole).
    for o in objs:
        if any(sl.material and (sl.material.name in GLOW_NAMES or sl.material.name == "kcrystal") for sl in o.material_slots):
            o.hide_render = True
    sized = sorted(objs, key=lambda o: o.dimensions.length)
    small = sized[: int(len(sized) * 0.7)]
    debris = []
    for o in objs:
        dx, dy, dz = o.dimensions
        if (dz > 0.45 and max(dx, dy) < 0.06) or (strip and strip(o)):
            o.hide_render = True
    for o in small:
        if o.name in keep or o.hide_render:
            continue
        r = rnd.random()
        if r < lose:
            o.hide_render = True
        elif r < lose + thrown and o.dimensions.length < 0.5:
            debris.append(o)
    for o in debris:                                                     # onto the ground round it
        a = rnd.uniform(0, 2 * math.pi); d = rnd.uniform(0.9, 1.5)
        o.parent = None
        o.location = (math.cos(a) * d, math.sin(a) * d * 1.2, o.dimensions.z * 0.3)
        o.rotation_mode = "XYZ"; o.rotation_euler = (rnd.uniform(-1.2, 1.2), rnd.uniform(-1.2, 1.2), rnd.uniform(0, 6.28))
    # The scorch: a soot disc on the ground, its edge broken by noise, fading out.
    if scorch:
        bpy.ops.mesh.primitive_circle_add(vertices=64, radius=scorch, fill_type="NGON", location=(0, 0, 0.004))
        sc = obj(); sc.scale = (1.0, 1.25, 1.0)
        m = bpy.data.materials.new("scorch"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]; L = nt.links.new
        b.inputs["Base Color"].default_value = (0.03, 0.025, 0.02, 1); b.inputs["Roughness"].default_value = 1.0
        # (The gradient on object coordinates ends a tile out whatever the disc's size, under the hull: scaled to it.)
        tc = nt.nodes.new("ShaderNodeTexCoord"); gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = "SPHERICAL"
        mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1 / scorch, 1 / scorch, 1)
        L(tc.outputs["Object"], mp.inputs["Vector"]); L(mp.outputs["Vector"], gr.inputs["Vector"])
        nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; L(tc.outputs["Object"], nz.inputs["Vector"])
        mx = nt.nodes.new("ShaderNodeMath"); mx.operation = "MULTIPLY"; L(gr.outputs["Fac"], mx.inputs[0]); L(nz.outputs["Fac"], mx.inputs[1])
        # (Faded from 0.05 to 0.4 it hardly showed beyond the hull, the first: it reaches out, darker.)
        rr = nt.nodes.new("ShaderNodeMapRange"); rr.inputs["From Min"].default_value = 0.0; rr.inputs["From Max"].default_value = fade
        rr.inputs["To Min"].default_value = 0.0; rr.inputs["To Max"].default_value = soot; L(mx.outputs[0], rr.inputs["Value"])
        L(rr.outputs["Result"], b.inputs["Alpha"])
        sc.data.materials.append(m)
    pivot = bpy.data.objects.new("wreck_pivot", None); scene.collection.objects.link(pivot)
    for o in objs:
        o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
    ground, sun, world = light(tiles, margin)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.04          # the passes' fill
    os.makedirs(f"{out}/wreck/body", exist_ok=True)
    for d in range(N):
        pivot.rotation_euler = (math.radians(tilt[0]), math.radians(tilt[1]), -2 * math.pi * d / N)
        pivot.location = (0, 0, -sink)
        ground.hide_render = False
        lpkit.render(scene, f"{out}/wreck/body/{d:03d}.png")
    return pivot


def tracks(TX, TW, IDL, SPR, frames=4, pitch=0.11):
    """Two runs of track shoes round the idler IDL and the sprocket SPR (each (y, z, radius)), TX out from the middle,
    TW wide (crawler.py's, for the kit's tracked vehicles). Returns (shoes, pose): pose(f) moves every shoe f / frames
    of a pitch along its loop, the bottom run going rearward, so `frames` loop seamlessly."""
    (yi, zi, ri), (ys, zs, rs) = IDL, SPR
    ri += 0.02; rs += 0.02
    pts, steps = [], 200
    for k in range(steps):
        f = k / steps; pts.append((yi + (ys - yi) * f, (zi - ri) + ((zs - rs) - (zi - ri)) * f))
    for k in range(steps):
        a = math.radians(270 - 180 * k / steps); pts.append((ys + math.cos(a) * rs, zs + math.sin(a) * rs))
    for k in range(steps):
        f = k / steps; pts.append((ys + (yi - ys) * f, (zs + rs) + ((zi + ri) - (zs + rs)) * f))
    for k in range(steps):
        a = math.radians(90 - 180 * k / steps); pts.append((yi + math.cos(a) * ri, zi + math.sin(a) * ri))
    seg = [math.dist(pts[k], pts[(k + 1) % len(pts)]) for k in range(len(pts))]
    L = sum(seg); n = int(L / pitch); P = L / n
    def at(s):
        s %= L; k = 0
        while s > seg[k]:
            s -= seg[k]; k += 1
        (y0, z0), (y1, z1) = pts[k], pts[(k + 1) % len(pts)]
        f = s / seg[k]
        return (y0 + (y1 - y0) * f, z0 + (z1 - z0) * f), math.atan2(z1 - z0, y1 - y0)
    a = box(TW, P * 0.86, 0.026, 0, 0, -0.013, M["tread"], bevel=0.004)
    b = box(TW * 0.96, 0.02, 0.022, 0, 0, 0.013, M["steel"], bevel=0.003)
    bpy.ops.object.select_all(action="DESELECT"); a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a; bpy.ops.object.join()
    shoes = []
    for sx in (-1, 1):
        for k in range(n):
            o = a.copy(); scene.collection.objects.link(o); shoes.append((o, sx, k))
    bpy.data.objects.remove(a)
    def pose(f):
        for o, sx, k in shoes:
            (y, z), ang = at((k + f / frames) * P)
            o.location = (sx * TX, y, z); o.rotation_euler = (ang, 0, 0)
    pose(0)
    return [o for o, _, _ in shoes], pose

def kh_palette():
    """Kessler-Hayashi's materials into M (its buildings' worn palette, tools/blender/lpkit.py: slate teal, dull hazard,
    lighter steel; the user, 2026-11-04, its gray had read as concrete): a contractor's kit, maintained, not scrap."""
    P = lpkit.palette_worn()
    # (Its buildings' slate teal came out pale and plastic on a unit under the units' strong sun, the first tank: darker,
    # three close shades for its plates, as the crawler's rusts.)
    M["kpaint"] = lpkit.worn("kpaint", (0.065, 0.14, 0.18), metal=0.3, rough=0.5, seams=5, wear=0.7)
    M["kpaint2"] = lpkit.worn("kpaint2", (0.05, 0.11, 0.145), metal=0.3, rough=0.55, seams=5, wear=0.7)
    M["kpaint3"] = lpkit.worn("kpaint3", (0.08, 0.13, 0.15), metal=0.35, rough=0.5, seams=5, wear=0.7)
    M["khazard"] = P["hazard"]
    M["kdark"] = lpkit.worn("kdark", (0.05, 0.06, 0.065), metal=0.5, rough=0.5, seams=4, rivets=False)
    M["kglow"] = lpkit.mat("kglow", (0.5, 0.9, 1.0), emit=(0.45, 0.85, 1.0), strength=3.0, grime=0.0)
    M["kwhite"] = lpkit.worn("kwhite", (0.6, 0.62, 0.6), metal=0.2, rough=0.5, seams=6, rivets=False, wear=0.5)
    # Graphite for its running gear, skirts and roof modules, a second colour (all teal was "a little too uniformly teal").
    M["kgraph"] = lpkit.worn("kgraph", (0.07, 0.075, 0.08), metal=0.45, rough=0.5, seams=4, rivets=False, wear=0.8)
    M["kwood"] = lpkit.mat("kwood", (0.3, 0.2, 0.11), rough=0.8, grime=0.5)
    # The Prism's crystal: dark violet glass, a lit core (its beam's colour in the game).
    M["copper"] = lpkit.worn("copper_w", (0.55, 0.3, 0.14), metal=0.85, rough=0.35, seams=12, rivets=False, wear=0.4, streaks=0.3)
    M["kcrystal"] = lpkit.mat("kcrystal", (0.2, 0.08, 0.3), metal=0.1, rough=0.08, grime=0.0)
    M["kviolet"] = lpkit.mat("kviolet", (0.85, 0.45, 1.0), emit=(0.85, 0.45, 1.0), strength=5.0, grime=0.0)
    M["kglow_soft"] = lpkit.mat("kglow_soft", (0.3, 0.75, 1.0), emit=(0.3, 0.75, 1.0), strength=1.2, grime=0.0)
    GLOW_NAMES.add("kglow"); GLOW_NAMES.add("kviolet"); GLOW_NAMES.add("kglow_soft")
