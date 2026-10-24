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
	var a: HillClimbActivity = main.activities
	a.records = HillClimbRecords.new()
	a.records.path = "/tmp/hill-integration-%d.cfg" % OS.get_process_id()
	for route in a.routes:
		route["enabled"] = true
	check(a.paused and not main.world_map.visible,"main menu hides GPS and pauses activities")
	main.menu.start_requested.emit()
	main.truck.freeze = true
	main.truck.set_physics_process(false)
	main.truck.position = a.markers[0]["p"]+Vector3.UP
	main.truck.linear_velocity = Vector3.ZERO
	for i in 50:
		await physics_frame
	check(a.prompt_ready() and a.state == HillClimbActivity.State.FREE_ROAM,"stopping does not auto-start")
	var awd: bool = main.truck.awd_on
	key(KEY_E)
	await process_frame
	check(a.state == HillClimbActivity.State.COUNTDOWN,"real E input starts countdown")
	check(main.truck.awd_on == awd,"E start does not leak into AWD")
	a.countdown = 0.01
	for i in 3:
		await physics_frame
	key(KEY_E)
	await process_frame
	check(main.truck.awd_on != awd,"E still toggles AWD during the climb")
	main.truck.freeze = false
	main.truck.linear_velocity = Vector3(1,0,0)
	var paused_position: Vector3 = main.truck.position
	main._open_menu(true)
	check(main.truck.freeze,"paused challenge freezes the vehicle as well as its clock")
	var elapsed := a.elapsed
	for i in 8:
		await physics_frame
	check(is_equal_approx(elapsed,a.elapsed),"pause menu freezes challenge clock")
	check(main.truck.position.is_equal_approx(paused_position),"vehicle cannot move while race clock is paused")
	main._close_menu()
	check(main.truck.controls_enabled and not main.truck.freeze,"resume returns driving controls and previous freeze state")
	main.truck.freeze = true
	a.fail("Test failure")
	var ui: HillClimbUI
	for layer in main.get_children():
		for child in layer.get_children():
			if child is HillClimbUI:
				ui = child
	check(ui != null and ui._results.visible,"failure UI offers actual buttons")
	main._open_menu(true)
	main._close_menu()
	check(not main.truck.controls_enabled,"closing menu cannot release failed vehicle")
	key(KEY_R)
	await process_frame
	check(a.state == HillClimbActivity.State.COUNTDOWN and a.next_checkpoint == 1,"R retries rather than resetting to road")
	key(KEY_BACKSPACE)
	await process_frame
	check(a.state == HillClimbActivity.State.FREE_ROAM and main.truck.controls_enabled,"Backspace exits to free roam")
	main.truck.position = a.markers[0]["p"]+Vector3.UP
	a._scan_markers(1.0)
	check(a.start_challenge(0),"same marker can be replayed")
	# The final checkpoint must transition to RESULTS before notifying the world:
	# its active checkpoint ring otherwise indexes one past the path's end.
	var invalid_running_indices: Array[int] = []
	a.changed.connect(func():
		if a.state == HillClimbActivity.State.RUNNING and a.next_checkpoint >= a.checkpoints.size():
			invalid_running_indices.append(a.next_checkpoint)
	)
	a.state = HillClimbActivity.State.RUNNING
	a.next_checkpoint = a.checkpoints.size() - 1
	a.elapsed = 20.0
	var finish_position := a.checkpoints[-1] + Vector3.UP
	a._previous_position = finish_position
	a.advance_run(0.1,finish_position)
	check(a.state == HillClimbActivity.State.RESULTS and ui._results.visible,"final crossing displays results with world and UI attached")
	check(invalid_running_indices.is_empty(),"final crossing never publishes an invalid active checkpoint")
	a.retry()
	main.select_vehicle(4)
	check(a.state == HillClimbActivity.State.FREE_ROAM and main.truck.spec_idx == 4,"garage selection exits safely before swapping vehicle")
	# Newly appended UAZs share activation, retry and per-vehicle record storage.
	for vehicle in [4, 5, 6]:
		main.select_vehicle(vehicle)
		main.truck.freeze = true
		main.truck.position = a.markers[0]["p"] + Vector3.UP
		main.truck.linear_velocity = Vector3.ZERO
		a._scan_markers(1.0)
		check(a.start_challenge(0), "UAZ can activate challenge: %d" % vehicle)
		key(KEY_1)
		check(main.truck.spec_idx == vehicle, "number keys cannot replace UAZ during run: %d" % vehicle)
		a.state = HillClimbActivity.State.RUNNING
		a.elapsed = 25.0
		a.next_checkpoint = a.checkpoints.size() - 1
		var uaz_finish := a.checkpoints[-1] + Vector3.UP
		a._previous_position = uaz_finish
		a.advance_run(0.1, uaz_finish)
		check(a.records.record(a.routes[0]["id"], vehicle)["completions"] == 1, "UAZ earns its own record: %d" % vehicle)
		a.retry()
		check(a.state == HillClimbActivity.State.COUNTDOWN and main.truck.spec_idx == vehicle, "UAZ retry keeps selected vehicle: %d" % vehicle)
		a.exit_challenge()
	var shown: Array = main.menu._vehicle_buttons.filter(func(b): return b.visible)
	# görünən: gizli olmayan və modeli diskdə olan bütün texnika (yeni maşınlar əlavə olunduqca artır)
	var expected := range(OffroadTruck.SPECS.size()).filter(func(i): return OffroadTruck.is_available(i)).size()
	check(main.menu._vehicle_buttons.size() == OffroadTruck.SPECS.size() and shown.size() == expected, "garage exposes every available vehicle (%d/%d)" % [shown.size(), expected])
	check(main.world_map.activities == a,"GPS shares live activity state")
	a.set_activity_enabled(a.routes[0]["id"],false)
	check(not a.marker_enabled(0) and a.marker_enabled(12),"per-route disable retains other activity hubs")
	for suffix in ["",".tmp",".bak"]:
		DirAccess.remove_absolute(a.records.path+suffix)
	main.free()
	print("HILL INTEGRATION failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
