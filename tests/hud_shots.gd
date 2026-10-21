extends SceneTree
## Kamera rejimləri və HUD üçün kadrlar: maşın qazla gedir, 3 rejim ardıcıl göstərilir.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/hud_shots.gd
## Kadrlar (render nömrəsi): 90 yaxın, 120 uzaq, 150 kapot.

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 100:
		Input.action_press(&"ui_left")
	if frames == 170:
		Input.action_release(&"ui_left")
	if frames == 181:
		main.cam.set_mode(ChaseCamera.Mode.FAR)
	if frames == 241:
		main.cam.set_mode(ChaseCamera.Mode.HOOD)
	if frames == 312:
		quit(0)
	return false
