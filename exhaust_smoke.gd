class_name ExhaustSmoke
extends Node3D
## A bounded world-space plume: lit, noise-eroded volume impostors, soft depth
## intersections and mass dilution. Ignition is driven by the actual engine state.
const CAPACITY := 144
# +Z is forward. Rear tips measured outside imported body bounds (including
# bumpers/accessories); trucks use upright stacks outside the procedural cab.
const OUTLETS := [Vector3(.42,-.48,-2.16),Vector3(.92,1.3,-.35),Vector3(.92,1.5,-.45),Vector3(-.55,-.48,-1.93),Vector3(-.52,-.47,-2.13),Vector3(-.57,-.48,-2.15),Vector3(.82,-.58,-2.62),Vector3(.46,-.60,-2.45),Vector3(.32,-.48,-2.36)]
const CYLINDERS := [6,6,8,4,4,4,4,4,4]
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
var _clock := 0.0
var _warmup := 0.0
var _load_smoke := 0.0
var _previous_throttle := 0.0
var _last_mouth := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _multimesh: MultiMesh
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _life := PackedFloat32Array()
var _lifetime := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _density := PackedFloat32Array()
var _soot := PackedFloat32Array()
var _seeds := PackedFloat32Array()
var _rolls := PackedFloat32Array()
var _visible: Array[int] = []
var _visual: MultiMeshInstance3D
var _pipe: MeshInstance3D
static var _noise_texture: ImageTexture3D

func _ready() -> void:
	_rng.seed = 82541
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = load("res://exhaust_volume.gdshader")
	material.set_shader_parameter("density_noise",_volume_noise())
	quad.material = material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = CAPACITY
	var node := MultiMeshInstance3D.new()
	node.multimesh = _multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	node.global_transform = Transform3D.IDENTITY
	_visual = node
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_life.resize(CAPACITY)
	_lifetime.resize(CAPACITY)
	_sizes.resize(CAPACITY)
	_density.resize(CAPACITY)
	_soot.resize(CAPACITY)
	_seeds.resize(CAPACITY)
	_rolls.resize(CAPACITY)
	_pipe = MeshInstance3D.new()
	_pipe.mesh = _pipe_mesh()
	add_child(_pipe)
	reset()

static func _volume_noise() -> ImageTexture3D:
	if _noise_texture != null:
		return _noise_texture
	# Small shared 32^3 scalar volume; no downloads or per-frame texture writes.
	var noise := FastNoiseLite.new()
	noise.seed = 714
	noise.frequency = .105
	noise.fractal_octaves = 3
	var slices: Array[Image] = []
	for z in 32:
		var bytes := PackedByteArray()
		bytes.resize(32*32)
		for y in 32:
			for x in 32:
				bytes[y*32+x] = int(clampf(.5+.7*_periodic_noise(noise,Vector3(x,y,z)),0,1)*255)
		slices.append(Image.create_from_data(32,32,false,Image.FORMAT_R8,bytes))
	_noise_texture = ImageTexture3D.new()
	_noise_texture.create(Image.FORMAT_R8,32,32,32,false,slices)
	return _noise_texture

static func _periodic_noise(noise: FastNoiseLite,p: Vector3) -> float:
	# Crossblend opposite faces so repeating volume coordinates have no seam.
	var f := p/32.0
	var value := 0.0
	for z in 2:
		for y in 2:
			for x in 2:
				var weight := (f.x if x else 1-f.x)*(f.y if y else 1-f.y)*(f.z if z else 1-f.z)
				value += noise.get_noise_3dv(p-Vector3(x,y,z)*32)*weight
	return value

static func _pipe_mesh() -> ArrayMesh:
	# Open metal tube with an inner wall and a thin rim, never a glowing cap.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var a := TAU*i/20.0
		var b := TAU*(i+1)/20.0
		for radii: Vector2 in [Vector2(.035,.035),Vector2(.028,.028),Vector2(.028,.035)]:
			var rim: bool = radii.x != radii.y
			var p := Vector3(cos(a)*radii.x,sin(a)*radii.x,0)
			var q := Vector3(cos(b)*radii.x,sin(b)*radii.x,0)
			var r := Vector3(cos(a)*radii.y,sin(a)*radii.y,-.28 if not rim else 0.0)
			var s := Vector3(cos(b)*radii.y,sin(b)*radii.y,-.28 if not rim else 0.0)
			for v in [p,r,q,q,r,s]:
				st.set_normal(Vector3(v.x,v.y,0).normalized() if not rim else Vector3.FORWARD)
				st.add_vertex(v)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.11,.105,.095)
	material.metallic = .65
	material.roughness = .72
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)
	return st.commit()

func reset() -> void:
	startup = 0.0
	_warmup = 0.0
	_credit = 0.0
	_load_smoke = 0.0
	_previous_throttle = 0.0
	_last_mouth = truck.to_global(OUTLETS[clampi(truck.spec_idx,0,8)]) if truck != null else Vector3.ZERO
	for i in CAPACITY:
		_life[i] = 0.0
	_multimesh.visible_instance_count = 0

func _process(delta: float) -> void:
	if truck == null:
		return
	var dt := minf(delta,.1)
	_clock += dt
	if _previous_vehicle != truck.spec_idx:
		_previous_vehicle = truck.spec_idx
		reset()
		_previous_state = truck.engine_state
	outlet = OUTLETS[clampi(truck.spec_idx,0,OUTLETS.size()-1)]
	var diesel := truck.spec_idx in [1,2]
	var direction := Vector3.UP if diesel else Vector3(.08,-.1,-1).normalized()
	var mouth := truck.to_global(outlet)
	var world_direction := (truck.global_basis*direction).normalized()
	_pipe.global_transform = Transform3D(Basis.looking_at(-world_direction,truck.global_basis.z if diesel else truck.global_basis.y),mouth)
	# Trucks have a long stack behind the cab; passenger cars a short tailpipe.
	# The Jeep's tailpipe runs forward under the frame (clear of the rear tyre) instead of hanging off the bumper.
	_pipe.scale = Vector3(1.25,1.25,4.8) if diesel else (Vector3(1.4,1.4,3.8) if truck.spec_idx == 0 else Vector3.ONE)
	var state := truck.engine_state
	if state == OffroadTruck.EngineState.RUNNING and _previous_state == OffroadTruck.EngineState.CRANKING:
		startup = 1.8
		_warmup = 1.0
	_previous_state = state
	if state == OffroadTruck.EngineState.OFF:
		startup = 0.0
	startup = maxf(0,startup-dt)
	_warmup = maxf(0,_warmup-dt/24.0)
	# Diesel tip-in soot is brief, rather than a permanently black idle cloud.
	var throttle := maxf(0,truck.throttle)
	_load_smoke = maxf(maxf(0,throttle-_previous_throttle)*2.0,_load_smoke-dt*1.8)
	_previous_throttle = throttle
	emission_rate = 0
	if state == OffroadTruck.EngineState.CRANKING:
		emission_rate = 10.0
	elif state == OffroadTruck.EngineState.RUNNING:
		emission_rate = ((25.0 if diesel else 20.0)+startup*32.0)/(1+truck.linear_velocity.length()*.14)
	_credit += emission_rate*dt
	var count := int(_credit)
	_credit -= count
	# Interpolate births along the mouth trajectory: no dotted trail at low FPS.
	if mouth.distance_to(_last_mouth)>8:
		reset()
	for n in count:
		_emit(diesel,_last_mouth.lerp(mouth,float(n+1)/maxi(count,1)),world_direction)
	_last_mouth = mouth
	var breeze := wind.velocity if wind != null else Vector3(.5,0,0)
	_visible.clear()
	for i in CAPACITY:
		if _life[i]<=0:
			continue
		_life[i] = maxf(0,_life[i]-dt)
		if _life[i]<=0:
			continue
		var age := 1-_life[i]/_lifetime[i]
		var phase := _seeds[i]*TAU
		var curl := Vector3(sin(_clock*2.1+phase),sin(_clock*1.7+phase*.7)*.35,cos(_clock*1.8+phase))*(.08+age*.18)
		# Exhaust initially inherits vehicle velocity, then loses momentum to air.
		_velocities[i] = _velocities[i].lerp(breeze+Vector3.UP*(.24+age*.3)+curl,1-exp(-dt*(1.0+age)))
		_positions[i] += _velocities[i]*dt
		_visible.append(i)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var eye := camera.global_position
		_visible.sort_custom(func(a,b): return eye.distance_squared_to(_positions[a])>eye.distance_squared_to(_positions[b]))
	if not _visible.is_empty():
		var bounds := AABB(_positions[_visible[0]],Vector3.ZERO)
		for i in _visible:
			bounds = bounds.expand(_positions[i])
		_visual.custom_aabb = bounds.grow(2.0)
	_multimesh.visible_instance_count = _visible.size()
	for slot in _visible.size():
		var i := _visible[slot]
		var age := 1-_life[i]/_lifetime[i]
		var diameter := puff_diameter(i)
		_multimesh.set_instance_transform(slot,Transform3D(Basis.from_scale(Vector3.ONE*diameter),_positions[i]))
		var opacity := puff_opacity(i)
		var color := Color(.64,.67,.69).lerp(Color(.16,.15,.135),_soot[i])
		color.a = clampf(opacity/6.0,0,1)
		_multimesh.set_instance_color(slot,color)
		_multimesh.set_instance_custom_data(slot,Color(age,_seeds[i],_rolls[i]+age*.08,.5+.4*sin(_seeds[i]*TAU)))

func puff_diameter(i: int) -> float:
	var age := 1-_life[i]/_lifetime[i]
	return _sizes[i]+age*.72+age*age*.45

func puff_opacity(i: int) -> float:
	# Expanding gas loses optical density, with a smooth birth and final fade.
	var age := 1-_life[i]/_lifetime[i]
	var dilution := pow(_sizes[i]/puff_diameter(i),1.15)
	return _density[i]*dilution*smoothstep(0,.065,age)*(1-smoothstep(.60,1,age))

func _emit(diesel: bool,position: Vector3,direction: Vector3) -> void:
	var i := _cursor
	_cursor = (_cursor+1)%CAPACITY
	var ignition := clampf(startup/1.8,0,1)
	var load := clampf(_load_smoke,0,1) if diesel else 0.0
	var pulse := 1+.09*sin(_clock*maxf(truck.rpm,400)/120.0*CYLINDERS[truck.spec_idx]*TAU)
	_positions[i] = position
	_velocities[i] = truck.linear_velocity+direction*(.65+ignition*1.2+maxf(truck.throttle,0)*.65)*pulse
	_velocities[i] += Vector3(_rng.randf_range(-.055,.055),_rng.randf_range(0,.055),_rng.randf_range(-.055,.055))
	_lifetime[i] = _rng.randf_range(1.7,2.8) if ignition>.1 else _rng.randf_range(1.25,2.0)
	_life[i] = _lifetime[i]
	_sizes[i] = _rng.randf_range(.10,.15)*(1+ignition*.35)
	_density[i] = ((.75 if diesel else .38)+ignition*3.4+_warmup*.25+load*1.4)/(1+truck.linear_velocity.length()*.07)
	_soot[i] = clampf((.18 if diesel else .015)+ignition*(.42 if diesel else .10)+load*.32,0,.85)
	_seeds[i] = _rng.randf()
	_rolls[i] = _rng.randf()
	emitted += 1
