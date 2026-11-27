"""The player's orbital cannon, the big one (the user, 2026-11-10: "structures you build on the side of a platform,
pointing down? Something big is needed"; then, of a first box-built try: "That cannon looks terrible. Why are we
settling"). The railgun spine of three clay outlines (cannon_concepts.py): Space Age's railgun turret's family, ten times
its mass. 8 by 12 tiles on the deck at the platform's edge, its barrel out over the void 11 tiles more, dipping toward
the planet.

Its parts, north (the barrel's way, +y here):
- a plinth of armour plate with chamfered corners, inset panels, bolt rows and four anchor clamps biting the deck;
- two wedge trunnion cheeks either side of the barrel's root, panelled, the barrel's pivot drums between them;
- the breech and capacitor body behind: a faceted armoured hull, vent banks lit cyan, corrugated copper hoses and pipe
  bundles looping from it to the cheeks (the vanilla railgun's and the silo's language);
- the barrel: one lofted, tapered, chamfered box section with seams, a recessed rail slot along its top lit inside, and
  copper coil packs between armour ribs down both sides, lit in turn as it charges; a heavy vented muzzle shroud;
- hydraulic rams from the plinth to the barrel's belly.
Materials: gunmetal darkened by ambient occlusion in the crevices and lightened at worn edges (pointiness), a little
rust; oxidised copper; a few hazard bands. Rendered in four directions: the body once, the glow GLOW_FRAMES times, a shadow.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/orbital_cannon.py -- <out_dir>
    then: uv run --with pillow python tools/blender/cannon_sheets.py <out_dir> landing-party-graphics/graphics/player/orbital-cannon
LP_DIRS=north LP_FRAMES=1 LP_SAMPLES=24 for a look.
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, mathutils
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
GLOW_FRAMES = int(os.environ.get("LP_FRAMES", 8))
DIRS = os.environ.get("LP_DIRS", "north,east,south,west").split(",")
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
V = mathutils.Vector
FRONT, REACH = 6, 11
CYAN = (0.45, 0.85, 1.0)

# --- Materials --------------------------------------------------------------------------------------------------
def grime(name, rgb, edge, metal=0.75, rough=(0.38, 0.62), dirt=0.55, rust=0.0, noise_scale=6.0, rust_rgb=(0.24, 0.11, 0.05)):
    """A base colour worn lighter at edges (pointiness) and darker in crevices (ambient occlusion), its value and roughness
    broken by noise, rust in streaks if asked."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    p = n["Principled BSDF"]
    p.inputs["Metallic"].default_value = metal
    geo = n.new("ShaderNodeNewGeometry")
    ao = n.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6; ao.samples = 8
    tex = n.new("ShaderNodeTexCoord")
    noise = n.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = noise_scale; noise.inputs["Detail"].default_value = 8
    l.new(tex.outputs["Object"], noise.inputs["Vector"])
    # Edge wear from the bevel shader: where its rounded normal leaves the true one (an edge), lift toward `edge`. (Not
    # pointiness: a vertex value spread over each face, so a long face whose only vertices sit on its convex edges read as
    # an edge all over, and the barrel came out pale grey; 2026-11-10.)
    bv = n.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.05; bv.samples = 6
    dot = n.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    l.new(bv.outputs["Normal"], dot.inputs[0]); l.new(geo.outputs["Normal"], dot.inputs[1])
    em = n.new("ShaderNodeMapRange"); em.inputs["From Min"].default_value = 0.995; em.inputs["From Max"].default_value = 0.9
    l.new(dot.outputs["Value"], em.inputs["Value"])
    # (Broken by the noise: worn in patches, not a painted line.)
    ew = n.new("ShaderNodeMath"); ew.operation = "MULTIPLY"
    l.new(em.outputs["Result"], ew.inputs[0]); l.new(noise.outputs["Fac"], ew.inputs[1])
    er = n.new("ShaderNodeMath"); er.operation = "MULTIPLY"; er.inputs[1].default_value = 1.6; er.use_clamp = True
    l.new(ew.outputs[0], er.inputs[0])
    mix_edge = n.new("ShaderNodeMix"); mix_edge.data_type = "RGBA"
    mix_edge.inputs[6].default_value = (*rgb, 1); mix_edge.inputs[7].default_value = (*edge, 1)
    l.new(er.outputs[0], mix_edge.inputs[0])
    # Value noise: +-15%.
    vr = n.new("ShaderNodeMapRange"); vr.inputs["To Min"].default_value = 0.85; vr.inputs["To Max"].default_value = 1.15
    l.new(noise.outputs["Fac"], vr.inputs["Value"])
    mul = n.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 1
    l.new(mix_edge.outputs[2], mul.inputs[6])
    comb = n.new("ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"): l.new(vr.outputs["Result"], comb.inputs[k])
    l.new(comb.outputs["Color"], mul.inputs[7])
    col = mul.outputs[2]
    if rust > 0:
        wave = n.new("ShaderNodeTexNoise"); wave.inputs["Scale"].default_value = 2.5; wave.inputs["Detail"].default_value = 3
        mapping = n.new("ShaderNodeMapping"); mapping.inputs["Scale"].default_value = (3, 3, 0.4)
        l.new(tex.outputs["Object"], mapping.inputs["Vector"]); l.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        rr = n.new("ShaderNodeValToRGB"); rr.color_ramp.elements[0].position = 0.5; rr.color_ramp.elements[1].position = 0.72
        l.new(wave.outputs["Fac"], rr.inputs["Fac"])
        rm = n.new("ShaderNodeMath"); rm.operation = "MULTIPLY"; rm.inputs[1].default_value = rust
        l.new(rr.outputs["Color"], rm.inputs[0])
        mr = n.new("ShaderNodeMix"); mr.data_type = "RGBA"; mr.inputs[7].default_value = (*rust_rgb, 1)
        l.new(rm.outputs[0], mr.inputs[0]); l.new(col, mr.inputs[6]); col = mr.outputs[2]
    # Dirt in the crevices: AO multiplies toward a dark brown.
    dr = n.new("ShaderNodeMapRange"); dr.inputs["From Min"].default_value = 0.0; dr.inputs["From Max"].default_value = 1.0
    dr.inputs["To Min"].default_value = dirt; dr.inputs["To Max"].default_value = 0.0
    l.new(ao.outputs["AO"], dr.inputs["Value"])
    md = n.new("ShaderNodeMix"); md.data_type = "RGBA"; md.inputs[7].default_value = (0.05, 0.03, 0.015, 1)
    l.new(dr.outputs["Result"], md.inputs[0]); l.new(col, md.inputs[6])
    l.new(md.outputs[2], p.inputs["Base Color"])
    # Micro texture that catches the light: fine scratches and dents (vanilla's metal is never smooth).
    fine = n.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 45; fine.inputs["Detail"].default_value = 4
    l.new(tex.outputs["Object"], fine.inputs["Vector"])
    vor = n.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 9
    l.new(tex.outputs["Object"], vor.inputs["Vector"])
    bsum = n.new("ShaderNodeMath"); bsum.operation = "ADD"
    l.new(fine.outputs["Fac"], bsum.inputs[0]); l.new(vor.outputs["Distance"], bsum.inputs[1])
    bump = n.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.12; bump.inputs["Distance"].default_value = 0.02
    l.new(bsum.outputs[0], bump.inputs["Height"]); l.new(bump.outputs["Normal"], p.inputs["Normal"])
    rmr = n.new("ShaderNodeMapRange"); rmr.inputs["To Min"].default_value = rough[0]; rmr.inputs["To Max"].default_value = rough[1]
    l.new(noise.outputs["Fac"], rmr.inputs["Value"]); l.new(rmr.outputs["Result"], p.inputs["Roughness"])
    return m

TEX = os.path.expanduser(os.environ.get("LP_TEX", "~/lp-tex"))
def textured(name, tex, hue=None, sat=1.0, val=1.0, scale=0.6, edge=(0.5, 0.5, 0.5), dirt=0.85, normal=0.7, rough_add=0.0):
    """A CC0 material set (ambientCG, in LP_TEX: <tex>/<tex>_2K-JPG_<map>.jpg) box-projected from the object's own
    coordinates (no UVs needed), recoloured by hue/sat/val, its edges worn lighter (the bevel shader) and its crevices
    dirtied (ambient occlusion): procedural noise alone read as a CG render beside Space Age's art (the user, 2026-11-10)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    p = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord"); mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (scale, scale, scale)
    l.new(tc.outputs["Object"], mp.inputs["Vector"])
    def img(kind, color=False):
        path = f"{TEX}/{tex}/{tex}_2K-JPG_{kind}.jpg"
        if not os.path.exists(path): return None
        t = n.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(path, check_existing=True)
        t.projection = "BOX"; t.projection_blend = 0.25
        if not color: t.image.colorspace_settings.name = "Non-Color"
        l.new(mp.outputs["Vector"], t.inputs["Vector"])
        return t
    col = img("Color", True).outputs["Color"]
    if hue is not None or sat != 1.0 or val != 1.0:
        hs = n.new("ShaderNodeHueSaturation")
        hs.inputs["Hue"].default_value = hue if hue is not None else 0.5
        hs.inputs["Saturation"].default_value = sat; hs.inputs["Value"].default_value = val
        l.new(col, hs.inputs["Color"]); col = hs.outputs["Color"]
    mt = img("Metalness")
    if mt: l.new(mt.outputs["Color"], p.inputs["Metallic"])
    rg = img("Roughness")
    if rg:
        ra = n.new("ShaderNodeMath"); ra.operation = "ADD"; ra.inputs[1].default_value = rough_add; ra.use_clamp = True
        l.new(rg.outputs["Color"], ra.inputs[0]); l.new(ra.outputs[0], p.inputs["Roughness"])
    nm = img("NormalGL")
    if nm:
        nmap = n.new("ShaderNodeNormalMap"); nmap.inputs["Strength"].default_value = normal
        l.new(nm.outputs["Color"], nmap.inputs["Color"]); l.new(nmap.outputs["Normal"], p.inputs["Normal"])
    # Edge wear (the bevel shader's normal leaving the true one), broken in patches by the texture's own value.
    geo = n.new("ShaderNodeNewGeometry")
    bv = n.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.05; bv.samples = 6
    dot = n.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    l.new(bv.outputs["Normal"], dot.inputs[0]); l.new(geo.outputs["Normal"], dot.inputs[1])
    em = n.new("ShaderNodeMapRange"); em.inputs["From Min"].default_value = 0.995; em.inputs["From Max"].default_value = 0.92
    l.new(dot.outputs["Value"], em.inputs["Value"])
    me = n.new("ShaderNodeMix"); me.data_type = "RGBA"; me.inputs[7].default_value = (*edge, 1)
    l.new(em.outputs["Result"], me.inputs[0]); l.new(col, me.inputs[6]); col = me.outputs[2]
    ao = n.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6; ao.samples = 8
    dr = n.new("ShaderNodeMapRange"); dr.inputs["To Min"].default_value = dirt; dr.inputs["To Max"].default_value = 0.0
    l.new(ao.outputs["AO"], dr.inputs["Value"])
    md = n.new("ShaderNodeMix"); md.data_type = "RGBA"; md.inputs[7].default_value = (0.05, 0.03, 0.015, 1)
    l.new(dr.outputs["Result"], md.inputs[0]); l.new(col, md.inputs[6])
    l.new(md.outputs[2], p.inputs["Base Color"])
    return m

def glow_mat(name, strength=0.0):
    return lpkit.mat(name, (0.2, 0.25, 0.28), metal=0.3, rough=0.4, emit=CYAN, strength=strength, grime=0.0)

GUN = grime("gunmetal", (0.12, 0.12, 0.125), (0.42, 0.41, 0.39), metal=0.45, rough=(0.45, 0.7), rust=0.55, dirt=0.9)
DARK = grime("darkmetal", (0.05, 0.05, 0.055), (0.22, 0.22, 0.22), rough=(0.45, 0.7), dirt=0.4)
PLATE = grime("plate", (0.11, 0.105, 0.1), (0.4, 0.38, 0.35), metal=0.7, rough=(0.4, 0.65), rust=0.8, noise_scale=3.0, dirt=0.9)
COPPER = grime("copper", (0.24, 0.12, 0.06), (0.5, 0.33, 0.2), metal=0.7, rough=(0.5, 0.75), dirt=0.85, rust=0.7, rust_rgb=(0.16, 0.27, 0.21))
PAINT = grime("paint", (0.075, 0.115, 0.14), (0.4, 0.4, 0.38), metal=0.25, rough=(0.55, 0.8), rust=0.6, dirt=0.9,
              noise_scale=4.0)
HOSE = grime("hose", (0.17, 0.09, 0.05), (0.42, 0.27, 0.16), metal=0.6, rough=(0.5, 0.75), dirt=0.9, rust=0.5, rust_rgb=(0.09, 0.08, 0.07))
HAZ = grime("hazard", (0.55, 0.42, 0.08), (0.7, 0.62, 0.35), metal=0.2, rough=(0.5, 0.7), dirt=0.6, rust=0.3)
if os.path.isdir(TEX):
    GUN = textured("gunmetal", "Metal038", val=0.55, scale=0.7, edge=(0.42, 0.41, 0.39), rough_add=0.15)
    # Hazard yellow as paint: chipped, faded, matte over bare steel (PaintedMetal004's red turned to yellow); as a shiny
    # metal it read as brass, and beside the black, a luxury item's gold (the user, 2026-11-10). Sparingly: the muzzle band
    # and small warning plates; rails, cages and valve wheels are steel.
    HAZ = textured("hazard", "PaintedMetal004", hue=0.66, sat=0.55, val=0.62, scale=0.6, edge=(0.4, 0.39, 0.36), rough_add=0.2)
    DARK = textured("darkmetal", "Metal038", val=0.42, sat=0.6, scale=0.8, edge=(0.3, 0.3, 0.29), dirt=0.7, rough_add=0.28)
    PLATE = textured("plate", "MetalPlates013", val=0.7, scale=0.45, edge=(0.42, 0.4, 0.37))
    # (The chipped paint's green turned to the platform's blue-grey; its rust and bare scratches kept.)
    PAINT = textured("paint", "PaintedMetal006", hue=0.58, sat=0.45, val=0.55, scale=0.5, edge=(0.4, 0.4, 0.38))
GLOW = glow_mat("glow", 1.2)
ARC = lpkit.mat("arc", (0.8, 0.95, 1.0), emit=(0.7, 0.92, 1.0), strength=12.0, grime=0.0)
SCALE = 1.5            # the whole, 12 by 18 tiles (the user: "This needs a big footprint")

def winding(name):
    """Copper wound round a torus: the radial angle about its axis in stripes, as a bump (its windings)."""
    m = grime(name, (0.26, 0.13, 0.06), (0.52, 0.34, 0.2), metal=0.7, rough=(0.45, 0.7), dirt=0.9, rust=0.7, rust_rgb=(0.16, 0.27, 0.21))
    nt = m.node_tree; n_ = nt.nodes; l = nt.links
    tex = n_.new("ShaderNodeTexCoord"); grad = n_.new("ShaderNodeTexGradient"); grad.gradient_type = "RADIAL"
    l.new(tex.outputs["Object"], grad.inputs["Vector"])
    mul = n_.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 2 * math.pi * 90
    l.new(grad.outputs["Fac"], mul.inputs[0])
    sin = n_.new("ShaderNodeMath"); sin.operation = "SINE"; l.new(mul.outputs[0], sin.inputs[0])
    bump = n_.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6; bump.inputs["Distance"].default_value = 0.03
    l.new(sin.outputs[0], bump.inputs["Height"])
    l.new(bump.outputs["Normal"], n_["Principled BSDF"].inputs["Normal"])
    return m
WIND = winding("winding")
SLOT = glow_mat("slot", 0.6)

# --- Builders ---------------------------------------------------------------------------------------------------
FIXED = set()          # what stays when the barrel recoils, whatever its place (the rams, the kitbashed props)
PROPS = os.path.expanduser(os.environ.get("LP_PROPS", "~/lp-props"))
_props = {}
def prop(name, asset):
    """A copy of a Poly Haven model's object (CC0, tools/blender/polyhaven_get.py), its materials with it; None without it."""
    path = f"{PROPS}/{asset}/{asset}_1k.blend"
    if not os.path.exists(path): return None
    key = (asset, name)
    if key not in _props:
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [name] if name in src.objects else []
        objs = [o for o in dst.objects if o]
        if not objs: return None
        _props[key] = objs[0]
        base = objs[0]
        # Toned into the cannon's palette: their red bottles and white boxes read as a dollhouse's pasted on (the first
        # look); desaturated and darkened, a little dirtier.
        for slot in base.material_slots:
            m = slot.material
            if not m or not m.use_nodes or m.get("lp_toned"): continue
            nt = m.node_tree
            bsdf = next((x for x in nt.nodes if x.type == "BSDF_PRINCIPLED"), None)
            if not bsdf or not bsdf.inputs["Base Color"].is_linked: continue
            link = bsdf.inputs["Base Color"].links[0]
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Saturation"].default_value = 0.45; hs.inputs["Value"].default_value = 0.6
            nt.links.new(link.from_socket, hs.inputs["Color"]); nt.links.new(hs.outputs["Color"], bsdf.inputs["Base Color"])
            m["lp_toned"] = True
        base.parent = None
        scene.collection.objects.link(base)
        FIXED.add(base)
        return base
    o = _props[key].copy(); scene.collection.objects.link(o)
    FIXED.add(o)
    return o

def obj_from_bm(bm, name, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); me.materials.append(m)
    return o

def bevel(o, w=0.04, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"
    md.harden_normals = True
    return o

def panelled(sx, sy, sz, x, y, z, m, inset=0.12, depth=0.035, rot=(0, 0, 0), min_face=0.5, taper=1.0, soft=0.03):
    """A box whose large faces carry an inset panel (a seam line round each), optionally tapered at its top (a wedge)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co.x *= sx; v.co.y *= sy; v.co.z *= sz
        if v.co.z > 0: v.co.x *= taper
        v.co.z += sz / 2
    big = [f for f in bm.faces if f.calc_area() >= min_face]
    bmesh.ops.inset_individual(bm, faces=big, thickness=inset, depth=-depth)
    o = obj_from_bm(bm, "panel", m)
    o.location = (x, y, z); o.rotation_euler = rot
    # (Soft: Space Age's forms are rolled, not cut; a wide bevel of many segments, the panels' seams kept.)
    return bevel(o, soft, 2 if soft <= 0.05 else 6)

def bolts(p0, p1, n, m=None, r=0.06):
    for k in range(n):
        t = (k + 0.5) / n
        p = [p0[i] + (p1[i] - p0[i]) * t for i in range(3)]
        lpkit.cyl(r, 0.05, p[0], p[1], p[2], m or DARK, verts=8)

def hose(points, r, m=None, rib=0.085):
    """A corrugated hose along a Catmull-Rom curve through points: tori a rib apart, on a core."""
    m = m or HOSE
    pts = [V(p) for p in points]
    def at(t):
        n = len(pts) - 1; i = min(int(t * n), n - 1); u = t * n - i
        p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, n)]
        return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)
    L = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))
    n = max(4, int(L / rib))
    for k in range(n + 1):
        t = k / n
        p = at(t); d = (at(min(1, t + 0.01)) - at(max(0, t - 0.01))).normalized()
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 0.92, minor_radius=r * 0.2, location=p, major_segments=20, minor_segments=6)
        o = bpy.context.object; o.rotation_mode = "QUATERNION"; o.rotation_quaternion = d.to_track_quat("Z", "Y")
        o.data.materials.append(m)
    for i in range(24):
        a, b = at(i / 24), at((i + 1) / 24)
        lpkit.rod(tuple(a), tuple(b), r * 0.88, m, verts=12)

def pipe(points, r, m=GUN, flanges=True):
    for a, b in zip(points, points[1:]):
        lpkit.rod(a, b, r, m, verts=12)
        lpkit.sphere(r * 1.02, *b, m)
        if flanges:
            mid = [(a[i] + b[i]) / 2 for i in range(3)]
            d = V(b) - V(a)
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r * 1.5, depth=0.08, location=mid)
            o = bpy.context.object; o.rotation_mode = "QUATERNION"; o.rotation_quaternion = d.to_track_quat("Z", "Y")
            o.data.materials.append(DARK)

# The barrel's line.
BASE = V((0.0, -0.6, 3.25)); TIP = V((0.0, FRONT + REACH, 1.0))
AXIS = (TIP - BASE).normalized()
PITCH = math.atan2(BASE.z - TIP.z, TIP.y - BASE.y)
LEN = (TIP - BASE).length
UP = V((0, math.sin(PITCH), math.cos(PITCH)))            # the barrel's own up
def along(t, up=0.0, side=0.0):
    return BASE + AXIS * (LEN * t) + UP * up + V((side, 0, 0))

def barrel_section(t0, t1, w0, w1, h0, h1, m, chamfer=0.28, seams=()):
    """A lofted chamfered box section from t0 to t1 (half-widths w, half-heights h), seams as shallow grooves at ts."""
    inner = [s for s in seams if t0 < s < t1]
    ts = sorted(set([t0, t1] + inner + [s - 0.004 for s in inner] + [s + 0.004 for s in inner]))
    bm = bmesh.new()
    rings = []
    for t in ts:
        u = (t - t0) / (t1 - t0)
        w, h = w0 + (w1 - w0) * u, h0 + (h1 - h0) * u
        k = 0.96 if any(abs(t - s) < 1e-6 for s in inner) else 1.0
        c = chamfer
        prof = [(-w + c, h), (w - c, h), (w, h - c), (w, -h + c), (w - c, -h), (-w + c, -h), (-w, -h + c), (-w, h - c)]
        rings.append([bm.verts.new(along(t, y * k, x * k)) for x, y in prof])
    for a, b in zip(rings, rings[1:]):
        for i in range(8):
            bm.faces.new((a[i], a[(i + 1) % 8], b[(i + 1) % 8], b[i]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bevel(obj_from_bm(bm, "barrel", m), 0.025, 2)

def on_barrel(sx, sl, sz, t, up, side, m, roll=0.0):
    """A box sitting on the barrel at t, pitched with it (size across, along, up; up is its middle), rolled about the
    barrel's axis by roll."""
    p = along(t, up, side)
    o = lpkit.box(sx, sl, sz, p.x, p.y, p.z - sz / 2, m, bevel=0.03)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = mathutils.Quaternion(AXIS, roll) @ mathutils.Euler((-PITCH, 0, 0)).to_quaternion()
    return o

coils, rings, fans, fan_parts = [], [], [], []
TOWER_TOP = 0.55 + 4.0
TOWER_LIFT = 0.7
TOWER_X, TOWER_Y, TOWER_PAD, TOWER_R = 3.15, -4.55, 1.05, 0.62   # the rear columns, fat (were 0.36 across, at 3.2, -4.4)
def build():
    # The plinth: a rounded slab of armour plate, its lip rolled, an inset top; a turntable ring under the barrel's mount.
    bm = bmesh.new()
    W, Dd, H, R = 3.7, 5.7, 0.55, 1.3
    outline = []
    for cx, cy, a0 in ((W - R, Dd - R, 0), (-W + R, Dd - R, 90), (-W + R, -Dd + R, 180), (W - R, -Dd + R, 270)):
        for k in range(9):
            a = math.radians(a0 + k * 90 / 8)
            outline.append((cx + R * math.cos(a), cy + R * math.sin(a)))
    nv = len(outline)
    bot = [bm.verts.new((x, y, 0)) for x, y in outline]; top = [bm.verts.new((x * 0.985, y * 0.99, H)) for x, y in outline]
    for i in range(nv): bm.faces.new((bot[i], bot[(i + 1) % nv], top[(i + 1) % nv], top[i]))
    topf = bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.inset_region(bm, faces=[topf], thickness=0.3, depth=-0.05)
    bevel(obj_from_bm(bm, "plinth", PLATE), 0.16, 5)
    lpkit.cyl(2.95, 0.22, 0, 0.3, H, DARK, verts=72, bevel=0.08)
    lpkit.torus(2.95, 0.07, 0, 0.3, H + 0.22, GUN)
    for k in range(36):
        a = k * 2 * math.pi / 36
        lpkit.cyl(0.05, 0.05, 2.8 * math.cos(a), 0.3 + 2.8 * math.sin(a), H + 0.22, GUN, verts=8)
    # (Not a square: round pads bulge out of the plinth's rear corners under the capacitor towers, the front corners
    # clamped; the user, 2026-11-10: "fatter columns at the back? we don't need to have a strictly symmetrical square base".)
    for sx in (-1, 1):
        lpkit.cyl(TOWER_PAD, H + 0.08, sx * TOWER_X, TOWER_Y, 0, PLATE, verts=48, bevel=0.12)
        lpkit.torus(TOWER_PAD - 0.05, 0.06, sx * TOWER_X, TOWER_Y, H + 0.08, GUN)
        for k in range(16):
            a = k * 2 * math.pi / 16
            lpkit.cyl(0.05, 0.05, sx * TOWER_X + (TOWER_PAD - 0.2) * math.cos(a), TOWER_Y + (TOWER_PAD - 0.2) * math.sin(a), H + 0.08,
                      DARK, verts=8)
        for sy in (1,):
            panelled(1.3, 1.3, 0.75, sx * 3.1, sy * 5.1, 0, DARK, inset=0.15, rot=(0, 0, math.radians(45 * sx * sy)), soft=0.22)
            lpkit.cyl(0.32, 0.18, sx * 3.1, sy * 5.1, 0.75, GUN, verts=16)
        bolts((sx * 3.55, -4.6, H), (sx * 3.55, 4.6, H), 14)
    bolts((-2.6, -5.55, H), (2.6, -5.55, H), 9); bolts((-2.6, 5.55, H), (2.6, 5.55, H), 9)
    for k in range(5):
        lpkit.box(0.55, 0.28, 0.04, -2.2 + k * 1.1, 5.35, H, HAZ, rot=math.radians(40), bevel=0.0)

    # The breech and capacitor hull behind: a faceted armoured body, a hexagonal back.
    panelled(5.2, 4.2, 2.0, 0, -3.6, H, PAINT, taper=0.8, min_face=1.0, soft=0.4)
    panelled(4.0, 3.0, 0.9, 0, -3.9, H + 2.0, DARK, taper=0.8, min_face=0.8, soft=0.3)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=1.25, depth=0.6, location=(0, -5.75, H + 1.35), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object; o.data.materials.append(DARK); bevel(o, 0.05)
    # Its exhaust: a dark recessed vent, louvred, a thin ring lit round it.
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.85, depth=0.66, location=(0, -5.78, H + 1.35), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(DARK)
    for k in range(4):
        lpkit.box(1.3 - 0.15 * abs(k - 1.5), 0.08, 0.08, 0, -6.1, H + 0.95 + k * 0.27, GUN, bevel=0.01)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.9, minor_radius=0.04, location=(0, -6.09, H + 1.35), rotation=(math.pi / 2, 0, 0),
                                     major_segments=6, minor_segments=6)
    bpy.context.object.data.materials.append(GLOW)
    for sx in (-1, 1):
        for k in range(6):
            lpkit.box(0.08, 0.32, 0.9, sx * 2.62, -5.2 + k * 0.5, H + 0.45, DARK, bevel=0.01)
            lpkit.box(0.04, 0.2, 0.75, sx * 2.6, -5.2 + k * 0.5, H + 0.52, GLOW, bevel=0.0)
    # The trunnion cheeks: wedges either side of the barrel's root, panelled, the pivot drums between.
    for sx in (-1, 1):
        panelled(1.5, 4.6, 3.1, sx * 2.3, 0.3, H, PAINT, taper=0.6, min_face=0.8, soft=0.35)
        panelled(0.5, 3.6, 0.4, sx * 2.3, 0.3, H + 3.1, DARK, min_face=0.3, soft=0.15)
        # Cable bundles along the cheek's top.
        for k in range(3):
            lpkit.rod((sx * (2.05 + k * 0.16), -1.9, H + 3.05 - k * 0.1), (sx * (2.05 + k * 0.16), 2.4, H + 3.05 - k * 0.1), 0.06,
                      HOSE if k == 1 else DARK, verts=8)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1.05, depth=0.5, location=(sx * 1.45, BASE.y + 0.4, BASE.z - 0.2),
                                            rotation=(0, math.pi / 2, 0))
        o = bpy.context.object; o.data.materials.append(DARK); bevel(o, 0.05)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.55, depth=0.56, location=(sx * 1.45, BASE.y + 0.4, BASE.z - 0.2),
                                            rotation=(0, math.pi / 2, 0))
        bpy.context.object.data.materials.append(GUN)
        bolts((sx * 3.07, -1.8, H + 0.4), (sx * 3.07, 2.4, H + 0.4), 8)
    # The barrel: root block, the long tapering section.
    barrel_section(-0.06, 0.12, 1.5, 1.45, 1.05, 1.0, PAINT, chamfer=0.55)
    barrel_section(0.12, 0.93, 1.35, 1.0, 0.85, 0.7, GUN, chamfer=0.3)
    # The slot along its top: a dark channel, its rails, the light inside.
    n = 24
    for k in range(n):
        a, b = 0.12 + 0.8 * k / n, 0.12 + 0.8 * (k + 1) / n
        w = 0.42 - 0.12 * (k / n)
        h = 0.85 - 0.15 * (k / n)
        on_barrel(w * 2 + 0.3, LEN * (b - a) + 0.01, 0.16, (a + b) / 2, h - 0.02, 0, DARK)
        on_barrel(0.16, LEN * (b - a) + 0.01, 0.03, (a + b) / 2, h + 0.07, 0, SLOT)
        for sx in (-1, 1):
            on_barrel(0.14, LEN * (b - a) + 0.01, 0.2, (a + b) / 2, h + 0.2, sx * (w + 0.08), GUN)
    # Bands round the barrel, bolted, and between them copper coil packs on its upper chamfers (where the game's camera
    # sees them, the vanilla railgun's orange coils), each with its light, lit in turn as it charges.
    def size_at(t):
        u = (t - 0.12) / 0.8
        return 1.35 - 0.35 * u, 0.85 - 0.15 * u
    bands = [0.2 + i * 0.09 for i in range(8)]
    for t in bands:
        w, h = size_at(t)
        barrel_section(t - 0.011, t + 0.011, w + 0.1, w + 0.1, h + 0.1, h + 0.1, DARK, chamfer=0.38)
        for sx in (-1, 1):
            bolts(tuple(along(t, h + 0.1, sx * (w * 0.6))), tuple(along(t, h + 0.1, sx * (w * 0.6 + 0.01))), 1)
    for i, t in enumerate(bands[:-1]):
        tm = t + 0.045
        w, h = size_at(tm)
        m = glow_mat(f"coil{i}")
        coils.append(m)
        for sx in (-1, 1):
            c = 0.3
            roll = -sx * math.pi / 4
            off_side, off_up = sx * (w - c / 2 + 0.06), h - c / 2 + 0.06
            on_barrel(0.5, LEN * 0.062, 0.16, tm, off_up, off_side, COPPER, roll=roll)
            for k in range(5):
                on_barrel(0.52, 0.035, 0.18, tm - 0.022 + k * 0.011, off_up, off_side, HOSE, roll=roll)
            on_barrel(0.1, LEN * 0.05, 0.2, tm, off_up + 0.02, off_side + sx * 0.02, m, roll=roll)
        # Its plates: a seam across the top mid-way between bands, rivets along the band's edges.
        on_barrel(w * 2 - 0.5, 0.035, 0.03, tm, h + 0.005, 0, DARK)
        for sx in (-1, 1):
            for k in range(3):
                p = along(t + 0.015, h + 0.01, sx * (0.45 + k * 0.22))
                lpkit.cyl(0.035, 0.03, p.x, p.y, p.z, DARK, verts=6)
        # Conduits along the flanks, clamped.
        for sx in (-1, 1):
            on_barrel(0.12, LEN * 0.09, 0.12, t + 0.045, 0.1, sx * (w + 0.08), GUN)
    # The muzzle shroud: a heavier block, its bore dark, a ring lit at the mouth.
    barrel_section(0.925, 1.0, 1.4, 1.5, 1.0, 1.05, PAINT, chamfer=0.55)
    barrel_section(0.94, 0.955, 1.55, 1.55, 1.12, 1.12, HAZ, chamfer=0.42)
    on_barrel(1.1, 0.25, 0.7, 1.0, 0.0, 0, DARK)
    on_barrel(0.7, 0.28, 0.35, 1.0, 0.0, 0, GLOW)
    # Hydraulic rams from the plinth's front to the barrel's belly (fixed: they stay when the barrel recoils).
    before_rams = set(scene.objects)
    for sx in (-1, 1):
        a = V((sx * 0.9, 4.4, H + 0.1)); b = along(0.34, -0.75, sx * 0.9)
        mid = a + (b - a) * 0.55
        lpkit.rod(tuple(a), tuple(mid), 0.32, GUN, verts=16)
        lpkit.rod(tuple(mid), tuple(b), 0.2, COPPER, verts=12)
        lpkit.cyl(0.5, 0.35, a.x, a.y, H, DARK, verts=16)
    FIXED.update(o for o in scene.objects if o not in before_rams)
    # Hoses and pipe bundles from the hull to the cheeks and the barrel's root.
    for sx in (-1, 1):
        if sx < 0:
            hose([(sx * 2.0, -4.6, H + 2.0), (sx * 2.9, -3.2, H + 2.9), (sx * 2.6, -1.4, H + 3.6), (sx * 1.3, -0.4, BASE.z + 0.9)], 0.24)
            pipe([(sx * 1.0, -5.0, H + 2.9), (sx * 0.9, -3.4, H + 3.2), (sx * 0.6, -1.6, BASE.z + 1.0)], 0.09, m=GUN)
            pipe([(sx * 1.25, -5.0, H + 2.9), (sx * 1.15, -3.4, H + 3.25), (sx * 0.85, -1.6, BASE.z + 1.05)], 0.07, m=DARK, flanges=False)
        else:
            hose([(sx * 2.3, -4.9, H + 1.6), (sx * 3.05, -3.0, H + 2.3), (sx * 2.8, -1.2, H + 3.2), (sx * 1.3, -0.3, BASE.z + 0.8)], 0.27)
            hose([(sx * 1.0, -5.0, H + 2.6), (sx * 0.7, -3.0, H + 3.4), (sx * 0.4, -1.5, BASE.z + 1.1)], 0.16)
        pipe([(sx * 2.7, -5.4, H + 0.3), (sx * 3.25, -4.0, H + 0.3), (sx * 3.25, -1.2, H + 0.3), (sx * 3.1, 2.6, H + 0.3)], 0.12)
        pipe([(sx * 2.8, -5.0, H + 0.6), (sx * 3.4, -3.5, H + 0.6), (sx * 3.4, 2.4, H + 0.6)], 0.09, flanges=False)
    # The deck's machinery round the hull and cheeks: junction boxes, conduit runs, a ladder up each cheek.
    for sx in (-1, 1):
        for k, (y, sz) in enumerate(((-1.4, 0.55), (-0.6, 0.4), (2.9, 0.5), (3.7, 0.35))):
            if sx > 0 and k < 2 and os.path.isdir(PROPS): continue    # (a utility box there, below)
            panelled(0.55, 0.6, sz, sx * 3.25, y, H, DARK if k % 2 else GUN, inset=0.06, min_face=0.12)
            lpkit.box(0.4, 0.06, 0.04, sx * 3.25, y - 0.31, H + sz * 0.7, HAZ, bevel=0.0)
        pipe([(sx * 3.25, -1.1, H + 0.45), (sx * 3.25, 2.6, H + 0.45)], 0.06, m=DARK, flanges=False)
        for k in range(7):
            lpkit.box(0.5, 0.05, 0.05, sx * 3.06, -0.9 + k * 0.4, H + 0.3 + k * 0.38, GUN, bevel=0.0)
        lpkit.rod((sx * 2.82, -1.0, H), (sx * 2.82, 1.6, H + 2.9), 0.03, GUN, verts=6)
        lpkit.rod((sx * 3.3, -1.0, H), (sx * 3.3, 1.6, H + 2.9), 0.03, GUN, verts=6)
        # Cable trays from the hull to the cheeks, on the deck.
        for k in range(3):
            lpkit.box(0.16, 1.6, 0.08, sx * (1.0 + k * 0.25), -1.1, H, DARK, bevel=0.01)
    # The hull's top filled (Space Age leaves no plane empty): valve wheels, small tanks, a junction box.
    hz = H + 2.0 + 0.9
    for sx in (-1, 1):
        lpkit.torus(0.22, 0.035, sx * 1.55, -4.95, hz + 0.25, GUN)
        for k in range(4):
            a = k * math.pi / 2
            lpkit.rod((sx * 1.55, -4.95, hz + 0.25), (sx * 1.55 + 0.2 * math.cos(a), -4.95 + 0.2 * math.sin(a), hz + 0.25), 0.02, GUN, verts=6)
        lpkit.cyl(0.05, 0.25, sx * 1.55, -4.95, hz, GUN, verts=8)
        if not os.path.isdir(PROPS):
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.24, depth=1.1, location=(sx * 1.35, -2.9, hz + 0.24), rotation=(math.pi / 2, 0, 0))
            o = bpy.context.object; o.data.materials.append(PLATE); bevel(o, 0.06, 4)
        panelled(0.5, 0.45, 0.35, sx * 0.4, -5.05, hz, DARK, inset=0.05, min_face=0.1, soft=0.06)
    # Status lamps on the hull, small, the player's cyan.
    for x in (-1.8, -1.4, 1.4, 1.8):
        lpkit.sphere(0.06, x, -1.62, H + 1.75, GLOW)
    # The great coils: five copper rings wound round the barrel, clamped, a light inside each lit in turn as it charges.
    for i, t in enumerate((0.245, 0.38, 0.515, 0.65, 0.785)):
        w, h = size_at(t)
        # (Not five copies: each a little other in size, its clamps turned its own way.)
        R, r = (w + 0.55) * (1 + 0.03 * ((i * 37) % 5 - 2) / 2), 0.34 * (1 + 0.06 * ((i * 53) % 3 - 1))
        c = along(t)
        bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=c, rotation=(math.pi / 2 - PITCH, 0, 0),
                                         major_segments=64, minor_segments=16)
        o = bpy.context.object; o.data.materials.append(WIND); o.scale = (1.0, (h + 0.55) / R, 1.0)
        m = glow_mat(f"ring{i}")
        rings.append(m)
        bpy.ops.mesh.primitive_torus_add(major_radius=R - r * 0.95, minor_radius=0.06, location=c, rotation=(math.pi / 2 - PITCH, 0, 0),
                                         major_segments=64, minor_segments=8)
        o = bpy.context.object; o.data.materials.append(m); o.scale = (1.0, (h + 0.55 - r * 0.95) / (R - r * 0.95), 1.0)
        for a in range(4):
            ang = math.pi / 4 + a * math.pi / 2 + 0.18 * ((i * 29) % 5 - 2)
            on_barrel(0.5, 0.9, 0.3, t, math.sin(ang) * (h + 0.55), math.cos(ang) * R, DARK, roll=-ang + math.pi / 2)
    # The breech's top behind the first coil: a capacitor housing, panelled, its bus bars to the coil, and the coil's
    # contact posts where the arcs strike (copper-tipped insulators either side).
    p0 = along(0.05, 1.45)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.62, depth=2.7, location=p0, rotation=(0, math.pi / 2, 0))
    o = bpy.context.object; o.data.materials.append(PAINT); bevel(o, 0.08, 4)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.7, depth=0.16, location=(p0.x + sx * 1.38, p0.y, p0.z),
                                            rotation=(0, math.pi / 2, 0))
        o = bpy.context.object; o.data.materials.append(DARK); bevel(o, 0.04, 3)
        for k in range(5):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.64, minor_radius=0.03, location=(p0.x + sx * (0.25 + k * 0.22), p0.y, p0.z),
                                             rotation=(0, math.pi / 2, 0), major_segments=40, minor_segments=6)
            bpy.context.object.data.materials.append(COPPER)
        # Its bus bars, thick, from the drum's end down into the first coil.
        w, h = size_at(0.245)
        for k in range(2):
            a = V((p0.x + sx * 1.3, p0.y + 0.1 + k * 0.25, p0.z - 0.2))
            b = along(0.245, 0.35 - k * 0.3, sx * (w + 0.35))
            mid = V((a.x + sx * 0.25, (a.y + b.y) / 2, max(a.z, b.z) + 0.15))
            pipe([tuple(a), tuple(mid), tuple(b)], 0.1, m=COPPER, flanges=False)
        # The coil's contact posts, where the arcs strike: insulator stacks, copper heads.
        q = along(0.245, 0.0, sx * (w + 0.55 + 0.35))
        lpkit.cyl(0.24, 0.12, q.x, q.y, q.z - 0.1, DARK, verts=16)
        for k in range(4):
            lpkit.cyl(0.2 - 0.02 * (k % 2), 0.16, q.x, q.y, q.z + 0.02 + k * 0.17, PLATE, verts=16)
        lpkit.sphere(0.27, q.x, q.y, q.z + 0.95, COPPER)
    # The small parts (Space Age leaves no stretch plain): between the coils, junction boxes and paired conduits on the
    # barrel's flanks, clamped; hatch plates either side of the slot; on the plinth, louvred vents along its front and
    # back lips, small tanks at its front corners, valve wheels on its side pipes.
    ring_ts = (0.245, 0.38, 0.515, 0.65, 0.785)
    for t0, t1 in zip(ring_ts, ring_ts[1:] + (0.92,)):
        tm = (t0 + t1) / 2
        w, h = size_at(tm)
        for sx in (-1, 1):
            on_barrel(0.3, LEN * 0.04, 0.34, tm - 0.015, -0.15, sx * (w + 0.1), DARK)
            on_barrel(0.08, LEN * 0.012, 0.36, tm - 0.015, -0.12, sx * (w + 0.26), HAZ)
            for k in (-1, 1):
                a_, b_ = along(t0 + 0.025, -0.45 + k * 0.12, sx * (w + 0.05)), along(t1 - 0.025, -0.45 + k * 0.12, sx * (w + 0.05))
                lpkit.rod(tuple(a_), tuple(b_), 0.045, COPPER if k > 0 else GUN, verts=8)
            for c in (t0 + 0.03, t1 - 0.03):
                on_barrel(0.14, 0.12, 0.34, c, -0.45, sx * (w + 0.06), DARK)
            o = on_barrel(0.42, LEN * 0.045, 0.05, tm + 0.02, h + 0.01, sx * (0.38 + w * 0.25), PLATE)
            for k in range(4):
                q = along(tm + 0.02 + (k - 1.5) * 0.012, h + 0.04, sx * (0.38 + w * 0.25 + (0.15 if k % 2 else -0.15)))
                lpkit.cyl(0.03, 0.03, q.x, q.y, q.z, DARK, verts=6)
    for sy, y in ((1, 5.2), (-1, -5.25)):
        for k in range(10):
            x = -2.5 + k * 0.55
            if abs(x) < 0.8 and sy < 0: continue
            lpkit.box(0.36, 0.06, 0.18, x, y, H - 0.05, DARK, bevel=0.01)
            for j in range(3):
                lpkit.box(0.3, 0.03, 0.02, x, y + sy * 0.035, H - 0.0 + j * 0.05, GUN, bevel=0.0)
    # Hand-made parts kitbashed on (Poly Haven, CC0, in LP_PROPS; none without them): placed unevenly, as a crew would.
    # (Real metres to these units, 1 a tile and a half: a prop at its size.)
    # (Factorio exaggerates: at its real size a prop read as a speck beside the cannon's parts; 2.5 times.)
    S = 2.5 / 1.5
    hz = H + 2.9
    for obj, f, at, rz, k in (
            # Where the game's camera sees them: the hull's top, the rear deck, the outer flanks, the cheeks' faces (the
            # barrel and coils hang over the front deck: props there were hidden, the first try).
            ("exterior_aircon_unit_rusted", "exterior_aircon_unit", (1.25, -2.75, hz), 90, 0.5),
            ("old_military_compressor", "old_military_compressor", (-1.3, -2.75, hz), 0, 0.45),
            ("utility_box_02", "utility_box_02", (3.32, -1.0, H), -90, 0.6),
            ("small_lpg_tank", "small_lpg_tank", (-3.4, -3.05, H), 20, 0.95),
            ("propane_tank", "propane_tank", (3.4, -3.2, H), -30, 0.9),
            ("power_box_01_box", "power_box_01", (3.03, 0.9, H + 0.9), -90, 1.2),
            ("power_box_01_box", "power_box_01", (-3.03, -0.3, H + 0.75), 90, 1.2),
            ("security_light", "security_light", (2.3, 2.45, H + 3.5), 0, 0.9),
            ("security_light", "security_light", (-2.3, 2.45, H + 3.5), 0, 0.9),
            ("pipe_valve_large_metal", "modular_pipes", (3.42, -2.1, H + 0.32), 90, 0.9),
            ("pipe_valve_small_1_metal", "modular_pipes", (-3.42, 1.4, H + 0.42), -90, 1.0),
            ("modular_industrial_pipes_01_pipe05", "modular_industrial_pipes_01", (1.65, -5.45, H), 0, 1.0),
            ("modular_industrial_pipes_01_pipe07", "modular_industrial_pipes_01", (-1.75, -5.45, H), 180, 1.0)):
        o = prop(obj, f)
        if o:
            o.location = at; o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], math.radians(rz)); o.scale = (S * k,) * 3
    for sx in (-1, 1):
        # Cable runs along the plinth's side tops (Poly Haven's modular cables, laid flat end to end).
        for j in range(7):
            o = prop("cable_straight_long", "modular_electric_cables")
            if o:
                o.location = (sx * (3.56 + 0.04 * (j % 2)), -4.0 + j * 0.61 * S, H + 0.02); o.rotation_euler = (math.radians(90), 0, 0)
                o.scale = (S,) * 3
        for y in (-3.0, 0.8):
            lpkit.torus(0.13, 0.025, sx * 3.47, y, H + 0.72, GUN)
            lpkit.cyl(0.03, 0.12, sx * 3.47, y, H + 0.6, GUN, verts=6)
    # Capacitor towers either side of the hull: ribbed columns, insulator stacks, terminal spheres (the arcs leap between).
    # (Not a mirror: the left tower taller by TOWER_LIFT, the right one with a service cage; arcs.lua's points read both.)
    for sx in (-1, 1):
        x, y = sx * TOWER_X, TOWER_Y
        lift = TOWER_LIFT if sx < 0 else 0.0
        base = H + 0.08
        lpkit.cyl(TOWER_R + 0.3, 0.4, x, y, base, DARK, verts=40, bevel=0.06)
        lpkit.cyl(TOWER_R, 2.5 + lift, x, y, base + 0.4, GUN, verts=40)
        for k in range(6 + (2 if lift else 0)):
            lpkit.torus(TOWER_R + 0.07, 0.08, x, y, base + 0.7 + k * 0.34, DARK)
        for k in range(4):
            lpkit.cyl(TOWER_R * 0.85 - 0.04 * (k % 2), 0.16, x, y, base + 2.9 + lift + k * 0.17, PLATE, verts=32)
        lpkit.sphere(TOWER_R * 1.05, x, y, TOWER_TOP + lift, DARK)
        lpkit.torus(TOWER_R * 1.08, 0.05, x, y, TOWER_TOP + lift, GLOW)
        if sx > 0:
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                lpkit.rod((x + 1.0 * math.cos(a), y + 1.0 * math.sin(a), H + 0.1), (x + 0.85 * math.cos(a), y + 0.85 * math.sin(a), H + 2.9),
                          0.035, GUN, verts=6)
            for z in (H + 1.0, H + 1.9, H + 2.8):
                lpkit.torus(0.93, 0.03, x, y, z, GUN)
    # Cooling fans on the hull's top, spinning while it works.
    for sx in (-1, 1):
        x, y, z = sx * 0.85, -3.9, H + 2.92
        lpkit.torus(0.72, 0.08, x, y, z, DARK)
        lpkit.cyl(0.66, 0.04, x, y, z - 0.1, DARK, verts=32)
        pivot = bpy.data.objects.new("fan", None); scene.collection.objects.link(pivot); pivot.location = (x, y, z)
        fans.append(pivot)
        for k in range(7):
            b = lpkit.box(0.6, 0.15, 0.025, 0.32, 0, -0.01, GUN, bevel=0.005)
            b.rotation_euler = (math.radians(22), 0, 0)
            holder = bpy.data.objects.new("blade", None); scene.collection.objects.link(holder)
            holder.parent = pivot; holder.rotation_euler = (0, 0, k * 2 * math.pi / 7)
            b.parent = holder
            fan_parts.append(b)
        hub = lpkit.cyl(0.14, 0.08, 0, 0, -0.02, DARK, verts=16); hub.parent = pivot; fan_parts.append(hub)
    for sx in (-1, 1):
        for k in range(6):
            lpkit.rod((sx * 3.55, -4.5 + k * 1.8, H), (sx * 3.55, -4.5 + k * 1.8, H + 0.55), 0.03, GUN, verts=6)
        lpkit.rod((sx * 3.55, -4.5, H + 0.55), (sx * 3.55, 4.5, H + 0.55), 0.035, GUN, verts=6)

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

rig = bpy.data.objects.new("rig", None); scene.collection.objects.link(rig)
model = group(build)
# The barrel (the user, 2026-11-10: "No firing animation? no recoil?"): what lies along its axis from just past the breech
# to the muzzle, within its coils' reach and not below its belly, less FIXED; rendered apart (its own sprite, which the
# script draws over the cannon and slides back as it fires), hidden from the body's render.
def barrel_part(o):
    if o in FIXED or o.type not in ("MESH", "CURVE"): return False
    c = sum((o.matrix_world @ V(b) for b in o.bound_box), V((0, 0, 0))) / 8
    t = (c - BASE).dot(AXIS) / LEN
    if t < 0.1 or t > 1.05: return False
    q = BASE + AXIS * (LEN * t)
    d = c - q
    return d.length <= 2.6 and d.z > -1.4
bpy.context.view_layer.update()
BARREL = set(o for o in model if barrel_part(o))
print("barrel parts", len(BARREL), "of", len(model))

# The scattered detail (the user, 2026-11-10: "Go for 1 and 2", the cannon's dense small parts, Space Age's way): over
# every large face of the armour, the hull, the cheeks, the plinth and the barrel, rivet rows along its two long edges
# and small parts (vents, boxes, hatches, pipe stubs, clamps) at seeded places, a few painted marks (seams, hazard
# squares). Built straight into one mesh a material, apart for the barrel and the rest (the barrel recoils, with its own).
def scatter():
    import bmesh as _bm
    srng = random.Random(20261110)
    SURF = {GUN, PAINT, PLATE, DARK}
    acc = {}                                      # (is_barrel, material) -> bmesh
    def bm_for(barrel, m):
        k = (barrel, m.name)
        if k not in acc: acc[k] = (_bm.new(), m)
        return acc[k][0]
    def place(bm, kind, centre, normal, spin, size):
        q = normal.to_track_quat("Z", "Y") @ mathutils.Quaternion(V((0, 0, 1)), spin)
        mat = mathutils.Matrix.Translation(centre) @ q.to_matrix().to_4x4()
        if kind == "box":
            r = _bm.ops.create_cube(bm, size=1.0)
            sc = mathutils.Matrix.Diagonal((size[0], size[1], size[2], 1))
            _bm.ops.transform(bm, matrix=mat @ mathutils.Matrix.Translation((0, 0, size[2] / 2)) @ sc, verts=r["verts"])
        else:
            r = _bm.ops.create_cone(bm, cap_ends=True, segments=8 if kind == "rivet" else 12, radius1=size[0], radius2=size[0],
                                    depth=size[2])
            _bm.ops.transform(bm, matrix=mat @ mathutils.Matrix.Translation((0, 0, size[2] / 2)), verts=r["verts"])
    count = 0
    for o in list(model):
        if o.type != "MESH" or o in FIXED:
            continue
        ms = [sl.material for sl in o.material_slots if sl.material]
        if not ms or ms[0] not in SURF:
            continue
        barrel = o in BARREL
        mw = o.matrix_world
        rot = mw.to_quaternion()
        for f in o.data.polygons:
            vs = [mw @ o.data.vertices[i].co for i in f.vertices]
            n = (rot @ f.normal).normalized()
            if n.z < -0.25 or len(vs) < 3:
                continue
            # (Its area in the world: the mesh scaled by its object.)
            area = 0.0
            for i in range(1, len(vs) - 1):
                area += ((vs[i] - vs[0]).cross(vs[i + 1] - vs[0])).length / 2
            if area < 0.5:
                continue
            c = sum(vs, V((0, 0, 0))) / len(vs)
            edges = sorted(((vs[i] - vs[(i + 1) % len(vs)]).length, i) for i in range(len(vs)))
            # Rivets along its two longest edges, a little in from them.
            for _, i in edges[-2:]:
                a0, a1 = vs[i], vs[(i + 1) % len(vs)]
                L = (a1 - a0).length
                k = max(2, int(L / 0.2))
                for j in range(1, k):
                    p0 = a0 + (a1 - a0) * (j / k)
                    p0 = p0 + (c - p0).normalized() * 0.07
                    place(bm_for(barrel, DARK), "rivet", p0 + n * 0.003, n, 0, (0.022, 0, 0.018))
                    count += 1
            # Its small parts, seeded, kept off its edges.
            for _ in range(int(area * 2.6)):
                t = [srng.random() for _ in vs]
                tot = sum(t)
                p0 = sum((v * (w / tot) for v, w in zip(vs, t)), V((0, 0, 0)))
                p0 = c + (p0 - c) * 0.75
                spin = srng.choice((0, math.pi / 2)) + srng.uniform(-0.05, 0.05)
                kind = srng.random()
                if kind < 0.3:      # a junction box
                    place(bm_for(barrel, DARK), "box", p0, n, spin, (srng.uniform(0.12, 0.28), srng.uniform(0.1, 0.22), srng.uniform(0.05, 0.12)))
                elif kind < 0.5:    # a vent: a plate and three slats
                    w, h = srng.uniform(0.2, 0.35), srng.uniform(0.15, 0.25)
                    place(bm_for(barrel, DARK), "box", p0, n, spin, (w, h, 0.02))
                    for s_ in (-1, 0, 1):
                        off = (n.to_track_quat("Z", "Y") @ mathutils.Quaternion(V((0, 0, 1)), spin)) @ V((0, s_ * h * 0.28, 0))
                        place(bm_for(barrel, GUN), "box", p0 + off + n * 0.02, n, spin, (w * 0.85, h * 0.12, 0.015))
                elif kind < 0.65:   # a hatch: a thin plate, a darker rim
                    w = srng.uniform(0.2, 0.4)
                    place(bm_for(barrel, DARK), "box", p0, n, spin, (w + 0.03, w * 0.8 + 0.03, 0.012))
                    place(bm_for(barrel, PLATE), "box", p0 + n * 0.012, n, spin, (w, w * 0.8, 0.012))
                elif kind < 0.8:    # a pipe stub and its collar
                    place(bm_for(barrel, GUN), "cyl", p0, n, 0, (srng.uniform(0.03, 0.06), 0, srng.uniform(0.06, 0.14)))
                    place(bm_for(barrel, DARK), "cyl", p0, n, 0, (0.07, 0, 0.025))
                elif kind < 0.92:   # a painted seam
                    place(bm_for(barrel, DARK), "box", p0, n, spin, (srng.uniform(0.3, 0.7), 0.012, 0.004))
                else:               # a hazard square
                    place(bm_for(barrel, HAZ), "box", p0, n, spin, (0.12, 0.12, 0.006))
                count += 1
    made = []
    for (barrel, _), (bm, m) in acc.items():
        me = bpy.data.meshes.new("scatter"); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new("scatter", me); scene.collection.objects.link(ob); me.materials.append(m)
        made.append(ob)
        if barrel: BARREL.add(ob)
    print("scattered", count, "parts in", len(made), "meshes")
    return made
model += scatter()
for o in model:
    if o.parent is None: o.parent = rig
rig.scale = (SCALE, SCALE, SCALE)
rng = random.Random(1110)

def arcs(f):
    """None: the arcs are the game's own beams, drawn by script between the towers' terminals and the first coil's contact
    posts (scripts/cannon.lua; drawn into the sprite they read as white scribbles, the user: "the arcs look like crap. Can't
    we add those at the game level?")."""
    made = []
    if True:
        return made
    for sx in (-1, 1):
        tip = (sx * 3.2, -4.4, TOWER_TOP + 0.3)
        made.append(lpkit.arc(tip, tuple(along(0.02, 1.15, sx * 0.6)), ARC, rng, kinks=7, jitter=0.4, r=0.06))
        # A branch off it, short.
        mid = tuple(tip[i] + (along(0.02, 1.15, sx * 0.6)[i] - tip[i]) * 0.45 for i in range(3))
        made.append(lpkit.arc(mid, (mid[0] + sx * 0.6, mid[1] + rng.uniform(-0.8, 0.8), mid[2] - 0.9), ARC, rng, kinks=3, jitter=0.25, r=0.035))
    for _ in range(2):
        made.append(lpkit.arc((-3.2, -4.4, TOWER_TOP + 0.4), (3.2, -4.4, TOWER_TOP + 0.4), ARC, rng, kinks=10, jitter=0.6, r=0.07))
    for c in made: c.parent = rig
    return made

def set_frame(f):
    t = f / max(1, GLOW_FRAMES)
    for p in fans:
        p.rotation_euler = (0, 0, t * 2 * math.pi / 7)
    nr = len(rings)
    for i, m in enumerate(rings):
        dd = abs(((t * nr - i) + nr / 2) % nr - nr / 2)
        lpkit.emission(m, max(0.0, 5.0 - 3.0 * dd))
    n = len(coils) // 2
    for i, m in enumerate(coils):
        k = i // 2
        dd = abs(((t * n - k) + n / 2) % n - n / 2)
        lpkit.emission(m, max(0.0, 3.0 - 1.6 * dd))
    bpy.context.view_layer.update()
    lpkit.emission(GLOW, 1.2 + 0.5 * math.sin(t * 2 * math.pi))
    bpy.context.view_layer.update()

FILL = 0.3    # (the mod's other renders 0.55: here a hero piece, contrast as vanilla's)
ground, sun, world = lpkit.stage(scene, 2 * (FRONT + REACH + 1) * SCALE, 0)
# Vanilla's harder key light from the upper left: brighter, a sharper shadow.
sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
bg = world.node_tree.nodes["Background"]
YAW = {"north": 0, "west": 90, "south": 180, "east": 270}
glowing = set(coils) | set(rings) | {GLOW, SLOT, ARC}
SAMPLES = scene.cycles.samples
def holdout_but(keep):
    for m in model:
        ms = [s.material for s in m.material_slots if s.material]
        m.is_holdout = not keep(m, ms)
for d in DIRS:
    rig.rotation_euler = (0, 0, math.radians(YAW[d]))
    bpy.context.view_layer.update()
    o = f"{out}/{d}"
    for k in ("body", "glow", "fans"): os.makedirs(f"{o}/{k}", exist_ok=True)
    for f in range(GLOW_FRAMES):
        set_frame(f)
        lpkit.border(scene, model)
        if f == 0:
            scene.cycles.samples = SAMPLES
            ground.hide_render = True; sun.hide_render = False; bg.inputs[1].default_value = FILL
            for m in model: m.is_holdout = False; m.visible_camera = m not in BARREL
            lpkit.render(scene, f"{o}/body/000.png")
            # The barrel alone, lit as the body, every other part hidden (not held out: it is drawn over the body).
            os.makedirs(f"{o}/barrel", exist_ok=True)
            for m in model: m.visible_camera = m in BARREL
            lpkit.render(scene, f"{o}/barrel/000.png")
            for m in model: m.visible_camera = True
        # The glow (lit parts and the frame's arcs), every other part a holdout.
        made = arcs(f)
        scene.cycles.samples = max(8, SAMPLES // 5)
        ground.hide_render = True; sun.hide_render = True; bg.inputs[1].default_value = 0.0
        holdout_but(lambda m, ms: any(x in glowing for x in ms))
        lpkit.render(scene, f"{o}/glow/{f:03d}.png")
        for c in made: bpy.data.objects.remove(c, do_unlink=True)
        # The fans, lit, every other part a holdout.
        scene.cycles.samples = max(8, SAMPLES // 3)
        sun.hide_render = False; bg.inputs[1].default_value = FILL
        holdout_but(lambda m, ms: m in fan_parts)
        lpkit.border(scene, fan_parts, pad=0.005)
        lpkit.render(scene, f"{o}/fans/{f:03d}.png")
    scene.cycles.samples = max(8, SAMPLES // 2)
    lpkit.border(scene, None)
    for m in model: m.is_holdout = False; m.visible_camera = False
    sun.hide_render = False; bg.inputs[1].default_value = FILL; ground.hide_render = False
    set_frame(0)
    lpkit.render(scene, f"{o}/shadow.png")
    for m in model: m.visible_camera = True
    print("rendered orbital cannon", d, o)
