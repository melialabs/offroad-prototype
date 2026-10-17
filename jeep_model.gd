class_name JeepModel
extends RefCounted
## "Jeep Wrangler (free)" modelini yükləyir və təkərləri gövdədən ayırır.
## Model: 3DFU_XXX, CC BY 4.0 (bax CREDITS.md). Təkərlər modeldə birləşmiş
## meshlərdə olduğu üçün həndəsəyə görə (bağlı hissələrə) 4 ayrı meshə bölünür.

const SCENE_PATH := "res://assets/jeep/scene.gltf"
const BODY_CENTER_Y := 0.95  # fizika gövdəsinin mərkəzi (metr)
# FBX-dən gələn mesh düyünlərində x100 miqyas var, xam koordinatlar isə metrdir
const MODEL_SCALE := 0.01

var body: Node3D
## Sıra: 0 = arxa (-x), 1 = arxa (+x), 2 = ön (-x), 3 = ön (+x). Model +Z irəlidir.
var wheel_meshes: Array[ArrayMesh] = []
var wheel_centers: Array[Vector3] = []  # model koordinatında
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


func _split_wheels(srcs: Array[MeshInstance3D]) -> bool:
	# 1) hər mənbə meshi bağlı hissələrə böl
	var comps: Array = []  # {src, root, verts, tris, centroid}
	var all_min := Vector3(INF, INF, INF)
	var all_max := Vector3(-INF, -INF, -INF)
	var material: Material = null
	for si in srcs.size():
		var mi := srcs[si]
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
				by_root[r] = {"src": si, "verts": [], "tris": [], "sum": Vector3.ZERO}
			var c: Dictionary = by_root[r]
			c["verts"].append(i)
			c["sum"] += xf * v[i]
			var wp := xf * v[i]
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
	for k in 4:
		acc.append({"pos": [], "nor": [], "tan": [], "uv": [], "idx": []})
	for c in comps:
		var cen: Vector3 = c["centroid"]
		var k := (2 if cen.z > zm else 0) + (1 if cen.x > xm else 0)
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
			a["pos"].append(xf * v[vid] * MODEL_SCALE)
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
	var radius_sum := 0.0
	for k in 4:
		var a: Dictionary = acc[k]
		if a["pos"].is_empty():
			return false
		var pos := PackedVector3Array(a["pos"])
		var bmin := Vector3(INF, INF, INF)
		var bmax := Vector3(-INF, -INF, -INF)
		for p in pos:
			bmin = bmin.min(p)
			bmax = bmax.max(p)
		var center := (bmin + bmax) * 0.5
		for i in pos.size():
			pos[i] -= center
		radius_sum += (bmax.y - bmin.y) * 0.5
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(a["nor"])
		if a["tan"].size() == pos.size() * 4:
			arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array(a["tan"])
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
	return true
