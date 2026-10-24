extends SceneTree
## Xəritənin yuxarıdan ortoqrafik kadrları (4 hissə, hər biri 1024 m): yol, çay, obyekt yoxlaması.
## godot --path . --resolution 1280x1280 -s res://tests/topdown_shots.gd -- <qovluq>
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main.menu.start_requested.emit()
	main.hud.visible = false
	main.world_map.visible = false
	main.truck.freeze = true
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1024.0
	cam.far = 3000.0
	main.add_child(cam)
	main.cam.current = false
	cam.current = true
	var k := 0
	var views: Array = [Vector2(-512, -512), Vector2(512, -512), Vector2(-512, 512), Vector2(512, 512)]
	# isteğe bağlı: -- <qovluq> <ölçü m> x z x z ... (yaxın plan)
	var a := OS.get_cmdline_user_args()
	if a.size() > 3:
		cam.size = float(a[1])
		views.clear()
		for idx in range(2, a.size() - 1, 2):
			views.append(Vector2(float(a[idx]), float(a[idx + 1])))
	for c in views:
		cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(c.x, 900, c.y))
		main.truck.global_position = Vector3(c.x, 950, c.y)
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png("%s/top_%d.png" % [out, k])
		k += 1
	quit(0)
