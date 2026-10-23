extends SceneTree
## Graphics pass: quality profiles apply real renderer settings, night keeps fog/lamps consistent,
## surface classification and tyre tracks work, and the HUD/vehicle systems are untouched.
## godot --headless --path . -s res://tests/graphics_test.gd
var main: Node
var frames := 0
var failures: Array[String] = []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("FAIL ", msg)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames != 5:
		return false
	var env: Environment = main._env
	var vp := main.get_viewport()
	var before := GraphicsQuality.saved_level()
	check(env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_depth_begin >= 60.0, "near scene not fogged (depth fog starts away from camera)")
	check(env.tonemap_mode == Environment.TONE_MAPPER_ACES and env.adjustment_saturation < 1.15, "natural tonemapping and saturation")
	GraphicsQuality.apply("LOW", env, main._sun, vp)
	check(not env.ssao_enabled and not env.volumetric_fog_enabled and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "LOW is light")
	GraphicsQuality.apply("MEDIUM", env, main._sun, vp)
	check(env.ssao_enabled and not env.ssil_enabled and main._sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "MEDIUM: SSAO and 4 shadow splits")
	GraphicsQuality.apply("HIGH", env, main._sun, vp)
	check(env.volumetric_fog_enabled and vp.use_taa and not env.sdfgi_enabled, "HIGH: volumetric fog and TAA")
	GraphicsQuality.apply("ULTRA", env, main._sun, vp)
	check(env.sdfgi_enabled and env.ssil_enabled and env.ssr_enabled and main._sun.directional_shadow_max_distance >= 200.0, "ULTRA: SDFGI, SSIL, SSR, long shadows")
	GraphicsQuality.apply(before, env, main._sun, vp)
	main.set_night(true)
	check(env.fog_depth_end < 2000.0, "night fog closes in")
	main.set_night(false)
	check(env.fog_depth_end > 3000.0, "day fog restored")
	var t: MudTerrain = main._terrain
	var sp: Dictionary = t.road_spawn()
	check(WheelEffects.classify(t, sp["pos"]) == WheelEffects.Surface.ASPHALT, "asphalt classified on the road")
	check(WheelEffects.classify(t, Vector3(0, -3.0, 0)) == WheelEffects.Surface.WATER, "below lake level is water")
	var sw: Vector3 = MudTerrain.SWAMPS[0]
	check(WheelEffects.classify(t, Vector3(sw.x, 0, sw.y)) == WheelEffects.Surface.WATER, "swamp pond is water")
	var fx: WheelEffects = main.wheel_fx
	fx._add_track(Vector3(0, 0, 0), Vector3(0, 0, 0.5), Vector3.UP, WheelEffects.Surface.DIRT)
	check(fx._tracks.visible_instance_count >= 1, "tyre track recorded")
	check(main.hud.truck == main.truck and main.world_map.truck == main.truck, "HUD and GPS still bound")
	print("GRAPHICS TEST failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
	return false
