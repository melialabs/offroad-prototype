class_name HillClimbZone
extends RefCounted
## Local deterministic sculpting only; asphalt and the old valley trail are protected.
const BIN := 16.0
var routes := HillClimbCatalog.courses()
var _segments: Array[Dictionary] = []
var _bins := {}
var trenches: Array[Dictionary] = []

func _init() -> void:
	for ri in routes.size():
		_index_line(routes[ri]["points"], ri)
		if routes[ri].has("alternative"):
			_index_line(routes[ri]["alternative"], ri)
	for ri in [5, 6, 11]:
		var pts: PackedVector2Array = routes[ri]["points"]
		trenches.append({"p": pts[2].lerp(pts[3], 0.45), "floor": 0.0, "radius": 4.5})

func _index_line(points: PackedVector2Array, route: int) -> void:
	var along := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var index := _segments.size()
		_segments.append({"a": a, "b": b, "route": route, "along": along})
		along += a.distance_to(b)
		var lo := a.min(b) - Vector2.ONE * 13
		var hi := a.max(b) + Vector2.ONE * 13
		for z in range(floori(lo.y / BIN), floori(hi.y / BIN) + 1):
			for x in range(floori(lo.x / BIN), floori(hi.x / BIN) + 1):
				var key := Vector2i(x, z)
				if not _bins.has(key):
					_bins[key] = []
				_bins[key].append(index)

func profile(p: Vector2) -> Dictionary:
	var best := {"distance": INF, "signed": INF, "along": 0.0, "route": -1}
	if not HillClimbCatalog.ZONE.grow(12).has_point(p):
		return best
	for index: int in _bins.get(Vector2i(floori(p.x / BIN), floori(p.y / BIN)), []):
		var seg: Dictionary = _segments[index]
		var ab: Vector2 = seg["b"] - seg["a"]
		var t := clampf((p - seg["a"]).dot(ab) / ab.length_squared(), 0, 1)
		var d := p.distance_to(seg["a"] + ab * t)
		if d < best["distance"]:
			best = {"distance": d, "signed": d * signf(ab.cross(p - seg["a"])), "along": seg["along"] + t * ab.length(), "route": seg["route"]}
	return best

func clearing(p: Vector2) -> bool:
	if not HillClimbCatalog.ZONE.grow(12).has_point(p):
		return false
	for route in routes:
		if p.distance_squared_to(route["points"][0]) < 9.0 * 9.0:
			return true
	var sample := profile(p)
	return sample["route"] >= 0 and sample["distance"] < float(routes[sample["route"]]["half_width"]) + 2.0

func _bump(p: Vector2) -> float:
	var edge := HillClimbCatalog.ZONE
	var fade := smoothstep(0, 18, minf(minf(p.x - edge.position.x, edge.end.x - p.x), minf(p.y - edge.position.y, edge.end.y - p.y)))
	return fade * (18.0 * exp(-p.distance_squared_to((Vector2(492,370) + HillClimbCatalog.OFFSET)) / 1700.0) + 8.0 * exp(-p.distance_squared_to((Vector2(510,320) + HillClimbCatalog.OFFSET)) / 650.0) + 11.0 * exp(-p.distance_squared_to((Vector2(510,310) + HillClimbCatalog.OFFSET)) / 200.0) + 12.0 * exp(-p.distance_squared_to((Vector2(540,345) + HillClimbCatalog.OFFSET)) / 160.0) + 12.0 * exp(-p.distance_squared_to((Vector2(492,382) + HillClimbCatalog.OFFSET)) / 500.0))

func _grid_lo() -> Vector2i:
	var r := HillClimbCatalog.ZONE
	return Vector2i(floori(r.position.x / MudTerrain.CELL) + 256 - 1, floori(r.position.y / MudTerrain.CELL) + 256 - 1)


func _grid_hi() -> Vector2i:
	var r := HillClimbCatalog.ZONE
	return Vector2i(ceili(r.end.x / MudTerrain.CELL) + 256 + 2, ceili(r.end.y / MudTerrain.CELL) + 256 + 2)


func sculpt(terrain: MudTerrain) -> void:
	for trench in trenches:
		var p: Vector2 = trench["p"]
		trench["floor"] = terrain.sample_grid(terrain.base, Vector3(p.x,0,p.y)) + _bump(p) - 0.85
	var summit := (Vector2(492,382) + HillClimbCatalog.OFFSET)
	var summit_height := terrain.sample_grid(terrain.base,Vector3(summit.x,0,summit.y))+_bump(summit)
	var trail_len := MudTerrain._lengths(terrain._trail)
	for z in range(_grid_lo().y, _grid_hi().y): # park sahəsinin şəbəkə hüdudları; ZONE yoxlaması dəqiqləşdirir
		for x in range(_grid_lo().x, _grid_hi().x):
			var i := z * MudTerrain.N + x
			var p := Vector2((x - 256) * MudTerrain.CELL, (z - 256) * MudTerrain.CELL)
			if not HillClimbCatalog.ZONE.has_point(p) or terrain.road_dist[i] < 18:
				continue
			if terrain._near_route(p, terrain._trail, trail_len, terrain._trail_bins)[0] < 6.0:
				continue
			var y := terrain.base[i] + _bump(p)
			var sample := profile(p)
			var ri: int = sample["route"]
			if ri >= 0:
				var route: Dictionary = routes[ri]
				var width: float = route["half_width"]
				var inside := 1.0 - smoothstep(width, width + 2.0, sample["distance"])
				var difficulty: int = route["difficulty"]
				y += sin(float(sample["along"]) * 0.43) * (0.06 + difficulty * 0.10) * inside
				# A narrow outside shoulder falls away on the cliff and razor routes.
				if ri in [7, 10] and sample["signed"] < 0:
					y -= (3.5 + difficulty) * smoothstep(width, width + 2, sample["distance"]) * (1.0 - smoothstep(width + 4, width + 9, sample["distance"]))
				terrain.soft[i] = lerpf(terrain.soft[i], float(route["mud"]), inside)
				terrain._aux_dirt[i] = maxf(terrain._aux_dirt[i], inside)
				terrain._aux_deepk[i] = maxf(terrain._aux_deepk[i], inside * 0.8)
			# Flat stopping bays: no activation circle on a sharp incline.
			for route in routes:
				var start: Vector2 = route["points"][0]
				var bay := 1.0 - smoothstep(5.5, 9.0, p.distance_to(start))
				if bay > 0:
					var sy := terrain.sample_grid(terrain.base, Vector3(start.x,0,start.y))
					y = lerpf(y, sy, bay)
					terrain.soft[i] *= 1.0 - bay
			for trench in trenches:
				var blend := 1.0 - smoothstep(2.5, float(trench["radius"]), p.distance_to(trench["p"]))
				y = lerpf(y, trench["floor"], blend)
				terrain.soft[i] = maxf(terrain.soft[i], blend * 0.94)
			y = lerpf(y,summit_height,1.0-smoothstep(5.0,10.0,p.distance_to(summit)))
			terrain.h[i] = y
			# Preserve immutable input until all bays have sampled the old terrain.
	for z in range(_grid_lo().y, _grid_hi().y):
		for x in range(_grid_lo().x, _grid_hi().x):
			var i := z * MudTerrain.N + x
			terrain.base[i] = terrain.h[i]

func initial_rut(p: Vector2) -> float:
	var sample := profile(p)
	var ri: int = sample["route"]
	if ri < 0 or sample["distance"] > 1.65:
		return 0.0
	var route: Dictionary = routes[ri]
	if p.distance_to(route["points"][0]) < 9.0:
		return 0.0
	var depth := 0.08 + float(route["difficulty"]) * 0.065
	return -depth * exp(-pow((absf(sample["signed"]) - 0.86) / 0.23, 2.0)) * float(route["mud"])
