extends SceneTree
## Yeni maşınların gecə fənərləri (öndən) və işlənmiş qaz tüstüsü (arxadan) kadrları.
## godot --path . --resolution 1280x720 -s res://tests/vehicle_shots.gd -- <qovluq> [indekslər...]

var out_dir := "user://vehicle_shots"
var order: Array[int] = [7, 8, 9, 10]


func _initialize() -> void:
	run.call_deferred()


func settle(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var beam := 1
	if args.size() > 1:
		order.clear()
		for a in args.slice(1):
			if a == "high":
				beam = 2
			else:
				order.append(int(a))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await settle(20)
	main.menu.start_requested.emit()
	var cam := Camera3D.new()
	cam.fov = 45.0
	main.add_child(cam)
	main.set_night(true)
	for idx in order:
		if not OffroadTruck.is_available(idx):
			continue
		main.select_vehicle(idx)
		var t: OffroadTruck = main.truck
		t.controls_enabled = false
		await settle(60)
		t.engine_state = OffroadTruck.EngineState.RUNNING
		t.lights.set_headlights(beam)
		main.cam.current = false
		cam.current = true
		main.hud.visible = false
		main.world_map.visible = false
		var b := t.global_transform
		cam.global_position = b.origin + b.basis.z * 6.5 + b.basis.x * 2.5 + Vector3(0, 1.4, 0)
		cam.look_at(b.origin + Vector3(0, 0.3, 0), Vector3.UP)
		await settle(40)
		root.get_texture().get_image().save_png("%s/front_%d.png" % [out_dir, idx])
		cam.global_position = b.origin - b.basis.z * 5.5 + b.basis.x * 2.0 + Vector3(0, 0.9, 0)
		cam.look_at(b.origin - b.basis.z * 1.5 + Vector3(0, -0.2, 0), Vector3.UP)
		await settle(90)
		root.get_texture().get_image().save_png("%s/rear_%d.png" % [out_dir, idx])
		print("SHOT ", idx)
	quit(0)
