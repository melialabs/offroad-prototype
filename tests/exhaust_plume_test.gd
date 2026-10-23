extends SceneTree
## Plume transport/optical behaviour, independent of a GPU or full world build.
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		print('FAIL ',label)
func body_rear(node: Node,t: Node3D) -> float:
	var rear := INF
	if node is MeshInstance3D:
		var bounds: AABB = t.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
		rear = bounds.position.z
	for child in node.get_children():
		rear = minf(rear,body_rear(child,t))
	return rear
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var t := OffroadTruck.new()
	root.add_child(t)
	t.freeze = true
	t.set_physics_process(false)
	t.position = Vector3(0,1,0)
	var w := WindField.new()
	root.add_child(w)
	w.set_process(false)
	w.velocity = Vector3(2,0,0)
	var smoke := ExhaustSmoke.new()
	smoke.truck = t
	smoke.wind = w
	root.add_child(smoke)
	smoke.set_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(3,2,-5)
	camera.current = true
	t.stop_engine()
	smoke._process(.016)
	check(smoke._multimesh.mesh.material is ShaderMaterial,'volume shader replaces unshaded sprites')
	check(smoke._multimesh.use_custom_data,'per-puff age, noise phase and roll')
	check(ExhaustSmoke._volume_noise() == ExhaustSmoke._volume_noise(),'shared volume texture')
	check(ExhaustSmoke._volume_noise().get_depth()==32,'bounded 32-cubed noise volume')
	var uniforms: Array = smoke._multimesh.mesh.material.shader.get_shader_uniform_list()
	check(uniforms.any(func(u):return u['name']=='density_noise'),'shader parses volume sampler')
	t.engine_state = OffroadTruck.EngineState.CRANKING
	smoke._process(.05)
	t.engine_state = OffroadTruck.EngineState.RUNNING
	smoke._process(.05)
	check(smoke.startup>1.6,'actual ignition starts burst')
	var index := smoke._cursor
	smoke._emit(false,t.to_global(smoke.outlet),Vector3.FORWARD)
	var start_density: float = smoke._density[index]
	var start_position: Vector3 = smoke._positions[index]
	t.position.x += 1
	smoke._process(.02)
	check(smoke._positions[index].distance_to(start_position)<.2,'old smoke stays in world space when vehicle moves')
	var before: float = smoke._velocities[index].x
	for f in 12:
		smoke._process(.02)
	check(smoke._velocities[index].x>before,'wind entrains the plume')
	# Draw slots sort back-to-front, without changing physical particle identity.
	var sorted := true
	for j in range(1,smoke._visible.size()):
		sorted = sorted and camera.global_position.distance_squared_to(smoke._positions[smoke._visible[j-1]])>=camera.global_position.distance_squared_to(smoke._positions[smoke._visible[j]])
	check(sorted,'transparent puffs sort back to front')
	smoke.startup = 0
	smoke._warmup = 0
	smoke._load_smoke = 0
	index = smoke._cursor
	smoke._emit(false,t.to_global(smoke.outlet),Vector3.FORWARD)
	check(smoke._density[index]<start_density*.25,'warm petrol idle is much thinner than ignition')
	var petrol_soot: float = smoke._soot[index]
	index = smoke._cursor
	smoke._emit(true,t.to_global(smoke.outlet),Vector3.UP)
	check(smoke._soot[index]>petrol_soot,'diesel and petrol have distinct soot')
	t.linear_velocity = Vector3(0,0,12)
	index = smoke._cursor
	smoke._emit(false,t.to_global(smoke.outlet),Vector3.FORWARD)
	check(smoke._velocities[index].z>10,'fresh exhaust inherits moving vehicle velocity')
	t.linear_velocity = Vector3.ZERO
	smoke.reset()
	smoke._process(.05)
	index = smoke._cursor
	smoke.startup = 1.8
	smoke._emit(false,t.to_global(smoke.outlet),Vector3.FORWARD)
	for f in 6:
		smoke._process(.02)
	var early_alpha := smoke.puff_opacity(index)
	var early_size := smoke.puff_diameter(index)
	for f in 26:
		smoke._process(.02)
	check(smoke.puff_opacity(index)<early_alpha,'expanding gas loses optical density')
	check(smoke.puff_diameter(index)>early_size,'plume expands rather than retaining round beads')
	check(smoke._visual.custom_aabb.has_point(smoke._positions[index]),'visible plume has cullable bounds')
	t.stop_engine()
	var emitted := smoke.emitted
	for f in 200:
		smoke._process(.02)
	check(smoke.emitted==emitted,'no emissions after shutoff')
	check(smoke._multimesh.visible_instance_count==0,'remaining plume fully dissipates')
	for vehicle in 7:
		t.apply_spec(vehicle)
		smoke._process(.02)
		var expected := (t.global_basis*(Vector3.UP if vehicle in [1,2] else Vector3(.08,-.1,-1).normalized())).normalized()
		if vehicle not in [1,2]:
			var body: Node3D = t._jeep.body if vehicle==0 else t._cars[vehicle]['model'].body
			check(smoke.outlet.z<body_rear(body,t)-.03,'tailpipe mouth clears actual bumper geometry %d'%vehicle)
		check(smoke._pipe.global_position.is_equal_approx(t.to_global(smoke.outlet)),'pipe mouth matches outlet %d'%vehicle)
		check(smoke._pipe.global_basis.z.normalized().dot(expected)>.999,'open pipe points along jet %d'%vehicle)
	smoke.reset()
	check(smoke._multimesh.visible_instance_count==0,'reset clears all particles')
	smoke.free()
	t.free()
	w.free()
	camera.free()
	print('EXHAUST PLUME failures=',failures.size())
	quit(0 if failures.is_empty() else 1)
