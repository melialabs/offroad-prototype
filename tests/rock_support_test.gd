extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var terrain := MudTerrain.new()
	root.add_child(terrain)
	var p := Vector3(-365,0,-425)
	var ground := terrain.height_at(p)
	var rock := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9,1,9)
	col.shape = box
	rock.add_child(col)
	rock.position = Vector3(p.x,ground+1.5,p.z)
	root.add_child(rock)
	var truck := OffroadTruck.new()
	truck.terrain = terrain
	root.add_child(truck)
	truck.position = Vector3(p.x,ground+3.2,p.z)
	truck.stop_engine()
	truck.controls_enabled = false
	for i in 180:
		await physics_frame
	var contacts := 0
	var failures := 0
	for wheel in truck.wheels:
		if wheel.is_in_contact() and wheel.get_contact_body() == rock:
			contacts += 1
			if truck._is_soil_support(wheel) or not is_equal_approx(wheel.wheel_friction_slip,OffroadTruck.TIRES[1]["hard"]):
				failures += 1
		if terrain.depth_at(wheel.global_position)>0.001:
			failures += 1
	if contacts != 4:
		print("FAIL rock wheel contact count=",contacts)
		failures += 1
	truck.free()
	rock.free()
	terrain.free()
	print("ROCK SUPPORT contacts=%d failures=%d" % [contacts,failures])
	quit(0 if failures==0 else 1)
