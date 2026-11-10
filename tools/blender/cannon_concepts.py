"""Clay silhouettes for the big orbital cannon (the user, 2026-11-10: "That cannon looks terrible. Why are we settling"):
three outlines on one deck strip at the platform's edge, grey clay, the game's camera, before any detail.
A: railgun spine (the Space Age railgun's family, one armoured box barrel), B: naval turret (barbette, twin barrels),
C: mass driver (open coil rings on a truss).

    Blender -b -P tools/blender/cannon_concepts.py -- <out.png>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import lpkit

out = sys.argv[sys.argv.index("--") + 1]
scene = lpkit.reset(); scene.cycles.samples = 24
CLAY = lpkit.mat("clay", (0.5, 0.5, 0.5), metal=0.0, rough=0.7, grime=0.0)
DECK = lpkit.mat("deck", (0.22, 0.22, 0.24), metal=0.0, rough=0.8, grime=0.0)
B = lpkit.box

def box(sx, sy, sz, x, y, z, pitch=0.0, bevel=0.08):
    o = B(sx, sy, sz, x, y, z, CLAY, bevel=bevel); o.rotation_euler[0] = -pitch; return o

def tube(p0, p1, r0, r1, verts=24):
    a, b = mathutils.Vector(p0), mathutils.Vector(p1); d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = "QUATERNION"; o.rotation_quaternion = d.to_track_quat("Z", "Y")
    o.data.materials.append(CLAY); return o

def spine(ox):
    # A massive cradle and wedge housing, one box barrel with a slot, coil bands either side.
    box(7.2, 9.0, 0.5, ox, -1.5, 0)
    box(5.8, 6.5, 2.2, ox, -2.0, 0.5, bevel=0.5)
    box(4.2, 4.0, 1.2, ox, -3.0, 2.7, bevel=0.4)
    base, tip = (ox, 0.0, 3.0), (ox, 17.0, 0.8)
    pitch = math.atan2(base[2] - tip[2], tip[1] - base[1])
    L = math.dist(base, tip)
    for k in range(5):
        t0, t1 = k / 5, (k + 1) / 5
        w = 2.8 - 0.25 * k
        c = [base[i] + (tip[i] - base[i]) * (t0 + t1) / 2 for i in range(3)]
        box(w, L / 5 + 0.05, 1.6 - 0.1 * k, c[0], c[1], c[2] - 0.8, pitch, bevel=0.15)
        for sx in (-1, 1):
            for j in range(4):
                t = t0 + (t1 - t0) * (j + 0.5) / 4
                q = [base[i] + (tip[i] - base[i]) * t for i in range(3)]
                box(0.35, 0.5, 1.1, q[0] + sx * (w / 2 + 0.15), q[1], q[2] - 0.55, pitch, bevel=0.1)
    box(3.4, 1.4, 2.0, tip[0], tip[1] - 0.4, tip[2] - 1.0, pitch, bevel=0.3)
    for sx in (-1, 1):
        box(1.2, 3.0, 3.2, ox + sx * 3.0, 0.5, 0.5, bevel=0.3)

def naval(ox):
    lpkit.cyl(3.8, 0.8, ox, -1.0, 0, CLAY, verts=64, bevel=0.2)
    box(6.0, 6.5, 2.4, ox, -1.5, 0.8, bevel=0.9)
    for sx in (-1, 1):
        tube((ox + sx * 1.2, 1.5, 2.2), (ox + sx * 1.2, 17.0, 0.6), 0.6, 0.42)
        lpkit.cyl(0.62, 1.2, ox + sx * 1.2, 16.5, 0.0, CLAY, verts=24)
    box(4.5, 2.5, 1.6, ox, -5.0, 0.8, bevel=0.4)

def driver(ox):
    box(6.5, 7.0, 3.0, ox, -2.5, 0, bevel=0.6)
    base, tip = (ox, 1.0, 3.2), (ox, 17.0, 0.4)
    tube(base, tip, 0.35, 0.35, verts=12)
    for i in range(8):
        t = (i + 0.5) / 8
        q = [base[j] + (tip[j] - base[j]) * t for j in range(3)]
        pitch = math.atan2(base[2] - tip[2], tip[1] - base[1])
        bpy.ops.mesh.primitive_torus_add(major_radius=2.0 - i * 0.1, minor_radius=0.4, location=q,
                                         rotation=(math.pi / 2 - pitch, 0, 0), major_segments=48, minor_segments=12)
        bpy.context.object.data.materials.append(CLAY)
    for sx in (-1, 1):
        tube((ox + sx * 2.0, 6.0, 0.3), (ox + sx * 0.4, 9.0, 2.2), 0.25, 0.25, verts=10)

# The deck: three footprints, 8 by 12, their front edge at y 6, the void beyond.
for k, fn in enumerate((spine, naval, driver)):
    ox = (k - 1) * 11
    B(10, 12.4, 0.1, ox, 0, -0.1, DECK, bevel=0.0)
    fn(ox)
ground, sun, world = lpkit.stage(scene, 36, 0)
scene.render.resolution_x = scene.render.resolution_y = 1400
cam = scene.camera; cam.location = (0, -20 + 4, 20 + 4)
ground.hide_render = False
lpkit.render(scene, out)
print("concepts", out)
