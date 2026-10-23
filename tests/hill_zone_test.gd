extends SceneTree
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ",label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	ProjectSettings.set_setting("offroad/hill_climb_enabled",false)
	var before := MudTerrain.new()
	root.add_child(before)
	check(before.hill_zone == null,"entire feature can be disabled")
	var old_h := before.h.duplicate()
	var old_soft := before.soft.duplicate()
	var old_road := before.road_dist.duplicate()
	before.free()
	ProjectSettings.set_setting("offroad/hill_climb_enabled",true)
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	var changed := 0
	var damage := 0
	var road_damage := 0
	for i in old_h.size():
		var p := Vector2((i%513-256)*4,(i/513-256)*4)
		if not is_equal_approx(old_h[i],terrain.h[i]):
			changed += 1
			if not HillClimbCatalog.ZONE.has_point(p):
				damage += 1
			if old_road[i] < 18.0:
				road_damage += 1
	print("SCULPTED ", changed)
	check(changed > 100 and changed < 7000,"only a small local zone is sculpted")
	check(damage == 0,"all terrain outside the park is preserved")
	check(road_damage == 0,"all asphalt and protected roadside heights preserved")
	var trail_len := MudTerrain._lengths(terrain._trail)
	for i in terrain._trail.size():
		var p := terrain._trail[i]
		var g := terrain._to_grid(Vector3(p.x,0,p.y))
		var index := terrain._idx(roundi(g.x),roundi(g.y))
		check(is_equal_approx(old_h[index],terrain.h[index]),"existing valley trail preserved")
	for route in terrain.hill_zone.routes:
		var path := HillClimbCatalog.checkpoint_path(route["points"])
		var steepest := 0.0
		for i in range(1,path.size()):
			var a := Vector3(path[i-1].x,0,path[i-1].y)
			var b := Vector3(path[i].x,0,path[i].y)
			steepest = maxf(steepest,absf(terrain.height_at(b)-terrain.height_at(a))/a.distance_to(b))
		var start := Vector3(path[0].x,0,path[0].y)
		var finish := Vector3(path[-1].x,0,path[-1].y)
		check(terrain.height_at(finish)>terrain.height_at(start)+8,"route gains meaningful elevation")
		print("ROUTE ",route["id"]," rise=",snappedf(terrain.height_at(finish)-terrain.height_at(start),0.1)," max_checkpoint_grade=",snappedf(steepest,0.01))
	# Real physics probe: the existing scout accelerates up the easy entry slope.
	var truck := OffroadTruck.new()
	truck.terrain = terrain
	root.add_child(truck)
	var points: PackedVector2Array = terrain.hill_zone.routes[0]["points"]
	var direction := points[1]-points[0]
	truck.position = Vector3(points[0].x,terrain.height_at(Vector3(points[0].x,0,points[0].y))+1.2,points[0].y)
	truck.rotation.y = atan2(direction.x,direction.y)
	for i in 150:
		await physics_frame
	var start := truck.position
	Input.action_press(&"ui_up")
	for i in 220:
		await physics_frame
	Input.action_release(&"ui_up")
	print("HILL DRIVE moved=",snappedf(truck.position.distance_to(start),0.1)," height_gain=",snappedf(truck.position.y-start.y,0.1))
	check(truck.position.distance_to(start)>6 and truck.position.y>start.y+1,"scout physically climbs easy route entry")
	truck.free()
	terrain.free()
	print("HILL ZONE changed_vertices=%d failures=%d" % [changed,failures.size()])
	quit(0 if failures.is_empty() else 1)
