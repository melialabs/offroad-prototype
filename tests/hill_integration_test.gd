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
	main.select_vehicle(4)
	check(a.state == HillClimbActivity.State.FREE_ROAM and main.truck.spec_idx == 4,"garage selection exits safely before swapping vehicle")
	check(main.world_map.activities == a,"GPS shares live activity state")
	a.set_activity_enabled(a.routes[0]["id"],false)
	check(not a.marker_enabled(0) and a.marker_enabled(12),"per-route disable retains other activity hubs")
	for suffix in ["",".tmp",".bak"]:
		DirAccess.remove_absolute(a.records.path+suffix)
	main.free()
	print("HILL INTEGRATION failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
