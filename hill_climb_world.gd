class_name HillClimbWorld
extends Node3D
## Low-cost discovery rings, checkpoint flags, real collision rocks and local foliage.
var activity: HillClimbActivity
var terrain: MudTerrain
var _markers: Array[Node3D] = []
var _checkpoint: Node3D
var _flags: MultiMeshInstance3D
var _rock_mesh: SphereMesh
var _stone: StandardMaterial3D

func _ready() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.30, 0.29, 0.25)
	_stone.roughness = 0.94
	_rock_mesh = SphereMesh.new()
	_rock_mesh.radial_segments = 9
	_rock_mesh.rings = 5
	_rock_mesh.radius = 1.0
	_rock_mesh.height = 2.0
	_rock_mesh.material = _stone
	for i in activity.markers.size():
		var marker: Dictionary = activity.markers[i]
		var route: Dictionary = activity.routes[marker["route"]]
		var root := Node3D.new()
		root.name = "Discovery_%02d" % i
		add_child(root)
		root.add_child(_ring(marker["p"], 5.5, HillClimbCatalog.COLORS[route["difficulty"]]))
		_label(root, "▲ HILL CLIMB" if marker["hub"] else "▲ %02d" % (int(marker["route"]) + 1), marker["p"] + Vector3.UP * 2.6, 0.012)
		_markers.append(root)
	_build_course_details()
	_add_alpine_trees()
	activity.changed.connect(_refresh)
	_refresh()

func _ring(center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 49:
		var angle := float(i) / 48.0 * TAU
		for r in [radius - 0.09, radius + 0.09]:
			var p := center + Vector3(cos(angle) * r, 0, sin(angle) * r)
			p.y = terrain.sample_grid(terrain.base, p) + 0.08
			vertices.append(p)
		if i < 48:
			var a := i * 2
			indices.append_array([a,a+2,a+1,a+1,a+2,a+3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 170.0
	mi.visibility_range_end_margin = 15.0
	return mi

func _label(parent: Node3D, text: String, at: Vector3, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 40
	label.pixel_size = pixel
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.84, 0.48)
	label.visibility_range_end = 120.0
	label.no_depth_test = false
	parent.add_child(label)

func _build_course_details() -> void:
	var finish_signs: Array[Vector2] = []
	var poles: Array[Transform3D] = []
	var colors: Array[Color] = []
	for ri in activity.routes.size():
		var route: Dictionary = activity.routes[ri]
		var points: PackedVector2Array = route["points"]
		var difficulty: int = route["difficulty"]
		for i in range(1, points.size()):
			var forward := (points[i] - points[i - 1]).normalized()
			var side := Vector2(-forward.y, forward.x)
			for sign_side in [-1,1]:
				var p := activity.ground(points[i] + side * float(route["half_width"]) * sign_side)
				p.y += 0.38
				poles.append(Transform3D(Basis.from_scale(Vector3(0.09,0.78,0.09)),p))
				colors.append(HillClimbCatalog.COLORS[difficulty].darkened(0.25))
			if difficulty > 0 and i in [2,4]:
				var p := activity.ground(points[i].lerp(points[i-1],0.4) + side * (0.7 if i % 2 == 0 else -0.7))
				_rock(p, Vector3(0.60 + difficulty*0.13, 0.22 + difficulty*0.09, 0.68), float(i + ri))
			if ri == 8 and i in [3,5]:
				_rock(activity.ground(points[i]),Vector3(1.1,0.48,0.48),float(i))
		# Finish pennant is visible without a giant beam in the forest.
		var signed := false
		for existing in finish_signs:
			if existing.distance_to(points[-1]) < 12:
				signed = true
		if not signed:
			finish_signs.append(points[-1])
			_label(self,"▲ SUMMIT" if ri >= 6 else "FINISH · %02d" % (ri+1),activity.ground(points[-1])+Vector3.UP*3.5,0.009)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.5
	pole_mesh.bottom_radius = 0.5
	pole_mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	pole_mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = pole_mesh
	mm.instance_count = poles.size()
	for i in poles.size():
		mm.set_instance_transform(i,poles[i])
		mm.set_instance_color(i,colors[i])
	_flags = MultiMeshInstance3D.new()
	_flags.multimesh = mm
	_flags.visibility_range_end = 220.0
	_flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flags)
	for trench in terrain.hill_zone.trenches:
		var p: Vector2 = trench["p"]
		var water := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 2.5
		disk.bottom_radius = 2.5
		disk.height = 0.015
		disk.radial_segments = 32
		water.mesh = disk
		water.position = Vector3(p.x, float(trench["floor"]) + 0.32, p.y)
		var wet := StandardMaterial3D.new()
		wet.albedo_color = Color(0.16,0.13,0.065,0.75)
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet.roughness = 0.12
		water.material_override = wet
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)
	# Rim boulders frame the summit without blocking its finish lines.
	for i in 14:
		var angle := i * TAU / 14.0
		var p := Vector2(492,382) + Vector2(cos(angle),sin(angle)) * 18
		if not terrain.hill_zone.clearing(p):
			_rock(activity.ground(p),Vector3(1.5,0.9,1.1),angle)

func _rock(at: Vector3, scale_rock: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3.UP * scale_rock.y * 0.45
	body.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh
	mi.scale = scale_rock
	mi.visibility_range_end = 180.0
	body.add_child(mi)
	var points := PackedVector3Array()
	for p in _rock_mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		points.append(p * scale_rock)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_alpine_trees() -> void:
	var species := VegetationAssets.load_species("pine_tree_01", "pine_spray")
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 8229
	for i in 120:
		var p := Vector2(rng.randf_range(245,600),rng.randf_range(160,430))
		var at := activity.ground(p)
		if at.y < 105 or at.y > 190 or terrain.hill_zone.clearing(p) or terrain.slope_at(at) > 0.55:
			continue
		var size_tree := rng.randf_range(0.65,0.95)
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size_tree),at))
		var body := StaticBody3D.new()
		body.position = at + Vector3.UP*2.5
		var col := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 5.0
		cylinder.radius = 0.3*size_tree
		col.shape = cylinder
		body.add_child(col)
		add_child(body)
	for variants: Array in species.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[mini(1,variants.size()-1)]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i,transforms[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.visibility_range_end = 210.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _refresh() -> void:
	for i in _markers.size():
		_markers[i].visible = activity.marker_enabled(i) and not activity.engaged()
	if _checkpoint != null:
		_checkpoint.free()
		_checkpoint = null
	if activity.state not in [HillClimbActivity.State.COUNTDOWN, HillClimbActivity.State.RUNNING]:
		return
	_checkpoint = Node3D.new()
	add_child(_checkpoint)
	var index := activity.next_checkpoint
	var p := activity.checkpoints[index]
	_checkpoint.add_child(_ring(p,3.5,Color(1,0.77,0.25)))
	_label(_checkpoint,"▲ %d / %d" % [index,activity.checkpoints.size()-1],p+Vector3.UP*3.0,0.018)
