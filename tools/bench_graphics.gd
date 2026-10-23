extends SceneTree
## Qrafika benchmark: 3 sabit kamera mövqeyində FPS, CPU/GPU kadr vaxtı, draw call və ekran şəkli.
## godot --path . --resolution 1600x900 -s res://tools/bench_graphics.gd -- TAG [LOW|MEDIUM|HIGH|ULTRA]
## Nəticə: /tmp/bench_TAG_*.png və konsolda BENCH sətirləri.
## 3-cü arqument (istəyə görə) — ölçmə üçün ayrı-ayrı söndürmələr, vergüllə:
## nossao, splits2, sdist=N, noshadow, vegshadow=N, nofade, noglow, novol, noaa, lod=N, only=VIEW
const VIEWS := [
	["road", Vector3(-690, 0, -650), Vector3(-760, 0, -700)],
	["forest", Vector3(-740, 0, 120), Vector3(-756, 0, 84)],
	["quarry", Vector3(470, 0, -440), Vector3(545, 0, -500)],
]
const WARM := 90
const MEASURE := 150
var main: Node
var cam: Camera3D
var tag := "run"
var level := ""
var overrides: PackedStringArray = []
var frames := 0
var view := 0
var t0 := 0
var gpu := 0.0
var cpu := 0.0
var draws := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: tag = a[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if a.size() > 1:
		level = a[1]
	if a.size() > 2:
		overrides = a[2].split(",")
	cam = Camera3D.new()
	main.add_child(cam)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		# yalnız tətbiq et, oyunçunun ayarına yazma
		if level != "" and ClassDB.class_exists("Node") and main.get("_env") != null and ResourceLoader.exists("res://graphics_quality.gd"):
			load("res://graphics_quality.gd").apply(level, main._env, main._sun, root.get_viewport(), false)
		_apply_overrides()
		main.hud.visible = false
		main.world_map.visible = false
		main.truck.freeze = true
		cam.current = true
	if frames < 3 or view >= VIEWS.size():
		return false
	var v: Array = VIEWS[view]
	var local := frames - 3 - view * (WARM + MEASURE + 5)
	if local == 0:
		var t: MudTerrain = main._terrain
		var p: Vector3 = v[1]; p.y = t.height_at(p) + 6.0
		var q: Vector3 = v[2]; q.y = t.height_at(q) + 2.0
		cam.look_at_from_position(p, q, Vector3.UP)
		var tp := p.lerp(q, 0.35); tp.y = t.height_at(tp) + 1.5
		main.truck.global_position = tp
	elif local == WARM:
		t0 = Time.get_ticks_usec(); gpu = 0.0; cpu = 0.0; draws = 0
	elif local > WARM and local <= WARM + MEASURE:
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		if local == WARM + MEASURE:
			var ms := (Time.get_ticks_usec() - t0) / 1000.0 / MEASURE
			print("BENCH %s %s fps=%.1f frame=%.2fms gpu=%.2fms cpu=%.2fms draws=%d" % [tag, v[0], 1000.0 / ms, ms, gpu / MEASURE, cpu / MEASURE, draws / MEASURE])
			var img := root.get_texture().get_image(); img.save_png("/tmp/bench_%s_%s.png" % [tag, v[0]])
			view += 1
			if view >= VIEWS.size():
				quit(0)
	return false


func _apply_overrides() -> void:
	var env: Environment = main._env
	var sun: DirectionalLight3D = main._sun
	for o in overrides:
		var kv := o.split("=")
		match kv[0]:
			"nossao": env.ssao_enabled = false
			"ssaolow": RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50.0, 300.0)
			"splits2": sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			"sdist": sun.directional_shadow_max_distance = float(kv[1])
			"noshadow": sun.shadow_enabled = false
			"noglow": env.glow_enabled = false
			"atlas": RenderingServer.directional_shadow_atlas_set_size(int(kv[1]), true)
			"novol": env.volumetric_fog_enabled = false
			"noaa":
				root.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				root.get_viewport().use_taa = false
			"lod": root.get_viewport().mesh_lod_threshold = float(kv[1])
			"vegshadow", "nofade":
				for n in main.vegetation.get_children():
					if n is MultiMeshInstance3D:
						var m := n as MultiMeshInstance3D
						if kv[0] == "nofade":
							m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
						elif str(m.name).ends_with("_shadow"):
							m.visibility_range_end = float(kv[1])
