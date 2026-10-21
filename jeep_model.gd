class_name JeepModel
extends RefCounted
## "Jeep Wrangler (free)" modelini yükləyir və təkərləri gövdədən ayırır.
## Model: 3DFU_XXX, CC BY 4.0 (bax CREDITS.md). Təkərlər modeldə birləşmiş
## meshlərdə olduğu üçün həndəsəyə görə (bağlı hissələrə) 4 ayrı meshə bölünür.

const SCENE_PATH := "res://assets/jeep/scene.gltf"
const BODY_CENTER_Y := 0.95  # fizika gövdəsinin mərkəzi (metr)
# FBX-dən gələn mesh düyünlərində x100 miqyas var, xam koordinatlar isə metrdir
const MODEL_SCALE := 0.01
const TIRE_WIDTH := 0.49  # modeldən ölçülüb (metr)

var body: Node3D
## Sıra: 0 = arxa (-x), 1 = arxa (+x), 2 = ön (-x), 3 = ön (+x). Model +Z irəlidir.
var wheel_meshes: Array[ArrayMesh] = []
var wheel_centers: Array[Vector3] = []  # model koordinatında
var wheel_yaws_deg: Array[float] = []  # modeldəki ilkin yaw bucağı (düzəldilməzdən əvvəl)
var static_tris := 0  # təkər meshindən gövdəyə qaytarılan üçbucaqların sayı
var wheel_radius := 0.55
var origin := Vector3.ZERO  # gövdə mərkəzi (model koordinatında)


static func available() -> bool:
	return ResourceLoader.exists(SCENE_PATH)


func load_model() -> bool:
	if not available():
		return false
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		return false
	body = packed.instantiate() as Node3D
	if body == null:
		return false

	var meshes: Array[MeshInstance3D] = []
	var junk: Array[Node] = []
	_collect(body, meshes, junk)
	for n in junk:  # Blender-dən gələn işıq və kamera lazım deyil
		n.get_parent().remove_child(n)
		n.free()

	var wheel_src: Array[MeshInstance3D] = []
	for mi in meshes:
		var bb := mi.get_aabb()
		if bb.position.y < 0.1 and bb.size.y > 1.0:  # yerə dəyən iri hissə = təkər
			wheel_src.append(mi)
	if wheel_src.is_empty():
		return false

	if not _split_wheels(wheel_src):
		return false
	for mi in wheel_src:
		mi.get_parent().remove_child(mi)
		mi.free()

	origin = Vector3(0, BODY_CENTER_Y, 0)
	for c in wheel_centers:
		origin.x += c.x / 4.0
		origin.z += c.z / 4.0
	body.scale = Vector3.ONE * MODEL_SCALE
	body.position = -origin
	return true


func _collect(n: Node, meshes: Array[MeshInstance3D], junk: Array[Node]) -> void:
	if n is Light3D or n is Camera3D:
		junk.append(n)
		return
	if n is MeshInstance3D:
		meshes.append(n)
	for c in n.get_children():
		_collect(c, meshes, junk)


func _rel_xf(node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != body:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## Align the tire axle with X by minimizing axial width, not its circular diameter.
## Yaw düzəlişini kobud, sonra dəqiq addımla axtarır (radian qaytarır).
static func _best_yaw(pos: PackedVector3Array) -> float:
	var best := 0.0
	var best_e := INF
	for s in range(-70, 71):
		var a := deg_to_rad(s * 0.5)
		var e := _x_extent(pos, a)
		if e < best_e:
			best_e = e
			best = a
	var center := best
	for s in range(-10, 11):
		var a := center + deg_to_rad(s * 0.05)
		var e := _x_extent(pos, a)
		if e < best_e:
			best_e = e
			best = a
	return best


static func _x_extent(pos: PackedVector3Array, yaw: float) -> float:
	var sn := sin(yaw)
	var cs := cos(yaw)
	var zmin := INF
	var zmax := -INF
	for p in pos:
		var z := p.x * cs + p.z * sn
		zmin = minf(zmin, z)
		zmax = maxf(zmax, z)
	return zmax - zmin


func _split_wheels(srcs: Array[MeshInstance3D]) -> bool:
	# 1) Dedicated front-wheel sources must remain whole, including inner sidewalls.
	var dedicated := {}
	# Other sources also contain suspension and are separated by component.
	var comps: Array = []  # {src, root, verts, tris, centroid}
	var all_min := Vector3(INF, INF, INF)
	var all_max := Vector3(-INF, -INF, -INF)
	var material: Material = null
	for si in srcs.size():
		var mi := srcs[si]
		var bounds := mi.get_aabb()
		dedicated[si] = bounds.size.x < 1.0 and bounds.size.z < 1.5
		var xf := _rel_xf(mi)
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			return false
		if material == null:
			material = mi.mesh.surface_get_material(0)
		var parent := PackedInt32Array()
		parent.resize(v.size())
		for i in v.size():
			parent[i] = i
		for t in range(0, idx.size(), 3):
			var ra := _find(parent, idx[t])
			var rb := _find(parent, idx[t + 1])
			var rc := _find(parent, idx[t + 2])
			parent[rb] = ra
			parent[_find(parent, rc)] = ra
		var by_root := {}
		for i in v.size():
			var r := _find(parent, i)
			if not by_root.has(r):
				by_root[r] = {"src": si, "verts": [], "tris": [], "sum": Vector3.ZERO,
						"xmin": INF, "xmax": -INF}
			var c: Dictionary = by_root[r]
			c["verts"].append(i)
			c["sum"] += xf * v[i]
			var wp := xf * v[i]
			c["xmin"] = minf(c["xmin"], wp.x)
			c["xmax"] = maxf(c["xmax"], wp.x)
			all_min = all_min.min(wp)
			all_max = all_max.max(wp)
		for t in range(0, idx.size(), 3):
			var r := _find(parent, idx[t])
			var tris: Array = by_root[r]["tris"]
			tris.append(idx[t])
			tris.append(idx[t + 1])
			tris.append(idx[t + 2])
		for r in by_root:
			var c: Dictionary = by_root[r]
			c["centroid"] = c["sum"] / float(c["verts"].size())
			comps.append(c)

	var xm := (all_min.x + all_max.x) * 0.5
	var zm := (all_min.z + all_max.z) * 0.5

	# 2) hissələri 4 təkərə paylaş
	var acc: Array = []
	for k in 5:  # 0..3 = təkərlər, 4 = təkər meshində qalan, amma fırlanmamalı hissələr
		acc.append({"pos": [], "nor": [], "tan": [], "uv": [], "idx": []})
	# hər təkərin xarici kənarı (sol: ən kiçik x, sağ: ən böyük x)
	var edges := [INF, -INF, INF, -INF]
	for c in comps:
		var cen: Vector3 = c["centroid"]
		var k := (2 if cen.z > zm else 0) + (1 if cen.x > xm else 0)
		c["wheel"] = k
		if k % 2 == 0:
			edges[k] = minf(edges[k], c["xmin"])
		else:
			edges[k] = maxf(edges[k], c["xmax"])
	var tire_w := TIRE_WIDTH / MODEL_SCALE
	var margin := 0.06 / MODEL_SCALE
	for c in comps:
		var cen: Vector3 = c["centroid"]
		var k: int = c["wheel"]
		# təkər enindən içəridə qalan hissələr (ox, əyləc çubuqları) fırlanmasın, gövdədə qalsın
		var inside: bool
		if k % 2 == 0:
			inside = cen.x <= edges[k] + tire_w + margin
		else:
			inside = cen.x >= edges[k] - tire_w - margin
		if dedicated.get(c["src"], false):
			inside = true
		var scale_f := MODEL_SCALE
		if not inside:
			k = 4
			scale_f = 1.0  # gövdə düyünü özü 0.01 miqyaslayır
		var a: Dictionary = acc[k]
		var mi := srcs[c["src"]]
		var xf := _rel_xf(mi)
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tan: PackedFloat32Array = PackedFloat32Array()
		if arrays[Mesh.ARRAY_TANGENT] != null:
			tan = arrays[Mesh.ARRAY_TANGENT]
		var uv: PackedVector2Array = PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uv = arrays[Mesh.ARRAY_TEX_UV]
		var remap := {}
		for vid in c["verts"]:
			remap[vid] = a["pos"].size()
			a["pos"].append(xf * v[vid] * scale_f)
			a["nor"].append((xf.basis * nrm[vid]).normalized())
			if tan.size() >= (vid + 1) * 4:
				var tv := xf.basis * Vector3(tan[vid * 4], tan[vid * 4 + 1], tan[vid * 4 + 2])
				tv = tv.normalized()
				a["tan"].append_array([tv.x, tv.y, tv.z, tan[vid * 4 + 3]])
			if uv.size() > vid:
				a["uv"].append(uv[vid])
		for t in c["tris"]:
			a["idx"].append(remap[t])

	# 3) hər təkər üçün mesh qur, mərkəzə gətir
	wheel_meshes.clear()
	wheel_centers.clear()
	wheel_yaws_deg.clear()
	var radius_sum := 0.0
	for k in 4:
		var a: Dictionary = acc[k]
		if a["pos"].is_empty():
			return false
		var pos := PackedVector3Array(a["pos"])
		var nor := PackedVector3Array(a["nor"])
		var tan := PackedFloat32Array(a["tan"])
		var bmin := Vector3(INF, INF, INF)
		var bmax := Vector3(-INF, -INF, -INF)
		for p in pos:
			bmin = bmin.min(p)
			bmax = bmax.max(p)
		var pivot := (bmin + bmax) * 0.5

		# Modeldə ön təkərlər artıq bir az dönmüş vəziyyətdədir. Dönəndə əyri görünməsin
		# deyə, oxu X-ə salan yaw düzəlişini tapırıq.
		var yaw := _best_yaw(pos)
		wheel_yaws_deg.append(rad_to_deg(yaw))
		var rot := Basis(Vector3.UP, yaw)
		for i in pos.size():
			pos[i] = rot * (pos[i] - pivot) + pivot
			nor[i] = rot * nor[i]
		if tan.size() == pos.size() * 4:
			for i in pos.size():
				var tv := rot * Vector3(tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2])
				tan[i * 4] = tv.x
				tan[i * 4 + 1] = tv.y
				tan[i * 4 + 2] = tv.z

		bmin = Vector3(INF, INF, INF)
		bmax = Vector3(-INF, -INF, -INF)
		for p in pos:
			bmin = bmin.min(p)
			bmax = bmax.max(p)
		var cy := (bmin.y + bmax.y) * 0.5
		var cz := (bmin.z + bmax.z) * 0.5
		var r := (bmax.y - bmin.y) * 0.5
		# daxili hissələr artıq ayrılıb, qalan geometriya yalnız təkərdir
		var center := Vector3((bmin.x + bmax.x) * 0.5, cy, cz)
		for i in pos.size():
			pos[i] -= center
		radius_sum += r
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nor
		if tan.size() == pos.size() * 4:
			arrays[Mesh.ARRAY_TANGENT] = tan
		if a["uv"].size() == pos.size():
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(a["uv"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(a["idx"])
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if material != null:
			am.surface_set_material(0, material)
		wheel_meshes.append(am)
		wheel_centers.append(center)
	wheel_radius = radius_sum / 4.0

	# fırlanmamalı hissələri gövdəyə qaytar
	var st: Dictionary = acc[4]
	static_tris = st["idx"].size() / 3
	if static_tris > 0:
		var sarr := []
		sarr.resize(Mesh.ARRAY_MAX)
		sarr[Mesh.ARRAY_VERTEX] = PackedVector3Array(st["pos"])
		sarr[Mesh.ARRAY_NORMAL] = PackedVector3Array(st["nor"])
		if st["tan"].size() == st["pos"].size() * 4:
			sarr[Mesh.ARRAY_TANGENT] = PackedFloat32Array(st["tan"])
		if st["uv"].size() == st["pos"].size():
			sarr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(st["uv"])
		sarr[Mesh.ARRAY_INDEX] = PackedInt32Array(st["idx"])
		var sm := ArrayMesh.new()
		sm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sarr)
		if material != null:
			sm.surface_set_material(0, material)
		var smi := MeshInstance3D.new()
		smi.name = "WheelStatic"
		smi.mesh = sm
		body.add_child(smi)
	return true
