extends SceneTree
## Vizual yoxlama: xəritəyə yuxarıdan baxış kadrı.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/overview_shot.gd

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		main.cam.global_position = Vector3(-95.0, 55.0, -95.0)
		main.cam.look_at(Vector3(15.0, 0.0, 15.0))
		main.hud.visible = false
	if frames == 40:
		quit(0)
	return false
