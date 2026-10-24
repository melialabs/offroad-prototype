extends SceneTree
## Körpülərin (yol çayı keçən yerlər) yoxlama kadrları və hündürlük hesabatı.
## godot --path . --resolution 1280x720 -s res://tests/bridge_shots.gd -- <qovluq>

func _initialize() -> void:
	run.call_deferred()


func settle(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://bridge_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await settle(20)
	main.menu.start_requested.emit()
	main.hud.visible = false
	main.world_map.visible = false
	var terrain: MudTerrain = main._terrain
	var road := terrain._road
	# yolun çayı keçdiyi seqmentlər
	var crossings: Array = []
	var inside := false
	for i in road.size() - 1:
		var mid := (road[i] + road[i + 1]) * 0.5
		var rv: float = terrain._near_route(mid, terrain._river, terrain._river_len, terrain._river_bins)[0]
		var near := rv < MapLayout.RIVER_HALF + 10.0 and terrain._road_gap[i] == 0
		if near and not inside:
			crossings.append(i)
		inside = near
	print("BRIDGE crossings=", crossings.size(), " road points=", road.size())
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2000.0
	main.add_child(cam)
	main.cam.current = false
	cam.current = true
	var n := 0
	for i in crossings:
		var a: Vector2 = road[i]
		var b: Vector2 = road[mini(i + 6, road.size() - 1)]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var h := terrain._road_h[i]
		var wl := terrain.water_level_at(Vector3(mid.x, 0, mid.y))
		print("BRIDGE %d at (%.0f, %.0f) road_h=%.2f water=%.2f ground=%.2f gap=%d" % [n, mid.x, mid.y, h, wl, terrain.height_at(Vector3(mid.x, 0, mid.y)), terrain._road_gap[i]])
		for view in [[side * 35.0, 10.0], [-dir * 45.0 + side * 8.0, 6.0]]:
			var off: Vector2 = view[0]
			cam.global_position = Vector3(mid.x + off.x, h + float(view[1]), mid.y + off.y)
			cam.look_at(Vector3(mid.x, h - 2.0, mid.y), Vector3.UP)
			main.truck.global_position = cam.global_position + Vector3(0, 50, 0)
			main.truck.freeze = true
			await settle(25)
			root.get_texture().get_image().save_png("%s/bridge_%d_%d.png" % [out_dir, n, int(view[1])])
		n += 1
		if n >= 6:
			break
	quit(0)
