extends SceneTree
## Arxa işıqlar yoxlaması (gecə, əyləc + qəza işığı), 3 Lada üçün: docs/qaraj/arxa_<indeks>.png
## godot --path . --resolution 1280x720 -s res://tests/rear_shot.gd
var main: Node
var cam: Camera3D
var f := 0
var idx := 5
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 35.0
	main.add_child(cam)
func _physics_process(_d: float) -> bool:
	var t: OffroadTruck = main.truck
	var k := f % 200
	f += 1
	if k == 1:
		main.select_vehicle(idx)
		if OS.get_cmdline_user_args().has("nolights"):
			t.lights.visible = false
		main.set_night(not OS.get_cmdline_user_args().has("day"))
		t.controls_enabled = false  # əyləc yanır
		main.cam.current = false
		cam.current = true
		main.hud.visible = false
		if not t.lights.hazard:
			t.lights.toggle_hazard()
	if k > 1:
		var b := t.global_transform
		cam.global_position = b.origin - b.basis.z * 3.4 + b.basis.x * 0.5 + Vector3(0, 0.45, 0)
		cam.look_at(b.origin - b.basis.z * 2.1 + Vector3(0, 0.1, 0), Vector3.UP)
	if k == 150:
		root.get_texture().get_image().save_png("res://docs/qaraj/arxa_%d.png" % idx)
		idx += 1
		if idx > 5:
			quit(0)
	return false
