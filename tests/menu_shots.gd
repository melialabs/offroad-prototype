extends SceneTree
## Menyu səhifələri və yeni HUD üçün kadrlar.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/menu_shots.gd
## Render kadrları: 30 ana, 55 texnika, 80 idarəetmə, 105 ayarlar, 175 HUD (oyun).

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 70:
		main.menu._show_page("vehicle")
	if frames == 120:
		main.menu._show_page("controls")
	if frames == 170:
		main.menu._show_page("settings")
	if frames == 230:
		main.menu.start_requested.emit()
		Input.action_press(&"ui_up")
	if frames == 400:
		quit(0)
	return false
