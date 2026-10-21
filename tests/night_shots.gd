extends SceneTree
## Gecə rejimi, fənərlər və qəza işıqları üçün kadrlar.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/night_shots.gd
## Render kadrları: 30 gündüz, 70 gecə yaxın fənər, 110 uzaq fənər, 150 qəza işıqları (dayanıb), 190 yan kamera.

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1
	var t: OffroadTruck = main.truck
	if frames == 100:
		main.set_night(true)
	if frames == 180:
		t.lights.set_headlights(2)
	if frames == 260:
		t.lights.set_headlights(1)
		t.lights.toggle_hazard()
		Input.action_press(&"ui_down")
	if frames == 340:
		main.cam.mode = ChaseCamera.Mode.FAR
	if frames == 400:
		quit(0)
	return false
