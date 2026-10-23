extends SceneTree
## Direction-of-effect checks for the per-wheel load, differential, sinkage and belly model.
## Pure functions only: no scene, no rendering. Vehicle feel still needs a driving playtest.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)


func _initialize() -> void:
	run.call_deferred()


func _bytes(values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for v in values:
		out.append(int(v))
	return out


func _floats(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in values:
		out.append(float(v))
	return out


func run() -> void:
	var weight := 2000.0 * 9.81

	# --- per-wheel load -------------------------------------------------------------
	var equal := OffroadSurface.wheel_loads(_floats([0.1, 0.1, 0.1, 0.1]), _bytes([1, 1, 1, 1]), weight)
	check(is_equal_approx(equal[0], weight / 4.0), "equal compression gives equal load")
	var sum := 0.0
	for v in equal:
		sum += v
	check(is_equal_approx(sum, weight), "loads sum to the supported weight")
	var uneven := OffroadSurface.wheel_loads(_floats([0.3, 0.05, 0.1, 0.1]), _bytes([1, 1, 1, 1]), weight)
	check(uneven[0] > uneven[1], "more compressed wheel carries more load")
	var airborne := OffroadSurface.wheel_loads(_floats([0.1, 0.1, 0.1, 0.1]), _bytes([1, 1, 1, 0]), weight)
	check(is_zero_approx(airborne[3]), "wheel in the air carries no load")
	check(airborne[0] > equal[0], "remaining wheels pick up the airborne wheel's share")
	var none := OffroadSurface.wheel_loads(_floats([0.1, 0.1]), _bytes([0, 0]), weight)
	check(is_zero_approx(none[0]) and is_zero_approx(none[1]), "no contact means no load")

	# --- traction capacity and differential ------------------------------------------
	check(OffroadSurface.traction_capacity(2.0, 1000.0) > OffroadSurface.traction_capacity(1.0, 1000.0), "more grip gives more capacity")
	check(OffroadSurface.traction_capacity(1.0, 2000.0) > OffroadSurface.traction_capacity(1.0, 1000.0), "more load gives more capacity")
	var strong := _floats([4000, 4000, 4000, 4000])
	check(is_equal_approx(OffroadSurface.deliverable_force(4000.0, strong, false), 1000.0), "enough traction delivers the full demand")
	var one_weak := _floats([4000, 4000, 4000, 100])
	var open_force := OffroadSurface.deliverable_force(20000.0, one_weak, false)
	var locked_force := OffroadSurface.deliverable_force(20000.0, one_weak, true)
	check(locked_force > open_force, "locked differential delivers more than open when one wheel is weak")
	check(open_force < 20000.0 / 4.0, "open differential is bounded below the demand")
	var lifted := _floats([4000, 4000, 4000, 0])
	check(OffroadSurface.deliverable_force(20000.0, lifted, false) > 0.0, "bias keeps some drive with a wheel in the air")
	check(OffroadSurface.deliverable_force(20000.0, _floats([]), false) == 0.0, "no driven wheels gives no force")
	var mud_caps := _floats([900, 900, 900, 900])
	check(OffroadSurface.deliverable_force(20000.0, mud_caps, false) < 20000.0 / 4.0, "weak surface limits force, so excess torque spins the wheels")

	# --- sinkage ---------------------------------------------------------------------
	check(is_zero_approx(OffroadSurface.sinkage_resistance(5000.0, 0.0, 0.5, 0.4)), "hard ground has no sinkage resistance")
	check(is_zero_approx(OffroadSurface.sinkage_resistance(5000.0, 1.0, 0.0, 0.4)), "no sinkage means no resistance")
	check(OffroadSurface.sinkage_resistance(5000.0, 1.0, 0.4, 0.4) > OffroadSurface.sinkage_resistance(5000.0, 1.0, 0.1, 0.4), "deeper sinkage resists more")
	check(OffroadSurface.sinkage_resistance(8000.0, 1.0, 0.3, 0.4) > OffroadSurface.sinkage_resistance(4000.0, 1.0, 0.3, 0.4), "heavier load resists more")
	check(OffroadSurface.sinkage_resistance(5000.0, 1.0, 5.0, 0.4) <= 5000.0 * OffroadSurface.SINK_RESISTANCE_CAP + 0.001, "resistance is capped relative to load")

	# --- belly ------------------------------------------------------------------------
	check(is_zero_approx(OffroadSurface.belly_support(0.2)), "clear chassis has no belly support")
	check(is_equal_approx(OffroadSurface.belly_support(0.0), 1.0), "grounded chassis is fully supported")
	check(OffroadSurface.wheel_weight(weight, 1.0) < weight, "belly support unloads the wheels")
	check(is_equal_approx(OffroadSurface.wheel_weight(weight, 0.0), weight), "no belly support keeps full wheel weight")
	check(OffroadSurface.belly_drag_force(weight, 1.0, 1.0) > OffroadSurface.belly_drag_force(weight, 0.2, 1.0), "belly drags more in soft ground")
	check(is_zero_approx(OffroadSurface.belly_drag_force(weight, 1.0, 0.0)), "no belly contact means no belly drag")

	# --- compaction -------------------------------------------------------------------
	check(OffroadSurface.compaction_gain(4000.0, 0.3, 0.4, 0.0) > OffroadSurface.compaction_gain(4000.0, 0.3, 0.4, 3.0), "rolling compacts more than spinning")
	check(OffroadSurface.effective_softness(1.0, 1.0) < OffroadSurface.effective_softness(1.0, 0.0), "compacted soil is firmer")
	check(OffroadSurface.effective_softness(0.0, 0.5) == 0.0, "hard ground stays hard")

	print("TRACTION PHASE: failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
