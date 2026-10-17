extends SceneTree
## Başsız test: seçilmiş texnika qaz verəndə irəli gedirmi.
## İstifadə: godot --headless -s res://tests/drive_test.gd -- <texnika indeksi 0..2>

var main: Node
var frames := 0
var start := Vector3.ZERO
var max_kmh := 0.0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		var args := OS.get_cmdline_user_args()
		if args.size() > 0:
			main.truck.apply_spec(int(args[0]))
	max_kmh = maxf(max_kmh, main.truck.linear_velocity.length() * 3.6)
	if frames == 200:
		var d: OffroadTruck = main.truck
		print("DEBUG fwd_speed=%.2f vel=%s basis_z=%s gear=%d" % [
			d.linear_velocity.dot(-d.global_transform.basis.z), d.linear_velocity,
			d.global_transform.basis.z, d.gear])
		print("DEBUG engine_force=%.0f brake=%.0f steering=%.2f traction=%s contact=%s skid=%s" % [
			d.engine_force, d.brake, d.steering,
			d.wheels.map(func(w): return w.use_as_traction),
			d.wheels.map(func(w): return w.is_in_contact()),
			d.wheels.map(func(w): return snappedf(w.get_skidinfo(), 0.01))])
	if frames == 120:
		start = main.truck.global_position
	if frames == 360:
		var t: OffroadTruck = main.truck
		var end := t.global_position
		var moved := Vector2(end.x - start.x, end.z - start.z).length()
		print("TEST %s: məsafə=%.1f m, hündürlük=%.2f, maks=%.0f km/saat, dişli=%d, dövr=%d, yanacaq=%.2f" % [
			t.spec["name"], moved, end.y, max_kmh, t.gear, int(t.rpm), t.fuel])
		var ahead := (end - start).dot(t.global_transform.basis.z)
		print("İrəli yerdəyişmə=%.1f m" % ahead)
		quit(0 if ahead > 15.0 and end.y > -5.0 and t.fuel < float(t.spec["fuel"]) else 1)
	return false
