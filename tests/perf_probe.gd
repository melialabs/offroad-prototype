extends SceneTree
## Performans ölçməsi (pəncərəli rejim, vsync söndürülür): orta kadr vaxtı, 99-cu faiz və FPS.
## godot --path . -s res://tests/perf_probe.gd -- [kadr sayı] [road|forest]
## forest: maşın ən sıx ağac klasterinin içinə qoyulur (render yükü üçün ən pis hal).
## Diaqnostika bayraqları (3-cü arqumentdən): noshadow, hide=grass_b,fern (növ prefiksləri)
## Başsız (--headless) rejimdə mənasızdır, çünki render yoxdur.

const WARMUP := 90
var main: Node
var frames := 0
var total_frames := 600
var samples: Array[float] = []
var last_us := 0
var preset := "road"
var load_ms := 0
var dc_sum := 0.0
var prim_sum := 0.0
var info_n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		total_frames = int(args[0])
	if args.size() > 1:
		preset = args[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _apply_flags() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(2, args.size()):
		var a: String = args[i]
		if a == "noshadow":
			for n in main.find_children("*", "MultiMeshInstance3D", true, false):
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif a.begins_with("hide="):
			for n in main.find_children("*", "MultiMeshInstance3D", true, false):
				for p in a.substr(5).split(","):
					if (n.name as String).begins_with(p + "_"):
						(n as Node3D).visible = false
		elif a == "novegetation":
			main.get_node("Vegetation").visible = false


func _dense_spot() -> Vector3:
	var veg: Vegetation = main.get_node("Vegetation")
	var trees: Array = veg._big_trees
	var best := Vector3.ZERO
	var best_n := -1
	for i in trees.size():
		var a: Vector3 = trees[i][0]
		var n := 0
		for j in trees.size():
			var b: Vector3 = trees[j][0]
			if Vector2(a.x - b.x, a.z - b.z).length() < 18.0:
				n += 1
		if n > best_n:
			best_n = n
			best = a
	print("PERF sıx klaster: ağac=%d mərkəz=%s" % [best_n, best])
	return best


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if frames == 0:
		load_ms = Time.get_ticks_msec()
	if frames == 10:
		_apply_flags()
	if frames == 20 and preset == "forest":
		var spot := _dense_spot()
		main.truck.linear_velocity = Vector3.ZERO
		main.truck.global_position = spot + Vector3(-6.0, 2.0, 0.0)
		main.truck.rotation = Vector3(0, PI * 0.5, 0)
	if frames > WARMUP:
		samples.append((now - last_us) / 1000.0)
	if frames > WARMUP:
		dc_sum += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prim_sum += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		info_n += 1
	last_us = now
	frames += 1
	if frames >= WARMUP + total_frames:
		samples.sort()
		var sum := 0.0
		for s in samples:
			sum += s
		var avg := sum / samples.size()
		var p99: float = samples[int(samples.size() * 0.99)]
		var win := DisplayServer.window_get_size()
		print("PERF [%s] pəncərə=%dx%d kadr=%d orta=%.2f ms (%.0f FPS) p99=%.2f ms (%.0f FPS) ən pis=%.2f ms | draw call=%.0f üçbucaq=%.0f | ilk kadra qədər=%d ms" % [
			preset, win.x, win.y, samples.size(), avg, 1000.0 / avg, p99, 1000.0 / p99, samples[samples.size() - 1],
			dc_sum / maxi(info_n, 1), prim_sum / maxi(info_n, 1), load_ms])
		quit(0)
	return false
