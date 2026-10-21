"""Poly Haven meşə modellərini oyun üçün optimallaşdırır (Blender daxilində işləyir).

İstifadə:
  blender -b --python tools/blender_optimize.py -- <asset_id> [<asset_id> ...]

Girişlər:
  assets_src/polyhaven/<id>/<id>_1k.gltf (+ .bin, textures/)  - orijinallar, toxunulmur
  tools/vegetation_config.json                                - hər model üçün qaydalar
Çıxışlar:
  assets/vegetation/<id>/<id>_lod0.glb, _lod1.glb, _lod2.glb   - həndəsə (materiallar Godot-da təyin olunur)
  assets/vegetation/textures/<id>_foliage.png                  - alfa kartlar üçün RGBA tekstura
  assets/vegetation/<id>/stats.json                            - üçbucaq sayları

Niyə glTF birbaşa oxunur: orijinallar 5-17 milyon üçbucaqdır. Blender-ə import etmək yüzlərlə MB RAM və dəqiqələr alır,
numpy ilə yalnız lazım olan massivlər oxunur.

İynəyarpaq/yarpaq (foliage) üçbucaqları (hər iynə ayrıca üçbucaqdır) üçbucaq mərkəzlərinə görə voksel klasterlərinə bölünür,
hər klaster üçün alfa kartlı budaq çubuqları qurulur. Odun (gövdə, qabıq, ölü budaqlar) decimate ilə azaldılır.
"""
import json
import math
import os
import random
import shutil
import struct
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(bpy.path.abspath("//")).resolve() if False else Path(__file__).resolve().parent.parent
CFG = json.loads((ROOT / "tools" / "vegetation_config.json").read_text(encoding="utf8"))
SRC = ROOT / "assets_src" / "polyhaven"
OUT = ROOT / "assets" / "vegetation"

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


# --- glTF oxuyucu (numpy) ----------------------------------------------------

class Gltf:
    def __init__(self, path):
        self.path = Path(path)
        self.g = json.loads(self.path.read_text(encoding="utf8"))
        self.bins = {}

    def _buf(self, idx):
        if idx not in self.bins:
            uri = self.g["buffers"][idx]["uri"]
            self.bins[idx] = np.memmap(self.path.parent / uri, dtype=np.uint8, mode="r")
        return self.bins[idx]

    def accessor(self, i):
        a = self.g["accessors"][i]
        bv = self.g["bufferViews"][a["bufferView"]]
        buf = self._buf(bv["buffer"])
        dt = np.dtype(COMP[a["componentType"]])
        n = NCOMP[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", dt.itemsize * n)
        count = a["count"]
        if stride == dt.itemsize * n:
            arr = np.frombuffer(buf, dtype=dt, count=count * n, offset=off).reshape(count, n)
        else:
            raw = np.frombuffer(buf, dtype=np.uint8, count=stride * (count - 1) + dt.itemsize * n, offset=off)
            arr = np.lib.stride_tricks.as_strided(raw.view(np.uint8), shape=(count, dt.itemsize * n),
                                                  strides=(stride, 1)).copy().view(dt).reshape(count, n)
        return np.array(arr)

    def primitives(self, mesh_index):
        """[(material_name, positions, normals, uv0, indices)] glTF koordinatlarında (Y yuxarı)."""
        out = []
        for p in self.g["meshes"][mesh_index]["primitives"]:
            at = p["attributes"]
            pos = self.accessor(at["POSITION"]).astype(np.float32)
            nor = self.accessor(at["NORMAL"]).astype(np.float32) if "NORMAL" in at else None
            uv = self.accessor(at["TEXCOORD_0"]).astype(np.float32) if "TEXCOORD_0" in at else None
            idx = self.accessor(p["indices"]).reshape(-1).astype(np.int64)
            out.append((self.g["materials"][p["material"]]["name"], pos, nor, uv, idx))
        return out


def to_blender(v):
    """glTF (x, y, z) Y-up -> Blender (x, -z, y) Z-up."""
    return np.stack([v[:, 0], -v[:, 2], v[:, 1]], axis=1)


# --- mesh qurucuları ---------------------------------------------------------

def make_mesh(name, pos, nor, uv, tri_idx, mat_idx_per_tri, materials, vcol=None):
    """numpy massivlərindən Blender mesh-i qurur (pos Blender koordinatında)."""
    me = bpy.data.meshes.new(name)
    nv = len(pos)
    nt = len(tri_idx) // 3
    me.vertices.add(nv)
    me.vertices.foreach_set("co", pos.astype(np.float32).reshape(-1))
    me.loops.add(nt * 3)
    me.polygons.add(nt)
    me.loops.foreach_set("vertex_index", tri_idx.astype(np.int32))
    me.polygons.foreach_set("loop_start", np.arange(0, nt * 3, 3, dtype=np.int32))
    me.polygons.foreach_set("loop_total", np.full(nt, 3, dtype=np.int32))
    me.polygons.foreach_set("use_smooth", np.ones(nt, dtype=bool))
    me.polygons.foreach_set("material_index", mat_idx_per_tri.astype(np.int32))
    if uv is not None:
        layer = me.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", uv[tri_idx].astype(np.float32).reshape(-1))
    if vcol is not None:
        attr = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
        attr.data.foreach_set("color", vcol.astype(np.float32).reshape(-1))
    me.update()
    me.validate()
    if nor is not None:
        me.normals_split_custom_set_from_vertices([tuple(n) for n in nor])
    for m in materials:
        me.materials.append(m)
    return me


def concat_wood(prims, drop):
    """Odun primitivlərini (drop siyahısındakı material adlarını atmaqla) tək massivlərə birləşdirir."""
    pos, nor, uv, tri, midx, mats = [], [], [], [], [], []
    off = 0
    for name, p, n, u, ix in prims:
        if any(d in name for d in drop):
            continue
        if name not in mats:
            mats.append(name)
        pos.append(p)
        nor.append(n if n is not None else np.tile([0.0, 0.0, 1.0], (len(p), 1)).astype(np.float32))
        uv.append(u if u is not None else np.zeros((len(p), 2), dtype=np.float32))
        tri.append(ix + off)
        midx.append(np.full(len(ix) // 3, mats.index(name)))
        off += len(p)
    return (np.concatenate(pos), np.concatenate(nor), np.concatenate(uv), np.concatenate(tri),
            np.concatenate(midx), mats)


def get_material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    return m


def weld_vertices(ob, dist=0.0005):
    """UV tikişlərində təkrarlanan təpələri mövqeyə görə birləşdirir (loop UV-ləri qalır).
    Bu olmadan Decimate tikiş kənarlarını sərhəd sayıb daha çox azalda bilmir."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def decimate_object(ob, target_tris):
    weld_vertices(ob)
    me = ob.data
    me.calc_loop_triangles()
    cur = len(me.loop_triangles)
    if cur <= target_tris:
        return cur
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(target_tris / cur, 0.001)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


# --- iynəyarpaq klasterləri -> alfa kartlar ------------------------------------

def cluster_cards(foliage_pts, voxel, cards_per_cluster, min_count, size_mul, spray_aspect, rng,
                  axis_xy=(0.0, 0.0), droop=0.25, lift_color=True):
    """foliage_pts: (N,3) üçbucaq mərkəzləri (Blender koordinatı). Qaytarır: pos, uv, tri_idx, normals, vcol."""
    keys = np.floor(foliage_pts / voxel).astype(np.int64)
    uniq, inv, counts = np.unique(keys, axis=0, return_inverse=True, return_counts=True)
    inv = inv.reshape(-1)
    sums = np.zeros((len(uniq), 3))
    for k in range(3):
        sums[:, k] = np.bincount(inv, weights=foliage_pts[:, k], minlength=len(uniq))
    centers = sums / counts[:, None]
    # klaster radiusu: nöqtələrin mərkəzdən orta məsafəsi
    d = np.linalg.norm(foliage_pts - centers[inv], axis=1)
    radius = np.bincount(inv, weights=d, minlength=len(uniq)) / counts
    keep = counts >= min_count
    centers = centers[keep]
    radius = radius[keep]
    counts_kept = counts[keep]

    P, UV, TRI, NOR, COL = [], [], [], [], []
    base = 0
    for c, r, cnt in zip(centers, radius, counts_kept):
        out = np.array([c[0] - axis_xy[0], c[1] - axis_xy[1], 0.0])
        ln = np.linalg.norm(out)
        if ln < 0.2:
            ang = rng.uniform(0, 2 * math.pi)
            out = np.array([math.cos(ang), math.sin(ang), 0.0])
        else:
            out /= ln
        # tək şaquli budaq üçün aşağı meyl, yuxarı çiçəkləmə yox
        stem = out * (1.0 - droop) + np.array([0.0, 0.0, -droop + rng.uniform(-0.1, 0.15)])
        stem /= np.linalg.norm(stem)
        length = float(np.clip(size_mul * max(r * 2.0, voxel * 0.8), voxel * 0.9, voxel * 3.0))
        width = length * spray_aspect
        side0 = np.cross(stem, np.array([0.0, 0.0, 1.0]))
        side0 /= max(np.linalg.norm(side0), 1e-6)
        shade = float(rng.uniform(0.82, 1.12))
        for i in range(cards_per_cluster):
            roll = (i / cards_per_cluster) * math.pi + rng.uniform(-0.25, 0.25)
            # side0-ı stem ətrafında roll qədər fırlat (Rodrigues)
            s = side0 * math.cos(roll) + np.cross(stem, side0) * math.sin(roll)
            b = c - stem * length * 0.35 + rng.normal(0, voxel * 0.12, 3)
            t = b + stem * length
            quad = np.array([b - s * width / 2, b + s * width / 2, t + s * width / 2, t - s * width / 2])
            P.append(quad)
            UV.append(np.array([[0, 0], [1, 0], [1, 1], [0, 1]], dtype=np.float32))
            TRI.append(np.array([base, base + 1, base + 2, base, base + 2, base + 3]))
            up_n = np.array([0.0, 0.0, 1.0]) * 0.65 + out * 0.35
            up_n /= np.linalg.norm(up_n)
            NOR.append(np.tile(up_n, (4, 1)))
            COL.append(np.tile([shade, shade, shade, 1.0], (4, 1)))
            base += 4
    if not P:
        return None
    return (np.concatenate(P).astype(np.float32), np.concatenate(UV).astype(np.float32),
            np.concatenate(TRI).astype(np.int64), np.concatenate(NOR).astype(np.float32),
            np.concatenate(COL).astype(np.float32))


# --- foliage teksturası (diff + alpha -> RGBA PNG) -----------------------------

def build_foliage_texture(asset_id, spec):
    """twig_diff və twig_alpha-dan kəsilmiş RGBA tekstura. spec: x0,y0,x1,y1 (piksel, yuxarı-solda sıfır)."""
    out = OUT / "textures" / ("%s_foliage.png" % spec["texture_name"])
    out.parent.mkdir(parents=True, exist_ok=True)
    src_id = spec.get("texture_source", asset_id)
    diff = bpy.data.images.load(str(SRC / src_id / "textures" / ("%s_%s_diff_1k.jpg" % (src_id, spec["atlas"]))), check_existing=False)
    alpha = bpy.data.images.load(str(SRC / src_id / "textures" / ("%s_%s_alpha_1k.png" % (src_id, spec["atlas"]))), check_existing=False)
    w, h = diff.size
    d = np.array(diff.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # indi yuxarıdan aşağı
    a = np.array(alpha.pixels[:], dtype=np.float32).reshape(alpha.size[1], alpha.size[0], 4)[::-1]
    x0, y0, x1, y1 = spec["rect"]
    crop = d[y0:y1, x0:x1, :3].copy()
    acrop = a[y0:y1, x0:x1, 0].copy()
    rgba = np.concatenate([crop, acrop[..., None]], axis=2)[::-1]  # Blender yazmaq üçün aşağıdan yuxarı
    img = bpy.data.images.new("foliage_" + spec["texture_name"], width=x1 - x0, height=y1 - y0, alpha=True)
    img.pixels.foreach_set(rgba.reshape(-1))
    img.filepath_raw = str(out)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    bpy.data.images.remove(diff)
    bpy.data.images.remove(alpha)
    return out


# --- əsas iş ------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(objs, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_apply=True, export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_normals=True, export_texcoords=True,
                              export_vertex_color="ACTIVE", export_cameras=False, export_lights=False)


def material_texture_map(gl):
    """glTF-dən: material adı -> {diff, nor, arm} tekstura fayl adları (hər material hansı faylı işlədir)."""
    g = gl.g
    imgs = [Path(i["uri"]).name for i in g.get("images", [])]
    tex = g.get("textures", [])

    def img(t):
        return imgs[tex[t["index"]]["source"]] if t else None

    out = {}
    for m in g["materials"]:
        pm = m["pbrMetallicRoughness"]
        out[m["name"]] = {"diff": img(pm.get("baseColorTexture")), "arm": img(pm.get("metallicRoughnessTexture")),
                          "nor": img(m.get("normalTexture"))}
    return out


def export_wood_materials(asset_id, gl, material_names):
    """Odun materialları üçün tekstura fayllarını assets/vegetation/textures/<id>/-ə kopyalayır, materials.json yazır."""
    mapping = material_texture_map(gl)
    dst = OUT / "textures" / asset_id
    dst.mkdir(parents=True, exist_ok=True)
    result = {}
    for mat in sorted(material_names):
        entry = mapping[mat]
        result[mat] = entry
        for fname in entry.values():
            if fname:
                shutil.copyfile(SRC / asset_id / "textures" / fname, dst / fname)
    (OUT / asset_id).mkdir(parents=True, exist_ok=True)
    (OUT / asset_id / "materials.json").write_text(json.dumps(result, indent=2), encoding="utf8")
    return result


def build_rgba_texture(asset_id, diff_name, alpha_name, out_name):
    """diff (JPG) + alpha (PNG) -> tam ölçülü RGBA PNG (alfa kartlı bitkilər üçün)."""
    out = OUT / "textures" / asset_id / out_name
    out.parent.mkdir(parents=True, exist_ok=True)
    d_img = bpy.data.images.load(str(SRC / asset_id / "textures" / diff_name), check_existing=False)
    a_img = bpy.data.images.load(str(SRC / asset_id / "textures" / alpha_name), check_existing=False)
    w, h = d_img.size
    d = np.array(d_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    a = np.array(a_img.pixels[:], dtype=np.float32).reshape(a_img.size[1], a_img.size[0], 4)
    if (a_img.size[0], a_img.size[1]) != (w, h):
        raise SystemExit("alfa ölçüsü diff ilə uyğun deyil: %s" % asset_id)
    rgba = np.concatenate([d[..., :3], a[..., :1]], axis=2)
    img = bpy.data.images.new("rgba_" + asset_id, width=w, height=h, alpha=True)
    img.pixels.foreach_set(rgba.reshape(-1))
    img.filepath_raw = str(out)
    img.file_format = "PNG"
    img.save()
    for i in (d_img, a_img, img):
        bpy.data.images.remove(i)
    return out_name


def process_conifer(asset_id, cfg):
    gl = Gltf(SRC / asset_id / ("%s_1k.gltf" % asset_id))
    rng = np.random.default_rng(cfg.get("seed", 1))
    foliage_mat_key = cfg.get("foliage_material_contains", "twig")
    tex = build_foliage_texture(asset_id, cfg["foliage_texture"])
    stats = {"asset": asset_id, "variants": {}}
    wood_mat_names = set()
    lod_objs = {i: [] for i in range(len(cfg["lods"]))}
    for vi, mesh_idx in enumerate(cfg["mesh_indices"]):
        vname = cfg["variant_names"][vi]
        prims = gl.primitives(mesh_idx)
        wood = [p for p in prims if foliage_mat_key not in p[0]]
        fol = [p for p in prims if foliage_mat_key in p[0]]
        # odun primitivləri Blender koordinatına çevrilir, LOD-a görə material filtri ilə birləşdirilir
        wood_prims = [(name, to_blender(p), to_blender(n) if n is not None else None, u, ix) for name, p, n, u, ix in wood]
        wood_tris_total = sum(len(p[4]) // 3 for p in wood_prims)
        wood_mat_names.update(p[0] for p in wood_prims)

        # foliage mərkəzləri
        cents = []
        for name, p, n, u, ix in fol:
            tr = to_blender(p)[ix.reshape(-1, 3)]
            cents.append(tr.mean(axis=1))
        fcent = np.concatenate(cents)
        stats["variants"][vname] = {"wood_tris": int(wood_tris_total), "foliage_tris": int(len(fcent))}
        height = float(max(max(p[1][:, 2].max() for p in wood_prims), fcent[:, 2].max()))
        stats["variants"][vname]["height_m"] = round(height, 2)
        for li, lod in enumerate(cfg["lods"]):
            r = random.Random(cfg.get("seed", 1) * 1000 + vi * 10 + li)
            wpos, wnor, wuv, wtri, wmi, mats = concat_wood(wood_prims, lod.get("drop_materials", []))
            me = make_mesh("%s_%s_wood" % (asset_id, vname), wpos, wnor, wuv, wtri, wmi,
                           [get_material(m) for m in mats])
            ob = bpy.data.objects.new("%s_%s" % (asset_id, vname), me)
            bpy.context.collection.objects.link(ob)
            wt = decimate_object(ob, lod["wood_tris"])
            card = cluster_cards(fcent, lod["voxel"], lod["cards"], lod["min_count"], lod["size_mul"],
                                 cfg["spray_aspect"], np.random.default_rng(r.randint(0, 10**9)),
                                 droop=cfg.get("droop", 0.25))
            ft = 0
            if card is not None:
                cpos, cuv, ctri, cnor, ccol = card
                fm = make_mesh("%s_%s_foliage" % (asset_id, vname), cpos, cnor, cuv, ctri,
                               np.zeros(len(ctri) // 3), [get_material("foliage")], vcol=ccol)
                fo = bpy.data.objects.new("fol", fm)
                bpy.context.collection.objects.link(fo)
                # odun ob-ə birləşdir: foliage material slotu sonda
                bpy.ops.object.select_all(action="DESELECT")
                fo.select_set(True)
                ob.select_set(True)
                bpy.context.view_layer.objects.active = ob
                bpy.ops.object.join()
                ft = len(ctri) // 3
            ob.data.calc_loop_triangles()
            tris_total = len(ob.data.loop_triangles)
            ob.name = "%s_%s" % (asset_id, vname)
            stats["variants"][vname]["lod%d" % li] = {"wood_tris": wt, "foliage_tris": ft, "total": tris_total}
            lod_objs[li].append(ob)
    for li, objs in lod_objs.items():
        export_glb(objs, OUT / asset_id / ("%s_lod%d.glb" % (asset_id, li)))
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    (OUT / asset_id).mkdir(parents=True, exist_ok=True)
    stats["materials"] = export_wood_materials(asset_id, gl, wood_mat_names)
    (OUT / asset_id / "stats.json").write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf8")
    print("OPT", json.dumps(stats, ensure_ascii=False))


def process_meshes(asset_id, cfg):
    """Konifer olmayan modellər: hər variant ayrıca mesh, hər LOD üçün hədəf üçbucaq sayı (None = orijinal)."""
    gl = Gltf(SRC / asset_id / ("%s_1k.gltf" % asset_id))
    mapping = material_texture_map(gl)
    node_names = {}
    for n in gl.g["nodes"]:
        if "mesh" in n:
            vn = n["name"].replace(asset_id + "_", "")
            vn = vn.replace("_LOD0", "").replace("LOD0", "").strip("_") or "a"
            node_names[n["mesh"]] = vn
    indices = cfg.get("mesh_indices") or sorted(node_names)
    stats = {"asset": asset_id, "variants": {}}
    lod_objs = {i: [] for i in range(len(cfg["lods"]))}
    used_mats = set()
    for mesh_idx in indices:
        vname = node_names[mesh_idx].replace("_", "")
        prims = gl.primitives(mesh_idx)
        pos, nor, uv, tri, midx, mats = [], [], [], [], [], []
        off = 0
        for name, p, n, u, ix in prims:
            if name not in mats:
                mats.append(name)
            pos.append(to_blender(p))
            nor.append(to_blender(n) if n is not None else np.tile([0.0, 0.0, 1.0], (len(p), 1)).astype(np.float32))
            uv.append(u if u is not None else np.zeros((len(p), 2), dtype=np.float32))
            tri.append(ix + off)
            midx.append(np.full(len(ix) // 3, mats.index(name)))
            off += len(p)
        used_mats.update(mats)
        pos, nor, uv, tri, midx = (np.concatenate(a) for a in (pos, nor, uv, tri, midx))
        stats["variants"][vname] = {"original_tris": int(len(tri) // 3)}
        for li, target in enumerate(cfg["lods"]):
            me = make_mesh("%s_%s" % (asset_id, vname), pos, nor, uv, tri, midx, [get_material(m) for m in mats])
            ob = bpy.data.objects.new("%s_%s" % (asset_id, vname), me)
            bpy.context.collection.objects.link(ob)
            if target:
                decimate_object(ob, target)
            ob.data.calc_loop_triangles()
            t = len(ob.data.loop_triangles)
            stats["variants"][vname]["lod%d" % li] = t
            lod_objs[li].append(ob)
    for li, objs in lod_objs.items():
        export_glb(objs, OUT / asset_id / ("%s_lod%d.glb" % (asset_id, li)))
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    # materials.json + tekstura
    result = {}
    dst = OUT / "textures" / asset_id
    dst.mkdir(parents=True, exist_ok=True)
    for mat in sorted(used_mats):
        entry = dict(mapping[mat])
        alpha_file = cfg.get("alpha_texture")
        if alpha_file:
            entry["diff"] = build_rgba_texture(asset_id, entry["diff"], alpha_file, "%s_rgba.png" % asset_id)
            entry["mode"] = "scissor"
        for key in ("diff", "arm", "nor"):
            f = entry.get(key)
            if f and not f.endswith("_rgba.png"):
                shutil.copyfile(SRC / asset_id / "textures" / f, dst / f)
        result[mat] = entry
    (OUT / asset_id).mkdir(parents=True, exist_ok=True)
    (OUT / asset_id / "materials.json").write_text(json.dumps(result, indent=2), encoding="utf8")
    stats["materials"] = result
    (OUT / asset_id / "stats.json").write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf8")
    print("OPT", json.dumps(stats, ensure_ascii=False))


def main():
    ids = sys.argv[sys.argv.index("--") + 1:]
    for aid in ids:
        reset_scene()
        cfg = CFG[aid]
        kind = cfg["type"]
        print("OPT başlayır:", aid, kind)
        if kind == "conifer":
            process_conifer(aid, cfg)
        elif kind == "meshes":
            process_meshes(aid, cfg)
        else:
            raise SystemExit("naməlum tip: " + kind)


main()
