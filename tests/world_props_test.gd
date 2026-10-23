extends SceneTree
## World props: buildings/piles placed on the ground off the road, asphalt street lamps spaced apart,
## one lamp beside each barn, and every lamp lights up only at night.
## godot --headless --path . -s res://tests/world_props_test.gd
var main: Node
var frames := 0
var failures: Array[String] = []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("FAIL ", msg)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames != 5:
		return false
	var props: WorldProps = main.props
	var t: MudTerrain = main._terrain
	check(props.get_child_count() >= WorldProps.PROPS.size(), "all props placed")
	for s in WorldProps.PROPS:
		var p: Vector2 = s["p"]
		check(t.road_distance_at(Vector3(p.x, 0, p.y)) > 10.0, "prop off the asphalt: %s" % s["model"])
		check(WorldProps.clearing(Vector3(p.x, 0, p.y)), "vegetation cleared at prop")
	for n in props.find_children("*Wire*", "MeshInstance3D", true, false):
		check(false, "dangling power cables removed")
	var lamps := main.get_tree().get_nodes_in_group("street_lamps")
	check(props.lamps.size() >= 20, "street lamps along the asphalt: %d" % props.lamps.size())
	check(lamps.size() == props.lamps.size() + main.barns.sites.size(), "one extra lamp per barn")
	for i in props.lamps.size() - 1:
		var a := props.lamps[i].global_position
		var b := props.lamps[i + 1].global_position
		check(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) > 60.0, "lamps spaced apart")
		var rd := t.road_distance_at(a)
		check(rd > MudTerrain.ROAD_HALF and rd < MudTerrain.ROAD_HALF + 4.0, "lamp beside the road: %.1f" % rd)
	main.set_night(false)
	for l in lamps:
		check(not (l as StreetLamp)._light.visible, "lamps off by day")
	main.set_night(true)
	for l in lamps:
		check((l as StreetLamp)._light.visible, "lamps on at night")
	main.set_night(false)
	print("WORLD PROPS TEST failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
	return false
