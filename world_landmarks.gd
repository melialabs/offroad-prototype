class_name WorldLandmarks
extends Node3D
## Original roadside landmarks built from simple meshes and existing materials.

const PLACES := MapLayout.PLACES

func build(terrain: MudTerrain) -> void:
	_build_road(terrain)
	for place in PLACES:
		var p: Vector2 = place[1]
		var ground := Vector3(p.x, 0, p.y)
		ground.y = terrain.height_at(ground)
		_box(ground + Vector3(0, 1.2, 0), Vector3(0.18, 2.4, 0.18), Color(0.25, 0.19, 0.12), true)
		_box(ground + Vector3(0, 2.25, 0), Vector3(4.2, 1.0, 0.15), Color(0.07, 0.24, 0.20), false)
		var label := Label3D.new()
		label.text = place[0]
		label.font_size = 52
		label.pixel_size = 0.008
		label.position = ground + Vector3(0, 2.25, 0.10)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		add_child(label)

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material_override = mat
	mesh.visibility_range_end = 280.0
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.position = pos
		body.add_child(col)
		add_child(body)


func _build_road(terrain: MudTerrain) -> void:
	# Smooth 8 m paved ribbon with its own collision above the coarse world grid.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in terrain._road.size() - 1:
		if terrain._road_gap[i] == 1:
			continue
		var a := terrain._road[i]
		var b := terrain._road[i + 1]
		var da := _road_tangent(terrain, i)
		var db := _road_tangent(terrain, i + 1)
		var sa := Vector2(-da.y, da.x) * MudTerrain.ROAD_HALF
		var sb := Vector2(-db.y, db.x) * MudTerrain.ROAD_HALF
		var points := [a + sa, a - sa, b + sb, b - sb]
		for k in [0, 1, 2, 1, 3, 2]:
			var p: Vector2 = points[k]
			var ri := i if k < 2 else i + 1
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(Vector3.RIGHT, 1))
			st.set_uv(p)
			st.set_uv2(Vector2(MudTerrain.ROAD_HALF * (1.0 if k % 2 == 0 else -1.0), terrain._road_len[ri]))
			st.add_vertex(Vector3(p.x, terrain._road_h[ri] + 0.08, p.y))
	var road := MeshInstance3D.new()
	road.name = "AsphaltRoads"
	road.mesh = st.commit()
	road.material_override = terrain._material
	add_child(road)
	road.create_trimesh_collision()


func _road_tangent(terrain: MudTerrain, index: int) -> Vector2:
	# eyni xətt daxilində qonşular (xətlər arasındakı kəsikdən keçmir)
	var line := terrain._road
	var gaps := terrain._road_gap
	var previous := index - 1 if index > 0 and gaps[index - 1] == 0 else index
	var following := index + 1 if index < line.size() - 1 and gaps[index] == 0 else index
	if previous == following:
		return Vector2.RIGHT
	return (line[following] - line[previous]).normalized()
