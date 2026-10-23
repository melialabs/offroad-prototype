class_name ExhaustSmoke
extends Node3D
## Bounded world-space puffs leave actual outlet positions instead of following
## the moving vehicle. Startup, running and shutoff use the same engine state
## consumed by GameAudio; no timer or input independently starts the engine.
const CAPACITY := 96
# Outlet offsets in vehicle coordinates, +Z forward. Model-specific tuning.
const OUTLETS := [Vector3(0.68,-0.48,-2.08),Vector3(0.84,0.55,-0.35),Vector3(0.85,0.85,-0.45),Vector3(-0.55,-0.48,-1.76),Vector3(-0.52,-0.47,-2.02),Vector3(-0.57,-0.48,-2.0),Vector3(0.82,-0.58,-2.45),Vector3(0.46,-0.60,-2.15),Vector3(0.32,-0.48,-2.02)]
var truck: OffroadTruck
var wind: WindField
var startup := 0.0
var emission_rate := 0.0
var emitted := 0
var outlet := Vector3.ZERO
var _previous_state := -1
var _previous_vehicle := -1
var _credit := 0.0
var _cursor := 0
var _rng := RandomNumberGenerator.new()
var _multimesh: MultiMesh
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _life := PackedFloat32Array()
var _lifetime := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _dense := PackedByteArray()

func _ready() -> void:
	_rng.seed = 82541
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puff_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = CAPACITY
	var node := MultiMeshInstance3D.new()
	node.multimesh = _multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	node.global_transform = Transform3D.IDENTITY
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_life.resize(CAPACITY)
	_lifetime.resize(CAPACITY)
	_sizes.resize(CAPACITY)
	_dense.resize(CAPACITY)
	for i in CAPACITY:
		_hide(i)

static func _puff_texture() -> ImageTexture:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 714
	noise.frequency = 0.15
	for x in 64:
		for y in 64:
			var distance := Vector2(x-31.5,y-31.5).length()/31.5
			var alpha := pow(maxf(0.0,1.0-distance),1.6)*(0.65+0.35*noise.get_noise_2d(x,y))
			image.set_pixel(x,y,Color(1,1,1,alpha))
	return ImageTexture.create_from_image(image)

func _hide(i: int) -> void:
	_multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))

func reset() -> void:
	startup = 0.0
	_credit = 0.0
	for i in CAPACITY:
		_life[i] = 0.0
		_hide(i)

func _process(delta: float) -> void:
	if truck == null:
		return
	if _previous_vehicle != truck.spec_idx:
		_previous_vehicle = truck.spec_idx
		reset()
		_previous_state = truck.engine_state
	outlet = OUTLETS[clampi(truck.spec_idx,0,OUTLETS.size()-1)]
	var state := truck.engine_state
	if state == OffroadTruck.EngineState.RUNNING and _previous_state == OffroadTruck.EngineState.CRANKING:
		startup = 1.8
	_previous_state = state
	startup = maxf(0.0,startup-delta)
	var speed := truck.linear_velocity.length()
	var diesel := truck.spec_idx in [1,2]
	emission_rate = 0.0
	if state == OffroadTruck.EngineState.CRANKING:
		emission_rate = 3.0
	elif state == OffroadTruck.EngineState.RUNNING:
		# A brief dense start puff, then lighter exhaust; travel disperses it.
		var base := (7.0 if diesel else 4.0)+truck.throttle*(6.0 if diesel else 1.5)
		emission_rate = (base+startup*25.0)/(1.0+speed*0.12)
	_credit += emission_rate*minf(delta,0.1)
	while _credit >= 1.0:
		_credit -= 1.0
		_emit(diesel)
	for i in CAPACITY:
		if _life[i] <= 0:
			continue
		_life[i] -= delta
		if _life[i] <= 0:
			_hide(i)
			continue
		var breeze := wind.velocity if wind != null else Vector3(0.5,0,0)
		_velocities[i] = _velocities[i].lerp(breeze+Vector3.UP*0.34,1.0-exp(-delta*1.3))
		_positions[i] += _velocities[i]*delta
		var age := 1.0-_life[i]/_lifetime[i]
		var size := _sizes[i]*(1.0+age*4.0)
		_multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*size),_positions[i]))
		var color := Color(0.26,0.27,0.28) if diesel else Color(0.72,0.75,0.78)
		var alpha := (0.62 if _dense[i] else 0.26)*sin(minf(age*8,1.0)*PI*0.5)*pow(1.0-age,1.8)
		color.a = alpha
		_multimesh.set_instance_color(i,color)

func _emit(diesel: bool) -> void:
	var i := _cursor
	_cursor = (_cursor+1)%CAPACITY
	_positions[i] = truck.to_global(outlet)
	var direction := Vector3.UP if diesel else -truck.global_basis.z
	_velocities[i] = truck.linear_velocity*0.65+direction*_rng.randf_range(0.8,1.5)+Vector3(_rng.randf_range(-0.1,0.1),0.15,_rng.randf_range(-0.1,0.1))
	_lifetime[i] = _rng.randf_range(1.3,2.2)
	_life[i] = _lifetime[i]
	_sizes[i] = _rng.randf_range(0.09,0.16)
	_dense[i] = 1 if startup > 0.1 else 0
	emitted += 1
