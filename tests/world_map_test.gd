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
	var paved := 0.0
	for i in terrain._road.size() - 1:
		if terrain._road_gap[i] == 0:
			paved += terrain._road[i].distance_to(terrain._road[i + 1])
	check(paved > 5000.0, "network should offer over 5 km of paved driving")
	var steepest := 0.0
	for i in terrain._road.size() - 1:
		if terrain._road_gap[i] == 1:
			continue
		steepest = maxf(steepest, absf(terrain._road_h[i + 1] - terrain._road_h[i]) / terrain._road[i].distance_to(terrain._road[i + 1]))
		check(absf(terrain._road[i].x) < 1000 and absf(terrain._road[i].y) < 1000, "paved route inside map")
	check(steepest < 0.105, "asphalt grades must stay below 10.5 percent")
	check(terrain.h[0] > 30.0, "outer terrain creates a mountain boundary")
	var lc := MapLayout.LAKE_CENTER
	check(terrain.height_at(Vector3(lc.x, 0, lc.y)) < MapLayout.LAKE_LEVEL - 2.0, "lake basin lies below water level")
	check(terrain.water_level_at(Vector3(lc.x, 0, lc.y)) == MapLayout.LAKE_LEVEL, "lake water level")
	var rv: Vector2 = MapLayout.RIVER[4]
	check(terrain.height_at(Vector3(rv.x, 0, rv.y)) < terrain.water_level_at(Vector3(rv.x, 0, rv.y)), "river bed below its water")
	check(terrain.height_at(Vector3(MapLayout.MINE.x, 0, MapLayout.MINE.y)) < -10.0, "open-pit mine is deep")
	check(absf(terrain.height_at(Vector3(MapLayout.TOWN.x + 60, 0, MapLayout.TOWN.y + 30)) - MapLayout.TOWN_H) < 1.5, "town sits on a flat plateau")
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
	print("WORLD MAP: 2048m, paved=%.0fm, max_grade=%.1f%%, terrain_build=%dms, failures=%d" % [paved, steepest * 100, Time.get_ticks_msec() - started, failures.size()])
	terrain.free()
	quit(0 if failures.is_empty() else 1)
