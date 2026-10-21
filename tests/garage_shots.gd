extends SceneTree
## Qaraj səhifəsi (şəkilli kartlar) üçün kadrlar; filmsiz, birbaşa pəncərədən saxlanır.
## godot --path . --resolution 1280x720 -s res://tests/garage_shots.gd

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
		160:
			root.get_texture().get_image().save_png("res://docs/qaraj/qaraj_niva.png")
			main.menu._select_vehicle(5)
		320:
			root.get_texture().get_image().save_png("res://docs/qaraj/qaraj_2106.png")
			quit(0)
	return false
