"""blender -b --python tools/blender_preview.py -- model.glb out.png  (workbench, 2 görünüş)"""
import sys, math
import bpy
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
mins = Vector((1e9,)*3); maxs = Vector((-1e9,)*3)
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            mins = Vector(min(mins[i], w[i]) for i in range(3)); maxs = Vector(max(maxs[i], w[i]) for i in range(3))
ctr = (mins + maxs) / 2; size = max((maxs - mins))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 1000; sc.render.resolution_y = 600
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.clip_end = 10000; cam.data.lens = 35
d = size * 1.6
for i, (dx, dy, dz) in enumerate([(1, -1, 0.6), (-1, 1, 0.5)]):
    cam.location = ctr + Vector((dx, dy, dz)) * d
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = a[1].replace(".png", "_%d.png" % i)
    bpy.ops.render.render(write_still=True)
