extends SceneTree
var failures: Array[String] = []

func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		print("FAIL: ", text)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var started := Time.get_ticks_msec()
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	check(is_equal_approx((MudTerrain.N - 1) * MudTerrain.CELL, 2048.0), "world width must be 2048 m")
	check(terrain._chunks.size() == 256, "256 terrain chunks expected")
	check(terrain._road[0].distance_to(terrain._road[-1]) < 0.01, "asphalt route closes")
	check(terrain._road_len[-1] > 5000.0, "route should offer over 5 km of paved driving")
	var steepest := 0.0
	for i in terrain._road.size() - 1:
		steepest = maxf(steepest, absf(terrain._road_h[i + 1] - terrain._road_h[i]) / terrain._road[i].distance_to(terrain._road[i + 1]))
		check(absf(terrain._road[i].x) < 1000 and absf(terrain._road[i].y) < 1000, "paved route inside map")
	check(steepest < 0.105, "asphalt grades must stay below 10.5 percent")
	check(terrain.h[0] > 30.0, "outer terrain creates a mountain boundary")
	check(terrain.height_at(Vector3(-150, 0, -120)) < -2.4, "lake basin lies below water level")
	var spawn: Vector3 = terrain.road_spawn()["pos"]
	check(terrain.road_distance_fast(spawn) < 0.1, "spawn sits on asphalt")
	# A deformation at a chunk corner must update all four shared collision edges.
	var gx := 256
	var gz := 256
	var point := Vector3.ZERO
	var idx := gz * MudTerrain.N + gx
	terrain.soft[idx] = 1.0
	var before := terrain.h[idx]
	terrain.deform(point, 5.0, 0.4)
	terrain._rebuild_mesh(false)
	check(terrain.h[idx] < before, "mud deforms")
	var n := MudTerrain.CHUNK_CELLS + 1
	for key in [Vector2i(7,7), Vector2i(8,7), Vector2i(7,8), Vector2i(8,8)]:
		var shape: HeightMapShape3D = terrain._chunks[key]["shape"]
		var lx: int = gx - key.x * MudTerrain.CHUNK_CELLS
		var lz: int = gz - key.y * MudTerrain.CHUNK_CELLS
		check(is_equal_approx(shape.map_data[lz * n + lx], terrain.h[idx]), "shared chunk collider remains seamless")
	print("WORLD MAP: 2048m, paved=%.0fm, max_grade=%.1f%%, terrain_build=%dms, failures=%d" % [terrain._road_len[-1], steepest * 100, Time.get_ticks_msec() - started, failures.size()])
	terrain.free()
	quit(0 if failures.is_empty() else 1)
