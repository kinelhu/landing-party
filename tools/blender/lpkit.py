"""Shared Blender pieces for Landing Party's rendered buildings (tesla_tower.py came first and keeps its own copy):
materials with grime and occlusion, primitives, Factorio's camera and sun, the body / glow / shadow passes, arcs.

Used from a script run as Blender -b -P <script> -- <out_dir> [frames]: `import lpkit` after putting this folder on
sys.path.
"""
import math, os, random
import bpy

PX = 64

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"; s.cycles.samples = 96; s.cycles.use_denoising = True
    s.render.film_transparent = True; s.view_settings.view_transform = "Standard"
    return s

def mat(name, rgb, metal=0.0, rough=0.5, emit=None, strength=0.0, grime=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 9.0; noise.inputs["Detail"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.35, 0.75
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.35
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = grime; mix.inputs["A"].default_value = (*rgb, 1)
    nt.links.new(ramp.outputs["Color"], mix.inputs["B"])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs["Factor"].default_value = 0.8
    nt.links.new(mix.outputs["Result"], mul.inputs["A"]); nt.links.new(ao.outputs["AO"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], b.inputs["Base Color"])
    rr = nt.nodes.new("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = rough; rr.inputs["To Max"].default_value = min(1, rough + 0.3)
    nt.links.new(noise.outputs["Fac"], rr.inputs["Value"]); nt.links.new(rr.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = strength
    return m

def emission(m, v):
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = v

def palette():
    return {"steel": mat("steel", (0.18, 0.19, 0.2), metal=0.85, rough=0.42),
            "dark": mat("dark", (0.06, 0.065, 0.07), metal=0.6, rough=0.6),
            "paint": mat("paint", (0.20, 0.33, 0.42), metal=0.3, rough=0.55),
            "copper": mat("copper", (0.55, 0.3, 0.16), metal=1.0, rough=0.35),
            "hazard": mat("hazard", (0.75, 0.6, 0.12), metal=0.2, rough=0.6),
            "glow": mat("glow", (0.5, 0.9, 1.0), emit=(0.45, 0.85, 1.0), strength=2.0, grime=0.0)}

def _add(o, m):
    o.data.materials.append(m); return o

def cyl(r, h, x, y, z, m, verts=24, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(x, y, z + h / 2), rotation=rot)
    o = bpy.context.object
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    return _add(o, m)

def rod(p0, p1, r, m, verts=8):
    """A thin cylinder from p0 to p1 (lattice members, braces)."""
    import mathutils
    a, b = mathutils.Vector(p0), mathutils.Vector(p1)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = d.to_track_quat("Z", "Y")
    return _add(o, m)

def box(sx, sy, sz, x, y, z, m, rot=0.0, bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2), rotation=(0, 0, rot))
    o = bpy.context.object; o.scale = (sx, sy, sz)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    return _add(o, m)

def sphere(r, x, y, z, m):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=24, ring_count=12)
    return _add(bpy.context.object, m)

def torus(R, r, x, y, z, m):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=(x, y, z), major_segments=48, minor_segments=12)
    return _add(bpy.context.object, m)

def stage(scene, tiles, margin):
    """Shadow catcher, the sun from the upper left, a warm sky, the camera from the south at 45 degrees; returns them."""
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0)); ground = bpy.context.object; ground.is_shadow_catcher = True
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10)); sun = bpy.context.object
    sun.data.energy = 2.6; sun.data.color = (1.0, 0.96, 0.9); sun.data.angle = math.radians(3)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-45))
    world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.75, 0.72, 0.68, 1); bg.inputs[1].default_value = 0.55
    bpy.ops.object.camera_add(location=(0, -20, 20), rotation=(math.radians(45), 0, 0)); cam = bpy.context.object
    cam.data.type = "ORTHO"; span = tiles + 2 * margin; cam.data.ortho_scale = span; scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = int(span * PX)
    return ground, sun, world

def render(scene, path):
    scene.render.filepath = path; bpy.ops.render.render(write_still=True)

def passes(scene, out, frames, set_frame, model, glowing, ground, sun, world):
    """Each frame's body and glow (the lit parts alone: every other part a holdout, no light), then one shadow."""
    bg = world.node_tree.nodes["Background"]
    for k in ("body", "glow"): os.makedirs(f"{out}/{k}", exist_ok=True)
    for f in range(frames):
        set_frame(f)
        ground.hide_render = True; sun.hide_render = False; bg.inputs[1].default_value = 0.55
        for o in model: o.is_holdout = False
        render(scene, f"{out}/body/{f:03d}.png")
        sun.hide_render = True; bg.inputs[1].default_value = 0.0
        for o in model:
            ms = [s.material for s in o.material_slots if s.material]
            o.is_holdout = not any(m in glowing for m in ms)
        render(scene, f"{out}/glow/{f:03d}.png")
    for o in model: o.is_holdout = False
    sun.hide_render = False; bg.inputs[1].default_value = 0.55; ground.hide_render = False
    for o in model: o.visible_camera = False
    render(scene, f"{out}/shadow.png")

def arc(p0, p1, m, rng, kinks=3, jitter=0.08, r=0.012):
    """A crooked bright line from p0 to p1 (a lightning arc), new kinks each call."""
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0)); c = bpy.context.object
    c.data.bevel_depth = r; sp = c.data.splines[0]; sp.bezier_points.add(kinks)
    pts = sp.bezier_points
    for k, p in enumerate(pts):
        u = k / (len(pts) - 1)
        p.co = tuple(p0[i] + (p1[i] - p0[i]) * u + (rng.uniform(-jitter, jitter) if 0 < k < len(pts) - 1 else 0) for i in range(3))
        p.handle_left_type = p.handle_right_type = "VECTOR"
    c.data.materials.append(m)
    return c
