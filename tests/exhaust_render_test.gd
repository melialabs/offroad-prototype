extends SceneTree
## Optional GPU smoke contact-sheet captures. Run WITHOUT --headless.
## PNGs are written to /tmp/exhaust-{scenario}.png; the preview closes itself.
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for f in n:
		await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	im.save_png('/tmp/exhaust-'+name+'.png')
	print('CAPTURE ',name)
func run() -> void:
	if DisplayServer.get_name() == 'headless':
		print('EXHAUST RENDER SKIPPED: requires a window and GPU')
		quit()
		return
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.27,.34,.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.8,.86,.95)
	env.ambient_light_energy = .5
	world.environment = env
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-40,0)
	sun.light_energy = 1.5
	scene.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.23,.20,.16)
	mat.roughness = 1
	floor.material_override = mat
	scene.add_child(floor)
	var truck := OffroadTruck.new()
	scene.add_child(truck)
	truck.freeze = true
	truck.set_physics_process(false)
	truck.position = Vector3(0,1.0,0)
	truck.stop_engine()
	var wind := WindField.new()
	scene.add_child(wind)
	wind.set_process(false)
	wind.velocity = Vector3(.2,0,.08)
	var smoke := ExhaustSmoke.new()
	smoke.truck = truck
	smoke.wind = wind
	scene.add_child(smoke)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(3,1.5,-5.2)
	camera.look_at(Vector3(0,1,-1.7))
	camera.current = true
	await frames(10)
	truck.engine_state = OffroadTruck.EngineState.CRANKING
	await frames(20)
	truck.engine_state = OffroadTruck.EngineState.RUNNING
	await frames(40)
	await shot('petrol-start')
	await frames(210)
	await shot('petrol-idle')
	truck.apply_spec(2)
	await frames(5)
	truck.engine_state = OffroadTruck.EngineState.CRANKING
	await frames(20)
	truck.engine_state = OffroadTruck.EngineState.RUNNING
	camera.position = Vector3(3,2.8,-4)
	camera.look_at(Vector3(.92,2.5,-.5))
	await frames(40)
	await shot('diesel-start')
	await frames(190)
	await shot('diesel-idle')
	sun.light_energy = .05
	env.ambient_light_energy = .08
	env.background_color = Color(.012,.018,.03)
	await frames(30)
	await shot('night')
	print('VISUAL RENDER COMPLETE')
	quit()
