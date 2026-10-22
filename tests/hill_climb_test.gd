extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	var truck := OffroadTruck.new()
	truck.terrain = terrain
	root.add_child(truck)
	truck.freeze = true
	truck.set_physics_process(false)
	var a := HillClimbActivity.new()
	a.terrain = terrain
	a.truck = truck
	a.records.path = "/tmp/hill-records-%d.cfg" % OS.get_process_id()
	root.add_child(a)
	a.set_physics_process(false)
	check(a.routes.size() == 12,"twelve independent routes")
	check(a.markers.size() == 15,"zone markers and three world discovery hubs")
	var sizes := [0,0,0,0]
	for r in a.routes:
		sizes[r["difficulty"]] += 1
	check(sizes == [3,3,3,3],"progressive difficulty groups")
	var p: Vector3 = a.markers[0]["p"]
	truck.position = p + Vector3.UP
	truck.linear_velocity = Vector3(0,0,5)
	a._scan_markers(1.0)
	check(not a.prompt_ready() and not a.start_challenge(0),"drive-through cannot start")
	truck.linear_velocity = Vector3.ZERO
	a._scan_markers(0.8)
	check(a.prompt_ready() and a.state == HillClimbActivity.State.FREE_ROAM,"stopping shows prompt without auto-start")
	var awd_before := truck.awd_on
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	a._input(event)
	check(a.state == HillClimbActivity.State.COUNTDOWN,"E confirms activity")
	check(truck.awd_on == awd_before,"activation does not toggle AWD")
	a.set_menu_paused(true)
	a._physics_process(1.0)
	check(is_equal_approx(a.countdown,3.0),"countdown pauses in main menu")
	a.set_menu_paused(false)
	a._physics_process(3.1)
	check(a.state == HillClimbActivity.State.RUNNING and truck.controls_enabled,"countdown releases vehicle")
	var index := a.next_checkpoint
	a.advance_run(0.1,a.checkpoints[-1]+Vector3.UP)
	check(a.state == HillClimbActivity.State.FAILED and a.next_checkpoint == index,"teleport cannot skip route")
	a.retry()
	check(a.state == HillClimbActivity.State.COUNTDOWN and a.next_checkpoint == 1 and a.elapsed == 0,"retry resets attempt")
	a._physics_process(3.1)
	truck.rotation.z = PI
	for i in 4:
		a.advance_run(1.0,truck.position)
	check(a.state == HillClimbActivity.State.FAILED,"overturned vehicle fails")
	a.exit_challenge()
	check(a.state == HillClimbActivity.State.FREE_ROAM and truck.controls_enabled,"exit restores free roam")
	truck.rotation = Vector3.ZERO
	# Exercise every complete ordered route, using small swept steps rather than
	# jumping between targets. This validates lifecycle, not physical drivability.
	for ri in a.routes.size():
		truck.apply_spec(ri % OffroadTruck.SPECS.size())
		truck.position = a.markers[ri]["p"]+Vector3.UP
		truck.linear_velocity = Vector3.ZERO
		a._scan_markers(1.0)
		check(a.start_challenge(ri),"route %d starts with current vehicle" % ri)
		a._physics_process(3.1)
		var pos := truck.position
		for ci in range(1,a.checkpoints.size()):
			var target := a.checkpoints[ci]+Vector3.UP
			var count := maxi(1,ceili(pos.distance_to(target)/3.0))
			var start := pos
			for step in range(1,count+1):
				pos = start.lerp(target,float(step)/count)
				a.advance_run(0.2,pos)
		check(a.state == HillClimbActivity.State.RESULTS,"route %d ordered finish" % ri)
		check(a.result_medal in ["Gold","Silver","Bronze"],"route medal")
		check(a.records.record(a.routes[ri]["id"],truck.spec_idx)["completions"] == 1,"one completion per attempt")
		a.finish()
		check(a.records.record(a.routes[ri]["id"],truck.spec_idx)["completions"] == 1,"finish is idempotent")
		if ri == 0:
			a.next_challenge()
			check(a.active_index == 1 and a.state == HillClimbActivity.State.COUNTDOWN,"next challenge transition")
		a.exit_challenge()
		check(truck.controls_enabled,"route %d returns to free roam" % ri)
	check(HillClimbActivity.medal(60,60)=="Gold" and HillClimbActivity.medal(80,60)=="Silver" and HillClimbActivity.medal(100,60)=="Bronze","medal boundaries")
	a.set_activity_enabled(a.routes[0]["id"],false)
	truck.position = a.markers[0]["p"]+Vector3.UP
	a._scan_markers(1)
	check(not a.prompt_ready(),"disabled route has no activation")
	var reloaded := HillClimbRecords.new()
	reloaded.path = a.records.path
	check(reloaded.load_records() == OK and not reloaded.enabled(a.routes[0]["id"]),"enabled settings survive restart")
	check(reloaded.record(a.routes[1]["id"],1)["completions"] == 1,"records survive restart per vehicle")
	check(reloaded.record(a.routes[1]["id"],0)["completions"] == 0,"different vehicles have independent bests")
	var previous: float = reloaded.record(a.routes[1]["id"],1)["best_time"]
	reloaded.complete(a.routes[1]["id"],1,previous+40,"Bronze")
	check(reloaded.record(a.routes[1]["id"],1)["best_time"] == previous,"slower attempt preserves personal best")
	check(FileAccess.file_exists(reloaded.path+".bak"),"previous progress is backed up")
	var file := FileAccess.open(reloaded.path+".bad",FileAccess.WRITE)
	file.store_string("[not a valid save")
	file.close()
	var bad := HillClimbRecords.new()
	bad.path = reloaded.path+".bad"
	check(bad.load_records() != OK and bad.complete("test",0,50,"Gold") != OK,"unreadable save is never overwritten")
	check(FileAccess.get_file_as_string(bad.path) == "[not a valid save","corrupt save retained for recovery")
	for suffix in ["",".bak",".tmp",".bad"]:
		DirAccess.remove_absolute(reloaded.path+suffix)
	a.free()
	truck.free()
	terrain.free()
	print("HILL CLIMB: checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
