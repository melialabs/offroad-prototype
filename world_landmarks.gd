class_name WorldLandmarks
extends Node3D
## Original roadside landmarks built from simple meshes and existing materials.

const PLACES := [
	["Başlanğıc bazası", Vector2(-755, -695)],
	["Daş karxanası", Vector2(540, -555)],
	["Dağ keçidi", Vector2(815, 270)],
	["Meşə düşərgəsi", Vector2(-715, 565)],
	["Göl dayanacağı", Vector2(-260, -220)],
]

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
	# Depot storage shed, open on the side facing the road.
	var hub := Vector3(-745, 0, -680)
	hub.y = terrain.height_at(hub)
	_box(hub + Vector3(0, 3.8, 0), Vector3(12, 0.35, 8), Color(0.23, 0.27, 0.29), true)
	for x in [-5.5, 5.5]:
		for z in [-3.5, 3.5]:
			_box(hub + Vector3(x, 1.8, z), Vector3(0.3, 3.6, 0.3), Color(0.4, 0.43, 0.43), true)
	for i in 5:
		var p := Vector3(550 + i * 9, 0, -570)
		p.y = terrain.height_at(p)
		_box(p + Vector3(0, 1.5, 0), Vector3(5, 3, 5), Color(0.47, 0.43, 0.35), true)
	# Route edge markers near curves, with small reflective caps.
	for i in range(0, terrain._road.size() - 1, 3):
		var p := terrain._road[i]
		var dir := (terrain._road[i + 1] - p).normalized()
		for side in [-1.0, 1.0]:
			var pos2: Vector2 = p + Vector2(-dir.y, dir.x) * (MudTerrain.ROAD_HALF + 1.3) * side
			var pos := Vector3(pos2.x, terrain.height_at(Vector3(pos2.x, 0, pos2.y)), pos2.y)
			_box(pos + Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), Color(0.8, 0.81, 0.75), false)


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
		var a := terrain._road[i]
		var b := terrain._road[i + 1]
		var da := _road_tangent(terrain._road, i)
		var db := _road_tangent(terrain._road, i + 1)
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
	road.name = "AsphaltLoop"
	road.mesh = st.commit()
	road.material_override = terrain._material
	add_child(road)
	road.create_trimesh_collision()


func _road_tangent(line: PackedVector2Array, index: int) -> Vector2:
	var count := line.size() - 1
	var previous := posmod(index - 1, count)
	var following := posmod(index + 1, count)
	return (line[following] - line[previous]).normalized()
