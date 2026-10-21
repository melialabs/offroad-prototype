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
var _heads: Array[SpotLight3D] = []
var _head_lens: Array[StandardMaterial3D] = []
var _tail_lights: Array[OmniLight3D] = []
var _tail_lens: Array[StandardMaterial3D] = []
var _amber_lights: Array[OmniLight3D] = []
var _amber_lens: Array[StandardMaterial3D] = []
var _rev_light: OmniLight3D
var _rev_lens: StandardMaterial3D


func _ready() -> void:
	for p in HEAD_POS:
		var sp := SpotLight3D.new()
		sp.position = p
		sp.shadow_enabled = false
		sp.spot_attenuation = 0.8
		add_child(sp)
		_heads.append(sp)
		_head_lens.append(_lens(p, Color(1.0, 0.96, 0.85), 0.07, _head_meshes))
	for p in TAIL_POS:
		var o := OmniLight3D.new()
		o.position = p + Vector3(0, 0, -0.15)
		o.light_color = Color(1.0, 0.1, 0.05)
		o.omni_range = 3.5
		o.shadow_enabled = false
		add_child(o)
		_tail_lights.append(o)
		_tail_lens.append(_lens(p, Color(1.0, 0.1, 0.05), 0.055, _tail_meshes))
	for i in AMBER_POS.size():
		var p: Vector3 = AMBER_POS[i]
		var o := OmniLight3D.new()
		o.position = p + Vector3(0, 0, 0.15 if p.z > 0.0 else -0.15)
		o.light_color = Color(1.0, 0.6, 0.05)
		o.omni_range = 4.0
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


## Maşının ölçüsünə görə işıq mövqelərini qurur (mərkəzə görə, irəli +Z).
func layout(front_z: float, rear_z: float, head_x: float, tail_x: float, head_y: float, tail_y: float) -> void:
	HEAD_POS = [Vector3(head_x, head_y, front_z), Vector3(-head_x, head_y, front_z)]
	TAIL_POS = [Vector3(tail_x, tail_y, rear_z), Vector3(-tail_x, tail_y, rear_z)]
	AMBER_POS = [Vector3(head_x + 0.18, head_y - 0.1, front_z), Vector3(-head_x - 0.18, head_y - 0.1, front_z),
		Vector3(tail_x - 0.12, tail_y, rear_z), Vector3(-tail_x + 0.12, tail_y, rear_z)]
	REV_POS = Vector3(0, tail_y + 0.02, rear_z)
	for i in 2:
		_head_meshes[i].position = HEAD_POS[i]
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
		_amber_lights[i].light_energy = 1.8 if amber_on else 0.0
		_amber_lens[i].emission_energy_multiplier = 6.0 if amber_on else 0.0

	var lamps_on := headlight_mode > 0
	var tail_e := 0.0
	var lens_e := 0.0
	if braking:
		tail_e = 1.6
		lens_e = 6.0
	elif lamps_on:
		tail_e = 0.45
		lens_e = 2.2
	for i in _tail_lights.size():
		_tail_lights[i].light_energy = tail_e
		_tail_lens[i].emission_energy_multiplier = lens_e

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
