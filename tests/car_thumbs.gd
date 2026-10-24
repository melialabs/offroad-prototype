extends SceneTree
## Qaraj kartları üçün maşın şəkilləri: hər texnika yolun üstündə 3/4 kadrdan çəkilir.
## godot --path . --resolution 1280x720 -s res://tests/car_thumbs.gd   (başsız yox, real render lazımdır)
## Nəticə: assets/ui/car_<indeks>.png (384x216)

var DIST := [6.2, 8.5, 9.5, 5.6, 5.6, 5.8]
## İstəyə görə: -- 7 8 9 (yalnız bu indekslər çəkilir); yoxdursa 0..5
var order: Array[int] = [0, 1, 2, 3, 4, 5]
var main: Node
var cam: Camera3D
var frames := 0
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		order.clear()
		for a in args:
			order.append(int(a))
	idx = order[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 40.0
	main.add_child(cam)
	cam.current = true


func _physics_process(_delta: float) -> bool:
	var t: OffroadTruck = main.truck
	var f := frames % 240
	if f == 1:
		main.select_vehicle(idx)
		t.controls_enabled = false
		main.cam.set_process(false)
		main.cam.current = false
		cam.current = true
		main.hud.visible = false
		main.world_map.visible = false
		t.lights.visible = false
	if f > 1:
		var d: float = DIST[idx] if idx < DIST.size() else 6.4
		var base := t.global_transform
		var yaw_fwd := -base.basis.z  # alt: maşın +Z-ə baxır
		cam.global_position = base.origin + base.basis.z * d * 0.82 + base.basis.x * d * 0.75 + Vector3(0, d * 0.28, 0)
		cam.look_at(base.origin + Vector3(0, 0.55, 0), Vector3.UP)
	if f == 200:
		var img := root.get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		var cw := int(h * 16.0 / 9.0)
		var crop := img.get_region(Rect2i((w - cw) / 2, 0, cw, h))
		crop.resize(384, 216, Image.INTERPOLATE_LANCZOS)
		crop.save_png("res://assets/ui/car_%d.png" % idx)
		var pos := order.find(idx) + 1
		if pos >= order.size():
			quit(0)
			return false
		idx = order[pos]
	frames += 1
	return false
