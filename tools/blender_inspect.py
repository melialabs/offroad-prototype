"""Blender daxilində işləyir: glTF modelinin statistikasını çıxarır.

İstifadə:
  blender -b --python tools/blender_inspect.py -- <model.gltf>
"""
import sys
import bpy


def main():
    argv = sys.argv
    path = argv[argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)

    total_tris = 0
    unique_tris = 0
    seen = set()
    rows = []
    mins = [1e18] * 3
    maxs = [-1e18] * 3
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)
        total_tris += tris
        if me.name not in seen:
            seen.add(me.name)
            unique_tris += tris
        mats = [m.name for m in me.materials if m]
        for c in ob.bound_box:
            w = ob.matrix_world @ __import__("mathutils").Vector(c)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
        rows.append((ob.name, me.name, len(me.vertices), tris, mats))

    print("INSPECT file=%s" % path)
    print("INSPECT objects=%d unique_meshes=%d" % (len(rows), len(seen)))
    print("INSPECT triangles_total=%d triangles_unique=%d" % (total_tris, unique_tris))
    print("INSPECT bbox_min=%s bbox_max=%s size=%s" % (
        [round(v, 3) for v in mins], [round(v, 3) for v in maxs],
        [round(maxs[i] - mins[i], 3) for i in range(3)]))
    mat_tris = {}
    for _, _, _, tris, mats in rows:
        key = ",".join(mats) or "-"
        mat_tris[key] = mat_tris.get(key, 0) + tris
    for k, v in sorted(mat_tris.items(), key=lambda kv: -kv[1]):
        print("INSPECT material %s triangles=%d" % (k, v))
    for r in sorted(rows, key=lambda r: -r[3])[:12]:
        print("INSPECT obj %s mesh=%s verts=%d tris=%d mats=%s" % r)
    for m in bpy.data.materials:
        node = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
        print("INSPECT mat %s blend=%s" % (m.name, getattr(m, "blend_method", "?")))


main()
