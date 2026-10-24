extends SceneTree
## Bitki örtüyü testləri: qaydalar, toqquşma, determinizm, üst-üstə düşmə.
## godot --headless --path . -s res://tests/vegetation_test.gd

var terrain: MudTerrain
var veg: Vegetation
var veg2: Vegetation
var frames := 0
var failures: Array[String] = []


func _initialize() -> void:
	terrain = MudTerrain.new()
	root.add_child(terrain)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		veg = Vegetation.new()
		root.add_child(veg)
		veg.build(terrain, 1234)
		veg2 = Vegetation.new()
		root.add_child(veg2)
		veg2.build(terrain, 1234)
	if frames == 6:
		_run_checks()
		for f in failures:
			print("FAIL ", f)
		print("VEG TEST: ağac=%d, növ sayları=%s, uğursuzluq=%d" % [veg._big_trees.size(), veg.stats, failures.size()])
		quit(0 if failures.is_empty() else 1)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _run_checks() -> void:
	var trees: Array = veg._big_trees
	_check(trees.size() >= 150, "ağac sayı çox azdır: %d" % trees.size())

	# 1) yerləşdirmə qaydaları
	var bad_road := 0
	var bad_mud := 0
	var bad_slope := 0
	var floating := 0
	for t in trees:
		var p: Vector3 = t[0]
		# Hill Climb parkında ağaclar sonradan sculpt olunmuş relyefə görə qaldırılır (Vegetation._add_instance);
		# qaydalar orada tests/hill_forest_preservation_test.gd ilə yoxlanılır
		if HillClimbCatalog.ZONE.has_point(Vector2(p.x, p.z)):
			continue
		if terrain.road_distance_fast(p) < MudTerrain.ROAD_HALF + 4.9:
			bad_road += 1
		if terrain.softness_at(p) > 0.21:
			bad_mud += 1
		if terrain.slope_at(p) > 0.43:
			bad_slope += 1
		if absf((p.y + 0.15) - terrain.height_at(p)) > 1.0:
			floating += 1
	_check(bad_road == 0, "yol dəhlizində ağac: %d" % bad_road)
	_check(bad_mud == 0, "dərin palçıqda ağac: %d" % bad_mud)
	_check(bad_slope == 0, "dik yamacda ağac: %d" % bad_slope)
	_check(floating == 0, "havada asılı/batmış ağac: %d" % floating)

	# 2) ağaclar bir-birinin içində deyil
	var min_d := INF
	for i in trees.size():
		for j in range(i + 1, trees.size()):
			var a: Vector3 = trees[i][0]
			var b: Vector3 = trees[j][0]
			min_d = minf(min_d, Vector2(a.x - b.x, a.z - b.z).length())
	_check(min_d >= 1.3, "ağaclar çox yaxındır: min məsafə %.2f m" % min_d)

	# 3) toqquşma: hər ağacın gövdəsinə üfüqi şüa dəyməlidir
	var space := root.world_3d.direct_space_state
	var hit := 0
	var sample := mini(trees.size(), 40)
	for i in sample:
		var p: Vector3 = trees[i * (trees.size() / sample)][0]
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(-4, 1.5, 0), p + Vector3(4, 1.5, 0))
		var r := space.intersect_ray(q)
		if not r.is_empty() and (r["collider"] as Node).name == "TreeColliders":
			hit += 1
	_check(hit >= sample - 2, "ağac toqquşması: %d/%d şüa dəydi" % [hit, sample])

	# 4) determinizm: eyni toxumla eyni nəticə
	_check(veg.stats == veg2.stats, "eyni toxumla növ sayları fərqlidir")
	_check(_hash(veg) == _hash(veg2), "eyni toxumla yerləşmə fərqlidir")

	# 5) yol üzərində ot/bitki olmamalıdır
	var on_road := 0
	for key in veg._inst:
		for xf in veg._inst[key]:
			var p: Vector3 = (xf as Transform3D).origin
			if terrain.road_distance_fast(p) < MudTerrain.ROAD_HALF:
				on_road += 1
	_check(on_road == 0, "asfalt üzərində bitki: %d" % on_road)


func _hash(v: Vegetation) -> int:
	var h := 0
	for key in v._inst:
		for xf in v._inst[key]:
			var o: Vector3 = (xf as Transform3D).origin
			h = (h + int(o.x * 1000.0) * 31 + int(o.z * 1000.0) * 17) % 2147483647
	return h
