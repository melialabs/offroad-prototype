extends SceneTree
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var truck := OffroadTruck.new()
	root.add_child(truck)
	truck.freeze = true
	var jeep := truck._jeep
	check(jeep != null, "Jeep model loads")
	for k in [2, 3]:
		var mesh := jeep.wheel_meshes[k]
		check(mesh.surface_get_array_index_len(0) / 3 == 3915, "complete original front tire geometry retained")
		check(mesh.get_aabb().size.x < 0.60, "front tire axle aligned with X")
		check(absf(mesh.get_aabb().size.z - mesh.get_aabb().size.y) < 0.03, "front wheel has circular radial bounds")
		check(truck.wheels[k].use_as_steering, "front wheels steer")
	for i in 2:
		check(not truck.lights._head_meshes[i].visible, "no floating front headlight sphere")
		check(not truck.lights._amber_meshes[i].visible, "no floating front indicator sphere")
		check(absf(truck.lights.HEAD_POS[i].y - 0.486) < 0.01, "headlamp height matches Jeep grille")
		check(absf(truck.lights.HEAD_POS[i].z - (2.295 - jeep.origin.z)) < 0.01, "headlamp depth matches Jeep grille")
	truck.lights.set_headlights(1)
	for i in 2:
		check(truck.lights._heads[i].position.is_equal_approx(truck.lights.HEAD_POS[i]), "beam originates at lamp mount")
		check((-truck.lights._heads[i].basis.z).z > 0.9, "beam faces forwards")
	truck.apply_spec(1)
	check(truck.lights._head_meshes[0].visible, "fallback lamps restored on box truck")
	truck.apply_spec(0)
	check(not truck.lights._head_meshes[0].visible, "Jeep lamp visibility restored on switch back")
	truck.free()
	print("JEEP ALIGNMENT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
