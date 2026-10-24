extends SceneTree
## Yeni maşınlar (G63, Brabus G700, Hilux, Crossroad Pickup): model yüklənir, təkərlər yerə oturur,
## ölçülər ağlabatandır, maşın sürülür. godot --headless --path . -s res://tests/new_vehicles_test.gd

const IDS := [7, 8, 9, 10]
var ids: Array = []
var main: Node
var frames := 0
var slot := 0
var failures: Array[String] = []
var pos0 := Vector3.ZERO


func _initialize() -> void:
	# Brabus modeli (CC BY-NC-ND) repoya qoyulmaya bilər: fayl yoxdursa həmin maşın yoxlanmır
	var present: Array = []
	for i in IDS:
		if ResourceLoader.exists(str(OffroadTruck.SPECS[i]["car"])):
			present.append(i)
		else:
			print("NEW model faylı yoxdur, keçilir: ", OffroadTruck.SPECS[i]["name"])
	ids = present
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _physics_process(_delta: float) -> bool:
	frames += 1
	var t: OffroadTruck = main.truck
	var idx: int = ids[slot]
	var f := frames % 400
	if f == 1:
		main.select_vehicle(idx)
		Input.action_release(&"ui_up")
	if f == 150:
		_check(t.spec_idx == idx, "seçim alınmadı: %d" % idx)
		var car: Dictionary = t._cars.get(idx, {})
		_check(not car.is_empty(), "model yüklənməyib: %d" % idx)
		if not car.is_empty():
			var cm: CarModel = car["model"]
			_check(cm.body.visible, "gövdə görünməlidir: %d" % idx)
			_check(cm.length > 4.3 and cm.length < 5.6, "uzunluq qəribədir (%d): %.2f" % [idx, cm.length])
			_check(absf(cm.wheel_radius - float(t.spec["radius"])) < 0.05, "təkər radiusu spec ilə uyğun deyil (%d): %.3f" % [idx, cm.wheel_radius])
			for k in 4:
				var dy: float = absf(t.wheels[k].position.y - cm.wheel_centers[k].y)
				var dx: float = absf(t.wheels[k].position.x - cm.wheel_centers[k].x)
				_check(dy < 0.05 and dx < 0.01, "təkər modeldəki yerdə deyil (%d/%d): dy=%.3f dx=%.3f" % [idx, k, dy, dx])
			# ön təkərlər +Z-dədir (irəli)
			_check(cm.wheel_centers[2].z > cm.wheel_centers[0].z, "ön/arxa təkər sırası tərsdir: %d" % idx)
		var contact := 0
		for w in t.wheels:
			if w.is_in_contact():
				contact += 1
		_check(contact == 4, "4 təkər yerə dəyməlidir (%d): %d" % [idx, contact])
		Input.action_press(&"ui_up")
		pos0 = t.global_position
		print("NEW %s radius=%.3f kütlə=%.0f" % [t.spec["name"], t.wheels[0].wheel_radius, t.mass])
	if f == 330:
		var moved := Vector2(t.global_position.x - pos0.x, t.global_position.z - pos0.z).length()
		_check(moved > 8.0, "maşın getməlidir (%d): %.1f m" % [idx, moved])
		_check(absf(t.global_basis.y.dot(Vector3.UP)) > 0.8, "maşın aşmamalıdır: %d" % idx)
		print("NEW %s getdi %.1f m, %.0f km/saat" % [t.spec["name"], moved, t.linear_velocity.length() * 3.6])
		slot += 1
		if slot >= ids.size():
			for m in failures:
				print("FAIL ", m)
			print("NEW VEHICLES TEST: uğursuzluq=%d" % failures.size())
			quit(0 if failures.is_empty() else 1)
	return false
