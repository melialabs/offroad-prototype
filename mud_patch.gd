class_name MudPatch
extends StaticBody3D
## Local heightfield: the visible rut and wheel collision share exactly the same heights.
const STEP := 0.25
const SIDE := 65
var terrain: MudTerrain
var tile: Vector2i
var depths := PackedFloat32Array()
## 0..1 per cell: soil firmed by passing wheels (reduces later digging, raises grip).
var compaction := PackedFloat32Array()
## Largest height a pushed-aside rim may rise above the original ground (m).
const BERM_MAX := 0.12
const BERM_SHARE := 0.22
var _base := PackedFloat32Array()
var _soft := PackedFloat32Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _indices := PackedInt32Array()
var _mesh: MeshInstance3D
var _shape: HeightMapShape3D
var _dirty := false
var _timer := 0.0

func _ready() -> void:
	position = Vector3(tile.x * 16.0, 0, tile.y * 16.0)
	if depths.is_empty():
		depths.resize(SIDE * SIDE)
	if compaction.is_empty():
		compaction.resize(SIDE * SIDE)
	for z in SIDE:
		for x in SIDE:
			var p := position + Vector3(x * STEP, 0, z * STEP)
			_base.append(terrain.base_height_at(p))
			_soft.append(terrain.sample_grid(terrain.soft, p))
			_uv.append(Vector2(p.x, p.z))
			var route := terrain._near_route(Vector2(p.x, p.z), terrain._road, terrain._road_len, terrain._road_bins)
			_uv2.append(Vector2(route[1], route[2]))
	for z in SIDE - 1:
		for x in SIDE - 1:
			var a := z * SIDE + x
			_indices.append_array([a, a + 1, a + SIDE, a + 1, a + SIDE + 1, a + SIDE])
	_mesh = MeshInstance3D.new()
	var mat := terrain._material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("detail_surface", true)
	_mesh.material_override = mat
	add_child(_mesh)
	_shape = HeightMapShape3D.new()
	_shape.map_width = SIDE
	_shape.map_depth = SIDE
	var col := CollisionShape3D.new()
	col.shape = _shape
	col.position = Vector3(8, 0, 8)
	col.scale = Vector3(STEP, 1, STEP)
	add_child(col)
	_rebuild()

func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= 0.12:
		_rebuild()
		_dirty = false
		_timer = 0.0

func _height(x: int, z: int) -> float:
	var i := clampi(z, 0, SIDE - 1) * SIDE + clampi(x, 0, SIDE - 1)
	return _base[i] - depths[i]

func _rebuild() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var tangents := PackedFloat32Array()
	var heights := PackedFloat32Array()
	for z in SIDE:
		for x in SIDE:
			var i := z * SIDE + x
			var y := _height(x, z)
			vertices.append(Vector3(x * STEP, y, z * STEP))
			var dx := _height(x + 1, z) - _height(x - 1, z)
			var dz := _height(x, z + 1) - _height(x, z - 1)
			normals.append(Vector3(-dx, 2.0 * STEP, -dz).normalized())
			var t := Vector3(2.0 * STEP, dx, 0).normalized()
			tangents.append_array([t.x, t.y, t.z, 1.0])
			colors.append(Color(maxf(depths[i], 0.0) / MudTerrain.MAX_DEPTH, _soft[i], 0, 1))
			heights.append(y)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.mesh = mesh
	_shape.map_data = heights

func depth_at(p: Vector3) -> float:
	var g := Vector2((p.x - position.x) / STEP, (p.z - position.z) / STEP)
	var x := clampi(floori(g.x), 0, SIDE - 2)
	var z := clampi(floori(g.y), 0, SIDE - 2)
	return lerpf(lerpf(depths[z * SIDE + x], depths[z * SIDE + x + 1], clampf(g.x - x, 0, 1)),
		lerpf(depths[(z + 1) * SIDE + x], depths[(z + 1) * SIDE + x + 1], clampf(g.x - x, 0, 1)), clampf(g.y - z, 0, 1))

func height_at(p: Vector3) -> float:
	return terrain.base_height_at(p) - depth_at(p)

func dig(p: Vector3, radius: float, amount: float) -> void:
	var gx := (p.x - position.x) / STEP
	var gz := (p.z - position.z) / STEP
	var reach := maxf(radius, STEP)
	# Displaced soil piles up in a ring just outside the contact, so ruts get raised edges.
	var outer := reach * 1.5
	if gx < -outer / STEP or gz < -outer / STEP or gx > 64 + outer / STEP or gz > 64 + outer / STEP:
		return
	for z in range(maxi(ceili(gz - outer / STEP), 0), mini(floori(gz + outer / STEP), 64) + 1):
		for x in range(maxi(ceili(gx - outer / STEP), 0), mini(floori(gx + outer / STEP), 64) + 1):
			var d := Vector2(x - gx, z - gz).length() * STEP
			if d > outer:
				continue
			var i := z * SIDE + x
			var world := position + Vector3(x * STEP, 0, z * STEP)
			if terrain.road_distance_fast(world) < MudTerrain.ROAD_HALF + 0.6:
				continue
			var soft := OffroadSurface.effective_softness(_soft[i], compaction[i])
			if d <= reach:
				var rim := terrain._detail_floor(Vector2(world.x, world.z)) / MudTerrain.DETAIL_UNDERFLOOR
				var profile := 1.0 - smoothstep(reach * 0.3, reach, d)
				depths[i] = minf(depths[i] + amount * profile * soft * rim, MudTerrain.MAX_DEPTH * _soft[i])
			else:
				var ring := 1.0 - (d - reach) / (outer - reach)
				depths[i] = maxf(depths[i] - amount * BERM_SHARE * ring * soft, -BERM_MAX * _soft[i])
			_dirty = true


## Firms the soil under a wheel that rolls without digging (rate already includes load).
func compact(p: Vector3, radius: float, amount: float) -> void:
	var gx := (p.x - position.x) / STEP
	var gz := (p.z - position.z) / STEP
	var reach := maxf(radius, STEP)
	if gx < -reach / STEP or gz < -reach / STEP or gx > 64 + reach / STEP or gz > 64 + reach / STEP:
		return
	for z in range(maxi(ceili(gz - reach / STEP), 0), mini(floori(gz + reach / STEP), 64) + 1):
		for x in range(maxi(ceili(gx - reach / STEP), 0), mini(floori(gx + reach / STEP), 64) + 1):
			var d := Vector2(x - gx, z - gz).length() * STEP
			if d > reach:
				continue
			var i := z * SIDE + x
			compaction[i] = minf(compaction[i] + amount * (1.0 - d / reach), 1.0)


## Softness seen by tires: the base value reduced by compaction (nearest cell).
func soft_at(p: Vector3) -> float:
	var x := clampi(roundi((p.x - position.x) / STEP), 0, SIDE - 1)
	var z := clampi(roundi((p.z - position.z) / STEP), 0, SIDE - 1)
	var i := z * SIDE + x
	return OffroadSurface.effective_softness(_soft[i], compaction[i])
