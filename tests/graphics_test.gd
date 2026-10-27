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
	GraphicsQuality.apply("MEDIUM", env, main._sun, vp, false, main.vegetation)
	check(env.ssao_enabled and not env.ssil_enabled and main._sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "MEDIUM: SSAO, 2 shadow splits (60 FPS forest budget)")
	for n in main.vegetation.get_children():
		if str(n.name).ends_with("_shadow"):
			check(is_equal_approx((n as MultiMeshInstance3D).visibility_range_end, 40.0), "MEDIUM tree shadows limited to 40 m")
			break
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
	var lc := MapLayout.LAKE_CENTER
	check(WheelEffects.classify(t, Vector3(lc.x, MapLayout.LAKE_LEVEL - 1.0, lc.y)) == WheelEffects.Surface.WATER, "below lake level is water")
	var sw: Vector3 = MudTerrain.SWAMPS[0]
	check(WheelEffects.classify(t, Vector3(sw.x, 0, sw.y)) == WheelEffects.Surface.WATER, "swamp pond is water")
	var fx: WheelEffects = main.wheel_fx
	fx._add_track(Vector3(0, 0, 0), Vector3(0, 0, 0.5), Vector3.UP, WheelEffects.Surface.DIRT)
	check(fx._tracks.visible_instance_count >= 1, "tyre track recorded")
	# su: Fresnel/dalğa shader-i, metal deyil
	var water_ok := false
	var lake := main._terrain.get_node_or_null("Lake") as MeshInstance3D
	if lake != null and lake.material_override is ShaderMaterial:
		water_ok = (lake.material_override as ShaderMaterial).shader.resource_path.ends_with("water.gdshader")
	check(water_ok, "lake uses the water shader")
	# maşın boyası dielektrik (metal teksturası olmayan glTF materialları metallic=1 gəlirdi)
	main.truck.apply_spec(6)
	var car: CarModel = main.truck._cars[6]["model"]
	var painted := 0
	for n in car.body.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m != null and m.resource_name.to_lower().contains("paint") and m.metallic_texture == null:
				check(m.metallic < 0.5 and m.clearcoat_enabled, "car paint is clear-coated dielectric: %s" % m.resource_name)
				painted += 1
	check(painted > 0, "paint materials found on UAZ 469")
	# maşın probe-u yalnız maşın qatına əks verir: əks halda yağışda torpaqda tünd kvadrat qalırdı
	fx.set_reflection_probe(true)
	fx._tag_vehicle()
	var pr: ReflectionProbe = fx._probe
	check(pr != null and (pr.reflection_mask & 1) == 0 and (pr.reflection_mask & WheelEffects.VEHICLE_LAYER) != 0, "vehicle probe does not reflect onto terrain")
	check((pr.cull_mask & WheelEffects.VEHICLE_LAYER) == 0, "vehicle probe does not capture the vehicle itself")
	var tagged := true
	for n in main.truck.find_children("*", "GeometryInstance3D", true, false):
		tagged = tagged and (n as GeometryInstance3D).layers == WheelEffects.VEHICLE_LAYER
	check(tagged, "all vehicle meshes on the vehicle layer")
	check(main.hud.truck == main.truck and main.world_map.truck == main.truck, "HUD and GPS still bound")
	print("GRAPHICS TEST failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
	return false
