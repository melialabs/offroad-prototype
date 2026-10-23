extends SceneTree
## Barn finds: three old garages with a tarp-covered locked vehicle each; discovery unlocks it, C/take
## hands it to the player. Uses its own progress file so the player's finds are untouched.
## godot --headless --path . -s res://tests/barn_finds_test.gd
const TEST_SAVE := "user://test_barn_progress.cfg"
var main: Node
var frames := 0
var failures: Array[String] = []
var _real_before := ""

func _initialize() -> void:
	_real_before = FileAccess.get_file_as_string(VehicleProgress.SAVE_PATH)
	VehicleProgress.save_path = TEST_SAVE
	VehicleProgress.reset(true)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("FAIL ", msg)

func _physics_process(_d: float) -> bool:
	frames += 1
	var b: BarnFinds = main.barns
	if frames == 5:
		check(b.sites.size() == 3, "three barns on the map")
		for spec in VehicleProgress.BARN_VEHICLES:
			check(not VehicleProgress.is_unlocked(spec), "barn vehicle starts locked: %d" % spec)
			check(spec not in OffroadTruck.selectable_specs(), "locked vehicle not on number keys: %d" % spec)
		main.menu._refresh_vehicle_buttons()
		check(main.menu._vehicle_buttons[4].disabled and not main.menu._vehicle_buttons[0].disabled, "garage card locked")
		for s in b.sites:
			var r: Node3D = s["root"]
			check(main._terrain.height_at(r.global_position) - r.global_position.y < 0.6, "barn sits on the ground: %s" % s["id"])
			check(not main._terrain.road_distance_fast(r.global_position) < 20.0, "barn is off the road: %s" % s["id"])
			check(BarnFinds.clearing(r.global_position), "vegetation cleared at barn: %s" % s["id"])
			for n in r.find_children("*", "MeshInstance3D", true, false):
				for k in (n as MeshInstance3D).mesh.get_surface_count():
					var m := (n as MeshInstance3D).get_active_material(k) as BaseMaterial3D
					check(m == null or m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "barn responds to light (no unlit glow at night)")
		main.truck.controls_enabled = true
		var s0: Dictionary = b.sites[0]
		main.truck.global_position = (s0["display"] as Node3D).global_position + (s0["root"] as Node3D).global_basis.z * 9.0 + Vector3(0, 2, 0)
	if frames == 60:
		var s0: Dictionary = b.sites[0]
		check(s0["found"], "driving close discovers the barn")
		check(VehicleProgress.is_unlocked(s0["spec"]), "discovered vehicle unlocked")
		check(s0["spec"] in OffroadTruck.selectable_specs(), "discovered vehicle selectable")
		main.truck.global_position = (s0["display"] as Node3D).global_position + (s0["root"] as Node3D).global_basis.z * 6.0 + Vector3(0, 1, 0)
		check(not b.nearest_takeable().is_empty(), "found vehicle can be taken nearby")
		b.take(s0)
		check(main.truck.spec_idx == s0["spec"] and s0["taken"], "taking switches to the found vehicle")
		check(not (s0["display"] as Node3D).visible, "parked display removed after taking")
		var cfg := ConfigFile.new()
		check(cfg.load(TEST_SAVE) == OK and s0["id"] in cfg.get_value("barns", "taken", []), "progress saved")
		check(FileAccess.get_file_as_string(VehicleProgress.SAVE_PATH) == _real_before, "player save untouched")
	if frames == 65:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
		print("BARN FINDS TEST failures=", failures.size())
		quit(0 if failures.is_empty() else 1)
	return false
