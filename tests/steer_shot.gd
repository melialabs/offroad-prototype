extends SceneTree
## Vizual yoxlama: sükan sola basılı vəziyyətdə kadr çəkmək üçün.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/steer_shot.gd

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_left")
	Input.action_press(&"ui_up")


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 150:
		quit(0)
	return false
