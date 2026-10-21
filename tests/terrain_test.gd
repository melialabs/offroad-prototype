extends SceneTree
## Landşaft testi: yol, palçıq, deformasiya və qismən mesh yenilənməsi.

var terrain: MudTerrain
var frames := 0
var spot := Vector3.ZERO
var h_before := 0.0


func _initialize() -> void:
	terrain = MudTerrain.new()
	root.add_child(terrain)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		var best := -1
		for i in terrain.soft.size():
			if terrain.soft[i] > 0.95 and terrain.slope_at(_world(i)) < 0.2:
				best = i
				break
		if best < 0:
			print("TEST XƏTA: tam palçıq nöqtəsi tapılmadı")
			quit(1)
			return true
		spot = _world(best)
		h_before = terrain.height_at(spot)
		for k in 20:
			terrain.deform(spot, 1.3, 0.1)
		print("TEST palçıq nöqtəsi=%s hündürlük=%.2f" % [spot, h_before])
	if frames == 30:
		var depth := terrain.depth_at(spot)
		var road := terrain.road_spawn()
		var rp: Vector3 = road["pos"]
		var road_soft := terrain.softness_at(rp)
		var before := terrain.height_at(rp)
		for k in 20:
			terrain.deform(rp, 1.3, 0.1)
		var after := terrain.height_at(rp)
		print("TEST deformasiya dərinliyi=%.2f m, yolda palçıq=%.2f, yolun hündürlüyü dəyişdi=%s" % [
			depth, road_soft, str(not is_equal_approx(before, after))])
		var ok := depth > 0.3 and road_soft < 0.01 and is_equal_approx(before, after)
		quit(0 if ok else 1)
	return false


func _world(i: int) -> Vector3:
	var half := (MudTerrain.N - 1) * 0.5
	var x := i % MudTerrain.N
	var z := i / MudTerrain.N
	return Vector3((x - half) * MudTerrain.CELL, terrain.h[i], (z - half) * MudTerrain.CELL)
