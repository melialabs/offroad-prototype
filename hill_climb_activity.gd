class_name HillClimbActivity
extends Node
## Confirmation-driven activity state machine. Input ownership precedes the
## vehicle's unhandled E (AWD); outside a stopped marker AWD remains untouched.
signal changed
signal cue(kind: String)
enum State { FREE_ROAM, COUNTDOWN, RUNNING, FAILED, RESULTS }
const STOP_SPEED := 0.65
const STOP_DWELL := 0.7
const START_RADIUS := 5.5

var terrain: MudTerrain
var truck: OffroadTruck
var main_node: Node
var records := HillClimbRecords.new()
var routes := HillClimbCatalog.courses()
var markers: Array[Dictionary] = []
var state := State.FREE_ROAM
var active_index := -1
var selected_index := 0
var near_marker := -1
var elapsed := 0.0
var countdown := 0.0
var next_checkpoint := 1
var checkpoints := PackedVector3Array()
var failure_reason := ""
var result_medal := ""
var personal_best := false
var paused := false
var _stop_time := 0.0
var _off_route_time := 0.0
var _roll_time := 0.0
var _idle_time := 0.0
var _previous_position := Vector3.ZERO
var _return_transform := Transform3D.IDENTITY
var _vehicle_index := 0
var _count_number := 0
var _menu_froze_vehicle := false
var _freeze_before_menu := false
var _menu_velocity := Vector3.ZERO
var _menu_angular_velocity := Vector3.ZERO

func _ready() -> void:
	records.load_records()
	for i in routes.size():
		routes[i]["enabled"] = records.enabled(routes[i]["id"])
		var p: Vector2 = routes[i]["points"][0]
		markers.append({"p": ground(p), "route": i, "hub": false})
	# Roadside discovery hubs distribute activities through the existing world.
	# Approaching them still requires a deliberate stop and E confirmation.
	var depot: Vector3 = terrain.road_spawn()["pos"]
	var heading: float = terrain.road_spawn()["yaw"]
	var shoulder := Vector3(cos(heading), 0, -sin(heading)) * 7.0
	markers.append({"p": ground(Vector2(depot.x + shoulder.x, depot.z + shoulder.z)), "route": 0, "hub": true})
	_add_hub(Vector2(524,-548),3)
	_add_hub(Vector2(-715,565),6)
	_previous_position = truck.global_position

func ground(p: Vector2) -> Vector3:
	var point := Vector3(p.x,0,p.y)
	point.y = terrain.sample_grid(terrain.base, point)
	return point

func engaged() -> bool:
	return state != State.FREE_ROAM

func prompt_ready() -> bool:
	return state == State.FREE_ROAM and near_marker >= 0 and _stop_time >= STOP_DWELL and not paused

func route_enabled(index: int) -> bool:
	return index >= 0 and index < routes.size() and routes[index]["enabled"]

func marker_enabled(index: int) -> bool:
	if markers[index]["hub"]:
		return next_enabled(-1) >= 0
	return route_enabled(markers[index]["route"])

func next_enabled(after: int) -> int:
	for step in range(1, routes.size() + 1):
		var i := (after + step) % routes.size()
		if route_enabled(i):
			return i
	return -1

func set_activity_enabled(id: String, on: bool) -> void:
	for i in routes.size():
		if routes[i]["id"] == id:
			routes[i]["enabled"] = on
			if active_index == i and engaged() and not on:
				exit_challenge()
			records.set_enabled(id, on)
			_stop_time = 0.0
			changed.emit()
			return

func _input(event: InputEvent) -> void:
	if paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_E and prompt_ready():
		if start_challenge(selected_index):
			get_viewport().set_input_as_handled()
	elif prompt_ready() and markers[near_marker]["hub"] and key in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		cycle_selection(-1 if key == KEY_BRACKETLEFT else 1)
		get_viewport().set_input_as_handled()
	elif engaged() and key in [KEY_R, KEY_BACKSPACE, KEY_ENTER, KEY_TAB, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		get_viewport().set_input_as_handled()
		if key == KEY_BACKSPACE:
			exit_challenge()
		elif key == KEY_R or (key == KEY_ENTER and state in [State.FAILED, State.RESULTS]):
			retry()
		elif key == KEY_TAB and state == State.RESULTS:
			next_challenge()

func cycle_selection(direction: int) -> void:
	for step in range(1, routes.size() + 1):
		var index := posmod(selected_index + step * direction, routes.size())
		if route_enabled(index):
			selected_index = index
			changed.emit()
			return

func _physics_process(delta: float) -> void:
	if paused:
		return
	if state == State.FREE_ROAM:
		_scan_markers(delta)
	elif state == State.COUNTDOWN:
		countdown = maxf(0, countdown - delta)
		var digit := ceili(countdown)
		if digit != _count_number and digit > 0:
			_count_number = digit
			cue.emit("countdown")
		if countdown <= 0:
			state = State.RUNNING
			_previous_position = truck.global_position
			restore_controls()
			cue.emit("start")
			changed.emit()
	elif state == State.RUNNING:
		advance_run(delta, truck.global_position)

func _scan_markers(delta: float) -> void:
	var found := -1
	var best := START_RADIUS
	for i in markers.size():
		if not marker_enabled(i):
			continue
		var p: Vector3 = markers[i]["p"]
		var d := Vector2(p.x - truck.global_position.x, p.z - truck.global_position.z).length()
		if d < best and absf(truck.global_position.y - p.y) < 4.5:
			found = i
			best = d
	if found != near_marker:
		near_marker = found
		_stop_time = 0.0
		if found >= 0:
			selected_index = markers[found]["route"]
			if not route_enabled(selected_index):
				selected_index = next_enabled(selected_index)
		changed.emit()
	if found >= 0 and truck.linear_velocity.length() < STOP_SPEED and truck.global_basis.y.dot(Vector3.UP) > 0.7:
		_stop_time += delta
	else:
		_stop_time = 0.0

func start_challenge(index: int) -> bool:
	if not prompt_ready() or not route_enabled(index) or index != selected_index:
		return false
	_return_transform = truck.global_transform
	active_index = index
	_vehicle_index = truck.spec_idx
	_setup_run()
	return true

func _setup_run() -> void:
	checkpoints.clear()
	for p in HillClimbCatalog.checkpoint_path(routes[active_index]["points"]):
		checkpoints.append(ground(p))
	next_checkpoint = 1
	elapsed = 0.0
	_off_route_time = 0
	_roll_time = 0
	_idle_time = 0
	failure_reason = ""
	personal_best = false
	result_medal = ""
	countdown = 3.0
	_count_number = 3
	state = State.COUNTDOWN
	var direction := checkpoints[1] - checkpoints[0]
	truck.linear_velocity = Vector3.ZERO
	truck.angular_velocity = Vector3.ZERO
	truck.global_transform = Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), checkpoints[0] + Vector3.UP * 1.2)
	terrain.prepare_mud(truck.global_position)
	_previous_position = truck.global_position
	restore_controls()
	if main_node != null:
		main_node.cam.snap()
	cue.emit("countdown")
	changed.emit()

func advance_run(delta: float, position: Vector3) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	if truck.spec_idx != _vehicle_index:
		fail("Vehicle changed · Retry with the selected vehicle")
		return
	if position.distance_to(_previous_position) > 14.0:
		fail("Vehicle reset outside the route")
		return
	var target := checkpoints[next_checkpoint]
	var prev := checkpoints[next_checkpoint - 1]
	var radius := 5.0 - int(routes[active_index]["difficulty"]) * 0.5
	var closest := Geometry3D.get_closest_point_to_segment(target + Vector3.UP, _previous_position, position)
	# Ordered, height-aware checkpoints and swept crossing prevent shortcuts and tunnelling.
	if Vector2(closest.x - target.x, closest.z - target.z).length() <= radius and absf(closest.y - target.y - 1.0) < 3.0:
		next_checkpoint += 1
		_idle_time = 0
		cue.emit("checkpoint")
		if next_checkpoint >= checkpoints.size():
			finish()
			return
		changed.emit()
	var corridor := Geometry2D.get_closest_point_to_segment(Vector2(position.x,position.z), Vector2(prev.x,prev.z), Vector2(target.x,target.z))
	var off_route := Vector2(position.x,position.z).distance_to(corridor) > 22.0
	_off_route_time = _off_route_time + delta if off_route else 0.0
	_roll_time = _roll_time + delta if truck.global_basis.y.dot(Vector3.UP) < 0.15 else 0.0
	_idle_time = _idle_time + delta if truck.linear_velocity.length() < 0.3 else 0.0
	if _off_route_time > 10.0:
		fail("Off route · Return to the marked track")
	elif _roll_time > 2.5:
		fail("Vehicle overturned")
	elif position.y < terrain.height_at(position) - 6.0 or absf(position.x) > 1008 or absf(position.z) > 1008:
		fail("Vehicle left the challenge area")
	elif elapsed > float(routes[active_index]["gold"]) * 5.0 + 180.0:
		fail("Time limit reached")
	_previous_position = position

func fail(reason: String) -> void:
	if not engaged() or state in [State.FAILED, State.RESULTS]:
		return
	failure_reason = reason
	state = State.FAILED
	restore_controls()
	cue.emit("fail")
	changed.emit()

static func medal(seconds: float, gold: float) -> String:
	if seconds <= gold:
		return "Gold"
	if seconds <= gold * 1.5:
		return "Silver"
	return "Bronze"

func finish() -> void:
	if state != State.RUNNING or next_checkpoint < checkpoints.size():
		return
	state = State.RESULTS
	result_medal = medal(elapsed, routes[active_index]["gold"])
	var old := records.record(routes[active_index]["id"], _vehicle_index)
	personal_best = old["best_time"] <= 0 or elapsed < old["best_time"]
	var error := records.complete(routes[active_index]["id"], _vehicle_index, elapsed, result_medal)
	if error != OK:
		failure_reason = "Record is in memory; save failed (%d)" % error
	restore_controls()
	cue.emit("finish")
	changed.emit()

func retry() -> void:
	if engaged() and route_enabled(active_index):
		_setup_run()

func next_challenge() -> void:
	if state != State.RESULTS:
		return
	var index := next_enabled(active_index)
	if index >= 0 and index != active_index:
		active_index = index
		_setup_run()

func exit_challenge() -> void:
	if not engaged():
		return
	_release_menu_freeze(false)
	var at_finish := state == State.RESULTS
	state = State.FREE_ROAM
	if not at_finish:
		truck.global_transform = _return_transform
		truck.position.y = maxf(truck.position.y, terrain.height_at(truck.position) + 0.9)
		truck.linear_velocity = Vector3.ZERO
		truck.angular_velocity = Vector3.ZERO
		if main_node != null:
			main_node.cam.snap()
	active_index = -1
	near_marker = -1
	_stop_time = 0.0
	restore_controls()
	changed.emit()

func set_menu_paused(on: bool) -> void:
	if on and not paused and engaged():
		_freeze_before_menu = truck.freeze
		_menu_velocity = truck.linear_velocity
		_menu_angular_velocity = truck.angular_velocity
		truck.freeze = true
		_menu_froze_vehicle = true
	elif not on:
		_release_menu_freeze(true)
	paused = on
	restore_controls()
	changed.emit()

func restore_controls() -> void:
	truck.controls_enabled = not paused and state in [State.FREE_ROAM, State.RUNNING]
	if main_node != null and not paused:
		main_node._set_mouse_capture(state in [State.FREE_ROAM, State.RUNNING])


func _add_hub(near: Vector2, route: int) -> void:
	var nearest := terrain._near_route(near,terrain._road,terrain._road_len,terrain._road_bins)
	var index: int = nearest[3]
	var a := terrain._road[index]
	var b := terrain._road[index+1]
	var forward := (b-a).normalized()
	var p := a.lerp(b,nearest[4])+Vector2(-forward.y,forward.x)*7.0
	markers.append({"p": ground(p),"route": route,"hub": true})


func _release_menu_freeze(restore_velocity: bool) -> void:
	if not _menu_froze_vehicle:
		return
	truck.freeze = _freeze_before_menu
	truck.linear_velocity = _menu_velocity if restore_velocity else Vector3.ZERO
	truck.angular_velocity = _menu_angular_velocity if restore_velocity else Vector3.ZERO
	_menu_froze_vehicle = false
