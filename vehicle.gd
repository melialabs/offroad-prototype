class_name OffroadTruck
extends VehicleBody3D
## Off-road texnikası: mühərrik əyrisi, dişli qutusu (aşağı/yuxarı diapazon),
## AWD, diferensial kilidi, təkər növləri və yanacaq.
## Rəqəmlər öz tərəfimizdən seçilib, heç bir oyundan çıxarılmayıb.

const STEER_MAX := 0.5
const IDLE_RPM := 800.0
const DRIVETRAIN_EFF := 0.85
## Yük altında oturmuş asmanın ölçülmüş uzanması (m). Hardtail Lada modellərində təkər mərkəzi modeldəki yerə düşür.
const SETTLED_EXTENSION := 0.25

# awd/diff: "none" yoxdur, "switch" açar-bağlar, "always" həmişə açıq
const SPECS := [
	{"name": "Skaut", "mass": 1800.0, "torque": 340.0, "fuel": 80.0,
		"radius": 0.55, "awd": "switch", "diff": "none", "tire": 1, "model": true},
	{"name": "Yük maşını", "mass": 3500.0, "torque": 650.0, "fuel": 140.0,
		"radius": 0.55, "awd": "switch", "diff": "switch", "tire": 1},
	{"name": "Ağır tır", "mass": 5500.0, "torque": 1250.0, "fuel": 220.0,
		"radius": 0.65, "awd": "always", "diff": "switch", "tire": 2},
	# Lada modelləri (CC BY 4.0, CREDITS.md): real kütlə, zəif mühərrik, yalnız Niva dörd təkərli
	{"name": "Lada Niva", "mass": 1250.0, "torque": 140.0, "fuel": 42.0,
		"radius": 0.36, "awd": "always", "diff": "switch", "tire": 1,
		"car": "res://assets/cars/lada_niva.glb", "origin": 0.8, "lights": [0.55, 0.78, 0.55, 0.62]},
	{"name": "Lada 2107", "mass": 1050.0, "torque": 125.0, "fuel": 39.0,
		"radius": 0.28, "awd": "none", "diff": "none", "tire": 0,
		"car": "res://assets/cars/lada_2107.glb", "origin": 0.72, "lights": [0.55, 0.7, 0.55, 0.78]},
	{"name": "Lada 2106", "mass": 1030.0, "torque": 116.0, "fuel": 39.0,
		"radius": 0.3, "awd": "none", "diff": "none", "tire": 0,
		"car": "res://assets/cars/lada_2106.glb", "origin": 0.72, "lights": [0.5, 0.55, 0.5, 0.74]},
	# User-supplied UAZ models. Indices are appended to preserve vehicle records.
	# Torque/suspension are gameplay tuning, not manufacturer specifications.
	{"name": "UAZ Expedition", "mass": 2300.0, "torque": 520.0, "fuel": 90.0,
		"radius": 0.468, "awd": "switch", "diff": "switch", "tire": 2,
		"car": "res://assets/cars/uaz_expedition.glb", "origin": 1.05, "lights": [0.66, 1.0, 1.36, 1.3],
		"collision_size": Vector3(2.0, 0.85, 4.8), "collision_offset": Vector3(0, 0.15, -0.1)},
	{"name": "UAZ 452 Bukhanka", "mass": 1900.0, "torque": 430.0, "fuel": 77.0,
		"radius": 0.43, "awd": "switch", "diff": "switch", "tire": 1,
		"car": "res://assets/cars/uaz_452.glb", "origin": 0.95, "lights": [0.6, 0.85, 1.08, 1.05],
		"collision_size": Vector3(1.95, 0.9, 4.4), "collision_offset": Vector3(0, 0.15, -0.05)},
	{"name": "UAZ 469 Classic", "mass": 1700.0, "torque": 400.0, "fuel": 78.0,
		"radius": 0.404, "awd": "switch", "diff": "switch", "tire": 1,
		"car": "res://assets/cars/uaz_469.glb", "origin": 0.9, "lights": [0.6, 0.75, 1.08, 0.85],
		"collision_size": Vector3(1.72, 0.8, 3.95), "collision_offset": Vector3(0, 0.08, -0.02)},
]

# hard = bərk yerdə tutuşma, mud = palçıqda tutuşma
const TIRES := [
	{"name": "Şosse", "asphalt": 3.8, "hard": 3.4, "mud": 0.45},
	{"name": "Dağ", "asphalt": 3.2, "hard": 2.8, "mud": 1.0},
	{"name": "Palçıq", "asphalt": 2.5, "hard": 2.2, "mud": 1.6},
]

## Separate response for scout, trucks, Niva and road cars. Rest length stays
## unchanged so existing model wheel mounts remain valid.
const SUSPENSIONS := [
	{"stiffness": 28.0, "travel": 0.5, "compression": 1.8, "rebound": 2.2, "width": 0.32},
	{"stiffness": 36.0, "travel": 0.45, "compression": 2.0, "rebound": 2.4, "width": 0.40},
	{"stiffness": 42.0, "travel": 0.4, "compression": 2.2, "rebound": 2.6, "width": 0.50},
	{"stiffness": 30.0, "travel": 0.42, "compression": 1.8, "rebound": 2.2, "width": 0.23},
	{"stiffness": 32.0, "travel": 0.26, "compression": 2.0, "rebound": 2.5, "width": 0.19},
	{"stiffness": 32.0, "travel": 0.26, "compression": 2.0, "rebound": 2.5, "width": 0.19},
	{"stiffness": 30.0, "travel": 0.48, "compression": 1.9, "rebound": 2.3, "width": 0.34},
	{"stiffness": 30.0, "travel": 0.42, "compression": 1.9, "rebound": 2.3, "width": 0.25},
	{"stiffness": 30.0, "travel": 0.44, "compression": 1.8, "rebound": 2.2, "width": 0.25},
]

var mud_spray: MudSpray
var terrain: MudTerrain
var wheels: Array[VehicleWheel3D] = []
var wheel_meshes: Array[MeshInstance3D] = []

var spec_idx := 0
var spec: Dictionary = SPECS[0]
var powertrain: Dictionary = VehicleDynamics.for_vehicle(0)
var throttle := 0.0
var shift_remaining := 0.0
signal gear_changed(previous: int, current: int)
signal vehicle_changed(index: int)
var tire_idx := 1
var gear := 1
var low_range := false
var awd_on := false
var diff_lock := false
var fuel := 100.0
var rpm := IDLE_RPM
var mud_level := 0.0  # HUD üçün: orta batma dərəcəsi
var wheel_slip := 0.0  # excess tread speed in m/s, averaged over contacting wheels

## HUD-a bildiriş göndərir (məs. mühərrik, işıq).
signal message(text: String)

enum EngineState { OFF, CRANKING, RUNNING }
const CRANK_TIME := 0.9

var controls_enabled := true  # menyu açıq olanda false: maşın dayanır, düymələr işləmir
## Standart: işləyir (testlər üçün). Yeni oyun başlayanda main.gd söndürür, I düyməsi ilə işə salınır.
var engine_state: int = EngineState.RUNNING
var lights: VehicleLights
var _crank_t := 0.0
var _shift_cooldown := 0.0
var _jeep: JeepModel
var _box_nodes: Array[Node3D] = []
## spec indeksi -> {model: CarModel, meshes: Array[MeshInstance3D], pos: Array[Vector3]}
var _cars: Dictionary = {}
var _col: CollisionShape3D
var _default_wheel_pos: Array[Vector3] = []
var _jeep_wheel_pos: Array[Vector3] = []


func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	# Aerodynamic drag is applied below; avoid the default damping acting
	# as a large hidden speed limiter on every powertrain.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.012

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
	_col = col

	for pos in [Vector3(-1.0, -0.3, -1.4), Vector3(1.0, -0.3, -1.4),
			Vector3(-1.0, -0.3, 1.4), Vector3(1.0, -0.3, 1.4)]:
		_add_wheel(pos, pos.z > 0.0)
		_default_wheel_pos.append(pos)

	_load_jeep_model()
	_load_cars()
	lights = VehicleLights.new()
	add_child(lights)
	apply_spec(spec_idx)
	mud_spray = MudSpray.new()
	add_child(mud_spray)


## Jeep modeli assets/jeep/ içindədirsə, gövdəni və təkərləri ona bağlayır.
func _load_jeep_model() -> void:
	var jeep := JeepModel.new()
	if not jeep.load_model():
		push_warning("Jeep modeli tapılmadı, qutu modeli istifadə olunur")
		return
	_jeep = jeep
	add_child(_jeep.body)
	for k in 4:
		var c := _jeep.wheel_centers[k] - _jeep.origin
		# bağlantı nöqtəsi təkər mərkəzindən asmanın rahat uzunluğu qədər yuxarıdadır
		_jeep_wheel_pos.append(c + Vector3(0, wheels[k].wheel_rest_length, 0))


## Lada modellərini yükləyir (fayl yoxdursa o texnika qutu kimi qalır).
func _load_cars() -> void:
	for i in SPECS.size():
		var sp: Dictionary = SPECS[i]
		if not sp.has("car"):
			continue
		var m := CarModel.new()
		if not m.load_model(sp["car"], float(sp["origin"])):
			push_warning("Maşın modeli tapılmadı: " + str(sp["car"]))
			continue
		add_child(m.body)
		m.body.visible = false
		var pos: Array[Vector3] = []
		for k in 4:
			# bağlantı nöqtəsi: asma yükün altında oturan (≈0.25 m uzanmış) vəziyyətdə təkər modeldəki yerində olsun
			pos.append(m.wheel_centers[k] + Vector3(0, SETTLED_EXTENSION, 0))
		_cars[i] = {"model": m, "pos": pos}


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
	powertrain = VehicleDynamics.for_vehicle(spec_idx)
	throttle = 0.0
	shift_remaining = 0.0
	_shift_cooldown = 0.0
	if engine_state == EngineState.RUNNING:
		rpm = float(powertrain["idle"])
	mass = float(spec["mass"])
	tire_idx = int(spec["tire"])
	fuel = float(spec["fuel"])
	gear = 1
	low_range = false
	awd_on = spec["awd"] == "always"
	diff_lock = spec["diff"] == "always"
	var r := float(spec["radius"])
	var car: Dictionary = _cars.get(spec_idx, {})
	var use_car := not car.is_empty()
	var use_jeep: bool = spec.get("model", false) and _jeep != null
	var use_model := use_car or use_jeep
	_col.position = spec.get("collision_offset", Vector3.ZERO)
	if use_car:
		r = (car["model"] as CarModel).wheel_radius
	elif use_jeep:
		r = _jeep.wheel_radius
	for node in _box_nodes:
		node.visible = not use_model
	if _jeep != null:
		_jeep.body.visible = use_jeep
	for k in _cars:
		(_cars[k]["model"] as CarModel).body.visible = (k == spec_idx)
	if use_car:
		var cm: CarModel = car["model"]
		var box := _col.shape as BoxShape3D
		box.size = spec.get("collision_size", Vector3(cm.width * 0.9, 0.7, cm.length - 0.1))
		var lp: Array = spec["lights"]
		var half := cm.length * 0.5
		var oh := float(spec["origin"])
		lights.layout(half - 0.1, -half + 0.1, lp[0], lp[1], lp[2] - oh + 0.1, lp[3] - oh)
		if not cm.head_lamps.is_empty() and not cm.tail_lamps.is_empty():
			lights.bind_model_lamps(cm.head_lamps, cm.head_lamp_pos, cm.tail_lamps, cm.tail_lamp_pos)
			lights.set_lens_visible(false)
		else:
			lights.clear_model_lamps()
			lights.set_lens_visible(true)
	elif use_jeep:
		(_col.shape as BoxShape3D).size = Vector3(1.8, 0.9, 4.2)
		lights.clear_model_lamps()
		# Measured on the original grille lens geometry, converted to body space.
		# Avoid adding round fallback lenses in front of the model's square lamps.
		lights.layout(2.295 - _jeep.origin.z, -2.08, 0.515, 0.76,
			1.436 - _jeep.origin.y, 0.2)
		lights.set_lens_visible(true)
		lights.set_front_lens_visible(false)
		if _jeep.head_lamps.size() == 2:
			var tail: Array[MeshInstance3D] = []
			var tail_pos: Array[Vector3] = [lights.TAIL_POS[0], lights.TAIL_POS[1]]
			lights.bind_model_lamps(_jeep.head_lamps, _jeep.head_lamp_pos, tail, tail_pos)
	else:
		(_col.shape as BoxShape3D).size = Vector3(1.8, 0.9, 4.2)
		lights.clear_model_lamps()
		lights.layout(2.1, -2.08, 0.58, 0.76, 0.22, 0.2)
		lights.set_lens_visible(true)
	var positions: Array = []
	var meshes: Array = []
	for i in 4:
		if use_car:
			positions.append(car["pos"][i])
			meshes.append((car["model"] as CarModel).wheel_meshes[i])
		elif use_jeep:
			positions.append(_jeep_wheel_pos[i])
			meshes.append(_jeep.wheel_meshes[i])
		else:
			positions.append(_default_wheel_pos[i])
			meshes.append(null)
	_rebuild_wheels(r, positions, meshes)
	var suspension: Dictionary = SUSPENSIONS[spec_idx]
	for w in wheels:
		w.suspension_stiffness = float(suspension["stiffness"])
		w.suspension_travel = float(suspension["travel"])
		w.damping_compression = float(suspension["compression"])
		w.damping_relaxation = float(suspension["rebound"])
	mud_level = 0.0
	wheel_slip = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	vehicle_changed.emit(spec_idx)


## Godot VehicleWheel3D bağlantı nöqtəsini yalnız ağaca ilk girəndə oxuyur: işləmə vaxtı position
## dəyişmək təsir etmir, yerində təkrar əlavə etmək də sonradan sürüşməyə səbəb olur. Ona görə texnika
## dəyişəndə təkərlər silinir və düzgün mövqedə yenidən yaradılır.
func _rebuild_wheels(r: float, positions: Array, meshes: Array) -> void:
	for w in wheels:
		remove_child(w)
		w.queue_free()
	wheels.clear()
	wheel_meshes.clear()
	for k in 4:
		_add_wheel(positions[k], k >= 2)  # sıra: 0,1 arxa (-x,+x), 2,3 ön
		var w := wheels[k]
		w.wheel_radius = r
		w.suspension_max_force = mass * 10.0
		var cyl: CylinderMesh = wheel_meshes[k].mesh
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 0.5
		if meshes[k] != null:
			wheel_meshes[k].visible = false
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[k]
			w.add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_I:
			toggle_engine()
		KEY_L:
			message.emit(lights.cycle_headlights())
		KEY_Z:
			message.emit(lights.toggle_hazard())
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
		KEY_4:
			apply_spec(3)
		KEY_5:
			apply_spec(4)
		KEY_6:
			apply_spec(5)
		KEY_7:
			apply_spec(6)
		KEY_8:
			apply_spec(7)
		KEY_9:
			apply_spec(8)


## Mühərriki işə sal / söndür (I düyməsi).
func toggle_engine() -> void:
	if engine_state == EngineState.OFF:
		if fuel <= 0.0:
			message.emit("Yanacaq yoxdur, mühərrik işə düşmür")
			return
		engine_state = EngineState.CRANKING
		_crank_t = CRANK_TIME
		message.emit("Mühərrik işə düşür...")
	else:
		engine_state = EngineState.OFF
		message.emit("Mühərrik söndürüldü")


## Səssiz söndürmə (yeni oyun başlayanda).
func stop_engine() -> void:
	engine_state = EngineState.OFF
	rpm = 0.0


func _forward_gears() -> Array:
	return powertrain["gears"]


func _ratio() -> float:
	if gear < 0:
		return -float(powertrain["reverse"]) * (float(powertrain["low"]) if low_range else 1.0)
	var g := _forward_gears()
	return float(g[clampi(gear - 1, 0, g.size() - 1)]) * (float(powertrain["low"]) if low_range else 1.0)


func _torque_at(r: float) -> float:
	return VehicleDynamics.torque_at(powertrain,r)

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
	if fuel <= 0.0 and engine_state != EngineState.OFF:
		engine_state = EngineState.OFF
		message.emit("Yanacaq bitdi, mühərrik söndü")
	if engine_state == EngineState.CRANKING:
		_crank_t -= delta
		if _crank_t <= 0.0:
			engine_state = EngineState.RUNNING
			message.emit("Mühərrik işləyir")
	var running := engine_state == EngineState.RUNNING
	if not running or fuel <= 0.0:
		drive = 0.0

	throttle = move_toward(throttle, drive, delta * float(powertrain["response"]))
	shift_remaining = maxf(0.0, shift_remaining - delta)
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
	var ratio := absf(_ratio()) * float(powertrain["final"])
	var idle := float(powertrain["idle"])
	var redline := float(powertrain["redline"])
	var target_rpm := idle
	if contact_n > 0:
		target_rpm = maxf(idle, rpm_sum / contact_n * ratio)
	if contact_n == 0 and drive > 0.0:
		target_rpm = lerpf(idle, redline * 0.93, throttle)
	if engine_state == EngineState.OFF:
		rpm = lerpf(rpm, 0.0, 1.0 - exp(-8.0 * delta))
	elif engine_state == EngineState.CRANKING:
		rpm = lerpf(rpm, 260.0 + sin(_crank_t * 38.0) * 60.0, 0.3)
	else:
		rpm = minf(lerpf(rpm, target_rpm, 1.0 - exp(-float(powertrain["response"]) * delta)), redline + 150.0)

	# avtomatik dişli dəyişmə
	_shift_cooldown -= delta
	if running and gear > 0 and _shift_cooldown <= 0.0:
		var previous_gear := gear
		if rpm > float(powertrain["up"]) and gear < _forward_gears().size():
			gear += 1
			_shift_cooldown = float(powertrain["shift"]) + 0.35
		elif rpm < float(powertrain["down"]) and gear > 1:
			gear -= 1
			_shift_cooldown = float(powertrain["shift"]) + 0.35

		if gear != previous_gear:
			shift_remaining = float(powertrain["shift"])
			gear_changed.emit(previous_gear, gear)

	# açıq diferensial: sürüşən təkər gücü aparır, kilid bunu aradan qaldırır
	var diff_factor := 1.0
	if not diff_lock:
		diff_factor = lerpf(1.0, clampf(min_skid, 0.3, 1.0), 0.7)

	var wheel_r := wheels[0].wheel_radius
	var total_force := _torque_at(rpm) * _ratio() * float(powertrain["final"]) * DRIVETRAIN_EFF / wheel_r * throttle
	# Fade propulsion near the per-vehicle target; never clamp body velocity.
	var top := float(powertrain["top"]) / 3.6
	if gear < 0:
		top = minf(top, 30.0 / 3.6)
	total_force *= 1.0 - smoothstep(top * 0.94, top, absf(fwd_speed))
	if shift_remaining > 0.0:
		total_force *= 0.12
	if not running:
		total_force = 0.0
	if driven.size() > 0:
		engine_force = total_force * diff_factor * clampf(1.0 - mud_level * 0.65, 0.25, 1.0) / driven.size()
	else:
		engine_force = 0.0
	brake = braking * mass * 0.05

	# hava müqaviməti
	apply_central_force(-linear_velocity * linear_velocity.length() * float(powertrain["drag"]))

	# yanacaq
	var burn := 0.0
	if engine_state == EngineState.RUNNING:
		burn = 0.0015 + throttle * rpm / redline * 0.05
	elif engine_state == EngineState.CRANKING:
		burn = 0.004
	if awd_on:
		burn *= 1.15
	fuel = maxf(fuel - burn * delta, 0.0)

	lights.braking = braking > 0.5
	lights.reversing = gear < 0 and drive > 0.0

	# təkər-yer qarşılıqlı təsiri
	if terrain != null:
		terrain.prepare_mud(global_position)
	if mud_spray != null:
		mud_spray.stop_all()
	var tire: Dictionary = TIRES[tire_idx]
	var total_depth := 0.0
	var soft_sum := 0.0
	var contact_count := 0
	for w in wheels:
		if terrain != null and (not w.is_in_contact() or _is_soil_support(w)):
			total_depth += terrain.depth_at(w.global_position)
		if w.is_in_contact():
			contact_count += 1
	var slip_sum := 0.0
	# Approximate equal static load; dynamic per-wheel load needs custom suspension.
	var load_per_wheel := mass * 9.81 / maxi(contact_count, 1)
	var tire_width := float(SUSPENSIONS[spec_idx]["width"])
	for wi in wheels.size():
		var w := wheels[wi]
		if not w.is_in_contact() or terrain == null:
			continue
		var contact := w.get_contact_point()
		var soil_support := _is_soil_support(w)
		var soft := terrain.softness_at(contact) if soil_support else 0.0
		var depth := terrain.depth_at(contact) if soil_support else 0.0
		var asphalt := terrain.road_distance_fast(contact) < MudTerrain.ROAD_HALF
		soft_sum += soft
		w.wheel_friction_slip = OffroadSurface.grip(tire, asphalt, soft, depth)
		var offset := contact - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var rolling_direction := global_basis.z
		if w.use_as_steering:
			rolling_direction = rolling_direction.rotated(global_basis.y.normalized(), steering)
		var ground_speed := point_velocity.dot(rolling_direction)
		var slip := OffroadSurface.slip_speed(w.get_rpm(), w.wheel_radius, ground_speed)
		slip_sum += slip
		if soil_support and not asphalt:
			var rate := OffroadSurface.digging_rate(load_per_wheel, tire_width, w.wheel_radius, slip)
			# Quarter-metre soil collision follows the real tire footprint.
			terrain.deform(contact, maxf(tire_width * 0.75, 0.26), delta * rate)
			if mud_spray != null:
				mud_spray.contact(wi, contact, point_velocity, rolling_direction, w.get_rpm(), w.wheel_radius, soft, slip)
			var horizontal := Vector3(point_velocity.x, 0.0, point_velocity.z)
			var drag := OffroadSurface.resistance(soft, depth, w.wheel_radius)
			apply_force(-horizontal * mass / maxi(contact_count, 1) * drag, offset)
	mud_level = total_depth / 4.0 / MudTerrain.MAX_DEPTH
	wheel_slip = slip_sum / maxi(contact_count, 1)

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


func _is_soil_support(wheel: VehicleWheel3D) -> bool:
	var support := wheel.get_contact_body()
	return support is MudTerrain or support is MudPatch
