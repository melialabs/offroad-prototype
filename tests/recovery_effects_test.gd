extends SceneTree
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ",label)
func _initialize() -> void:
	run.call_deferred()
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await physics_frame
	main.menu.start_requested.emit()
	var t: OffroadTruck = main.truck
	var smoke: ExhaustSmoke = main.exhaust
	var audio: GameAudio = main.audio
	check(main.winch != null and main.vegetation._winch_cells.size()>0,"standing forest trunks indexed for winch")
	var shader_materials := 0
	for material in VegetationAssets.cached_materials():
		if material is ShaderMaterial:
			shader_materials += 1
	check(shader_materials>10,"trees and understory use animated materials")
	main.wind.set_process(false)
	main.wind.night = false
	main.wind.advance(30)
	var day_wind: float = main.wind.strength
	main.set_night(true)
	main.wind.advance(30)
	check(main.wind.strength>day_wind,"evening strengthens shared wind")
	check(audio._wind_trees.stream.get_length()>30,"real stereo tree wind recording loads")
	audio._night_mix = 1.0
	audio._update_ambient(.1)
	check(audio._wind_trees.volume_db > -35,"evening tree wind is audible")
	check(VegetationAssets._wind_materials[0].get_shader_parameter("wind_strength") == main.wind.strength,"visual shader and audio share wind state")
	smoke.set_process(false)
	audio.set_process(false)
	t.set_physics_process(false)
	t.freeze = true
	var starts: Array[String] = []
	for i in 9:
		main.select_vehicle(i)
		t.controls_enabled = true
		t.freeze = true
		t.stop_engine()
		smoke._process(.01)
		check(is_zero_approx(smoke.emission_rate),"no exhaust with engine off: %d" % i)
		starts.append(audio._starter.stream.resource_path)
		check(audio._starter.stream is AudioStreamWAV and audio._starter.stream.get_length()>=float(EngineStartCatalog.profile(i)["seconds"]),"recorded starter covers actual crank time: %d" % i)
		t.toggle_engine()
		audio._update_engine(.01)
		smoke._process(.01)
		check(audio._starter.playing and smoke.emission_rate>0,"starter sound and exhaust share crank state: %d" % i)
		for frame in 260:
			t._physics_process(1.0/60.0)
			if t.engine_state == OffroadTruck.EngineState.RUNNING:
				break
		smoke._process(.04)
		var burst: float = smoke.emission_rate
		check(smoke.startup>1.5 and burst>30,"ignition triggers dense exhaust burst: %d" % i)
		for frame in 55:
			smoke._process(.04)
		var idle: float = smoke.emission_rate
		check(idle<burst*.4,"startup smoke settles to light idle: %d" % i)
		t.linear_velocity = Vector3(0,0,18)
		smoke._process(.04)
		check(smoke.emission_rate<idle,"moving exhaust is lighter: %d" % i)
		t.stop_engine()
		smoke._process(.04)
		check(is_zero_approx(smoke.emission_rate),"stopping stops new smoke: %d" % i)
		check(smoke.outlet == ExhaustSmoke.OUTLETS[i],"vehicle-specific exhaust outlet: %d" % i)
		check(audio._starter.stream.resource_path.ends_with("start_%s.wav" % EngineStartCatalog.profile(i)["id"]),"selected vehicle has its own start sample: %d" % i)
	check(smoke._multimesh.instance_count == 96,"exhaust pool stays bounded")
	main.set_night(false)
	# Opening pause/failed challenge must never apply a winch force.
	main._open_menu(true)
	check(not t.controls_enabled,"menu blocks winch controls")
	main._close_menu()
	main.free()
	await create_timer(.15).timeout
	print("RECOVERY EFFECTS failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
