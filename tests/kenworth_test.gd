extends SceneTree
## Heavy truck (Kenworth-style, supplied Kenwood model): model loads, tandem rear axle has four
## visual tyres following the two rear physics wheels, front wheels steer.
## godot --headless --path . -s res://tests/kenworth_test.gd
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var truck := OffroadTruck.new()
	root.add_child(truck)
	truck.freeze = true
	truck.apply_spec(2)
	await process_frame
	var car: Dictionary = truck._cars.get(2, {})
	check(not car.is_empty(), "Kenworth model loads for the heavy truck")
	var cm: CarModel = car["model"]
	check(cm.body.visible, "model visible")
	check(cm.extra_wheels.size() == 4, "four tandem tyres")
	check(truck._extra_wheel_nodes.size() == 4, "tandem tyres instantiated")
	check(absf(cm.wheel_radius - 0.53) < 0.03, "wheel radius from the front tyres")
	check(truck.wheels[2].use_as_steering and truck.wheels[3].use_as_steering, "front axle steers")
	check(not truck.wheels[0].use_as_steering and not truck.wheels[1].use_as_steering, "tandem axle fixed")
	for e in cm.extra_wheels:
		check(absf(absf((e["offset"] as Vector3).z) - 0.63) < 0.1, "tandem tyres sit about 0.63 m either side of the anchor")
	truck.apply_spec(0)
	check(truck._extra_wheel_nodes.is_empty(), "tandem tyres removed on other vehicles")
	truck.free()
	print("KENWORTH TEST failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
