extends SceneTree
## Kamera testi: V düyməsi rejimləri dövrə ilə dəyişir, yaxın kamera maşından 4-8 m aralıdadır və yerin üstündədir.
## godot --headless --path . -s res://tests/camera_test.gd

var main: Node
var frames := 0
var failures: Array[String] = []
var dist_min := INF
var dist_max := -INF
var min_clear := INF


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _press_v() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	ev.keycode = KEY_V
	ev.pressed = true
	Input.parse_input_event(ev)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames > 90 and frames <= 300 and main.cam.mode == ChaseCamera.Mode.CLOSE:
		var d: float = main.cam.global_position.distance_to(main.truck.global_position)
		dist_min = minf(dist_min, d)
		dist_max = maxf(dist_max, d)
		min_clear = minf(min_clear, main.cam.global_position.y - main._terrain.height_at(main.cam.global_position))
	if frames == 310:
		_check(main.cam.mode == ChaseCamera.Mode.CLOSE, "başlanğıc rejim yaxın olmalıdır")
		_press_v()
	if frames == 314:
		_check(main.cam.mode == ChaseCamera.Mode.FAR, "V (1): uzaq kamera olmalı idi, rejim=%d" % main.cam.mode)
		_press_v()
	if frames == 318:
		_check(main.cam.mode == ChaseCamera.Mode.HOOD, "V (2): kapot olmalı idi, rejim=%d" % main.cam.mode)
		_press_v()
	if frames == 322:
		_check(main.cam.mode == ChaseCamera.Mode.CLOSE, "V (3): yenə yaxın olmalı idi, rejim=%d" % main.cam.mode)
		_check(dist_min >= 3.5 and dist_max <= 8.5, "yaxın kamera məsafəsi: min %.1f max %.1f m" % [dist_min, dist_max])
		_check(min_clear >= 0.5, "kamera yerə girir: min boşluq %.2f m" % min_clear)
		for f in failures:
			print("FAIL ", f)
		print("CAMERA TEST: məsafə %.1f-%.1f m, yerdən min boşluq %.2f m, uğursuzluq=%d" % [dist_min, dist_max, min_clear, failures.size()])
		quit(0 if failures.is_empty() else 1)
	return false
