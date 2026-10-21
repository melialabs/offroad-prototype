extends SceneTree
## Gecə fənər kadrları (3 Lada): ön fənər + arxa əyləc/qəza. docs/qaraj/fener_<indeks>_<on|arxa>.png
## godot --path . --resolution 1280x720 -s res://tests/lamp_shots.gd
var main: Node
var cam: Camera3D
var f := 0
var idx := 3
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 40.0
	main.add_child(cam)
func _physics_process(_d: float) -> bool:
	var t: OffroadTruck = main.truck
	var k := f % 260
	f += 1
	if k == 1:
		main.select_vehicle(idx)
		main.set_night(true)
		t.controls_enabled = false  # əyləc işığı yanır
		main.cam.current = false
		cam.current = true
		main.hud.visible = false
		t.lights.set_headlights(1)
		if not t.lights.hazard:
			t.lights.toggle_hazard()
	if k > 1:
		var b := t.global_transform
		var front := k < 130
		var s := 1.0 if front else -1.0
		cam.global_position = b.origin + b.basis.z * s * 4.0 + b.basis.x * 1.6 + Vector3(0, 0.9, 0)
		cam.look_at(b.origin + b.basis.z * s * 1.5 + Vector3(0, 0.3, 0), Vector3.UP)
	if k == 125 or k == 250:
		# qəza işığının yanan fazasını tut
		var ok := false
		for i in 40:
			ok = t.lights.get("_last_amber") == true
			if ok:
				break
		root.get_texture().get_image().save_png("res://docs/qaraj/fener_%d_%s.png" % [idx, "on" if k == 125 else "arxa"])
	if k == 250:
		idx += 1
		if idx > 5:
			quit(0)
	return false
