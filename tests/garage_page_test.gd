extends SceneTree
## Garage page: the vehicle is parked inside the 3D garage room and the camera moves into the room;
## selecting another vehicle re-parks it; leaving the page puts it back on the road.
## godot --headless --path . -s res://tests/garage_page_test.gd
var main: Node
var frames := 0
var failures: Array[String] = []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		main.menu._show_page("vehicle")
	if frames == 60:
		_check(main.garage_active and main.garage.visible, "garage opens")
		var rel: Vector3 = main.truck.global_position - main.GARAGE_POS
		_check(absf(rel.x) < 5.0 and absf(rel.z) < 3.0 and rel.y > 0.2 and rel.y < 2.5, "vehicle rests inside the garage room: %s" % rel)
		_check(main.cam.garage_mode, "camera in garage mode")
		main.menu._select_vehicle(6)
	if frames == 120:
		_check(main.truck.spec_idx == 6, "vehicle switches inside the garage")
		var rel2: Vector3 = main.truck.global_position - main.GARAGE_POS
		_check(rel2.y > 0.2 and rel2.y < 2.5 and absf(rel2.x) < 5.0, "new vehicle rests inside the garage: %s" % rel2)
		main.menu._show_page("main")
	if frames == 160:
		_check(not main.garage_active and not main.garage.visible, "garage closes")
		_check(main.truck.global_position.y < 300.0, "vehicle returns to the world")
		_check(is_equal_approx(main._sun.light_energy, main._saved_light.x) and main._sun.light_energy > 0.5, "world sun restored")
		for f in failures:
			print("FAIL ", f)
		print("GARAGE PAGE TEST failures=", failures.size())
		quit(0 if failures.is_empty() else 1)
	return false
