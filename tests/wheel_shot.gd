extends SceneTree
## Ön təkərin yaxın kadrı (hər iki tərəf): docs/qaraj/tekar_<indeks>_<sol|sag>.png
## godot --path . --resolution 1280x720 -s res://tests/wheel_shot.gd -- 5
var main: Node
var cam: Camera3D
var f := 0
var side := 1.0
var idx := 5
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		idx = int(a[0])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 30.0
	main.add_child(cam)
func _physics_process(_d: float) -> bool:
	var t: OffroadTruck = main.truck
	f += 1
	if f == 1:
		main.select_vehicle(idx)
		t.controls_enabled = false
		main.cam.current = false
		cam.current = true
		main.hud.visible = false
		t.lights.visible = false
	if f > 1:
		var b := t.global_transform
		var w := t.wheels[3 if side > 0 else 2]
		cam.global_position = w.global_position + b.basis.x * side * 2.4 + b.basis.z * 1.4 + Vector3(0, 0.5, 0)
		cam.look_at(w.global_position, Vector3.UP)
	if f == 160 or f == 300:
		var nm := "sag" if side > 0 else "sol"
		root.get_texture().get_image().save_png("res://docs/qaraj/tekar_%d_%s.png" % [idx, nm])
		side = -side
	if f == 300:
		quit(0)
	return false
