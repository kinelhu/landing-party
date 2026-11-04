"""The dome taking a hit (the user, 2026-11-04: "shouldn't the effect come from the impact and dissipate over the whole
bubble?"): a flash where the shell meets the dome's skin and a wavefront crossing the whole hemisphere from there, lighting
its lattice as it passes and fading on the far side. One unit dome, REF tiles in radius at PX a tile, from DIRS directions
of the impact (the game picks the nearest and scales the sprite to its dome's radius).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/dome_wave.py -- <out_dir> [frames=24] [dirs=8]

Same camera as dome_ripple.py (orthographic, 45 degrees; anim_sheet.py stretches by sqrt(2)): frames in
<out_dir>/d<k>/frames, k = 1 for an impact due south (towards the camera), counting counter-clockwise as seen from above.
"""
import math, os, sys
import bpy, bmesh

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES = int(args[1]) if len(args) > 1 else 24
DIRS = int(args[2]) if len(args) > 2 else 8
REF, PX = 16, 12             # the dome rendered REF tiles in radius at PX pixels a tile (a soft glow, scaled up in game)
ELEV = math.radians(22)      # where the shell meets the skin: this far up from the rim

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"

bpy.ops.mesh.primitive_uv_sphere_add(radius=REF, segments=96, ring_count=48, location=(0, 0, 0))
dome = bpy.context.object
bm = bmesh.new(); bm.from_mesh(dome.data)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1),
                       clear_inner=True)
bm.to_mesh(dome.data); bm.free()
bpy.ops.object.shade_smooth()

m = bpy.data.materials.new("wave"); m.use_nodes = True
nt = m.node_tree; nt.nodes.clear()
N = nt.nodes.new; L = nt.links.new
def math_node(op, a=None, b=None):
    n = N("ShaderNodeMath"); n.operation = op
    if a is not None: n.inputs[0].default_value = a
    if b is not None: n.inputs[1].default_value = b
    return n

outn = N("ShaderNodeOutputMaterial")
tc = N("ShaderNodeTexCoord")
norm = N("ShaderNodeVectorMath"); norm.operation = "NORMALIZE"; L(tc.outputs["Object"], norm.inputs[0])
imp = N("ShaderNodeCombineXYZ")                                  # the impact's direction, set per direction
dot = N("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"; L(norm.outputs[0], dot.inputs[0]); L(imp.outputs[0], dot.inputs[1])
clampd = N("ShaderNodeClamp"); clampd.inputs["Min"].default_value = -1; clampd.inputs["Max"].default_value = 1
L(dot.outputs["Value"], clampd.inputs["Value"])
ang = math_node("ARCCOSINE"); L(clampd.outputs[0], ang.inputs[0])          # how far round the skin from the impact, 0 to pi
# The wavefront: a band at `front` radians from the impact, `width` wide.
sub = math_node("SUBTRACT"); L(ang.outputs[0], sub.inputs[0])              # inputs[1] = front, per frame
div = math_node("DIVIDE"); L(sub.outputs[0], div.inputs[0])                # inputs[1] = width, per frame
sq = math_node("POWER", None, 2.0); L(div.outputs[0], sq.inputs[0])
neg = math_node("MULTIPLY", None, -1.0); L(sq.outputs[0], neg.inputs[0])
band = math_node("EXPONENT"); L(neg.outputs[0], band.inputs[0])
# Behind the front a faint afterglow (the skin it lit, dying): where ang < front.
behind = math_node("LESS_THAN"); L(ang.outputs[0], behind.inputs[0])       # inputs[1] = front
after = math_node("MULTIPLY"); L(behind.outputs[0], after.inputs[0])       # inputs[1] = afterglow, per frame
# The lattice: hex-like cells on the skin, their edges bright.
vor = N("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"; vor.inputs["Scale"].default_value = 9.0
L(norm.outputs[0], vor.inputs["Vector"])
edge = N("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.0; edge.inputs["From Max"].default_value = 0.05
edge.inputs["To Min"].default_value = 1.0; edge.inputs["To Max"].default_value = 0.0
L(vor.outputs["Distance"], edge.inputs["Value"])
skin = math_node("ADD", None, 0.25); L(edge.outputs["Result"], skin.inputs[0])   # the lattice, and a little of the skin between
lit = math_node("ADD"); L(band.outputs[0], lit.inputs[0]); L(after.outputs[0], lit.inputs[1])
onskin = math_node("MULTIPLY"); L(lit.outputs[0], onskin.inputs[0]); L(skin.outputs[0], onskin.inputs[1])
# The rim: the skin seen edge-on, where the wave passes.
lw = N("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.3
rim = math_node("MULTIPLY"); L(lw.outputs["Facing"], rim.inputs[0]); L(band.outputs[0], rim.inputs[1])
rimk = math_node("MULTIPLY", None, 0.8); L(rim.outputs[0], rimk.inputs[0])
# The flash at the impact: a bright spot, gone in the first third.
fsc = math_node("DIVIDE", None, 0.10); L(ang.outputs[0], fsc.inputs[0])
fsq = math_node("POWER", None, 2.0); L(fsc.outputs[0], fsq.inputs[0])
fng = math_node("MULTIPLY", None, -1.0); L(fsq.outputs[0], fng.inputs[0])
fex = math_node("EXPONENT"); L(fng.outputs[0], fex.inputs[0])
flash = math_node("MULTIPLY"); L(fex.outputs[0], flash.inputs[0])          # inputs[1] = flash, per frame
s1 = math_node("ADD"); L(onskin.outputs[0], s1.inputs[0]); L(rimk.outputs[0], s1.inputs[1])
s2 = math_node("ADD"); L(s1.outputs[0], s2.inputs[0]); L(flash.outputs[0], s2.inputs[1])
fade = math_node("MULTIPLY"); L(s2.outputs[0], fade.inputs[0])             # inputs[1] = fade, per frame
cl = N("ShaderNodeClamp"); L(fade.outputs[0], cl.inputs["Value"])
em = N("ShaderNodeEmission"); em.inputs["Color"].default_value = (0.25, 0.75, 1.0, 1)
tr = N("ShaderNodeBsdfTransparent")
mix = N("ShaderNodeMixShader")
L(cl.outputs[0], mix.inputs["Fac"]); L(tr.outputs[0], mix.inputs[1]); L(em.outputs[0], mix.inputs[2])
L(mix.outputs[0], outn.inputs["Surface"])
dome.data.materials.append(m)

bpy.ops.object.camera_add(location=(0, -100, 100), rotation=(math.radians(45), 0, 0))
cam = bpy.context.object
cam.data.type = "ORTHO"
span = 2 * REF + 2
cam.data.ortho_scale = span
scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = int(span * PX)
# Framed on the dome: seen at 45 degrees it spans from 0.707 REF below its centre on the ground (the near rim) to REF above.
cam.data.shift_y = 0.146 * REF / span

for k in range(DIRS):
    az = -math.pi / 2 + 2 * math.pi * k / DIRS          # k = 0: due south (towards the camera), then counter-clockwise from above
    ix, iy, iz = math.cos(ELEV) * math.cos(az), math.cos(ELEV) * math.sin(az), math.sin(ELEV)
    imp.inputs[0].default_value, imp.inputs[1].default_value, imp.inputs[2].default_value = ix, iy, iz
    os.makedirs(f"{out}/d{k + 1}/frames", exist_ok=True)
    for f in range(FRAMES):
        t = f / (FRAMES - 1)
        e = 1 - (1 - t) ** 1.6                           # fast from the impact, slowing as it spreads
        front = 0.05 + e * math.pi * 0.95
        sub.inputs[1].default_value = front
        behind.inputs[1].default_value = front
        div.inputs[1].default_value = 0.16 + 0.22 * t    # the band widens as it goes
        after.inputs[1].default_value = 0.12 * (1 - t) ** 2
        flash.inputs[1].default_value = 3.0 * max(0.0, 1 - t / 0.3) ** 2
        fade.inputs[1].default_value = (1 - t) ** 1.2
        em.inputs["Strength"].default_value = 1.8 * (1 - t) + 0.3
        scene.render.filepath = f"{out}/d{k + 1}/frames/{f:03d}.png"
        bpy.ops.render.render(write_still=True)
print("rendered", out)
