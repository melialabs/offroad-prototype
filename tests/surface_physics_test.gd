extends SceneTree
## Gameplay invariants: tire choices, coasting vs wheelspin, pressure and terrain.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var highway: Dictionary = OffroadTruck.TIRES[0]
	var mud: Dictionary = OffroadTruck.TIRES[2]
	check(OffroadSurface.grip(highway, true, 0.0, 0.0) > OffroadSurface.grip(mud, true, 0.0, 0.0), "highway tires grip asphalt better")
	check(OffroadSurface.grip(mud, false, 1.0, 0.7) > OffroadSurface.grip(highway, false, 1.0, 0.7), "mud tires grip deep mud better")
	var rolling_rpm := 5.0 * 60.0 / (TAU * 0.4)
	check(is_zero_approx(OffroadSurface.slip_speed(rolling_rpm, 0.4, 5.0)), "coasting is not wheelspin")
	check(is_zero_approx(OffroadSurface.slip_speed(-rolling_rpm, 0.4, -5.0)), "reverse coasting is not wheelspin")
	check(OffroadSurface.slip_speed(rolling_rpm, 0.4, 0.0) > 4.9, "stationary wheelspin detected")
	var rolling := OffroadSurface.digging_rate(3500.0, 0.3, 0.4, 0.0)
	var spinning := OffroadSurface.digging_rate(3500.0, 0.3, 0.4, 5.0)
	check(spinning > rolling * 3.0, "spinning digs faster than rolling")
	check(OffroadSurface.digging_rate(7000.0, 0.3, 0.4, 1.0) > OffroadSurface.digging_rate(3500.0, 0.3, 0.4, 1.0), "greater load digs faster")
	check(OffroadSurface.digging_rate(3500.0, 0.5, 0.4, 1.0) < OffroadSurface.digging_rate(3500.0, 0.2, 0.4, 1.0), "wider tires reduce ground pressure")
	check(is_zero_approx(OffroadSurface.resistance(0.0, 0.7, 0.4)), "hard terrain has no mud drag")
	check(OffroadSurface.resistance(1.0, 0.5, 0.4) > OffroadSurface.resistance(1.0, 0.1, 0.4), "deeper ruts resist movement more")
	var velocity := Vector3(4.0, 0.0, -2.0)
	var drag_force := -velocity * OffroadSurface.resistance(1.0, 0.5, 0.4)
	check(drag_force.dot(velocity) <= 0.0, "mud drag removes rather than adds energy")
	check(float(OffroadTruck.SUSPENSIONS[3]["travel"]) > float(OffroadTruck.SUSPENSIONS[4]["travel"]), "Niva has more suspension travel than road sedan")
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	var spawn: Vector3 = terrain.road_spawn()["pos"]
	check(terrain.road_distance_fast(spawn) < MudTerrain.ROAD_HALF, "road spawn classifies as asphalt")
	var before := terrain.height_at(spawn)
	terrain.deform(spawn, 1.3, spinning)
	check(is_equal_approx(before, terrain.height_at(spawn)), "asphalt remains rigid")
	terrain.free()
	print("SURFACE PHYSICS: 14 checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
