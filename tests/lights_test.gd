extends SceneTree
## Mühərrik, fənər, qəza işığı və gecə rejimi testi.
## godot --headless --path . -s res://tests/lights_test.gd

var main: Node
var frames := 0
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
	if frames == 30:
		t.stop_engine()
		pos0 = t.global_position
		Input.action_press(&"ui_up")
		Input.parse_input_event(_key(KEY_W, true))
	if frames == 150:
		var moved := Vector2(t.global_position.x - pos0.x, t.global_position.z - pos0.z).length()
		_check(moved < 1.0, "mühərrik söndürülüyü halda maşın getdi: %.1f m" % moved)
		_check(t.rpm < 100.0, "söndürülü mühərrikdə rpm sıfıra enməlidir: %.0f" % t.rpm)
		t.toggle_engine()
		_check(t.engine_state == OffroadTruck.EngineState.CRANKING, "işə düşmə mərhələsi olmalıdır")
	if frames == 230:
		_check(t.engine_state == OffroadTruck.EngineState.RUNNING, "mühərrik işləməlidir")
		pos0 = t.global_position
	if frames == 430:
		var moved2 := Vector2(t.global_position.x - pos0.x, t.global_position.z - pos0.z).length()
		_check(moved2 > 5.0, "işləyən mühərriklə maşın getməlidir: %.1f m" % moved2)
		Input.parse_input_event(_key(KEY_W, false))
		_check(t.lights.headlight_mode == 0, "fənərlər başlanğıcda söndürülü olmalıdır")
		t.lights.cycle_headlights()
		_check(t.lights.headlight_mode == 1, "L yaxın fənəri yandırmalıdır")
		t.lights.cycle_headlights()
		_check(t.lights.headlight_mode == 2, "L uzaq fənəri yandırmalıdır")
		t.lights.cycle_headlights()
		_check(t.lights.headlight_mode == 0, "L fənəri söndürməlidir")
		t.lights.toggle_hazard()
		_check(t.lights.hazard, "Z qəza işığını yandırmalıdır")
		t.lights.toggle_hazard()
		_check(not t.lights.hazard, "Z qəza işığını söndürməlidir")
		main.set_night(true)
		_check(main.night, "gecə rejimi aktiv olmalıdır")
		_check(t.lights.headlight_mode == 1, "gecə fənərlər avtomatik yanmalıdır")
		_check(main._env.ambient_light_energy < 0.3, "gecə ambient aşağı olmalıdır")
		main.set_night(false)
		_check(not main.night and t.lights.headlight_mode == 0, "gündüz rejiminə qayıtmalıdır")
		for f in failures:
			print("FAIL ", f)
		print("LIGHTS TEST: uğursuzluq=%d" % failures.size())
		quit(0 if failures.is_empty() else 1)
	return false


func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev
