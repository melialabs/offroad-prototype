class_name MudTerrain
extends StaticBody3D
## Deformasiya olunan landşaft: təkər basdıqca palçıqlı yer batır.

const N := 97              # tor ölçüsü (N x N nöqtə)
const CELL := 1.5          # bir xanənin metrlə ölçüsü
const MAX_DEPTH := 0.7     # yerin ən çox batma dərinliyi
const REBUILD_INTERVAL := 0.1

var h := PackedFloat32Array()     # cari hündürlük
var base := PackedFloat32Array()  # ilkin hündürlük
var soft := PackedFloat32Array()  # 0 = bərk yer, 1 = dərin palçıq

var _mesh_inst := MeshInstance3D.new()
var _shape := HeightMapShape3D.new()
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _dirty := false
var _timer := 0.0


func _ready() -> void:
	_generate()
	_build_indices()
	_shape.map_width = N
	_shape.map_depth = N
	_shape.map_data = h
	var col := CollisionShape3D.new()
	col.shape = _shape
	col.scale = Vector3(CELL, 1.0, CELL)
	add_child(col)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.albedo_texture = load("res://assets/tex/ground_diff.jpg")
	mat.roughness_texture = load("res://assets/tex/ground_rough.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/tex/ground_nor_gl.jpg")
	mat.ao_enabled = true
	mat.ao_texture = load("res://assets/tex/ground_ao.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mesh_inst.material_override = mat
	add_child(_mesh_inst)
	_rebuild_mesh()


func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= REBUILD_INTERVAL:
		_timer = 0.0
		_dirty = false
		_shape.map_data = h
		_rebuild_mesh()


func _generate() -> void:
	h.resize(N * N)
	base.resize(N * N)
	soft.resize(N * N)
	var hills := FastNoiseLite.new()
	hills.seed = 7
	hills.frequency = 0.012
	var mud := FastNoiseLite.new()
	mud.seed = 21
	mud.frequency = 0.02
	var half := (N - 1) * 0.5
	for z in N:
		for x in N:
			var wx := (x - half) * CELL
			var wz := (z - half) * CELL
			var dist := Vector2(wx, wz).length()
			var flat := clampf((dist - 8.0) / 25.0, 0.0, 1.0)
			var i := z * N + x
			h[i] = hills.get_noise_2d(wx, wz) * 6.0 * flat
			base[i] = h[i]
			# başlanğıcdan bir az aralıda palçıq sahələri
			var m := mud.get_noise_2d(wx + 40.0, wz) * 0.5 + 0.5
			soft[i] = clampf((m - 0.45) * 5.0, 0.0, 1.0) * clampf(dist / 12.0, 0.0, 1.0)


func _idx(x: int, z: int) -> int:
	return clampi(z, 0, N - 1) * N + clampi(x, 0, N - 1)


func _build_indices() -> void:
	for z in N - 1:
		for x in N - 1:
			var a := z * N + x
			var b := a + 1
			var c := a + N
			var d := c + 1
			_indices.append_array([a, b, c, b, d, c])
	_verts.resize(N * N)
	_normals.resize(N * N)
	_colors.resize(N * N)


func _rebuild_mesh() -> void:
	var half := (N - 1) * 0.5
	for z in N:
		for x in N:
			var i := z * N + x
			_verts[i] = Vector3((x - half) * CELL, h[i], (z - half) * CELL)
			var dx := h[_idx(x + 1, z)] - h[_idx(x - 1, z)]
			var dz := h[_idx(x, z + 1)] - h[_idx(x, z - 1)]
			_normals[i] = Vector3(-dx, 2.0 * CELL, -dz).normalized()
			var depth := clampf((base[i] - h[i]) / MAX_DEPTH, 0.0, 1.0)
			var grass := Color(0.60, 0.80, 0.40)
			var wet := Color(0.55, 0.42, 0.30)
			var rut := Color(0.30, 0.22, 0.16)
			var c := grass.lerp(wet, clampf(soft[i] * 1.8, 0.0, 1.0))
			_colors[i] = c.lerp(rut, depth)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_inst.mesh = mesh


## Dünya koordinatından tor indeksinə.
func _to_grid(world_pos: Vector3) -> Vector2:
	var local := to_local(world_pos)
	var half := (N - 1) * 0.5
	return Vector2(local.x / CELL + half, local.z / CELL + half)


func softness_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	return soft[z * N + x]


func depth_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	var i := z * N + x
	return base[i] - h[i]


func height_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	return h[_idx(roundi(g.x), roundi(g.y))]


## Təkərin basdığı yeri batırır, kənarlarını bir az qaldırır.
func deform(world_pos: Vector3, radius: float, amount: float) -> void:
	var g := _to_grid(world_pos)
	var r := int(ceil(radius / CELL))
	var cx := roundi(g.x)
	var cz := roundi(g.y)
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or z < 0 or x >= N or z >= N:
				continue
			var d := Vector2(x - g.x, z - g.y).length() * CELL
			if d > radius:
				continue
			var i := z * N + x
			var falloff := 1.0 - d / radius
			var s: float = soft[i]
			if s <= 0.0:
				continue
			h[i] = maxf(h[i] - amount * falloff * s, base[i] - MAX_DEPTH)
			_dirty = true
