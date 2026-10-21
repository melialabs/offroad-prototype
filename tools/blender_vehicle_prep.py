"""Blender daxilində: Sketchfab maşın GLB-sini oyun üçün hazırlayır.

 - metrə çevirir (real uzunluğa görə), irəli = Godot +Z (Blender -Y), yerə oturdur, mərkəzləşdirir
 - 4 təkəri ayrı obyektlərə (W_RL, W_RR, W_FL, W_FR) ayırır, mənşəyi təkər mərkəzinə qoyur
 - qalan hissələri tək "Body" obyektinə birləşdirir (material sayı saxlanır)
 - teksturaları max ölçüyə kiçildir, istəyə görə üçbucaqları azaldır
İstifadə: blender -b --python tools/blender_vehicle_prep.py -- <niva|2107|2106> <giriş.glb> <çıxış.glb>
"""
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

MODELS = {
    # length: real uzunluq (m); flip: 180° çevir (model +Y-ə baxırsa); wheels: ad ilə seçim (None = həndəsə ilə)
    # lamps: ön ("head") və arxa ("tail") fənərlər. obj = obyekt adı prefiksləri, mat = (material adı hissələri, region)
    "niva": {"lamps": {"head": {"obj": ["headlight_low"]}, "tail": {"obj": ["taillight_low"]}},
             "length": 3.74, "flip": False, "wheel_prefix": ["wheel_low_niva", "wheel_low.001_", "wheel_low.002_", "wheel_low.003_"], "tex": 1024, "decimate": 1.0},
    "2107": {"lamps": {"head": {"obj": ["base_Fari_0"]}, "tail": {"mat": [["material_13", "material_14"], "rear"]}},
             "length": 4.14, "flip": True, "wheel_prefix": ["Wheel P P", "Wheel P Z", "Wheel L P", "Wheel L Z"], "tex": 1024, "decimate": 1.0},
    "2106": {"lamps": {"head": {"mat": [["Matte__FF00FFC8", "z_far"], "front"]}, "tail": {"mat": [["material.005", "material_4", "material_3", "material_5"], "rear"]}},
             "length": 4.17, "flip": False, "wheel_prefix": None, "tex": 1024, "decimate": 0.5,
             # baqaj kilidi (xrom düymə) gecə işıq kimi görünür: gövdədən silinir (x, y aralığı, z aralığı, max ölçü)
             "strip": [(0.01, 1.95, 2.03, 0.69, 0.74, 0.06)]},
}


def world_bbox(obs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in obs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(min(lo[i], w[i]) for i in range(3))
            hi = Vector(max(hi[i], w[i]) for i in range(3))
    return lo, hi


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def select_only(obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]


def join(obs, name):
    select_only(obs)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


def centroid(ob):
    lo, hi = world_bbox([ob])
    return (lo + hi) / 2, lo, hi


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    key, src, dst = a
    cfg = MODELS[key]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)

    # 1) hamısını dünya koordinatına çevir (valideyn əlaqələri və miqyas tətbiq olunur)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
    obs = meshes()
    for o in obs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    obs = meshes()
    select_only(obs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # 2) ölçü, istiqamət, yer
    lo, hi = world_bbox(obs)
    if cfg["flip"]:
        for o in obs:
            # glTF importu kvaternion rejimi verir; euler yazmaq təsirsiz qalırdı (2107 tərs idi)
            o.rotation_mode = "XYZ"
            o.rotation_euler = (0.0, 0.0, 3.14159265)
        bpy.context.view_layer.update()
        select_only(obs)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        lo, hi = world_bbox(obs)
    s = cfg["length"] / (hi.y - lo.y)
    for o in obs:
        o.location = o.location * s
        o.scale = o.scale * s
    select_only(obs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = world_bbox(obs)
    shift = Vector(((lo.x + hi.x) / -2, (lo.y + hi.y) / -2, -lo.z))
    for o in obs:
        o.location += shift
    select_only(obs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = world_bbox(obs)
    print("PREP scale=%.5f size=%s" % (s, [round(hi[i] - lo[i], 3) for i in range(3)]))

    # 3) təkərləri seç
    groups = {}
    if cfg["wheel_prefix"]:
        for pref in cfg["wheel_prefix"]:
            g = [o for o in meshes() if o.name.startswith(pref)]
            if not g:
                raise SystemExit("təkər tapılmadı: " + pref)
            groups[pref] = g
    else:
        groups = geometric_wheels()

    # hər qrupun mərkəzi, radiusu
    wheel_info = []
    for name, g in groups.items():
        l, h = world_bbox(g)
        c = (l + h) / 2
        wheel_info.append((name, g, c, (h.z - l.z) / 2, h.x - l.x))
    # R/L, F/R təyin et: Blender -Y = irəli, +X = sol (Godot x ilə eyni)
    out = {}
    for name, g, c, r, w in wheel_info:
        front = c.y < 0
        right = c.x > 0
        key2 = ("W_F" if front else "W_R") + ("R" if right else "L")
        out[key2] = (g, c, r, w)
    print("PREP wheels=%s" % {k: ([round(v, 3) for v in c], round(r, 3), round(w, 3)) for k, (g, c, r, w) in out.items()})
    if len(out) != 4:
        raise SystemExit("4 təkər olmalıdır: %d" % len(out))

    wheel_objs = set()
    final = {}
    for k, (g, c, r, w) in out.items():
        ob = join(g, k)
        wheel_objs.add(ob)
        # mənşəyi təkər mərkəzinə
        bpy.context.scene.cursor.location = c
        select_only([ob])
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        final[k] = ob

    # 4) fənər obyektləri (ad ilə), sonra gövdə
    lamp_parts = {"head": [], "tail": []}
    for kind, rule in cfg.get("lamps", {}).items():
        for pref in rule.get("obj", []):
            lamp_parts[kind] += [o for o in meshes() if o not in wheel_objs and o.name.startswith(pref)]
    taken = set(sum(lamp_parts.values(), []))
    body = [o for o in meshes() if o not in wheel_objs and o not in taken]
    bob = join(body, "Body")
    # material ilə seçilən fənərlər: gövdənin yan-yana üzlərindən ayrılır
    for kind, rule in cfg.get("lamps", {}).items():
        if "mat" in rule:
            names, region = rule["mat"]
            part = extract_faces(bob, names, region, cfg["length"])
            if part is not None:
                lamp_parts[kind].append(part)
    for kind, parts in lamp_parts.items():
        finish_lamps(parts, kind)
    bpy.context.scene.cursor.location = (0, 0, 0)
    select_only([bob])
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bob.data.calc_loop_triangles()
    print("PREP body_tris=%d" % len(bob.data.loop_triangles))
    for (xmax, ylo, yhi, zlo, zhi, smax) in cfg.get("strip", []):
        strip_islands(bob, xmax, ylo, yhi, zlo, zhi, smax)
    if cfg["decimate"] < 1.0:
        # ciddi sətir: yalnız normalları qoruyan qrup-collapse
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.object.mode_set(mode="OBJECT")
        mod = bob.modifiers.new("dec", "DECIMATE")
        mod.ratio = cfg["decimate"]
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
        bob.data.calc_loop_triangles()
        print("PREP body_tris_after=%d" % len(bob.data.loop_triangles))

    # 5) teksturalar
    mx = cfg["tex"]
    for im in bpy.data.images:
        if im.size[0] > mx or im.size[1] > mx:
            f = mx / max(im.size[0], im.size[1])
            im.scale(max(1, int(im.size[0] * f)), max(1, int(im.size[1] * f)))
    for o in meshes():
        o.data.calc_loop_triangles()
    print("PREP total_tris=%d" % sum(len(o.data.loop_triangles) for o in meshes()))

    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="AUTO",
                              export_apply=False, export_yup=True, export_cameras=False, export_lights=False)
    print("PREP done")


def extract_faces(ob, names, region, length):
    """Verilmiş material adlarını (hissə) daşıyan və ön/arxa bölgəsində olan üzləri ayrıca obyektə çıxarır."""
    before = set(bpy.data.objects)
    select_only([ob])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(ob.data)
    yb = length * 0.5 - 0.35
    n = 0
    for f in bm.faces:
        mat = ob.material_slots[f.material_index].material
        nm = mat.name if mat else ""
        y = f.calc_center_median().y
        ok_region = (y < -yb) if region == "front" else (y > yb)
        if ok_region and any(k in nm for k in names):
            f.select = True
            n += 1
    bmesh.update_edit_mesh(ob.data)
    if n:
        bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    print("PREP lamp faces %s %s = %d" % (names, region, n))
    new = [o for o in bpy.data.objects if o not in before]
    return new[0] if new else None


def finish_lamps(parts, kind):
    """Fənər hissələrini birləşdirir, bağlı hissələrə bölür, x işarəsinə görə 2 obyektə (L_<kind>_N / _P) toplayır."""
    parts = [p for p in parts if p is not None]
    if not parts:
        return
    ob = join(parts, "L_tmp") if len(parts) > 1 else parts[0]
    before = set(bpy.data.objects)
    select_only([ob])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = [ob] + [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    sides = {"N": [], "P": []}
    for o in pieces:
        lo, hi = world_bbox([o])
        sides["P" if (lo.x + hi.x) / 2 > 0 else "N"].append(o)
    for sd, g in sides.items():
        if not g:
            continue
        j = join(g, "L_%s_%s" % (kind.upper(), sd)) if len(g) > 1 else g[0]
        j.name = "L_%s_%s" % (kind.upper(), sd)
        select_only([j])
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        lo, hi = world_bbox([j])
        print("PREP lamp %s center=%s size=%s" % (j.name, [round(v, 3) for v in (lo + hi) / 2], [round(v, 3) for v in (hi - lo)]))


def strip_islands(ob, xmax, ylo, yhi, zlo, zhi, smax):
    """Gövdədən kiçik bağlı hissələri (ölçü < smax) verilmiş qutu daxilində silir."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen = set()
    kill = []
    for f in bm.faces:
        if f in seen:
            continue
        stack = [f]
        seen.add(f)
        faces = []
        while stack:
            c = stack.pop()
            faces.append(c)
            for e in c.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
        vs = {v for g in faces for v in g.verts}
        lo = [min(v.co[a] for v in vs) for a in range(3)]
        hi = [max(v.co[a] for v in vs) for a in range(3)]
        ctr = [(lo[a] + hi[a]) / 2 for a in range(3)]
        if max(hi[a] - lo[a] for a in range(3)) < smax and abs(ctr[0]) < xmax and ylo <= ctr[1] <= yhi and zlo <= ctr[2] <= zhi:
            kill.extend(faces)
    print("PREP strip faces=%d" % len(kill))
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()


def geometric_wheels():
    """Təkərləri birləşmiş meshlərdən həndəsə ilə çıxarır: hər mesh bağlı hissələrə bölünür,
    təkər oxuna yaxın, dairəvi (YZ-də) hissələr 4 təkərə paylanır."""
    obs = meshes()
    # yalnız yerə yaxın obyektlər (təkər qapaqlıları)
    candidates = []
    for o in obs:
        lo, hi = world_bbox([o])
        if lo.z < 0.15:
            candidates.append(o)
    select_only(candidates)
    parts = []
    for o in candidates:
        select_only([o])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in meshes()]
    lo_all, hi_all = world_bbox(parts)
    # təkər oxu mövqeyi: təxmini (uzunluğun ±0.29-u, iz ±0.7)
    by_axle = {}
    found = []
    for o in parts:
        lo, hi = world_bbox([o])
        size = hi - lo
        c = (lo + hi) / 2
        # təkər hissəsi: x-də nazik, YZ-də ~dairəvi, diametri 0.45..0.75, yerə dəyən və ya yuxarıda
        if 0.45 <= size.y <= 0.8 and 0.45 <= size.z <= 0.8 and size.x <= 0.35 and abs(size.y - size.z) < 0.1 and lo.z < 0.08 and abs(c.x) > 0.45:
            found.append(o)
    print("PREP tire-like parts=%d" % len(found))
    # hər kvadrantdan ən böyük hissə = rezin
    quad = {}
    for o in found:
        lo, hi = world_bbox([o])
        c = (lo + hi) / 2
        k = (c.y < 0, c.x > 0)
        vol = (hi - lo).x * (hi - lo).y * (hi - lo).z
        if k not in quad or vol > quad[k][1]:
            quad[k] = (o, vol, c, (hi - lo).y / 2)
    groups = {}
    for k, (tire, vol, c, r) in quad.items():
        g = [tire]
        for o in parts:
            if o is tire:
                continue
            lo, hi = world_bbox([o])
            oc = (lo + hi) / 2
            size = hi - lo
            # təkər oxuna konsentrik hissələr (rezin, disk, qapaq, hub); gövdə hissələri (asma, qanad) oxdan kənardadır
            if abs(oc.x - c.x) < 0.3 and Vector((0, oc.y - c.y, oc.z - c.z)).length < 0.05 and max(size.y, size.z) < r * 2.6 and size.x < 0.3:
                g.append(o)
        groups["q%d%d" % k] = g
        print("PREP wheel group %s parts=%d" % (k, len(g)))
    return groups


main()
