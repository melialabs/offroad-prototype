class_name MudSpray
extends Node3D
## A bounded, instanced clod pool. World-space ballistic flight, soil impact and
## flattened deposits prevent particles following the car or passing through land.
const CAPACITY := 256
class WheelEmitter extends RefCounted:
	var emitting := false
	var point := Vector3.ZERO
	var direction := Vector3.UP
	var velocity := Vector3.ZERO
	var speed := 0.0
	var rate := 0.0
	var credit := 0.0

var emitters: Array[WheelEmitter] = []
var impacts := 0
var _terrain: MudTerrain
var _instances: MultiMesh
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _landed := PackedByteArray()
var _cursor := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_terrain = (get_parent() as OffroadTruck).terrain
	_rng.seed = 3817
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.065, 0.025)
	material.roughness = 0.30
	var clod := SphereMesh.new()
	clod.radius = 1.0
	clod.height = 1.5
	clod.radial_segments = 6
	clod.rings = 3
	clod.material = material
	_instances = MultiMesh.new()
	_instances.transform_format = MultiMesh.TRANSFORM_3D
	_instances.mesh = clod
	_instances.instance_count = CAPACITY
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _instances
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_life.resize(CAPACITY)
	_size.resize(CAPACITY)
	_landed.resize(CAPACITY)
	for i in CAPACITY:
		_instances.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	for i in 4:
		emitters.append(WheelEmitter.new())

func stop_all() -> void:
	for e in emitters:
		e.emitting = false

func contact(i: int, point: Vector3, velocity: Vector3, forward: Vector3, rpm: float, radius: float, soft: float, slip: float) -> void:
	var e := emitters[i]
	var tread := absf(rpm) * TAU * radius / 60.0
	var activity := maxf(slip, velocity.length() * 0.4)
	e.emitting = soft > 0.3 and activity > 0.6 and tread > 0.7
	if not e.emitting:
		return
	e.point = point + Vector3.UP * 0.16
	var travel_sign := signf(velocity.dot(forward))
	if absf(velocity.dot(forward)) < 0.2:
		travel_sign = signf(rpm)
	if travel_sign == 0.0:
		travel_sign = 1.0
	e.direction = (-forward * travel_sign * 0.8 + Vector3.UP * 0.9).normalized()
	e.velocity = velocity * 0.15
	e.speed = clampf(2.0 + tread * 0.28, 2.0, 8.0)
	e.rate = clampf(soft * activity * 12.0, 8.0, 70.0)

func _physics_process(delta: float) -> void:
	for e in emitters:
		if not e.emitting:
			e.credit = 0.0
			continue
		e.credit += delta * e.rate
		while e.credit >= 1.0:
			e.credit -= 1.0
			_spawn(e)
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		_life[i] = maxf(0.0, _life[i] - delta)
		if _landed[i] == 0:
			_velocities[i] += Vector3.DOWN * 9.81 * delta
			_positions[i] += _velocities[i] * delta
			if _terrain != null:
				var ground := _terrain.height_at(_positions[i]) + 0.018
				if _positions[i].y <= ground:
					_positions[i].y = ground
					_landed[i] = 1
					_life[i] = minf(_life[i], 0.65)
					impacts += 1
		var radius := _size[i] * smoothstep(0.0, 0.2, _life[i])
		var scale_clod := Vector3(radius, radius, radius)
		if _landed[i] == 1:
			scale_clod = Vector3(radius * 1.9, radius * 0.13, radius * 1.9)
		_instances.set_instance_transform(i, Transform3D(Basis.from_scale(scale_clod), _positions[i]))

func _spawn(e: WheelEmitter) -> void:
	var i := _cursor
	_cursor = (_cursor + 1) % CAPACITY
	_positions[i] = e.point + Vector3(_rng.randf_range(-0.09, 0.09), 0, _rng.randf_range(-0.09, 0.09))
	var scatter := Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.15, 0.25), _rng.randf_range(-0.4, 0.4))
	_velocities[i] = (e.direction + scatter).normalized() * e.speed * _rng.randf_range(0.5, 1.0) + e.velocity
	_life[i] = 1.6
	_size[i] = _rng.randf_range(0.015, 0.06)
	_landed[i] = 0
