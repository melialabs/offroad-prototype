class_name VehicleLights
extends Node3D
## Maşın işıqları: ön fənərlər (söndürülüb / yaxın / uzaq), qəza işıqları (4 künc sarı, yanıb-sönür),
## arxa işıqlar (fənərlə zəif, əyləcdə güclü) və geri hərəkət işığı.
## Mövqelər maşının lokal koordinatındadır (irəli +Z, sol +X). Bütün texnikalar üçün eyni gövdə ölçüsünə uyğundur.

var HEAD_POS := [Vector3(0.58, 0.22, 2.1), Vector3(-0.58, 0.22, 2.1)]
var TAIL_POS := [Vector3(0.76, 0.2, -2.08), Vector3(-0.76, 0.2, -2.08)]
var AMBER_POS := [Vector3(0.8, 0.12, 2.1), Vector3(-0.8, 0.12, 2.1), Vector3(0.62, 0.2, -2.1), Vector3(-0.62, 0.2, -2.1)]
var REV_POS := Vector3(0, 0.22, -2.1)
var _head_meshes: Array[MeshInstance3D] = []
var _tail_meshes: Array[MeshInstance3D] = []
var _amber_meshes: Array[MeshInstance3D] = []
var _rev_mesh: MeshInstance3D
const BLINK_PERIOD := 0.8

## Qəza işığı yanıb-sönəndə (tıqqıltı səsi üçün).
signal tick(on: bool)

const MODE_NAMES := ["Fənərlər söndürüldü", "Yaxın fənər", "Uzaq fənər"]

var headlight_mode := 0  # 0 söndürülüb, 1 yaxın, 2 uzaq
var hazard := false
var braking := false
var reversing := false

var _t := 0.0
var _last_amber := false
## Hazır modelin öz fənər meshləri: yananda üstünə əlavə (ADD) parıltı materialı qoyulur
var _model_head: Array[MeshInstance3D] = []
var _model_tail: Array[MeshInstance3D] = []
var _ov_head: StandardMaterial3D
var _ov_tail: StandardMaterial3D
var _heads: Array[SpotLight3D] = []
var _head_lens: Array[StandardMaterial3D] = []
var _tail_lights: Array[OmniLight3D] = []
var _tail_lens: Array[StandardMaterial3D] = []
var _amber_lights: Array[OmniLight3D] = []
var _amber_lens: Array[StandardMaterial3D] = []
var _rev_light: OmniLight3D
var _rev_lens: StandardMaterial3D
## Dam işıq paneli (məs. pikapın üstündəki fənərlər): yalnız uzaq işıqda yanır
var _roof_lights: Array[SpotLight3D] = []
var _roof_lens: Array[StandardMaterial3D] = []
var _roof_nodes: Array[Node3D] = []


func _ready() -> void:
	for p in HEAD_POS:
		var sp := SpotLight3D.new()
		sp.position = p
		sp.shadow_enabled = true
		sp.light_color = Color(1.0, 0.94, 0.79)
		sp.spot_attenuation = 0.8
		add_child(sp)
		_heads.append(sp)
		_head_lens.append(_lens(p, Color(1.0, 0.96, 0.85), 0.07, _head_meshes))
	for p in TAIL_POS:
		var o := OmniLight3D.new()
		o.position = p + Vector3(0, 0, -0.15)
		o.light_color = Color(1.0, 0.1, 0.05)
		o.omni_range = 2.6
		o.shadow_enabled = false
		add_child(o)
		_tail_lights.append(o)
		_tail_lens.append(_lens(p, Color(1.0, 0.1, 0.05), 0.055, _tail_meshes))
	for i in AMBER_POS.size():
		var p: Vector3 = AMBER_POS[i]
		var o := OmniLight3D.new()
		o.position = p + Vector3(0, 0, 0.15 if p.z > 0.0 else -0.15)
		o.light_color = Color(1.0, 0.6, 0.05)
		o.omni_range = 2.8
		o.shadow_enabled = false
		add_child(o)
		_amber_lights.append(o)
		_amber_lens.append(_lens(p, Color(1.0, 0.6, 0.05), 0.045, _amber_meshes))
	_rev_light = OmniLight3D.new()
	_rev_light.position = Vector3(0, 0.2, -2.15)
	_rev_light.light_color = Color(1, 1, 1)
	_rev_light.omni_range = 6.0
	_rev_light.shadow_enabled = false
	add_child(_rev_light)
	var rm: Array = []
	_rev_lens = _lens(REV_POS, Color(1, 1, 1), 0.045, rm)
	_rev_mesh = rm[0]
	_apply()


## Hazır modelin fənər meshlərini bağlayır: işıq mənbələri onların mərkəzinə köçür, mesh üzərində parıltı yanır.
func bind_model_lamps(head: Array[MeshInstance3D], head_pos: Array[Vector3], tail: Array[MeshInstance3D], tail_pos: Array[Vector3]) -> void:
	clear_model_lamps()
	_model_head = head
	_model_tail = tail
	if _ov_head == null:
		_ov_head = _overlay()
		_ov_tail = _overlay()
	var hp: Array = head_pos if head_pos.size() == 2 else HEAD_POS
	var tp: Array = tail_pos if tail_pos.size() == 2 else TAIL_POS
	var rz: float = (tp[0] as Vector3).z - 0.02
	HEAD_POS = [hp[0], hp[1]]
	TAIL_POS = [tp[0] + Vector3(0, 0, -0.02), tp[1] + Vector3(0, 0, -0.02)]
	AMBER_POS = [HEAD_POS[0], HEAD_POS[1], TAIL_POS[0], TAIL_POS[1]]
	REV_POS = Vector3(0, (tp[0] as Vector3).y, rz)
	for i in 2:
		_tail_lights[i].position = TAIL_POS[i] + Vector3(0, 0, -0.15)
	for i in 4:
		var p: Vector3 = AMBER_POS[i]
		_amber_lights[i].position = p + Vector3(0, 0, 0.15 if p.z > 0.0 else -0.15)
	_rev_light.position = REV_POS + Vector3(0, 0, -0.1)
	_apply()


func clear_model_lamps() -> void:
	for m in _model_head + _model_tail:
		if is_instance_valid(m):
			m.material_overlay = null
	_model_head = []
	_model_tail = []


func _overlay() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0, 0, 0, 1)
	return m


func _set_overlay(meshes: Array[MeshInstance3D], mat: StandardMaterial3D, c: Color) -> void:
	var on := c.r + c.g + c.b > 0.02
	mat.albedo_color = c
	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = mat if on else null


## Hazır modeldə öz fənər şüşələri olanda yapışdırılmış kürələr gizlədilir (yalnız işıq mənbələri qalır).
func set_lens_visible(v: bool) -> void:
	for arr in [_head_meshes, _tail_meshes, _amber_meshes]:
		for m in arr:
			(m as MeshInstance3D).visible = v
	_rev_mesh.visible = v


## Some models already include front lamp glass and indicator lenses.
func set_front_lens_visible(v: bool) -> void:
	for mesh in _head_meshes:
		mesh.visible = v
	for i in mini(2, _amber_meshes.size()):
		_amber_meshes[i].visible = v


## Maşının ölçüsünə görə işıq mövqelərini qurur (mərkəzə görə, irəli +Z).
func layout(front_z: float, rear_z: float, head_x: float, tail_x: float, head_y: float, tail_y: float) -> void:
	HEAD_POS = [Vector3(head_x, head_y, front_z), Vector3(-head_x, head_y, front_z)]
	TAIL_POS = [Vector3(tail_x, tail_y, rear_z), Vector3(-tail_x, tail_y, rear_z)]
	AMBER_POS = [Vector3(head_x + 0.18, head_y - 0.1, front_z), Vector3(-head_x - 0.18, head_y - 0.1, front_z),
		Vector3(tail_x - 0.12, tail_y, rear_z), Vector3(-tail_x + 0.12, tail_y, rear_z)]
	REV_POS = Vector3(0, tail_y + 0.02, rear_z)
	for i in 2:
		_head_meshes[i].position = HEAD_POS[i]
		_head_meshes[i].scale = Vector3.ONE
		_tail_meshes[i].position = TAIL_POS[i]
		_tail_lights[i].position = TAIL_POS[i] + Vector3(0, 0, -0.15)
	for i in 4:
		var p: Vector3 = AMBER_POS[i]
		_amber_meshes[i].position = p
		_amber_lights[i].position = p + Vector3(0, 0, 0.15 if p.z > 0.0 else -0.15)
	_rev_mesh.position = REV_POS
	_rev_light.position = REV_POS + Vector3(0, 0, -0.05)
	_apply()


## Yanan şüşə: kiçik emissiv kürə (söndürülü olanda tünd).
func _lens(pos: Vector3, color: Color, radius: float, store: Array = []) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.7)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.0
	m.roughness = 0.2
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	store.append(mi)
	return m


## Fənər rejimini dövrə ilə dəyişir, bildiriş mətnini qaytarır.
func cycle_headlights() -> String:
	headlight_mode = (headlight_mode + 1) % 3
	_apply()
	return MODE_NAMES[headlight_mode]


func set_headlights(mode: int) -> void:
	headlight_mode = clampi(mode, 0, 2)
	_apply()


func toggle_hazard() -> String:
	hazard = not hazard
	_t = 0.0
	return "Qəza işıqları yandırıldı" if hazard else "Qəza işıqları söndürüldü"


func _process(delta: float) -> void:
	_t += delta
	var blink := fposmod(_t, BLINK_PERIOD) < BLINK_PERIOD * 0.5
	var amber_on := hazard and blink
	if hazard and amber_on != _last_amber:
		tick.emit(amber_on)
	_last_amber = amber_on
	for i in _amber_lights.size():
		_amber_lights[i].light_energy = 1.0 if amber_on else 0.0
		_amber_lens[i].emission_energy_multiplier = 6.0 if amber_on else 0.0

	var lamps_on := headlight_mode > 0
	var tail_e := 0.0
	var lens_e := 0.0
	if braking:
		tail_e = 1.1
		lens_e = 6.0
	elif lamps_on:
		tail_e = 0.45
		lens_e = 2.2
	for i in _tail_lights.size():
		_tail_lights[i].light_energy = tail_e
		_tail_lens[i].emission_energy_multiplier = lens_e

	if not _model_head.is_empty() or not _model_tail.is_empty():
		var amber := Color(2.2, 0.9, 0.05)
		var hc := Color(0, 0, 0)
		if headlight_mode == 1:
			hc = Color(1.5, 1.4, 1.1)
		elif headlight_mode == 2:
			hc = Color(2.4, 2.3, 1.9)
		if amber_on:
			hc = amber
		var tc := Color(0, 0, 0)
		if braking:
			tc = Color(2.4, 0.12, 0.05)
		elif lamps_on:
			tc = Color(0.9, 0.05, 0.02)
		if amber_on:
			tc = amber
		_set_overlay(_model_head, _ov_head, hc)
		_set_overlay(_model_tail, _ov_tail, tc)
	_rev_light.light_energy = 0.9 if reversing else 0.0
	_rev_lens.emission_energy_multiplier = 5.0 if reversing else 0.0


func _apply() -> void:
	var pitch := 0.0
	var energy := 0.0
	var angle := 30.0
	var rng := 40.0
	match headlight_mode:
		1:
			pitch = deg_to_rad(6.0)
			energy = 14.0
			angle = 40.0
			rng = 38.0
		2:
			pitch = deg_to_rad(1.5)
			energy = 28.0
			angle = 30.0
			rng = 75.0
	for i in _heads.size():
		var sp := _heads[i]
		sp.visible = headlight_mode > 0
		sp.light_energy = energy
		sp.spot_angle = angle
		sp.spot_range = rng
		# SpotLight -Z-yə baxır, ona görə +Z (irəli) üçün 180° Y fırlanma, sonra aşağı əyilmə
		sp.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -pitch), HEAD_POS[i])
		_head_lens[i].emission_energy_multiplier = 0.0 if headlight_mode == 0 else (3.5 if headlight_mode == 1 else 7.0)
	var roof_on := headlight_mode == 2
	for sp in _roof_lights:
		sp.visible = roof_on
	for m in _roof_lens:
		m.emission_energy_multiplier = 8.0 if roof_on else 0.0
	if not _model_head.is_empty():
		_set_overlay(_model_head, _ov_head, Color(3.2, 2.9, 2.4) if headlight_mode > 0 else Color.BLACK)


## Dam işıq paneli: lens mövqeləri (maşın koordinatında). Boş massiv paneli silir.
## Hər iki lensə bir projektor düşür ki, kölgəli işıq sayı az qalsın.
func set_roof_bar(lenses: Array) -> void:
	for n in _roof_nodes:
		n.queue_free()
	_roof_nodes.clear()
	_roof_lights.clear()
	_roof_lens.clear()
	var meshes: Array[MeshInstance3D] = []
	for p in lenses:
		_roof_lens.append(_lens(p, Color(1.0, 0.97, 0.9), 0.06, meshes))
	for mi in meshes:
		mi.scale = Vector3(1.0, 1.0, 0.35)
		_roof_nodes.append(mi)
	for i in range(0, lenses.size(), 2):
		var a: Vector3 = lenses[i]
		var b: Vector3 = lenses[mini(i + 1, lenses.size() - 1)]
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.97, 0.9)
		sp.light_energy = 22.0
		sp.spot_angle = 24.0
		sp.spot_range = 90.0
		sp.spot_attenuation = 0.7
		sp.shadow_enabled = false
		sp.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -deg_to_rad(4.0)), (a + b) * 0.5)
		add_child(sp)
		_roof_lights.append(sp)
		_roof_nodes.append(sp)
	_apply()


## Modelin öz fənər şüşəsinin yeri məlumdursa: ön fənər mənbələri oraya keçir və yalnız ön
## linzalar (yastı disk kimi) görünür ki, yaxın/uzaq işıqda modelin fənərləri yansın.
func place_heads(positions: Array) -> void:
	HEAD_POS = [positions[0], positions[1]]
	for i in 2:
		_head_meshes[i].position = HEAD_POS[i]
		_head_meshes[i].scale = Vector3(1.25, 1.25, 0.3)
		_head_meshes[i].visible = true
	_apply()
