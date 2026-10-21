extends SceneTree
## Eyni kamera mövqelərindən 5 görünüş (yol, yol kənarı, palçıq cığırı, çay sahili, ümumi).
## Hər görünüş 16 fizika kadrı (8 render kadrı) çəkilir, ekran görüntüsü hər görünüşün sonunda götürülür.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/vegetation_shots.gd
## Çıxış kadrları: out00000008.png (yol), ...16 (yol kənarı), ...24 (cığır), ...32 (çay sahili), ...40 (ümumi).

var main: Node
var terrain: MudTerrain
var cam: Camera3D
var frames := 0
var views: Array = []  # [pozisiya, hədəf, ad]


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		terrain = main._terrain
		main.truck.freeze = true
		main.truck.global_position = Vector3(0, 300, 0)
		main.hud.visible = false
		cam = Camera3D.new()
		cam.fov = 65.0
		cam.far = 1500.0
		root.add_child(cam)
		cam.make_current()
		views = _build_views()
		_print_counts()
		_hide_species()
		_apply_season()
	var k := (frames - 4) / 16
	if frames >= 4 and (frames - 4) % 16 == 0 and k < views.size():
		var v: Array = views[k]
		cam.global_position = v[0]
		cam.look_at(v[1])
		print("VIEW ", k, " ", v[2], " kamera=", v[0], " hədəf=", v[1])
	if frames == 4 + 16 * 5 + 2:
		quit(0)
	return false


func _build_views() -> Array:
	var out: Array = []
	var sp := terrain.road_spawn()
	var rp: Vector3 = sp["pos"]
	var yaw: float = sp["yaw"]
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	# 1 yol: maşının arxasından baxış
	out.append([rp - fwd * 8.0 + Vector3(0, 3.5, 0), rp + fwd * 14.0, "yol"])
	# 2 yol kənarı: yolun kənarından meşəyə baxış
	var rp2 := rp + fwd * 40.0
	rp2.y = terrain.height_at(rp2)
	out.append([rp2 + side * 5.0 + Vector3(0, 1.8, 0), rp2 + side * 28.0 + Vector3(0, 2.0, 0), "yol kənarı"])
	# 3 palçıq cığırı
	var tp := Vector3(46.0, 0.0, 2.0)
	tp.y = terrain.height_at(tp)
	out.append([tp + Vector3(-6, 3.0, -6), tp + Vector3(6, 0.5, 6), "palçıq cığırı"])
	# 4 çay sahili: su səviyyəsinə (-2.4) ən yaxın, çox dik olmayan nöqtə (varsa)
	var half := (MudTerrain.N - 1) * 0.5
	var best := Vector3.ZERO
	var best_score := INF
	for i in MudTerrain.N * MudTerrain.N:
		var hh := terrain.h[i]
		var p := Vector3((i % MudTerrain.N - half) * MudTerrain.CELL, hh,
				(i / MudTerrain.N - half) * MudTerrain.CELL)
		if terrain.slope_at(p) > 0.5 or maxf(absf(p.x), absf(p.z)) > 80.0:
			continue
		var score := absf(hh - (-1.6))
		if score < best_score:
			best_score = score
			best = p
	print("RIVERBANK nöqtə=", best, " hündürlük fərqi=", best_score)
	out.append([best + Vector3(9, 3.5, 9), best, "çay sahili"])
	# 5 ümumi görünüş
	out.append([Vector3(-92, 45, -92), Vector3(15, 0, 15), "ümumi"])
	return out


## Diaqnostika: `-- hide=grass_b,fern` kimi arqumentlə növləri gizlədir.
func _hide_species() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("hide="):
			continue
		var prefixes := a.substr(5).split(",")
		for n in main.find_children("*", "MultiMeshInstance3D", true, false):
			for p in prefixes:
				if (n.name as String).begins_with(p + "_"):
					(n as MultiMeshInstance3D).visible = false


## Diaqnostika: `-- season=autumn` fəsil rəng tonunu tətbiq edir (gələcək fəsil sisteminin yoxlanması).
func _apply_season() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "season=autumn":
			main.get_node("Vegetation").call("apply_season_tint", Color(1.0, 0.72, 0.38))


func _print_counts() -> void:
	var total := 0
	for n in main.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		print("MULTIMESH ", n.name, " nümunə=", mm.instance_count)
		total += mm.instance_count
	print("MULTIMESH cəmi nümunə=", total)
