"""Grubstake's harrier, its scrap flier (the unit pass, 2026-11-08: after the buggies, the crawler and the hauler): an
autogyro of salvage, as Mad Max's (the user's inspiration). An open frame of tubes, a seat and its pilot hunched in it,
an engine at the back with a pusher prop, a rudder on a tail boom, a light gun under the nose, Grubstake's amber on the
frame and its red pennant. It hovers a tile up (the distractor's height), its shadow on the ground. The rotor and the
prop are discs of motion blur, faint streaks of their blades in them (a unit's run animation steps with the distance it
covers and holds when it stops: a modelled rotor would freeze on a hovering harrier; a blur reads as turning in every
state). Layers: the airframe (base), the rotor (its own, over it), the shadow of both.

    /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/harrier.py -- <out_dir> [N=64]
    then one sheet.py run a part: out/base, out/rotor
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

H = 1.0                                # its height above the ground (the distractor's)
if os.environ.get("LP_WRECK"):
    H = 0.2                            # a wreck down on its skids

def blur_mat(name, rgb, alpha, streaks=6.0):
    """A disc of motion blur: the colour at `alpha`, faint radial streaks (a wave texture round its centre)."""
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

def airframe():
    # The keel: a tube from nose to tail, the seat frame, a skid each side under it.
    # (Spindly at game scale, the first look, fainter than vanilla's distractor: tubes thicker, more plate.)
    rod((0, 0.55, H), (0, -0.55, H + 0.08), 0.045, M["cage"])
    for sx in (-1, 1):
        rod((sx * 0.16, 0.4, H - 0.02), (sx * 0.16, -0.2, H - 0.02), 0.034, M["cage"])
        rod((sx * 0.16, 0.4, H - 0.02), (0, 0.55, H), 0.03, M["cage"])
        rod((sx * 0.16, -0.2, H - 0.02), (0, -0.3, H + 0.05), 0.03, M["cage"])
        rod((sx * 0.2, 0.38, H - 0.2), (sx * 0.2, -0.28, H - 0.2), 0.022, M["tube"])            # skids
        # Side plates: amber armour over the cockpit's flanks.
        V.panel([(sx * 0.17, 0.32, H - 0.05), (sx * 0.17, -0.14, H - 0.05), (sx * 0.15, -0.12, H + 0.14), (sx * 0.15, 0.28, H + 0.12)],
                M["amber"] if sx < 0 else M["amber_dull"], t=0.014)
        for y in (0.25, -0.15):
            rod((sx * 0.14, y, H - 0.02), (sx * 0.18, y, H - 0.2), 0.012, M["tube"])
    # A nose fairing: a dented scoop of amber plate over the pilot's feet, a lamp in it.
    # (A rounded fairing read as an egg, the first: flat plates bent round the nose, a wind deflector over them.)
    V.panel([(-0.13, 0.3, H - 0.04), (0.13, 0.3, H - 0.04), (0.06, 0.58, H - 0.02), (-0.06, 0.58, H - 0.02)], M["amber"], t=0.014)
    for sx in (-1, 1):
        V.panel([(sx * 0.13, 0.3, H - 0.04), (sx * 0.06, 0.58, H - 0.02), (sx * 0.05, 0.56, H + 0.08), (sx * 0.13, 0.32, H + 0.1)],
                M["amber"] if sx < 0 else M["rust"], t=0.012)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.33, H + 0.15), rotation=(math.radians(-35), 0, 0))
    o = V.obj(); o.scale = (0.2, 0.01, 0.1); o.data.materials.append(M["glass"])
    cyl(0.035, 0.01, 0, 0.62, H - 0.02, M["lamp"], rot=(math.pi / 2, 0, 0))
    # The seat and its pilot: a canvas seat, a hunched figure in leathers, a helmet and goggles.
    box(0.2, 0.18, 0.04, 0, 0.08, H + 0.02, M["canvas"], bevel=0.015)
    box(0.2, 0.04, 0.2, 0, -0.02, H + 0.04, M["canvas"], bevel=0.015)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.1, location=(0, 0.1, H + 0.17), segments=24, ring_count=12)
    o = V.obj(); o.scale = (1.0, 0.85, 1.2); o.data.materials.append(M["olive"])                 # torso
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(0, 0.14, H + 0.31), segments=24, ring_count=12)
    V.obj().data.materials.append(M["plate"])                                                    # helmet
    box(0.09, 0.02, 0.025, 0, 0.19, H + 0.31, M["glass"], bevel=0.006)                         # goggles
    for sx in (-1, 1):
        rod((sx * 0.08, 0.14, H + 0.2), (sx * 0.06, 0.3, H + 0.12), 0.022, M["olive"])          # arms to the stick
    rod((0, 0.32, H + 0.04), (0, 0.3, H + 0.14), 0.01, M["dark"])
    # A gunner behind the pilot, facing aft-out over the right, a pintle gun with a shield.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0.04, -0.1, H + 0.18), segments=24, ring_count=12)
    o = V.obj(); o.scale = (1.0, 0.85, 1.15); o.data.materials.append(M["olive"])
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, location=(0.05, -0.1, H + 0.31), segments=24, ring_count=12)
    V.obj().data.materials.append(M["rust2"])
    rod((0.16, -0.1, H), (0.18, -0.06, H + 0.24), 0.02, M["steel"])
    box(0.07, 0.24, 0.06, 0.18, -0.02, H + 0.24, M["dark"], bevel=0.01)
    rod((0.18, 0.08, H + 0.27), (0.2, 0.42, H + 0.27), 0.02, M["dark"])
    box(0.16, 0.02, 0.12, 0.18, 0.08, H + 0.2, M["rust"], bevel=0.006)
    # The mast up to the rotor head, its braces.
    rod((0, -0.05, H + 0.05), (0, -0.02, H + 0.55), 0.035, M["steel"])
    for sx in (-1, 1):
        rod((sx * 0.14, -0.15, H - 0.02), (0, -0.02, H + 0.4), 0.012, M["tube"])
    rod((0, 0.25, H), (0, -0.02, H + 0.4), 0.012, M["tube"])
    cyl(0.05, 0.06, 0, -0.02, H + 0.52, M["dark"], bevel=0.008)
    # The engine behind the seat: a finned cylinder block, its exhaust, a fuel tank on top; the pusher prop's hub.
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.11, depth=0.24, location=(0, -0.36, H + 0.08), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(M["plate"])
    for k in range(7):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.115, minor_radius=0.01, location=(0, -0.26 - k * 0.034, H + 0.08),
                                         rotation=(math.pi / 2, 0, 0), major_segments=32, minor_segments=6)
        V.obj().data.materials.append(M["steel"])
    rod((0.08, -0.3, H + 0.06), (0.16, -0.42, H + 0.02), 0.014, M["heat"])                        # exhaust
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.075, depth=0.26, location=(0, -0.3, H + 0.24), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(M["red"])
    for dy in (-0.08, 0.08):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.077, minor_radius=0.008, location=(0, -0.3 + dy, H + 0.24), rotation=(math.pi / 2, 0, 0),
                                         major_segments=32, minor_segments=6)
        V.obj().data.materials.append(M["dark"])
    cyl(0.03, 0.06, 0, -0.5, H + 0.08, M["dark"], rot=(math.pi / 2, 0, 0))                       # the prop's hub
    # The tail: the boom carries on back, a rudder of amber plate, the pennant on a whip above it.
    rod((0, -0.46, H + 0.08), (0, -0.85, H + 0.14), 0.016, M["cage"])
    rod((0, -0.3, H + 0.05), (0, -0.85, H + 0.14), 0.012, M["tube"])
    V.panel([(0, -0.76, H + 0.1), (0, -0.94, H + 0.1), (0, -0.98, H + 0.42), (0, -0.84, H + 0.38)], M["amber"], t=0.016)
    V.panel([(-0.14, -0.84, H + 0.14), (0.14, -0.84, H + 0.14), (0.12, -0.92, H + 0.14), (-0.12, -0.92, H + 0.14)], M["rust"], t=0.01)
    rod((0, -0.9, H + 0.36), (0, -0.96, H + 0.62), 0.007, M["bright"])
    V.panel([(0, -0.955, H + 0.5), (0, -0.96, H + 0.62), (0, -1.12, H + 0.57)], M["rag"], t=0.004)
    # The gun under the nose, its ammo box.
    rod((0.06, 0.4, H - 0.08), (0.06, 0.78, H - 0.1), 0.018, M["dark"])
    rod((0.06, 0.68, H - 0.1), (0.06, 0.8, H - 0.1), 0.024, M["steel"])
    box(0.08, 0.12, 0.08, 0.1, 0.3, H - 0.14, M["olive"], bevel=0.008)

def rotor():
    """The rotor's disc and the pusher prop's, blurred; the faint blades in them; the rotor head's hub over all."""
    # (Six bold streaks read as a desk fan, the first: two soft ones, fainter; the disc a size down, as the distractor's.)
    disc = blur_mat("rotor_blur", (0.12, 0.12, 0.11), 0.16, streaks=2.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.62, depth=0.004, location=(0, -0.02, H + 0.57))
    V.obj().data.materials.append(disc)
    for a in (0.3, 0.3 + math.pi):                                                               # two blades, faint
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 0.3, -0.02 + math.sin(a) * 0.3, H + 0.575), rotation=(0, 0, a))
        o = V.obj(); o.scale = (0.58, 0.05, 0.006); o.data.materials.append(blur_mat("blade_blur", (0.18, 0.17, 0.15), 0.2, streaks=1.0))
    # A faint bright rim, the blade tips' path (games draw rotor blur so: the disc alone was faint at game scale).
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.006, location=(0, -0.02, H + 0.57), major_segments=96, minor_segments=6)
    V.obj().data.materials.append(blur_mat("rim_blur", (0.55, 0.53, 0.48), 0.25, streaks=0.0))
    cyl(0.04, 0.04, 0, -0.02, H + 0.56, M["steel"], bevel=0.006)
    prop = blur_mat("prop_blur", (0.15, 0.14, 0.13), 0.28)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.26, depth=0.004, location=(0, -0.5, H + 0.08), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(prop)

base = V.group(airframe)
modules = {"rotor": V.group(rotor)}
V.finish(mud=0.0)
# LP_WRECK=1: its wreck (4 directions, its shadow in the picture; the rotor gone), then stop.
if os.environ.get("LP_WRECK"):
    for o in modules["rotor"]: o.hide_render = True
    V.wreck(base, out, seed=13, tilt=(9, -14), sink=0.02, tiles=2, margin=1.0, scorch=1.2)
    print("harrier wreck to", out); sys.exit(0)
rig = V.light(2, 2.4)                  # (at 1.6 the rotor, a tile and a half up, ran off the frame)
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, light_rig=rig)
print("harrier:", N, "directions to", out)
