extends SceneTree
## Qaraj səhifəsi və Lada modelləri üçün kadrlar.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/garage_shots.gd
## Render kadrları (~fizika/2): 40 qaraj+Niva, 100 2107 menyu, 160 2106 menyu, 220 Niva oyunda, 280 2106 gecə

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		10:
			main.menu._show_page("vehicle")
			main.menu._select_vehicle(3)
		150:
			main.menu._select_vehicle(4)
		270:
			main.menu._select_vehicle(5)
		390:
			main.menu._select_vehicle(3)
			main.menu.start_requested.emit()
			main.truck.toggle_engine()
			Input.action_press(&"ui_up")
		560:
			main.menu._select_vehicle(5) if false else null
			main.select_vehicle(5)
			main.truck.toggle_engine()
			main.set_night(true)
		680:
			quit(0)
	return false
