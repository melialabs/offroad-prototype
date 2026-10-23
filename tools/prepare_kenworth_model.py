"""Prepare the supplied Kenwood/Kenworth-style truck GLB for the game.

python3 tools/prepare_kenworth_model.py SOURCE.glb assets/cars/truck_kenworth.glb

The Max exporter left unusable material colours and a ~1/32 node scale. This bakes
every node transform, scales to metres, rotates to the game's axes (forward +Z, up +Y,
ground at y=0), assigns paint/chrome/glass/rubber materials by part name, merges the
body into one "Body" mesh and writes the six tyres as separate, wheel-centred meshes:
W_FL/W_FR (steering) and tandem T_RL_A/B, T_RR_A/B (named by side, A = front axle).
Requires numpy. Logo meshes are dropped.
"""
import json
import struct
import sys
import numpy as np

SRC, DST = sys.argv[1], sys.argv[2]

d = open(SRC, "rb").read()
jl, _ = struct.unpack("<II", d[12:20])
J = json.loads(d[20:20 + jl])
off = 20 + jl
bl, _ = struct.unpack("<II", d[off:off + 8])
BIN = d[off + 8:off + 8 + bl]
N, ACC, BV = J["nodes"], J["accessors"], J["bufferViews"]
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(ai):
    a = ACC[ai]
    bv = BV[a["bufferView"]]
    cnt, nc = a["count"], NC[a["type"]]
    dt = np.dtype(CT[a["componentType"]])
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", nc * dt.itemsize)
    if stride == nc * dt.itemsize:
        return np.frombuffer(BIN, dt, cnt * nc, start).reshape(cnt, nc).copy()
    out = np.empty((cnt, nc), dt)
    for i in range(cnt):
        out[i] = np.frombuffer(BIN, dt, nc, start + i * stride)
    return out


parent = {}
for i, n in enumerate(N):
    for c in n.get("children", []):
        parent[c] = i


def mat(i):
    return np.array(N[i]["matrix"]).reshape(4, 4).T if "matrix" in N[i] else np.eye(4)


def world(i):
    m = mat(i)
    while i in parent:
        i = parent[i]
        m = mat(i) @ m
    return m


SCALE = float(np.linalg.norm(world(1)[:3, 0]))  # root * Device scale (about 0.0315)
# Max world (x forward, y up, z side) -> game (forward +Z, up +Y, side x = -z)
ROT = np.array([[0, 0, -1], [0, 1, 0], [1, 0, 0]], dtype=np.float64)

DROP = {"Kenworth_logo_1", "LogoFront_1", "PhysCamera001", "PhysCamera001.Target"}
WHEELS = {"Wheel_front_right_1", "Rubber_left_1", "Wheel_back_front_left_1", "Wheel_back_back_left_1",
          "Wheel_back_back_right_1", "Wheel_back_front_right_1"}

PAINT = dict(color=[0.11, 0.17, 0.30, 1.0], metal=0.45, rough=0.32)
CHROME = dict(color=[0.82, 0.84, 0.86, 1.0], metal=1.0, rough=0.22)
DARK = dict(color=[0.05, 0.05, 0.055, 1.0], metal=0.3, rough=0.6)
STEEL = dict(color=[0.35, 0.36, 0.38, 1.0], metal=0.9, rough=0.4)
GLASS = dict(color=[0.35, 0.5, 0.58, 0.32], metal=0.0, rough=0.05, blend=True)
HEAD = dict(color=[0.95, 0.93, 0.8, 1.0], metal=0.0, rough=0.2, emis=[0.15, 0.14, 0.1])
TAIL = dict(color=[0.75, 0.04, 0.03, 1.0], metal=0.0, rough=0.3, emis=[0.12, 0.0, 0.0])
AMBER = dict(color=[1.0, 0.55, 0.05, 1.0], metal=0.0, rough=0.3, emis=[0.2, 0.08, 0.0])
RUBBER = dict(color=[0.025, 0.025, 0.027, 1.0], metal=0.0, rough=0.9)
RIM = dict(color=[0.62, 0.63, 0.65, 1.0], metal=1.0, rough=0.35)
BYNAME = {
    "Cab_1": PAINT, "Aripi_spate_1": PAINT, "Aparatoare_1": PAINT, "Stock_1": DARK,
    "Grille_1": CHROME, "Grille_margin_1": CHROME, "Grille_solid_1": DARK, "Grills_1": DARK, "Front_bar_1": CHROME,
    "Esapament_1": CHROME, "Mirrors_1": CHROME, "Bolts_1": STEEL, "Back_truck_device_1": STEEL, "Device_1": STEEL,
    "Barells_under_1": CHROME, "Barrels_small_1": STEEL, "Big_Barrels_1": CHROME, "Capace_benzina_1": CHROME,
    "Side_stair_1": STEEL, "OrnamentsCab_1": CHROME, "Cadru_Window_1": DARK,
    "Windshield_1": GLASS, "Windshield_front_ap_1": GLASS, "Glass_cap_signs_1": GLASS, "Glass_Lights_front_1": GLASS,
    "Lights_front_1": HEAD, "Lights_back_1": TAIL, "Blinkers_1": AMBER, "Signal_back_1": AMBER,
}

materials, mat_index = [], {}


def material(spec, name):
    key = json.dumps(spec, sort_keys=True)
    if key not in mat_index:
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": spec["color"], "metallicFactor": spec["metal"],
                                                     "roughnessFactor": spec["rough"]}, "doubleSided": True}
        if spec.get("blend"):
            m["alphaMode"] = "BLEND"
        if "emis" in spec:
            m["emissiveFactor"] = spec["emis"]
        mat_index[key] = len(materials)
        materials.append(m)
    return mat_index[key]


def prim_geometry(prim, w):
    pos = read(prim["attributes"]["POSITION"]).astype(np.float64)
    nor = read(prim["attributes"]["NORMAL"]).astype(np.float64) if "NORMAL" in prim["attributes"] else None
    idx = read(prim["indices"]).reshape(-1).astype(np.uint32)
    p = (np.c_[pos, np.ones(len(pos))] @ w.T)[:, :3] / SCALE
    p = p @ ROT.T
    if nor is not None:
        nn = (nor @ w[:3, :3].T)
        nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        nor = nn @ ROT.T
    return p, nor, idx


body = {}      # material index -> list of (pos, nor, idx)
wheel_geo = {}  # name -> list of (pos, nor, idx, radius)
for i, n in enumerate(N):
    if "mesh" not in n or n["name"] in DROP:
        continue
    w = world(i)
    for prim in J["meshes"][n["mesh"]]["primitives"]:
        p, nr, ix = prim_geometry(prim, w)
        if n["name"] in WHEELS:
            wheel_geo.setdefault(n["name"], []).append((p, nr, ix))
        else:
            if len(sys.argv) > 3:
                print('part', n['name'], np.round(p.min(axis=0), 2), np.round(p.max(axis=0), 2))
            body.setdefault(material(BYNAME.get(n["name"], DARK), n["name"]), []).append((p, nr, ix))

# Ground at y = 0 (lowest tyre point), truck centred on its wheelbase/body midpoint.
all_wheel = np.vstack([g[0] for v in wheel_geo.values() for g in v])
ground = all_wheel[:, 1].min()
allb = np.vstack([g[0] for v in body.values() for g in v])
cz = (allb[:, 2].min() + allb[:, 2].max()) / 2.0
shift = np.array([0.0, -ground, -cz])

chunks = []   # binary payload pieces
views, accs, prims_by_mesh = [], [], {}


def add_acc(arr, ctype, typ, target, with_minmax=False):
    raw = arr.tobytes()
    pad = (-len(raw)) % 4
    start = sum(len(c) for c in chunks)
    chunks.append(raw + b"\0" * pad)
    views.append({"buffer": 0, "byteOffset": start, "byteLength": len(raw), "target": target})
    a = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr) if arr.ndim == 1 else arr.shape[0], "type": typ}
    if with_minmax:
        a["min"] = arr.min(axis=0).tolist()
        a["max"] = arr.max(axis=0).tolist()
    accs.append(a)
    return len(accs) - 1


def mesh_from(primdata):
    """primdata: list of (material_idx, [(pos,nor,idx)...])"""
    out = []
    for mi, parts in primdata:
        pos, nor, idx, base = [], [], [], 0
        for p, nr, ix in parts:
            pos.append(p)
            nor.append(nr)
            idx.append(ix + base)
            base += len(p)
        P = np.vstack(pos).astype(np.float32)
        Nn = np.vstack(nor).astype(np.float32)
        I = np.concatenate(idx).astype(np.uint32)
        out.append({"attributes": {"POSITION": add_acc(P, 5126, "VEC3", 34962, True),
                                   "NORMAL": add_acc(Nn, 5126, "VEC3", 34962)},
                    "indices": add_acc(I, 5125, "SCALAR", 34963), "material": mi})
    return out


def shifted(parts, extra=0.0):
    return [(p + shift - extra, nr, ix) for p, nr, ix in parts]


meshes, nodes = [], []
body_prims = mesh_from([(mi, shifted(parts)) for mi, parts in body.items()])
meshes.append({"name": "Body", "primitives": body_prims})
nodes.append({"name": "Body", "mesh": 0})

centers = {}
tire_mat, rim_mat = material(RUBBER, "Rubber"), material(RIM, "Rim")
for name, geos in wheel_geo.items():
    # centre of the wheel on all prims; tyre = the prim with the larger radius from the axle (x axis)
    allp = np.vstack([g[0] for g in geos]) + shift
    c = (allp.min(axis=0) + allp.max(axis=0)) / 2.0
    radii = [np.linalg.norm((g[0] + shift - c)[:, 1:], axis=1).max() for g in geos]
    order = np.argsort(radii)[::-1]
    pd = []
    for rank, gi in enumerate(order):
        pd.append((tire_mat if rank == 0 else rim_mat, shifted([geos[gi]], c - shift)))
    centers[name] = c
    meshes.append({"name": name, "primitives": mesh_from(pd)})
    nodes.append({"name": name, "mesh": len(meshes) - 1, "translation": c.tolist()})

# Name the wheels by side (x) and axle (z)
by = {nd["name"]: np.array(nd["translation"]) for nd in nodes[1:]}
front = [k for k in by if by[k][2] == max(v[2] for v in by.values()) or abs(by[k][2] - max(v[2] for v in by.values())) < 0.3]
rear = [k for k in by if k not in front]
ren = {}
for k in front:
    ren[k] = "W_FL" if by[k][0] < 0 else "W_FR"
for side, sx in (("L", -1), ("R", 1)):
    ks = sorted([k for k in rear if (by[k][0] < 0) == (sx < 0)], key=lambda k: -by[k][2])
    for tag, k in zip("AB", ks):
        ren[k] = "T_R%s_%s" % (side, tag)
for nd in nodes[1:]:
    nd["name"] = ren[nd["name"]]
    meshes[nd["mesh"]]["name"] = nd["name"]

# Physics rear anchors W_RL/W_RR: empty markers at the tandem midpoints (visuals are the T_* tyres)
for side in "LR":
    a = next(nd for nd in nodes if nd["name"] == "T_R%s_A" % side)
    b = next(nd for nd in nodes if nd["name"] == "T_R%s_B" % side)
    mid = (np.array(a["translation"]) + np.array(b["translation"])) / 2.0
    tri = np.array([[0, 0, 0], [0, 0.001, 0], [0, 0, 0.001]], np.float32)
    mi = len(meshes)
    meshes.append({"name": "W_R" + side, "primitives": [{"attributes": {"POSITION": add_acc(tri, 5126, "VEC3", 34962, True)},
                                                          "indices": add_acc(np.array([0, 1, 2], np.uint32), 5125, "SCALAR", 34963)}]})
    nodes.append({"name": "W_R" + side, "mesh": mi, "translation": mid.tolist()})

out = {"asset": {"version": "2.0", "generator": "Offroad Kenworth-style truck preparation (numpy)"},
       "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes,
       "materials": materials, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": sum(len(c) for c in chunks)}]}
js = json.dumps(out, separators=(",", ":")).encode()
js += b" " * ((-len(js)) % 4)
binb = b"".join(chunks)
with open(DST, "wb") as f:
    f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(binb)))
    f.write(struct.pack("<I4s", len(js), b"JSON") + js)
    f.write(struct.pack("<I4s", len(binb), b"BIN\0") + binb)
for nd in nodes:
    print(nd["name"], np.round(nd.get("translation", [0, 0, 0]), 3))
print("size MB", round((20 + len(js) + len(binb)) / 1e6, 1), "scale", SCALE)
allp = np.vstack([g[0] for v in body.values() for g in v]) + shift
print("body bbox", allp.min(axis=0).round(2), allp.max(axis=0).round(2))
