class_name OffroadTruck
extends VehicleBody3D
## Off-road texnikası: mühərrik əyrisi, dişli qutusu (aşağı/yuxarı diapazon),
## AWD, diferensial kilidi, təkər növləri və yanacaq.
## Rəqəmlər öz tərəfimizdən seçilib, heç bir oyundan çıxarılmayıb.

const MAX_SPEED_DRAG := 0.6
const STEER_MAX := 0.5
const IDLE_RPM := 800.0
const REDLINE_RPM := 3000.0
const SHIFT_UP_RPM := 2500.0
const SHIFT_DOWN_RPM := 1000.0
const FINAL_DRIVE := 3.2
const DRIVETRAIN_EFF := 0.85
const GEARS_LOW := [6.5, 4.2]
const GEARS_HIGH := [3.8, 2.6, 1.8, 1.25, 0.9]
const GEAR_REVERSE := -5.0

# awd/diff: "none" yoxdur, "switch" açar-bağlar, "always" həmişə açıq
const SPECS := [
	{"name": "Skaut", "mass": 1800.0, "torque": 450.0, "fuel": 80.0,
		"radius": 0.55, "awd": "switch", "diff": "none", "tire": 1, "model": true},
	{"name": "Yük maşını", "mass": 3500.0, "torque": 800.0, "fuel": 140.0,
		"radius": 0.55, "awd": "switch", "diff": "switch", "tire": 1},
	{"name": "Ağır tır", "mass": 5500.0, "torque": 1300.0, "fuel": 220.0,
		"radius": 0.65, "awd": "always", "diff": "switch", "tire": 2},
]

# hard = bərk yerdə tutuşma, mud = palçıqda tutuşma
const TIRES := [
	{"name": "Şosse", "hard": 3.4, "mud": 0.45},
	{"name": "Dağ", "hard": 2.8, "mud": 1.0},
	{"name": "Palçıq", "hard": 2.2, "mud": 1.6},
]

var terrain: MudTerrain
var wheels: Array[VehicleWheel3D] = []
var wheel_meshes: Array[MeshInstance3D] = []

var spec_idx := 0
var spec: Dictionary = SPECS[0]
var tire_idx := 1
var gear := 1
var low_range := false
var awd_on := false
var diff_lock := false
var fuel := 100.0
var rpm := IDLE_RPM
var mud_level := 0.0  # HUD üçün: orta batma dərəcəsi

var controls_enabled := true  # menyu açıq olanda false: maşın dayanır, düymələr işləmir
var _shift_cooldown := 0.0
var _jeep: JeepModel
var _box_nodes: Array[Node3D] = []
var _jeep_wheel_meshes: Array[MeshInstance3D] = []
var _default_wheel_pos: Array[Vector3] = []
var _jeep_wheel_pos: Array[Vector3] = []


func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	linear_damp = 0.15

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.45, 0.10)
	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.7, 4.2)
	body_mesh.mesh = box
	body_mesh.material_override = mat
	add_child(body_mesh)

	var cab := MeshInstance3D.new()
	var cab_box := BoxMesh.new()
	cab_box.size = Vector3(1.7, 0.7, 1.5)
	cab.mesh = cab_box
	cab.position = Vector3(0, 0.65, 0.9)  # ön tərəf +Z (VehicleBody3D qaydası)
	cab.material_override = mat
	add_child(cab)
	_box_nodes = [body_mesh, cab]

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.9, 4.2)
	col.shape = shape
	add_child(col)

	for pos in [Vector3(-1.0, -0.3, -1.4), Vector3(1.0, -0.3, -1.4),
			Vector3(-1.0, -0.3, 1.4), Vector3(1.0, -0.3, 1.4)]:
		_add_wheel(pos, pos.z > 0.0)
		_default_wheel_pos.append(pos)

	_load_jeep_model()
	apply_spec(spec_idx)


## Jeep modeli assets/jeep/ içindədirsə, gövdəni və təkərləri ona bağlayır.
func _load_jeep_model() -> void:
	var jeep := JeepModel.new()
	if not jeep.load_model():
		push_warning("Jeep modeli tapılmadı, qutu modeli istifadə olunur")
		return
	_jeep = jeep
	add_child(_jeep.body)
	for k in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = _jeep.wheel_meshes[k]
		wheels[k].add_child(mi)
		_jeep_wheel_meshes.append(mi)
		var c := _jeep.wheel_centers[k] - _jeep.origin
		# bağlantı nöqtəsi təkər mərkəzindən asmanın rahat uzunluğu qədər yuxarıdadır
		_jeep_wheel_pos.append(c + Vector3(0, wheels[k].wheel_rest_length, 0))


func _add_wheel(pos: Vector3, front: bool) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.wheel_rest_length = 0.35
	w.suspension_travel = 0.5
	w.suspension_stiffness = 30.0
	w.damping_compression = 1.6
	w.damping_relaxation = 1.9
	w.wheel_roll_influence = 0.4

	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.rotation_degrees = Vector3(0, 0, 90)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.08)
	mesh.material_override = m
	w.add_child(mesh)
	add_child(w)
	wheels.append(w)
	wheel_meshes.append(mesh)


## Texnikanı dəyişir: kütlə, təkər ölçüsü, yanacaq, AWD və diferensial vəziyyəti.
func apply_spec(idx: int) -> void:
	spec_idx = clampi(idx, 0, SPECS.size() - 1)
	spec = SPECS[spec_idx]
	mass = float(spec["mass"])
	tire_idx = int(spec["tire"])
	fuel = float(spec["fuel"])
	gear = 1
	low_range = false
	awd_on = spec["awd"] == "always"
	diff_lock = spec["diff"] == "always"
	var r := float(spec["radius"])
	var use_model: bool = spec.get("model", false) and _jeep != null
	if use_model:
		r = _jeep.wheel_radius
	for node in _box_nodes:
		node.visible = not use_model
	if _jeep != null:
		_jeep.body.visible = use_model
	for i in wheels.size():
		wheels[i].wheel_radius = r
		wheels[i].suspension_max_force = mass * 10.0
		wheels[i].position = _jeep_wheel_pos[i] if use_model else _default_wheel_pos[i]
		wheel_meshes[i].visible = not use_model
		if i < _jeep_wheel_meshes.size():
			_jeep_wheel_meshes[i].visible = use_model
		var cyl: CylinderMesh = wheel_meshes[i].mesh
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 0.5
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_Q:
			low_range = not low_range
			gear = clampi(gear, 1, _forward_gears().size())
		KEY_E:
			if spec["awd"] == "switch":
				awd_on = not awd_on
		KEY_F:
			if spec["diff"] == "switch":
				diff_lock = not diff_lock
		KEY_T:
			tire_idx = (tire_idx + 1) % TIRES.size()
		KEY_1:
			apply_spec(0)
		KEY_2:
			apply_spec(1)
		KEY_3:
			apply_spec(2)


func _forward_gears() -> Array:
	return GEARS_LOW if low_range else GEARS_HIGH


func _ratio() -> float:
	if gear < 0:
		return GEAR_REVERSE
	var g := _forward_gears()
	return g[clampi(gear - 1, 0, g.size() - 1)]


func _torque_at(r: float) -> float:
	if r >= REDLINE_RPM:
		return 0.0
	var x := (r - 1800.0) / 2000.0
	return float(spec["torque"]) * clampf(1.0 - x * x * 0.75, 0.25, 1.0)


func _physics_process(delta: float) -> void:
	var want := Input.get_axis(&"ui_down", &"ui_up")
	if Input.is_physical_key_pressed(KEY_W):
		want = 1.0
	elif Input.is_physical_key_pressed(KEY_S):
		want = -1.0
	var steer := Input.get_axis(&"ui_right", &"ui_left")
	if Input.is_physical_key_pressed(KEY_A):
		steer = 1.0
	elif Input.is_physical_key_pressed(KEY_D):
		steer = -1.0

	if not controls_enabled:
		want = 0.0
		steer = 0.0

	# irəli/geri qərarı: hərəkətin əksinə basanda əyləc
	var fwd_speed := linear_velocity.dot(global_transform.basis.z)
	var drive := 0.0
	var braking := 0.0
	if want > 0.0:
		if fwd_speed < -1.5:
			braking = 1.0
		else:
			drive = want
			if gear < 0:
				gear = 1
	elif want < 0.0:
		if fwd_speed > 1.5:
			braking = 1.0
		else:
			drive = -want
			gear = -1
	if Input.is_physical_key_pressed(KEY_SPACE) or not controls_enabled:
		braking = 1.0
	if fuel <= 0.0:
		drive = 0.0

	# aparıcı təkərlər
	var driven: Array[VehicleWheel3D] = []
	for w in wheels:
		w.use_as_traction = awd_on or w.position.z < 0.0  # arxa təkərlər həmişə aparıcıdır
		if w.use_as_traction:
			driven.append(w)

	# mühərrik dövrü təkərlərin fırlanmasından hesablanır
	var rpm_sum := 0.0
	var contact_n := 0
	var min_skid := 1.0
	for w in driven:
		if w.is_in_contact():
			rpm_sum += absf(w.get_rpm())
			contact_n += 1
			min_skid = minf(min_skid, w.get_skidinfo())
		else:
			min_skid = 0.0
	var ratio := absf(_ratio()) * FINAL_DRIVE
	var target_rpm := IDLE_RPM
	if contact_n > 0:
		target_rpm = maxf(IDLE_RPM, rpm_sum / contact_n * ratio)
	rpm = minf(lerpf(rpm, target_rpm, 0.25), REDLINE_RPM + 200.0)

	# avtomatik dişli dəyişmə
	_shift_cooldown -= delta
	if gear > 0 and _shift_cooldown <= 0.0:
		if rpm > SHIFT_UP_RPM and gear < _forward_gears().size():
			gear += 1
			_shift_cooldown = 0.5
		elif rpm < SHIFT_DOWN_RPM and gear > 1:
			gear -= 1
			_shift_cooldown = 0.5

	# açıq diferensial: sürüşən təkər gücü aparır, kilid bunu aradan qaldırır
	var diff_factor := 1.0
	if not diff_lock:
		diff_factor = lerpf(1.0, clampf(min_skid, 0.3, 1.0), 0.7)

	var wheel_r := float(spec["radius"])
	var total_force := _torque_at(rpm) * _ratio() * FINAL_DRIVE * DRIVETRAIN_EFF / wheel_r * drive
	if driven.size() > 0:
		engine_force = total_force * diff_factor / driven.size()
	else:
		engine_force = 0.0
	brake = braking * mass * 0.05

	# hava müqaviməti
	apply_central_force(-linear_velocity * linear_velocity.length() * MAX_SPEED_DRAG)

	# yanacaq
	var burn := 0.0015 + drive * rpm / REDLINE_RPM * 0.05
	if awd_on:
		burn *= 1.15
	fuel = maxf(fuel - burn * delta, 0.0)

	# təkər-yer qarşılıqlı təsiri
	var tire: Dictionary = TIRES[tire_idx]
	var total_depth := 0.0
	var soft_sum := 0.0
	for w in wheels:
		if not w.is_in_contact() or terrain == null:
			continue
		var contact := w.global_position - Vector3.UP * w.wheel_radius
		var soft := terrain.softness_at(contact)
		var depth := terrain.depth_at(contact)
		total_depth += depth
		soft_sum += soft
		var mud := clampf(soft * 0.6 + depth / MudTerrain.MAX_DEPTH * 0.6, 0.0, 1.0)
		w.wheel_friction_slip = lerpf(float(tire["hard"]), float(tire["mud"]), mud)
		var spin := absf(w.get_rpm()) / 100.0
		terrain.deform(contact, 1.3, delta * (0.05 + 0.25 * minf(spin, 1.0)))
	mud_level = total_depth / 4.0 / MudTerrain.MAX_DEPTH

	# sükan: sürətlə azalır, bərk yerdə kilid sükanı çətinləşdirir
	var steer_limit := STEER_MAX / (1.0 + linear_velocity.length() * 0.08)
	if diff_lock and soft_sum / 4.0 < 0.2:
		steer_limit *= 0.6
	steering = move_toward(steering, steer * steer_limit, delta * 2.0)


func hud_text() -> String:
	var gear_txt := "R" if gear < 0 else str(gear)
	var awd_txt := "həmişə" if spec["awd"] == "always" else ("açıq" if awd_on else "bağlı")
	var diff_txt := "yoxdur"
	if spec["diff"] != "none":
		diff_txt = "kilidli" if diff_lock else "açıq"
	var tire: Dictionary = TIRES[tire_idx]
	return "%s | dişli %s (%s) | %d dövr | yanacaq %d L\nAWD: %s [E] | diff kilid: %s [F] | təkər: %s [T] | diapazon [Q]" % [
		spec["name"], gear_txt, "aşağı" if low_range else "yuxarı", int(rpm), int(fuel),
		awd_txt, diff_txt, tire["name"]]
