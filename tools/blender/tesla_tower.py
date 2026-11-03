"""The dome tower, modelled and rendered headless for Factorio (the 3D spike, 2026-11-03).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/tesla_tower.py -- <out_dir>

Factorio's look: an orthographic camera tilted 45 degrees, the image then stretched by sqrt(2) vertically (ground tiles
square, heights up the screen; tools/blender/factorio_frame.py does the stretch), the sun from the upper left, 64 px a
tile, the shadow as its own layer (a shadow catcher with the model hidden from the camera).
"""
import math
import sys
import bpy

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES = int(args[1]) if len(args) > 1 else 0     # 0: one still; else its loop, frame by frame (body, glow, shadow)
TILES = 3            # footprint
PX = 64              # pixels a tile
MARGIN = 2.0         # tiles of room round it (the tower's height and its shadow)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"

def mat(name, rgb, metal=0.0, rough=0.5, emit=None, strength=0.0, grime=0.5):
    """Principled, with grime: a noise darkening the colour and roughening the surface, and ambient occlusion darkening
    the creases (clean CG next to Wube's art read as plastic, the first render)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 9.0; noise.inputs["Detail"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.35, 0.75
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.35
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = grime
    mix.inputs["A"].default_value = (*rgb, 1)
    nt.links.new(ramp.outputs["Color"], mix.inputs["B"])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs["Factor"].default_value = 0.8
    nt.links.new(mix.outputs["Result"], mul.inputs["A"])
    nt.links.new(ao.outputs["AO"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], b.inputs["Base Color"])
    rr = nt.nodes.new("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = rough; rr.inputs["To Max"].default_value = min(1, rough + 0.3)
    nt.links.new(noise.outputs["Fac"], rr.inputs["Value"])
    nt.links.new(rr.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

steel = mat("steel", (0.18, 0.19, 0.2), metal=0.85, rough=0.42)
dark = mat("dark", (0.06, 0.065, 0.07), metal=0.6, rough=0.6)
paint = mat("paint", (0.20, 0.33, 0.42), metal=0.3, rough=0.55)     # Kessler-Hayashi's slate-teal
copper = mat("copper", (0.55, 0.3, 0.16), metal=1.0, rough=0.35)
glow = mat("glow", (0.5, 0.9, 1.0), emit=(0.45, 0.85, 1.0), strength=2.5, grime=0.0)
hazard = mat("hazard", (0.75, 0.6, 0.12), metal=0.2, rough=0.6)

def add(obj, m):
    obj.data.materials.append(m)
    return obj

def cyl(r, h, z, m, verts=32, depth_bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(0, 0, z + h / 2))
    o = bpy.context.object
    if depth_bevel:
        mod = o.modifiers.new("b", "BEVEL"); mod.width = depth_bevel; mod.segments = 2
    return add(o, m)

def box(sx, sy, sz, x, y, z, m, rot=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2), rotation=(0, 0, rot))
    o = bpy.context.object
    o.scale = (sx, sy, sz)
    mod = o.modifiers.new("b", "BEVEL"); mod.width = 0.03; mod.segments = 2
    return add(o, m)

def torus(R, r, z, m):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=(0, 0, z), major_segments=48, minor_segments=12)
    return add(bpy.context.object, m)

# Footing: a hexagonal plinth on a square pad, hazard trim.
box(2.9, 2.9, 0.12, 0, 0, 0, dark)
cyl(1.35, 0.22, 0.12, steel, verts=6, depth_bevel=0.04)
cyl(1.38, 0.05, 0.12, hazard, verts=6)
# Four braced legs to the column, painted.
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    x, y = math.cos(a) * 1.05, math.sin(a) * 1.05
    box(0.22, 0.22, 1.1, x, y, 0.3, paint, rot=a)
    box(0.5, 0.5, 0.18, x, y, 0.3, steel, rot=a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.05, depth=1.25,
        location=(x * 0.6, y * 0.6, 1.05), rotation=(math.radians(55) * math.sin(a), -math.radians(55) * math.cos(a), 0))
    add(bpy.context.object, steel)
# The column: housing, then the coil stack.
cyl(0.62, 0.9, 0.34, paint, verts=24, depth_bevel=0.03)
cyl(0.66, 0.08, 1.24, steel, verts=24)
cyl(0.32, 1.7, 1.32, dark, verts=20)
# Each ring its own material: its glow is the pulse climbing the coil (the loop).
rings = []
for i in range(6):
    m = mat(f"ring{i}", (0.55, 0.3, 0.16), metal=1.0, rough=0.35, emit=(0.45, 0.85, 1.0), strength=0.0)
    rings.append(m)
    torus(0.42 - i * 0.02, 0.085, 1.48 + i * 0.26, m)
# Detail (the density Wube's art has): access panels and vents round the housing, a bolt ring, cable runs from the
# legs to the housing, conduit boxes on the plinth.
for k in range(8):
    a = k * math.pi / 4
    box(0.26, 0.05, 0.36, math.cos(a) * 0.63, math.sin(a) * 0.63, 0.58, steel if k % 2 else dark, rot=a + math.pi / 2)
for k in range(16):
    a = k * math.pi / 8
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.035, depth=0.05, location=(math.cos(a) * 0.6, math.sin(a) * 0.6, 1.3))
    add(bpy.context.object, steel)
for k in range(4):
    a = k * math.pi / 2
    box(0.34, 0.26, 0.2, math.cos(a) * 1.15, math.sin(a) * 1.15, 0.34, dark, rot=a)
    box(0.18, 0.04, 0.12, math.cos(a) * 1.15, math.sin(a) * 1.15, 0.54, hazard, rot=a)
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object
    c.data.bevel_depth = 0.03
    pts = c.data.splines[0].bezier_points
    pts[0].co = (math.cos(a) * 1.15, math.sin(a) * 1.15, 0.5); pts[0].handle_right = (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.95)
    pts[1].co = (math.cos(a) * 0.55, math.sin(a) * 0.55, 1.15); pts[1].handle_left = (math.cos(a) * 0.8, math.sin(a) * 0.8, 1.2)
    pts[0].handle_left = pts[0].co; pts[1].handle_right = pts[1].co
    c.data.materials.append(dark)
# Insulator collar and emitter.
cyl(0.5, 0.12, 3.02, steel, verts=24, depth_bevel=0.02)
torus(0.52, 0.06, 3.2, glow)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(0, 0, 3.42), segments=32, ring_count=16)
add(bpy.context.object, glow)
model = [o for o in scene.objects]

# The shadow catcher: a ground plane that shows only the shadow (rendered in its own pass with the model invisible).
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.object
ground.is_shadow_catcher = True

# The sun from the upper left (Factorio's shadows fall to the lower right).
bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
sun = bpy.context.object
sun.data.energy = 2.6
sun.data.color = (1.0, 0.96, 0.9)
sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(50), 0, math.radians(-45))
world = bpy.data.worlds.new("w"); scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.72, 0.68, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55

# The camera: orthographic, from the south, 45 degrees down.
bpy.ops.object.camera_add(location=(0, -20, 20), rotation=(math.radians(45), 0, 0))
cam = bpy.context.object
cam.data.type = "ORTHO"
span = TILES + 2 * MARGIN
cam.data.ortho_scale = span
scene.camera = cam
scene.render.resolution_x = int(span * PX)
scene.render.resolution_y = int(span * PX)          # stretched by sqrt(2) afterwards

def render(path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

def emission(m, v):
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = v

import random
rng = random.Random(7)
arcs = []
def set_frame(f):
    """Frame f of FRAMES: the pulse at height f/FRAMES up the coil, the emitter breathing twice a loop, two to three arcs
    from the emitter to the collar, new each frame (seeded)."""
    t = f / FRAMES
    for i, m in enumerate(rings):
        d = abs(((t * 6 - i) + 3) % 6 - 3)          # distance of ring i from the pulse, round the loop
        emission(m, max(0.0, 3.0 - 2.2 * d))
    emission(glow, 2.0 + 1.2 * math.sin(t * 4 * math.pi))
    for o in arcs:
        bpy.data.objects.remove(o, do_unlink=True)
    arcs.clear()
    for _ in range(rng.choice((2, 2, 3))):
        a0 = rng.uniform(0, 2 * math.pi)
        bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
        c = bpy.context.object
        c.data.bevel_depth = 0.012
        sp = c.data.splines[0]
        sp.bezier_points.add(2)
        pts = sp.bezier_points
        z0, z1 = 3.42, 3.08
        for k, p in enumerate(pts):
            u = k / (len(pts) - 1)
            r = 0.3 + 0.25 * u
            a = a0 + rng.uniform(-0.5, 0.5) * u
            p.co = (math.cos(a) * r, math.sin(a) * r, z0 + (z1 - z0) * u + rng.uniform(-0.06, 0.06))
            p.handle_left_type = p.handle_right_type = "VECTOR"
        c.data.materials.append(glow)
        arcs.append(c)

if not FRAMES:
    # Body: the model, no ground.
    ground.hide_render = True
    render(out + "/body.png")
    # Shadow: the ground's catcher, the model casting but unseen.
    ground.hide_render = False
    for o in model:
        o.visible_camera = False
    render(out + "/shadow.png")
else:
    import os
    for k in ("body", "glow"):
        os.makedirs(f"{out}/{k}", exist_ok=True)
    for f in range(FRAMES):
        set_frame(f)
        ground.hide_render = True
        sun.hide_render = False
        world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
        for o in model: o.is_holdout = False
        render(f"{out}/body/{f:03d}.png")
        # Glow alone: the lit parts, every other part a holdout (it hides what is behind it), no light.
        sun.hide_render = True
        world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
        for o in model:
            ms = [s.material for s in o.material_slots if s.material]
            o.is_holdout = not any(m is glow or m in rings for m in ms)
        render(f"{out}/glow/{f:03d}.png")
    for o in model: o.is_holdout = False
    sun.hide_render = False
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    ground.hide_render = False
    for o in model: o.visible_camera = False
    render(f"{out}/shadow.png")
print("rendered", out)
