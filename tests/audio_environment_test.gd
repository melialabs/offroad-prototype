extends SceneTree
## Real recording mix, slope direction, mud wheelspin and summit gust regressions.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 150:
		await physics_frame
	var a: GameAudio = main.audio
	var t: OffroadTruck = main.truck
	a.set_process(false)
	t.set_physics_process(false)
	var contacts := 0
	for w in t.wheels:
		contacts += 1 if w.is_in_contact() else 0
	check(contacts == 4, "load test has four actual grounded wheels")
	Input.action_press(&"ui_up")
	t.engine_state = OffroadTruck.EngineState.RUNNING
	t.controls_enabled = true
	t.throttle = 1.0
	t.gear = 1
	t.mud_level = 0.0
	t.wheel_slip = 0.0
	t.rotation.x = -0.4
	a._update_engine(10.0)
	check(a.last_engine_load > 0.6, "uphill throttle adds engine strain")
	t.rotation.x = 0.4
	a._update_engine(10.0)
	check(a.last_engine_load < 0.01, "downhill does not add climbing strain")
	t.gear = -1
	a._update_engine(10.0)
	check(a.last_engine_load > 0.6, "reversing uphill also loads the engine")
	t.rotation = Vector3.ZERO
	t.gear = 1
	t.mud_level = 0.8
	t.wheel_slip = 6.0
	a._update_engine(10.0)
	check(a.last_engine_load > 0.7, "bogged spinning wheels load the engine")
	Input.action_release(&"ui_up")
	t.global_position = Vector3(-365, 0, -425)
	t.linear_velocity = Vector3.ZERO
	a._speed = 0.0
	t.wheel_slip = 0.0
	a._update_road(1.0)
	check(a._mud.volume_db < -70.0, "idling in mud is quiet without wheel motion")
	t.wheel_slip = 8.0
	a._update_road(1.0)
	check(a._mud.volume_db > -30.0, "wheelspin churn is audible even without forward travel")
	t.global_position = Vector3(0, 10, 0)
	a._night_mix = 0.0
	a._update_ambient(0.1)
	check(a._bird.volume_db > -30.0 and a._bed.volume_db > -30.0, "daytime forest and birds are audible")
	a._night_mix = 1.0
	a._hoot_t = 0.0
	a._update_ambient(0.1)
	check(a._animal.playing, "night forest schedules a recorded positional owl")
	check(a._bird.volume_db < -70.0 and a._bed.volume_db < -70.0, "dawn recordings do not persist at night")
	check(a._crickets.volume_db > -30.0, "night crickets replace the daytime chorus")
	a._night_mix = 0.0
	a._update_ambient(0.1)
	check(not a._animal.playing, "owl stops when returning to daytime")
	t.global_position = Vector3(-150, 10, -120)
	a._update_ambient(0.1)
	var near_water := a._brook.volume_db
	t.global_position = Vector3(600, 10, 600)
	a._update_ambient(0.1)
	check(a._brook.volume_db < near_water - 30.0, "water recording fades with distance from the lake")
	# Vehicle speed must not introduce wind; the natural forest bed stays intact.
	t.global_position = Vector3(0,10,0)
	t.linear_velocity = Vector3.ZERO
	a._update_ambient(.1)
	var forest_wind := a._wind_trees.volume_db
	t.linear_velocity = Vector3(0,0,40)
	a._update_road(5.0)
	a._update_ambient(.1)
	check(a._wind.volume_db < -70.0, "fast driving adds no wind rush")
	check(is_equal_approx(a._wind_trees.volume_db,forest_wind), "natural forest wind is independent of vehicle speed")
	t.linear_velocity = Vector3.ZERO
	a._speed = 0.0
	t.global_position = Vector3(492, 180, 382)
	a._update_ambient(0.1)
	check(a._bird.volume_db < -70.0, "summit does not sound like the forest floor")
	a._update_road(0.1)
	var first_wind := a._wind.volume_db
	t.linear_velocity = Vector3(0,0,40)
	a._update_road(5.0)
	check(is_equal_approx(a._wind.volume_db,first_wind) and is_equal_approx(a._wind.pitch_scale,1.0), "mountain wind gain and pitch ignore driving speed")
	t.linear_velocity = Vector3.ZERO
	# Ambient gusts now read the shared wind clock.
	main.wind.advance(7.0)
	a._update_ambient(7.0)
	a._update_road(0.1)
	check(a._wind.volume_db > -40.0 and absf(a._wind.volume_db - first_wind) > 0.1, "summit wind gusts while parked")
	t.global_position = Vector3(0, 500, 0)
	t.rotation.x = -0.4
	Input.action_press(&"ui_up")
	for i in 3:
		await physics_frame
	a._update_engine(10.0)
	check(a.last_engine_load < 0.01, "airborne wheels do not produce climbing strain")
	Input.action_release(&"ui_up")
	a.set_enabled(false)
	check(AudioServer.is_bus_mute(0), "sound setting mutes environmental and vehicle audio")
	a.set_enabled(true)
	check(not AudioServer.is_bus_mute(0), "sound setting restores audio")
	print("AUDIO ENVIRONMENT TEST: failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
