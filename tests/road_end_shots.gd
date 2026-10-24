extends SceneTree
## Yol uclarının kadrları: yol bitən yerdən sonra relyefdə yol izi qalmamalıdır.
## godot --path . --resolution 1280x720 -s res://tests/road_end_shots.gd -- <qovluq>
func _initialize() -> void:
	run.call_deferred()
func settle(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await settle(20)
	main.menu.start_requested.emit()
	main.hud.visible = false
	main.world_map.visible = false
	main.truck.freeze = true
	var t: MudTerrain = main._terrain
	var cam := Camera3D.new()
	cam.far = 2000.0
	main.add_child(cam)
	main.cam.current = false
	cam.current = true
	var ends: Array = []
	for i in t._road.size():
		var last := i == t._road.size() - 1 or t._road_gap[i] == 1
		var first := i == 0 or t._road_gap[i - 1] == 1
		if last and i > 0:
			ends.append([t._road[i], (t._road[i] - t._road[i - 1]).normalized(), t._road_h[i]])
		elif first and i < t._road.size() - 1:
			ends.append([t._road[i], (t._road[i] - t._road[i + 1]).normalized(), t._road_h[i]])
	print("ROAD ENDS ", ends.size())
	var k := 0
	for e in ends:
		var p: Vector2 = e[0]
		var d: Vector2 = e[1]
		var back := p - d * 22.0
		cam.global_position = Vector3(back.x, float(e[2]) + 7.0, back.y)
		cam.look_at(Vector3(p.x + d.x * 40.0, float(e[2]), p.y + d.y * 40.0), Vector3.UP)
		main.truck.global_position = cam.global_position + Vector3(0, 60, 0)
		await settle(30)
		root.get_texture().get_image().save_png("%s/end_%d.png" % [out, k])
		k += 1
	quit(0)
