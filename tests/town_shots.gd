extends SceneTree
## Şəhər binaları, köhnə maşınlar və yol kənarı binalar üçün kadrlar.
## godot --path . --resolution 1280x720 -s res://tests/town_shots.gd -- <qovluq>
func _initialize() -> void:
	run.call_deferred()
func settle(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await settle(20)
	print("TOWN load_ms=", Time.get_ticks_msec() - t0, " buildings=", main.features.buildings, " extras=", WorldProps.extras.size())
	main.menu.start_requested.emit()
	main.hud.visible = false
	main.world_map.visible = false
	var terrain: MudTerrain = main._terrain
	var cam := Camera3D.new()
	cam.fov = 65.0
	cam.far = 2500.0
	main.add_child(cam)
	main.cam.current = false
	cam.current = true
	var shots: Array = []
	# şəhər mərkəzi (yuxarıdan və yolda)
	var tc := MapLayout.TOWN
	shots.append(["town_aerial", Vector3(tc.x - 90, terrain.height_at(Vector3(tc.x, 0, tc.y)) + 70, tc.y + 90), Vector3(tc.x, terrain.height_at(Vector3(tc.x, 0, tc.y)) + 5, tc.y)])
	shots.append(["town_street", Vector3(tc.x - 40, terrain.height_at(Vector3(tc.x - 40, 0, tc.y)) + 8, tc.y + 40), Vector3(tc.x + 20, terrain.height_at(Vector3(tc.x + 20, 0, tc.y)) + 4, tc.y - 10)])
	var n := 0
	var seen := {}
	for e in WorldProps.extras:
		if seen.has(e["kind"]):
			continue
		seen[e["kind"]] = true
		var p: Vector2 = e["p"]
		var g := terrain.height_at(Vector3(p.x, 0, p.y))
		var def: Dictionary = WorldProps.TOWN_PROPS[e["kind"]]
		var dist: float = 7.0 if def["car"] else 26.0
		shots.append(["%s_%d" % [e["kind"], n], Vector3(p.x + dist * 0.8, g + (2.5 if def["car"] else 9.0), p.y + dist * 0.8), Vector3(p.x, g + (0.8 if def["car"] else 3.0), p.y)])
		n += 1
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		main.truck.global_position = s[1] + Vector3(0, -300, 0)
		await settle(25)
		root.get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
		print("SHOT ", s[0])
	quit(0)
