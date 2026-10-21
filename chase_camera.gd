class_name ChaseCamera
extends Camera3D
## GTA tipli yaxın izləyici kamera. V düyməsi rejimləri dəyişir:
##   0 Yaxın (GTA), 1 Uzaq, 2 Kapot (sürücü gözü).
## Kamera maşının istiqamətinə yumşaq (gecikmə ilə) dönür, sürətlə bir az uzaqlaşır və FOV artır,
## ağaca və yerə girməsin deyə şüa ilə yoxlanır.

signal mode_changed(mode_name: String)

enum Mode { CLOSE, FAR, HOOD }
const MODE_NAMES := ["Yaxın kamera", "Uzaq kamera", "Kapot kamerası"]

# dist: maşından geriyə məsafə, height: yerdən yuxarı, look_h: baxış nöqtəsinin hündürlüyü,
# drop: baxış nöqtəsi aşağı salınır (maşın kadrda yuxarı qalxır, aşağı HUD-a düşmür), ahead: baxış nöqtəsi irəlidə, fov: bazis görmə bucağı, yaw_rate: dönmə gecikməsi, pos_rate: mövqe gecikməsi
const PARAMS := [
	{"dist": 4.5, "height": 1.65, "look_h": 1.2, "drop": 1.4, "ahead": 4.5, "fov": 68.0, "yaw_rate": 4.2, "pos_rate": 14.0},
	{"dist": 9.5, "height": 4.2, "look_h": 1.0, "drop": 0.9, "ahead": 0.0, "fov": 70.0, "yaw_rate": 3.0, "pos_rate": 8.0},
]
## Kapot kamerası: sürücü gözü, maşının lokal koordinatında (irəli +Z, sol +X)
const HOOD_OFFSET := Vector3(0.32, 0.85, 0.15)

var target: OffroadTruck
var terrain: MudTerrain
var mode: int = Mode.CLOSE

## Menyu açıq olanda maşının ətrafında yavaş fırlanır, maşın ekranın sağında qalır.
var menu_orbit := false

var _yaw := 0.0
var _orbit_angle := 0.6
var _fov := 68.0
var _snap := true


func _ready() -> void:
	near = 0.1
	far = 1500.0
	_fov = PARAMS[0]["fov"]
	fov = _fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_mode((mode + 1) % MODE_NAMES.size())


func set_mode(m: int) -> void:
	mode = m
	_snap = true
	near = 0.05 if mode == Mode.HOOD else 0.1
	mode_changed.emit(MODE_NAMES[mode])


## Maşın başqa yerə qoyulanda (məs. R düyməsi) kameranı dərhal yeni mövqeyə atır.
func snap() -> void:
	_snap = true


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if menu_orbit:
		_update_orbit(delta)
	elif mode == Mode.HOOD:
		_update_hood(delta)
	else:
		_update_chase(delta)


func _update_orbit(delta: float) -> void:
	_orbit_angle += delta * 0.22
	var c := target.global_position
	var pos := c + Vector3(cos(_orbit_angle) * 7.2, 2.3, sin(_orbit_angle) * 7.2)
	var f := (c - pos).normalized()
	var right := f.cross(Vector3.UP).normalized()
	# baxış nöqtəsi maşının solundadır, ona görə maşın ekranın sağında görünür
	look_at_from_position(pos, c + Vector3.UP * 0.9 - right * 2.6, Vector3.UP)
	fov = 55.0
	_fov = 55.0
	_snap = true


func _heading() -> Vector3:
	var f := target.global_transform.basis.z  # VehicleBody3D-nin irəlisi +Z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _update_hood(delta: float) -> void:
	var xf := target.global_transform
	var pos := xf * HOOD_OFFSET
	var fwd := xf.basis.z
	look_at_from_position(pos, pos + fwd * 10.0, xf.basis.y)
	_fov = lerpf(_fov, 76.0 + clampf(target.linear_velocity.length() * 3.6 / 80.0, 0.0, 1.0) * 6.0, 1.0 - exp(-3.0 * delta))
	fov = _fov
	_snap = false


func _update_chase(delta: float) -> void:
	var p: Dictionary = PARAMS[mode]
	var speed := target.linear_velocity.length()
	var fwd_speed := target.linear_velocity.dot(target.global_transform.basis.z)

	# istiqamət: maşının başı, sürətlə hərəkətdə sürüşmə istiqamətinə doğru bir az qarışır
	var heading := _heading()
	var want := heading
	if fwd_speed > 4.0:
		var vel := target.linear_velocity
		vel.y = 0.0
		if vel.length() > 0.5:
			want = heading.lerp(vel.normalized(), clampf((speed - 4.0) / 12.0, 0.0, 0.5)).normalized()
	var want_yaw := atan2(want.x, want.z)
	if _snap:
		_yaw = want_yaw
	else:
		_yaw = lerp_angle(_yaw, want_yaw, 1.0 - exp(-float(p["yaw_rate"]) * delta))

	var dir := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var dist: float = float(p["dist"]) + clampf(speed / 18.0, 0.0, 1.0) * 1.1
	var anchor := target.global_position + Vector3.UP * float(p["look_h"])
	var desired := target.global_position - dir * dist + Vector3.UP * float(p["height"])

	# şüa: ağaca və ya yerə girməsin
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(anchor, desired, 0xFFFFFFFF, [target.get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		desired = hit["position"] + (hit["normal"] as Vector3) * 0.35
	if terrain != null:
		desired.y = maxf(desired.y, terrain.height_at(desired) + 0.9)

	if _snap or global_position.distance_to(desired) > 40.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-float(p["pos_rate"]) * delta))
	var look_at_pt := anchor + dir * float(p["ahead"]) - Vector3.UP * float(p["drop"])
	look_at(look_at_pt, Vector3.UP)

	var want_fov: float = float(p["fov"]) + clampf(speed * 3.6 / 80.0, 0.0, 1.0) * 7.0
	_fov = lerpf(_fov, want_fov, 1.0 - exp(-3.0 * delta))
	fov = _fov
	_snap = false
