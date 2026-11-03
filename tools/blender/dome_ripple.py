"""The dome's catch: a hemisphere of light spreading from where a shell is caught and fading (the user, 2026-11-03: "A
hemisphere effect rippling from the impact might also be good"). Rendered as frames for an explosion animation.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/dome_ripple.py -- <out_dir> [frames=16]

Same camera as tesla_tower.py (orthographic, 45 degrees; anim_sheet.py stretches by sqrt(2)), 32 px a tile (a soft glow,
drawn at scale 1): its frames in <out_dir>/frames.
"""
import math, os, sys
import bpy, bmesh

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES = int(args[1]) if len(args) > 1 else 16
PX = 32
R0, R1 = 0.5, 4.5           # tiles: its radius at the first frame and the last
os.makedirs(out + "/frames", exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"

# A hemisphere: a sphere cut at the ground.
bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=64, ring_count=32, location=(0, 0, 0))
dome = bpy.context.object
bm = bmesh.new(); bm.from_mesh(dome.data)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1),
                       clear_inner=True)
bm.to_mesh(dome.data); bm.free()
bpy.ops.object.shade_smooth()

# Its light: a cyan rim brightest where the surface turns from the eye (layer weight), a hex-like lattice (Voronoi edges),
# the rest clear. `fade` on its emission and its mask, driven per frame.
m = bpy.data.materials.new("ripple"); m.use_nodes = True
nt = m.node_tree; nt.nodes.clear()
outn = nt.nodes.new("ShaderNodeOutputMaterial")
em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (0.2, 0.7, 1.0, 1)
tr = nt.nodes.new("ShaderNodeBsdfTransparent")
mixs = nt.nodes.new("ShaderNodeMixShader")
lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.35
vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"; vor.inputs["Scale"].default_value = 6.0
edge = nt.nodes.new("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.0; edge.inputs["From Max"].default_value = 0.06
edge.inputs["To Min"].default_value = 1.0; edge.inputs["To Max"].default_value = 0.0
add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
nt.links.new(lw.outputs["Facing"], add.inputs[0])
lat = nt.nodes.new("ShaderNodeMath"); lat.operation = "MULTIPLY"; lat.inputs[1].default_value = 0.45
nt.links.new(edge.outputs["Result"], lat.inputs[0])
nt.links.new(vor.outputs["Distance"], edge.inputs["Value"])
nt.links.new(lat.outputs[0], add.inputs[1])
fade = nt.nodes.new("ShaderNodeMath"); fade.operation = "MULTIPLY"; fade.inputs[1].default_value = 1.0
nt.links.new(add.outputs[0], fade.inputs[0])
clamp = nt.nodes.new("ShaderNodeClamp")
nt.links.new(fade.outputs[0], clamp.inputs["Value"])
nt.links.new(clamp.outputs[0], mixs.inputs["Fac"])
nt.links.new(tr.outputs[0], mixs.inputs[1])
nt.links.new(em.outputs[0], mixs.inputs[2])
nt.links.new(mixs.outputs[0], outn.inputs["Surface"])
dome.data.materials.append(m)

bpy.ops.object.camera_add(location=(0, -20, 20), rotation=(math.radians(45), 0, 0))
cam = bpy.context.object
cam.data.type = "ORTHO"
span = 2 * R1 + 1.5
cam.data.ortho_scale = span
scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = int(span * PX)

for f in range(FRAMES):
    t = f / (FRAMES - 1)
    e = 1 - (1 - t) ** 2.2                       # ease out: fast at the catch, slowing as it spreads
    r = R0 + (R1 - R0) * e
    dome.scale = (r, r, r * 0.85)
    k = (1 - t) ** 1.4                           # fading
    fade.inputs[1].default_value = k
    em.inputs["Strength"].default_value = 1.6 * k + 0.2   # (at 4 its cyan saturated to white)
    scene.render.filepath = f"{out}/frames/{f:03d}.png"
    bpy.ops.render.render(write_still=True)
print("rendered", out)
