extends SceneTree
## Ana menyu testi: açılışda menyu açıqdır və maşın idarə olunmur, "başla" idarəni açır,
## Esc oyun içində menyunu açır/bağlayır, texnika seçimi işləyir.
## godot --headless --path . -s res://tests/menu_test.gd

var main: Node
var frames := 0
var failures: Array[String] = []
var pos_before := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main  # əsas səhnə kimi, menyu açılsın
	Input.action_press(&"ui_up")


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_check(main.menu.visible, "açılışda menyu görünməlidir")
		_check(not main.truck.controls_enabled, "menyu açıqkən maşın idarə olunmamalıdır")
		_check(main.cam.menu_orbit, "menyuda kamera fırlanmalıdır")
		_check(not main.hud.visible, "menyuda HUD gizli olmalıdır")
		pos_before = main.truck.global_position
	if frames == 100:
		# qaz basılı olsa da maşın yerindən tərpənməməlidir
		var moved := Vector2(main.truck.global_position.x - pos_before.x, main.truck.global_position.z - pos_before.z).length()
		_check(moved < 1.5, "menyu açıqkən maşın hərəkət etdi: %.1f m" % moved)
		main.menu.start_requested.emit()
		pos_before = main.truck.global_position
	if frames == 104:
		_check(not main.menu.visible, "başladıqdan sonra menyu bağlanmalıdır")
		_check(main.truck.controls_enabled, "başladıqdan sonra idarə açılmalıdır")
		_check(main.hud.visible, "başladıqdan sonra HUD görünməlidir")
		_check(not main.cam.menu_orbit, "başladıqdan sonra kamera izləməlidir")
		_check(main.truck.engine_state == OffroadTruck.EngineState.OFF, "yeni oyunda mühərrik söndürülü olmalıdır")
		main.truck.toggle_engine()
	if frames == 330:
		var moved := Vector2(main.truck.global_position.x - pos_before.x, main.truck.global_position.z - pos_before.z).length()
		_check(moved > 8.0, "başladıqdan sonra maşın getməlidir: %.1f m" % moved)
		_esc()
	if frames == 334:
		_check(main.menu.visible, "Esc oyun içində menyunu açmalıdır")
		_check(main.menu.in_game, "oyun içində menyu 'Davam et' rejimində olmalıdır")
		_check(main.menu._btn_start.text == "Davam et", "düymə 'Davam et' olmalıdır: %s" % main.menu._btn_start.text)
		main.select_vehicle(2)
	if frames == 338:
		_check(main.truck.spec_idx == 2, "texnika seçimi işləmədi: %d" % main.truck.spec_idx)
		_esc()
	if frames == 342:
		_check(not main.menu.visible, "Esc menyunu bağlamalıdır (davam et)")
		_check(main.truck.controls_enabled, "davam etdikdən sonra idarə açılmalıdır")
		for f in failures:
			print("FAIL ", f)
		print("MENU TEST: uğursuzluq=%d" % failures.size())
		quit(0 if failures.is_empty() else 1)
	return false
