extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	var heights := []
	for z in range(0, MudTerrain.N, 4):
		var row := []
		for x in range(0, MudTerrain.N, 4):
			row.append(terrain.h[z * MudTerrain.N + x])
		heights.append(row)
	var road := []
	for p in terrain._road:
		road.append([p.x, p.y])
	var trail := []
	for p in terrain._trail:
		trail.append([p.x, p.y])
	var places := []
	for place in WorldLandmarks.PLACES:
		var p: Vector2 = place[1]
		places.append([place[0], p.x, p.y])
	DirAccess.make_dir_recursive_absolute("res://build")
	var file := FileAccess.open("res://build/world-map.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"heights": heights, "road": road, "trail": trail, "places": places, "road_m": terrain._road_len[-1]}))
	file.close()
	terrain.free()
	quit()
