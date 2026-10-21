extends SceneTree
## Siçanla kamera: yaw/pitch kameranı fırladır, boşda arxaya qayıdır, V rejimi sıfırlayır.
## godot --headless --path . -s res://tests/mouse_camera_test.gd

var main: Node
var frames := 0
var failures: Array[String] = []
var base_pos := Vector3.ZERO
var turned_pos := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _physics_process(_delta: float) -> bool:
	frames += 1
	var cam: ChaseCamera = main.cam
	var t: OffroadTruck = main.truck
	if frames == 120:
		base_pos = cam.global_position
		# siçan sağa 300 piksel: kamera maşının solundan baxır (kamera sağa döndü)
		cam.mouse_look(Vector2(300, 0))
	if frames == 150:
		turned_pos = cam.global_position
		var side := (turned_pos - base_pos)
		var right := -t.global_transform.basis.x
		_check(side.length() > 1.5, "kamera siçanla çevrilməyib: %.2f m" % side.length())
		_check(absf(cam.mouse_yaw) > 0.5, "mouse_yaw dəyişməlidir: %.2f" % cam.mouse_yaw)
		# kamera maşını hələ də görür (maşından 3..8 m aralı)
		var d := cam.global_position.distance_to(t.global_position)
		_check(d > 3.0 and d < 8.0, "kamera maşından uzaqdır: %.1f" % d)
		cam.mouse_look(Vector2(0, -400))  # yuxarı baxmaq = kamera aşağı enir
		_check(cam.mouse_pitch >= ChaseCamera.PITCH_MIN - 0.001, "pitch aşağı həddi aşılıb")
		cam.mouse_look(Vector2(0, 5000))
		_check(cam.mouse_pitch <= ChaseCamera.PITCH_MAX + 0.001, "pitch yuxarı həddi aşılıb: %.2f" % cam.mouse_pitch)
	if frames == 400:
		_check(absf(cam.mouse_yaw) < 0.08 and absf(cam.mouse_pitch) < 0.08, "kamera arxaya qayıtmalıdır: yaw=%.2f pitch=%.2f" % [cam.mouse_yaw, cam.mouse_pitch])
		cam.mouse_look(Vector2(200, 100))
		cam.set_mode(ChaseCamera.Mode.FAR)
		_check(cam.mouse_yaw == 0.0 and cam.mouse_pitch == 0.0, "rejim dəyişəndə siçan bucağı sıfırlanmalıdır")
		cam.set_mode(ChaseCamera.Mode.HOOD)
		cam.mouse_look(Vector2(-250, 0))
	if frames == 430:
		var fwd := -cam.global_transform.basis.z
		var truck_fwd := t.global_transform.basis.z
		_check(fwd.dot(truck_fwd) < 0.98, "kapot rejimində baş çevrilməlidir: %.3f" % fwd.dot(truck_fwd))
		for f in failures:
			print("FAIL ", f)
		print("MOUSE CAMERA TEST: uğursuzluq=%d" % failures.size())
		quit(0 if failures.is_empty() else 1)
	return false
