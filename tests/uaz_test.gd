extends SceneTree
## Supplied UAZs: wheels, actual lamp surfaces, chassis switching and driving.
## godot --headless --path . -s res://tests/uaz_test.gd

var main: Node
var frames := 0
var idx := 4
var failures: Array[String] = []
var pos0 := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _physics_process(_delta: float) -> bool:
	frames += 1
	var t: OffroadTruck = main.truck
	var f := frames % 400
	if f == 1:
		main.select_vehicle(idx)
		# Check model alignment at rest; acceleration legitimately extends the
		# front suspension after the drivetrain power increase.
		Input.action_release(&"ui_up")
	if f == 150:
		var car: Dictionary = t._cars.get(idx, {})
		_check(not car.is_empty(), "model yüklənməyib: %d" % idx)
		_check((car["model"] as CarModel).body.visible, "gövdə görünməlidir: %d" % idx)
		var contact := 0
		for w in t.wheels:
			if w.is_in_contact():
				contact += 1
		_check(contact == 4, "4 təkər yerə dəyməlidir (%d): %d" % [idx, contact])
		var cm: CarModel = car["model"]
		_check(cm.head_lamps.size() == 2 and cm.tail_lamps.size() == 2, "four actual model lamps: %d" % idx)
		_check(t.lights._model_head == cm.head_lamps, "lights bind to selected car: %d" % idx)
		_check(t._col.position.is_equal_approx(t.spec["collision_offset"]), "chassis offset: %d" % idx)
		for lamp in cm.head_lamps:
			_check(lamp.get_aabb().size.x < 0.3, "headlamp extraction excludes body: %d" % idx)
		for k in 2:
			_check(t.lights._heads[k].position.distance_to(cm.head_lamp_pos[k]) < 0.001, "spotlight at real lens: %d/%d" % [idx,k])
			_check(cm.head_lamp_pos[k].z > cm.wheel_centers[2].z, "headlight ahead of front axle: %d" % idx)
		_check(not t.wheels[0].use_as_steering and not t.wheels[1].use_as_steering and t.wheels[2].use_as_steering and t.wheels[3].use_as_steering, "correct front steering axle: %d" % idx)
		t.lights.headlight_mode = 1
		t.lights._apply()
		_check(cm.head_lamps[0].material_overlay != null, "actual lens glows: %d" % idx)
		t.awd_on = true
		t.diff_lock = true
		for k in 4:
			var dy: float = absf(t.wheels[k].position.y - cm.wheel_centers[k].y)
			var dx: float = absf(t.wheels[k].position.x - cm.wheel_centers[k].x)
			_check(dy < 0.05 and dx < 0.01, "təkər modeldəki yerdə deyil (%d/%d): dy=%.3f dx=%.3f" % [idx, k, dy, dx])
		Input.action_press(&"ui_up")
		pos0 = t.global_position
		print("UAZ %s radius=%.3f y=%.2f" % [t.spec["name"], t.wheels[0].wheel_radius, t.global_position.y])
	if f == 330:
		var moved := Vector2(t.global_position.x - pos0.x, t.global_position.z - pos0.z).length()
		_check(moved > 8.0, "maşın getməlidir (%d): %.1f m" % [idx, moved])
		print("UAZ %s getdi %.1f m, %.0f km/saat" % [t.spec["name"], moved, t.linear_velocity.length() * 3.6])
		idx += 1
		if idx > 6:
			for m in failures:
				print("FAIL ", m)
			print("UAZ TEST: uğursuzluq=%d" % failures.size())
			quit(0 if failures.is_empty() else 1)
	return false
