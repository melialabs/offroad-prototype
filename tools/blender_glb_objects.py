"""Blender daxilində: GLB obyektlərini (ad, üçbucaq, dünya bbox) və ümumi ölçünü çıxarır.
  blender -b --python tools/blender_glb_objects.py -- <model.glb>
"""
import sys
import bpy
from mathutils import Vector

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
mins = [1e18] * 3
maxs = [-1e18] * 3
tot = 0
rows = []
for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    ob.data.calc_loop_triangles()
    t = len(ob.data.loop_triangles)
    tot += t
    ws = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = [min(w[i] for w in ws) for i in range(3)]
    hi = [max(w[i] for w in ws) for i in range(3)]
    for i in range(3):
        mins[i] = min(mins[i], lo[i]); maxs[i] = max(maxs[i], hi[i])
    rows.append((ob.name, t, [round(v, 2) for v in lo], [round(v, 2) for v in hi], [m.name for m in ob.data.materials if m][:2]))
print("OBJ file=%s meshes=%d tris=%d" % (path, len(rows), tot))
print("OBJ bbox min=%s max=%s" % ([round(v, 2) for v in mins], [round(v, 2) for v in maxs]))
for r in rows[:400]:
    print("OBJ", r)
imgs = [(i.name, i.size[0], i.size[1]) for i in bpy.data.images]
print("OBJ images", imgs[:20], len(imgs))
