class_name BarnFinds
extends Node3D
## Xəritədə gizli köhnə qarajlar: içində örtük altında kilidli maşın gözləyir. Yaxınlaşanda örtük
## götürülür və maşın açılır (qarajda görünür); C ilə dərhal götürmək olar.
## Model: assets/barn/old_garage.glb (fotoskan, qapılar modelin +Z tərəfində).

signal discovered(spec: int)

const MODEL := "res://assets/barn/old_garage.glb"
## Qarajın ölçüsü: 0.75 -> təxminən 7.5 x 9.1 m, hündürlük ~5.3 m (maşınlardan xeyli böyük). Aşağıdakı ölçülər buna görə hesablanır.
const SCALE := 0.75
const MODEL_GROUND := Vector3(1.66, 1.107, -0.22)  # modeldə döşəmənin mərkəzi
## Skan modeldə ~23° fırlanıb: döndərib mərkəzləyirik ki, qapılar düz +Z-ə baxsın.
const MODEL_YAW := 0.398
# Model vahidlərində (miqyasdan əvvəl) ölçülüb; oyunda SCALE ilə vurulur.
const CENTER_UNITS := Vector3(-0.071, 0.0, -0.357)  # divarların mərkəzi (döndərmədən əvvəl)
const PIVOT_UNITS := Vector3(-0.238, 0.0, -0.119)
const HALF_UNITS := Vector3(5.0, 3.57, 6.07)
const MODEL_CENTER := CENTER_UNITS * SCALE
const PIVOT_OFFSET := PIVOT_UNITS * SCALE
const HALF := HALF_UNITS * SCALE  # oyunda yarım ölçülər (m)
## Fotoskanda qapının sağ küncündə (+X, +Z) deşik var: sağlam sol küncün güzgülənmiş həndəsəsi ilə
## bağlanır (tools/make_barn_corner.gd ilə hazırlanıb).
const CORNER_FILL := "res://assets/barn/corner_fill.res"
const SITES := [
	{"id": "barn_west", "p": Vector2(-756, 84), "vehicle": 6},
	{"id": "barn_east", "p": Vector2(828, -228), "vehicle": 5},
	{"id": "barn_south", "p": Vector2(204, 804), "vehicle": 4},
]
const CLEAR_RADIUS := 17.0
const DISCOVER_RANGE := 18.0
const TAKE_RANGE := 10.0
## GPS-də "şayiə" dairəsi: tapılmamış qaraj təxmini sahədə göstərilir
const RUMOR_RADIUS := 70.0
const RUMOR_OFFSET := [Vector2(28, -22), Vector2(-25, 30), Vector2(20, 26)]

var truck: OffroadTruck
var main: Node
var sites: Array[Dictionary] = []


## Bitki örtüyü qarajların ətrafında yer saxlayır (MudTerrain.activity_clearing).
static func clearing(p: Vector3) -> bool:
	for s in SITES:
		if Vector2(p.x, p.z).distance_to(s["p"]) < CLEAR_RADIUS:
			return true
	return false


func build(terrain: MudTerrain) -> void:
	var scene := load(MODEL) as PackedScene if ResourceLoader.exists(MODEL) else null
	for i in SITES.size():
		var s: Dictionary = SITES[i]
		var c2: Vector2 = s["p"]
		var dir := _road_dir(terrain, c2)
		var yaw := atan2(dir.x, dir.y)
		var basis := Basis(Vector3.UP, yaw)
		# yamacda: orta hündürlüyə qoyulur, aşağı tərəfdəki boşluğu beton özül doldurur
		var low := INF
		var sum := 0.0
		var pts := [Vector3(-HALF.x, 0, -HALF.z), Vector3(HALF.x, 0, -HALF.z), Vector3(-HALF.x, 0, HALF.z), Vector3(HALF.x, 0, HALF.z), Vector3.ZERO]
		for corner in pts:
			var w: Vector3 = Vector3(c2.x, 0, c2.y) + basis * corner
			var hh := terrain.height_at(w)
			low = minf(low, hh)
			sum += hh
		var ground := sum / pts.size() - 0.08
		var root := Node3D.new()
		root.transform = Transform3D(basis, Vector3(c2.x, ground, c2.y))
		add_child(root)
		_foundation(root, ground - low + 0.4)
		if scene != null:
			var model := scene.instantiate() as Node3D
			model.scale = Vector3.ONE * SCALE
			model.position = -MODEL_GROUND * SCALE - MODEL_CENTER
			var pivot := Node3D.new()
			pivot.rotation.y = MODEL_YAW
			pivot.position = PIVOT_OFFSET
			pivot.add_child(model)
			root.add_child(pivot)
			_corner_patch(root)
			_make_lit(root)
		_static_box(root, Vector3(0, HALF.y, 0), HALF * 2.0)
		# qapının yanında küçə lampası, qolu qapı qarşısındakı maşına baxır
		var lamp := StreetLamp.new()
		var lp: Vector3 = root.transform * Vector3(HALF.x + 1.2, 0, HALF.z + 0.8)
		lp.y = terrain.height_at(lp) - 0.05
		var toward: Vector3 = basis * Vector3(-1, 0, 1).normalized()
		lamp.transform = Transform3D(Basis(Vector3.UP, atan2(-toward.z, toward.x)), lp)
		add_child(lamp)
		# gizli maşın qapının qarşısında, burnu yola baxır, örtük altında
		var spec: int = s["vehicle"]
		var car_pos := Vector3(0, 0, HALF.z + 3.4)
		var wp: Vector3 = root.transform * car_pos
		wp.y = terrain.height_at(wp)
		var display := _vehicle_display(spec)
		display.transform = Transform3D(basis, wp)
		add_child(display)
		var tarp := _tarp(display)
		var found := VehicleProgress.is_found(s["id"])
		var taken := VehicleProgress.is_taken(s["id"])
		display.visible = not taken
		if found:
			_remove_tarp(display)
		var body := _static_box(display, Vector3(0, 0.9, 0), Vector3(2.0, 1.8, 4.4))
		if taken:
			body.process_mode = Node.PROCESS_MODE_DISABLED
			(body.get_child(0) as CollisionShape3D).disabled = true
		sites.append({"id": s["id"], "spec": spec, "root": root, "display": display, "tarp": tarp,
			"body": body, "found": found, "taken": taken, "rumor": c2 + RUMOR_OFFSET[i % RUMOR_OFFSET.size()]})


func _process(_delta: float) -> void:
	if truck == null or not truck.controls_enabled:
		return
	for s in sites:
		if s["found"]:
			continue
		if truck.global_position.distance_to((s["display"] as Node3D).global_position) < DISCOVER_RANGE:
			_discover(s)


func _unhandled_input(event: InputEvent) -> void:
	if truck == null or not truck.controls_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		var s := nearest_takeable()
		if not s.is_empty():
			take(s)
			get_viewport().set_input_as_handled()


func nearest_takeable() -> Dictionary:
	for s in sites:
		if s["found"] and not s["taken"] and truck.global_position.distance_to((s["display"] as Node3D).global_position) < TAKE_RANGE:
			return s
	return {}


func _discover(s: Dictionary) -> void:
	s["found"] = true
	VehicleProgress.discover(s["id"], s["spec"])
	var tarp: StandardMaterial3D = s["tarp"]
	var display: Node3D = s["display"]
	var tw := create_tween()
	tw.tween_property(tarp, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(func(): _remove_tarp(display))
	truck.message.emit(I18n.t("barn_found") % I18n.vehicle(str(OffroadTruck.SPECS[s["spec"]]["name"])))
	discovered.emit(s["spec"])


## Tapılmış maşını götürür: sürücü həmin maşına keçir, maşın onun yerində dayanır.
func take(s: Dictionary) -> void:
	if main != null and main.get("activities") != null and main.activities.engaged():
		return
	var display: Node3D = s["display"]
	var xf := display.global_transform
	s["taken"] = true
	VehicleProgress.take(s["id"])
	display.visible = false
	(s["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
	((s["body"] as Node).get_child(0) as CollisionShape3D).disabled = true
	truck.apply_spec(s["spec"])
	truck.linear_velocity = Vector3.ZERO
	truck.angular_velocity = Vector3.ZERO
	truck.global_transform = Transform3D(xf.basis, xf.origin + Vector3(0, 1.4, 0))
	truck.message.emit(I18n.t("barn_taken") % I18n.vehicle(str(OffroadTruck.SPECS[s["spec"]]["name"])))


func _foundation(root: Node3D, depth: float) -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(HALF.x * 2.0 + 0.25, depth, HALF.z * 2.0 + 0.25)
	slab.mesh = box
	slab.position = Vector3(0, 0.04 - depth * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.34, 0.31)
	mat.roughness = 1.0
	slab.material_override = mat
	root.add_child(slab)


func _make_lit(node: Node) -> void:
	WorldProps.make_lit(node)


func _corner_patch(root: Node3D) -> void:
	if not ResourceLoader.exists(CORNER_FILL):
		return
	var fill := MeshInstance3D.new()
	fill.mesh = load(CORNER_FILL)
	root.add_child(fill)


func _road_dir(terrain: MudTerrain, c: Vector2) -> Vector2:
	var best := INF
	var target := c + Vector2(0, 1)
	for p in terrain._road:
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			target = p
	return (target - c).normalized()


## Statik maşın modeli: gövdə + təkərlər (CarModel), torpağa oturdulmuş.
func _vehicle_display(spec: int) -> Node3D:
	var node := Node3D.new()
	var sp: Dictionary = OffroadTruck.SPECS[spec]
	var m := CarModel.new()
	if sp.has("car") and m.load_model(sp["car"], float(sp["origin"])):
		var holder := Node3D.new()
		holder.position = Vector3(0, float(sp["origin"]), 0)
		holder.add_child(m.body)
		for k in 4:
			var w := MeshInstance3D.new()
			w.mesh = m.wheel_meshes[k]
			w.position = m.wheel_centers[k]
			holder.add_child(w)
		node.add_child(holder)
	return node


## Örtük: maşının bütün meshlərinə parça materialı geyindirilir (maşının siluetində brezent).
func _tarp(display: Node3D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.28, 0.21)
	mat.roughness = 1.0
	mat.grow = true
	mat.grow_amount = 0.03
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	for n in display.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat
	return mat


func _remove_tarp(display: Node3D) -> void:
	for n in display.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = null


func _static_box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.add_child(col)
	parent.add_child(body)
	return body
