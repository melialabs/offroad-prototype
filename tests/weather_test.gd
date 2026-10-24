extends SceneTree
## Hava presetləri: mühit dəyərlərinin istiqaməti, gecə ilə birləşmə, yağış və yer nəmliyi.
## Görünüş (rəng, bulud, yağış) bu testlə yoxlanmır; bax: tests/weather_shots.gd.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var w: WeatherSystem = main.weather
	var env: Environment = main._env
	var sun: DirectionalLight3D = main._sun
	var sky: ShaderMaterial = main._sky_mat

	check(w != null, "weather system exists")
	check(WeatherSystem.IDS.size() == 4, "four presets")
	check(WeatherSystem.next_id("rain") == "sunny", "preset cycle wraps")

	main.set_weather("sunny", true)
	var sunny_sun := sun.light_energy
	var sunny_density := env.fog_density
	check(is_equal_approx(sunny_sun, main.DAY_SUN), "sunny keeps the original day sun")
	check(is_equal_approx(sunny_density, 0.00065), "sunny keeps the original fog")
	check(is_zero_approx(float(sky.get_shader_parameter("cloud_cover"))), "sunny sky has no extra cloud layer")
	check(is_zero_approx(w.rain_level), "no rain when sunny")

	main.set_weather("cloudy", true)
	check(sun.light_energy < sunny_sun * 0.5, "cloudy dims the direct sun")
	check(float(sky.get_shader_parameter("cloud_cover")) > 0.9, "cloudy covers the sky")
	check(env.adjustment_saturation < main.DAY_SATURATION, "cloudy desaturates")
	check(env.fog_density > sunny_density, "cloudy is hazier than sunny")
	check(sun.light_color.b > sun.light_color.r, "cloudy light is cold")
	check(sun.light_angular_distance > 1.0, "cloudy shadows are soft")

	main.set_weather("fog", true)
	check(env.fog_density > 0.01, "fog is dense")
	check(env.fog_depth_end <= 1500.0, "fog limits visibility")
	check(float(sky.get_shader_parameter("haze")) > 0.9, "fog hazes the sky")
	check(sun.light_energy < sunny_sun * 0.3, "fog dims the sun")
	check(w.wet > 0.3, "fog leaves the ground damp")

	main.set_weather("rain", true)
	check(w.rain_level > 0.99, "rain at full intensity")
	check(w.wet > 0.99, "rain wets the ground")
	check(float(sky.get_shader_parameter("cloud_dark")) > 0.5, "rain clouds are dark")
	check(sun.light_energy < sunny_sun * 0.25, "rain is the darkest preset")
	check(main._terrain.wet_level > 0.99, "terrain receives wetness")
	check(main.audio.rain > 0.99, "audio receives rain level")
	check(main.wind.weather_mul > 1.3, "rain strengthens the wind")
	await process_frame
	await process_frame
	check(w._rain.emitting, "rain particles emit")

	# gecə + yağış gündüz + yağışdan qaranlıqdır
	var rain_day_sun := sun.light_energy
	var rain_day_fog := env.fog_light_color.v
	main.set_night(true)
	check(sun.light_energy < rain_day_sun, "night rain is darker than day rain")
	check(env.fog_light_color.v < rain_day_fog, "night fog is darker")
	main.set_night(false)
	check(is_equal_approx(sun.light_energy, rain_day_sun), "returning to day restores rain lighting")

	# yumşaq keçid: preset dəyişəndə dərhal tam dəyişmir, sonra yaxınlaşır
	main.set_weather("sunny", true)
	main.set_weather("rain", false)
	check(w.rain_level < 0.2, "transition does not jump")
	for i in 600:
		w._step(0.1)
	check(w.rain_level > 0.95, "transition converges to rain")
	check(w.wet > 0.95, "ground becomes wet over time")
	var wet_before := w.wet
	main.set_weather("sunny", false)
	for i in 100:
		w._step(0.1)
	check(w.wet < wet_before, "ground dries slowly")
	check(w.wet > 0.7, "drying is slower than wetting")
	check(w.rain_level < 0.1, "rain stops when weather clears")

	# yer nəmliyi fizikaya təsir edir: yaş asfalt daha az tutuşludur
	main.set_weather("sunny", true)
	main.truck.apply_spec(1)
	main.truck.controls_enabled = false
	main._terrain.set_surface_conditions(0.0, 0.0, 0.0)
	var spawn: Dictionary = main._terrain.road_spawn()
	main.truck.global_position = spawn["pos"] + Vector3(0, 1.5, 0)
	for i in 90:
		await physics_frame
	var dry_grip: float = main.truck._w_grip[0]
	main._terrain.set_surface_conditions(1.0, 0.0, 0.0)
	for i in 3:
		await physics_frame
	var wet_grip: float = main.truck._w_grip[0]
	check(wet_grip < dry_grip, "wet asphalt grips less (%.2f -> %.2f)" % [dry_grip, wet_grip])
	check(wet_grip > dry_grip * 0.6, "wet asphalt is slippery, not ice")

	print("WEATHER: failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
