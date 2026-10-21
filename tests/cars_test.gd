extends SceneTree
## Lada modelləri: yüklənir, təkərlər yerə oturur, maşın sürülür.
## godot --headless --path . -s res://tests/cars_test.gd

var main: Node
var frames := 0
var idx := 3
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
		Input.action_press(&"ui_up")
	if f == 150:
		var car: Dictionary = t._cars.get(idx, {})
		_check(not car.is_empty(), "model yüklənməyib: %d" % idx)
		_check((car["model"] as CarModel).body.visible, "gövdə görünməlidir: %d" % idx)
		var contact := 0
		for w in t.wheels:
			if w.is_in_contact():
				contact += 1
		_check(contact == 4, "4 təkər yerə dəyməlidir (%d): %d" % [idx, contact])
		pos0 = t.global_position
		print("CARS %s radius=%.3f y=%.2f" % [t.spec["name"], t.wheels[0].wheel_radius, t.global_position.y])
	if f == 330:
		var moved := Vector2(t.global_position.x - pos0.x, t.global_position.z - pos0.z).length()
		_check(moved > 8.0, "maşın getməlidir (%d): %.1f m" % [idx, moved])
		print("CARS %s getdi %.1f m, %.0f km/saat" % [t.spec["name"], moved, t.linear_velocity.length() * 3.6])
		idx += 1
		if idx > 5:
			for m in failures:
				print("FAIL ", m)
			print("CARS TEST: uğursuzluq=%d" % failures.size())
			quit(0 if failures.is_empty() else 1)
	return false
