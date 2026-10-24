extends SceneTree
## Hava kadrları (pəncərə rejimi, GPU lazımdır):
## godot --path . --resolution 1280x720 -s res://tests/weather_shots.gd -- <qovluq>
## Hər preset üçün gündüz kadrı, yağış üçün əlavə gecə kadrı yazılır.

var out_dir := "user://weather_shots"


func _initialize() -> void:
	run.call_deferred()


func shot(name: String, frames := 3) -> void:
	for i in frames:
		await process_frame
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


func settle(frames: int) -> void:
	for i in frames:
		await process_frame


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await settle(30)
	main.menu.start_requested.emit()
	main.truck.controls_enabled = false
	await settle(60)
	for id in WeatherSystem.IDS:
		main.set_weather(id, true)
		await settle(90)
		await shot("day_" + id)
	main.set_weather("storm", true)
	await settle(90)
	await shot("day_storm_calm")
	main.weather.strike(700.0)
	await shot("day_storm_flash", 1)
	await settle(120)
	main.weather.strike(380.0)
	await shot("day_storm_close", 1)
	await settle(100)
	main.set_weather("rain", true)
	main.set_night(true)
	await settle(90)
	await shot("night_rain")
	main.set_weather("fog", true)
	await settle(60)
	await shot("night_fog")
	main.set_weather("storm", true)
	await settle(60)
	main.weather.strike(650.0)
	await shot("night_storm_flash", 1)
	main.set_night(false)
	main.set_weather("cloudy", true)
	main._open_menu(true)
	main.menu._show_page("settings")
	await settle(30)
	await shot("menu_settings")
	quit(0)
