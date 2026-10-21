class_name OffroadSurface
extends RefCounted
## Original gameplay model; coefficients are tuned for this prototype, not extracted.
## This approximates terrain resistance, not a soil mechanics solver.

static func grip(tire: Dictionary, asphalt: bool, softness: float, rut_depth: float) -> float:
	if asphalt:
		return float(tire["asphalt"])
	var mud_weight := clampf(softness * 0.6 + rut_depth / 0.7 * 0.6, 0.0, 1.0)
	return lerpf(float(tire["hard"]), float(tire["mud"]), mud_weight)


static func slip_speed(wheel_rpm: float, radius: float, ground_speed: float) -> float:
	var tread_speed := absf(wheel_rpm) * TAU * radius / 60.0
	return maxf(tread_speed - absf(ground_speed), 0.0)


static func digging_rate(load_newtons: float, width: float, radius: float, slip: float) -> float:
	var area := maxf(width * radius * 0.6, 0.02)
	var pressure := clampf(load_newtons / area / 45000.0, 0.2, 3.0)
	return pressure * (0.012 + 0.10 * clampf(slip / 3.0, 0.0, 1.0))


static func resistance(softness: float, depth: float, radius: float) -> float:
	var burial := clampf(depth / maxf(radius, 0.1), 0.0, 1.5)
	return clampf(softness, 0.0, 1.0) * (0.08 + burial * burial * 1.4)
