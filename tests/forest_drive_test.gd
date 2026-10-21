extends SceneTree
## Meşədə sürüş: maşın ağaca sürülür, gövdədən keçməməli, dayanmalıdır.
## godot --headless --path . -s res://tests/forest_drive_test.gd

var main: Node
var frames := 0
var tree_pos := Vector3.ZERO
var start_pos := Vector3.ZERO
var dir := Vector3.ZERO
var max_progress := -INF
var min_speed_near := INF


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _pick_tree() -> void:
	var veg: Vegetation = main.get_node("Vegetation")
	var terrain: MudTerrain = main._terrain
	# açıq, düz, yoldan uzaq, ətrafı boş olan bir ağac seç: maşın 14 m yaxından düz gələ bilsin
	for t in veg._big_trees:
		var p: Vector3 = t[0]
		if t[1] != "pine" and t[1] != "fir":
			continue
		var d := Vector3(0, 0, 1)
		var s := p - d * 14.0
		var ok := true
		for k in range(1, 15):
			var q := p - d * float(k)
			if terrain.slope_at(q) > 0.15 or terrain.softness_at(q) > 0.05:
				ok = false
				break
			for u in veg._big_trees:
				var o: Vector3 = u[0]
				if o != p and Vector2(o.x - q.x, o.z - q.z).length() < 3.0:
					ok = false
					break
			if not ok:
				break
		if ok:
			tree_pos = p
			dir = d
			start_pos = Vector3(p.x, terrain.height_at(s) + 1.5, s.z)
			return


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_pick_tree()
		if tree_pos == Vector3.ZERO:
			print("FOREST TEST: uyğun ağac tapılmadı")
			quit(1)
			return true
		var t: OffroadTruck = main.truck
		t.linear_velocity = Vector3.ZERO
		t.rotation = Vector3.ZERO  # +Z irəli
		t.global_position = start_pos
		t.apply_spec(0)
		t.global_position = start_pos
	if frames > 3:
		var t: OffroadTruck = main.truck
		var progress := (t.global_position - start_pos).dot(dir)
		var to_tree := (tree_pos - start_pos).dot(dir)
		max_progress = maxf(max_progress, progress)
		if absf(progress - (to_tree - 2.5)) < 2.0:
			min_speed_near = minf(min_speed_near, t.linear_velocity.length())
	if frames == 420:
		var to_tree := (tree_pos - start_pos).dot(dir)
		var passed := max_progress > to_tree + 0.3
		print("FOREST TEST: ağaca məsafə=%.1f m, maşın maksimum irəliləyiş=%.1f m, ağacdan keçdi=%s, ağac yanında min sürət=%.1f m/s" % [
			to_tree, max_progress, str(passed), min_speed_near])
		quit(0 if not passed else 1)
	return false
