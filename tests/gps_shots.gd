extends SceneTree
## GPS kadrları: mini-xəritə (sürüş zamanı) və böyük xəritə (M).
## godot --path . --resolution 1600x900 -s res://tests/gps_shots.gd -- <qovluq>
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
	var t0 := Time.get_ticks_msec()
	await settle(90)
	print("GPS bake ready=", main.world_map.map_texture != null, " ms~", Time.get_ticks_msec() - t0)
	root.get_texture().get_image().save_png(out + "/gps_mini.png")
	main.world_map.opened = true
	await settle(10)
	root.get_texture().get_image().save_png(out + "/gps_full.png")
	quit(0)
