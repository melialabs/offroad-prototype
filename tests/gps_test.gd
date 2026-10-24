extends SceneTree
## GPS: xəritə bişirilir, hədəf seçilir, yol şəbəkəsi ilə marşrut qurulur.
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
	for i in 10:
		await process_frame
	var gps: WorldMap = main.world_map
	check(gps.map_texture != null, "map baked")
	check(gps.features != null and not gps.features.footprints.is_empty(), "town footprints available")
	check(gps._adj.size() == main._terrain._road.size(), "road graph built")
	var me := Vector2(main.truck.global_position.x, main.truck.global_position.z)
	for i in WorldLandmarks.PLACES.size():
		gps.set_target(i)
		gps._compute_route()
		var goal: Vector2 = WorldLandmarks.PLACES[i][1]
		check(gps.route.size() >= 2, "route exists to %s" % WorldLandmarks.PLACES[i][0])
		check(gps.route_length >= me.distance_to(goal) - 1.0, "route not shorter than straight line: %d" % i)
		check(gps.route[0].distance_to(me) < 0.5 and gps.route[gps.route.size() - 1].distance_to(goal) < 0.5, "route starts at car and ends at target: %d" % i)
	gps.set_target(1)
	gps._compute_route()
	check(gps.route.size() > 4, "city route follows the roads")
	check(gps._turn_hint() != "", "turn hint available")
	gps.set_target(-1)
	check(gps.route.is_empty(), "clearing target clears route")
	print("GPS TEST: failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
