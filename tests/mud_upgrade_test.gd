extends SceneTree
var failures: Array[String] = []
var terrain: MudTerrain

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	terrain = MudTerrain.new()
	root.add_child(terrain)
	var p := Vector3(-365, 0, -425)
	var started := Time.get_ticks_msec()
	terrain.prepare_mud(p)
	print("DETAIL initial window ms=", Time.get_ticks_msec() - started)
	check(terrain._fine_patches.size() == 9, "bounded local detail window")
	check(terrain.softness_at(p) > 0.9, "swamp is soft")
	var before := terrain.height_at(p)
	for i in 40:
		terrain.deform(p, 0.3, 0.04)
	check(terrain.depth_at(p) > 0.8, "deep rut created")
	check(terrain.depth_at(p) <= MudTerrain.MAX_DEPTH + 0.001, "soil depth bounded")
	check(terrain.depth_at(p + Vector3(0.8, 0, 0)) < 0.01, "rut does not flatten neighbouring tire track")
	var patch: MudPatch = terrain._fine_patches[terrain._detail_key(p)]
	patch._rebuild()
	var x := roundi((p.x - patch.position.x) / MudPatch.STEP)
	var z := roundi((p.z - patch.position.z) / MudPatch.STEP)
	check(absf(patch._shape.map_data[z * MudPatch.SIDE + x] - terrain.height_at(p)) < 0.001, "collision follows visible rut")
	check(terrain.height_at(p) < before - 0.8, "actual support height sinks")
	# A stamp across a tile boundary must write the shared height identically.
	var edge := Vector3(-368, 0, -425)
	for i in 10:
		terrain.deform(edge, 0.3, 0.04)
	var left: MudPatch = terrain._fine_patches[Vector2i(-24, -27)]
	var right: MudPatch = terrain._fine_patches[Vector2i(-23, -27)]
	var row := roundi((edge.z - left.position.z) / MudPatch.STEP)
	check(absf(left._height(64, row) - right._height(0, row)) < 0.0001, "rut collision seamless across tiles")
	var road: Vector3 = terrain.road_spawn()["pos"]
	var road_before := terrain.height_at(road)
	terrain.deform(road, 0.4, 2.0)
	check(is_equal_approx(road_before, terrain.height_at(road)), "asphalt rigid")
	var cached := terrain.depth_at(p)
	terrain.prepare_mud(p + Vector3(100, 0, 0))
	terrain.prepare_mud(p)
	check(absf(terrain.depth_at(p) - cached) < 0.001, "ruts retained on return")
	# Evict one side of a boundary: restoring the neighbour must close the seam.
	terrain.prepare_mud(p + Vector3(100, 0, 0))
	terrain._rut_cache.erase(Vector2i(-24, -27))
	terrain.prepare_mud(p)
	left = terrain._fine_patches[Vector2i(-24, -27)]
	right = terrain._fine_patches[Vector2i(-23, -27)]
	check(absf(left._height(64, row) - right._height(0, row)) < 0.0001, "shared edge survives one-sided cache eviction")
	terrain.set_surface_conditions(0.8, 0.0, 0.0)
	check(is_equal_approx(terrain._fine_patches.values()[0]._mesh.material_override.get_shader_parameter("wetness"), 0.8), "weather reaches fine soil")
	# Validate real VehicleWheel3D support, rather than only modifying an array.
	var truck := OffroadTruck.new()
	truck.terrain = terrain
	root.add_child(truck)
	truck.apply_spec(3)
	truck.stop_engine()
	truck.controls_enabled = false
	truck.position = Vector3(p.x + 5.0, terrain.height_at(p) + 1.4, p.z + 5.0)
	for i in 120:
		await physics_frame
	var initial_y := truck.position.y
	for frame in 90:
		for w in truck.wheels:
			if w.is_in_contact():
				terrain.deform(w.get_contact_point(), 0.34, 0.035)
		await physics_frame
	for i in 60:
		await physics_frame
	var drop := initial_y - truck.position.y
	print("SINK body drop=%.3fm mud=%.2f" % [drop, truck.mud_level])
	check(drop > 0.2, "vehicle physically descends into ruts")
	check(drop < 1.6, "underfloor stops falling through world")
	# Source glow and spotlight use the same actual lamp for all imported cars.
	for spec in [0, 3, 4, 5, 6]:
		truck.apply_spec(spec)
		truck.lights.set_headlights(1)
		truck.lights._process(0.0)
		check(truck.lights._model_head.size() == 2, "model lens glow bound: %d" % spec)
		for i in 2:
			check(truck.lights._model_head[i].material_overlay != null, "actual glass lights up: %d" % spec)
			check(truck.lights._heads[i].position.distance_to(truck.lights.HEAD_POS[i]) < 0.001, "beam origin at glass")
	truck.mud_spray.contact(0, p, Vector3.ZERO, Vector3.FORWARD, 0, 0.5, 1, 0)
	check(not truck.mud_spray.emitters[0].emitting, "stationary wheel does not throw mud")
	truck.mud_spray.contact(0, p, Vector3.ZERO, Vector3.FORWARD, 180, 0.5, 1, 8)
	check(truck.mud_spray.emitters[0].emitting, "wheelspin throws mud even when stuck")
	truck.mud_spray.contact(0, p, Vector3(0,0,8), Vector3.FORWARD, 180, 0.5, 0, 8)
	check(not truck.mud_spray.emitters[0].emitting, "dry contact does not throw mud")
	truck.mud_spray.contact(0, Vector3(p.x, terrain.height_at(p), p.z), Vector3.ZERO, Vector3.FORWARD, 100, 0.5, 1, 5)
	for i in 12:
		truck.mud_spray._physics_process(1.0 / 60.0)
	truck.mud_spray.stop_all()
	for i in 100:
		truck.mud_spray._physics_process(1.0 / 60.0)
	check(truck.mud_spray.impacts > 0, "flying clods hit soil and flatten")
	check(truck.mud_spray._instances.instance_count == 256, "splash pool bounded")
	truck.free()
	terrain.free()
	print("MUD UPGRADE failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
