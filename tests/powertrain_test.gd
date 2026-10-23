extends SceneTree
## Real flat-ground acceleration, gear shifts, reverse, braking and support.
var failures: Array[String] = []
var shifts := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ",label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000,1,2000)
	collider.shape = shape
	ground.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)
	var t := OffroadTruck.new()
	world.add_child(t)
	t.gear_changed.connect(func(_old: int,_new: int): shifts += 1)
	var speeds: Array[float] = []
	var identities: Array[String] = []
	for index in 4:
		t.apply_spec(index)
		t.global_transform = Transform3D(Basis.IDENTITY,Vector3(index*15,2,0))
		t.linear_velocity = Vector3.ZERO
		t.angular_velocity = Vector3.ZERO
		Input.action_release(&"ui_up")
		for f in 120:
			await physics_frame
		var contacts := 0
		for wheel in t.wheels:
			contacts += 1 if wheel.is_in_contact() else 0
		check(contacts == 4,"four ground contacts: %d" % index)
		var profile := t.powertrain
		identities.append(profile["id"])
		check(t._torque_at(float(profile["redline"])+1) == 0,"redline torque cut: %d" % index)
		var ratio := t._ratio()
		t.low_range = true
		check(t._ratio() > ratio*1.5,"low range multiplies actual gears: %d" % index)
		t.low_range = false
		t.awd_on = t.spec["awd"] != "none"
		t.diff_lock = true
		var origin := t.global_position
		var shift_start := shifts
		Input.action_press(&"ui_up")
		for f in 720:
			await physics_frame
		var kmh := Vector2(t.linear_velocity.x,t.linear_velocity.z).length()*3.6
		speeds.append(kmh)
		check(t.global_position.z-origin.z > 12,"actual forward acceleration: %d" % index)
		check(kmh > 15 and kmh <= float(profile["top"])*1.1,"plausible measured speed: %d %.1f" % [index,kmh])
		check(shifts > shift_start,"automatic gear shifts: %d" % index)
		check(t.rpm <= float(profile["redline"])+151,"RPM stays bounded: %d" % index)
		print("POWERTRAIN %s · 12s %.1f km/h · gear %d · RPM %.0f · distance %.1fm" % [t.spec["name"],kmh,t.gear,t.rpm,t.global_position.z-origin.z])
		Input.action_release(&"ui_up")
		Input.action_press(&"ui_down")
		for f in 120:
			await physics_frame
		check(t.linear_velocity.length()*3.6 < kmh,"opposite control brakes forward motion: %d" % index)
		# Verify the limiter removes propulsion without rewriting momentum.
		Input.action_release(&"ui_down")
		Input.action_press(&"ui_up")
		t.linear_velocity = Vector3(0,0,float(profile["top"])/3.6*1.05)
		var overspeed := t.linear_velocity
		t._physics_process(1.0/60.0)
		check(is_zero_approx(t.engine_force),"target speed cuts propulsion: %d" % index)
		check(t.linear_velocity == overspeed,"limiter preserves physics velocity: %d" % index)
		Input.action_release(&"ui_up")
		t.linear_velocity = Vector3.ZERO
		Input.action_press(&"ui_down")
		for f in 90:
			await physics_frame
		check(t.gear == -1 and t.linear_velocity.z < -0.5,"reverse control drives backward: %d" % index)
		Input.action_release(&"ui_down")
		t.stop_engine()
		t._physics_process(1.0/60.0)
		check(t.engine_force == 0,"engine off cannot propel: %d" % index)
		t.engine_state = OffroadTruck.EngineState.RUNNING
	check(identities.size()==4,"four distinct powertrain identities")
	check(speeds.max()-speeds.min()>10,"vehicles accelerate differently")
	world.free()
	print("POWERTRAIN TEST failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
