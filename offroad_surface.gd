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
	return pressure * (0.028 + 0.18 * clampf(slip / 3.0, 0.0, 1.0))


static func resistance(softness: float, depth: float, radius: float) -> float:
	var burial := clampf(depth / maxf(radius, 0.1), 0.0, 1.5)
	return clampf(softness, 0.0, 1.0) * (0.18 + burial * burial * 3.2)


# --- Phase 1/2: per-wheel load, traction-limited open/locked differential, sinkage ---
# Original gameplay approximations (not extracted from any game). All constants are
# tuning values that need visible driving playtests; the unit tests only check direction.

## Godot limits a wheel's friction force to wheel_friction_slip * suspension force, so the
## traction capacity uses the same product (grip is already that coefficient).
const GRIP_TO_MU := 1.0
## Open differential: the weakest wheel limits the torque, but never below this share of
## the strongest wheel's capacity (diff friction / bias).
const OPEN_DIFF_BIAS := 0.25
## Force slightly above the limiting wheel's capacity lets that wheel actually spin.
const SPIN_MARGIN := 1.15
## Smallest per-wheel weight share so a wheel at full droop still carries a little.
const LOAD_FLOOR := 0.05
const SINK_RESISTANCE := 0.55
const SINK_RESISTANCE_CAP := 1.0
## Fraction of the weight carried by the chassis belly when it is fully grounded.
const BELLY_WEIGHT_SHARE := 0.6
const BELLY_DRAG := 0.35
const COMPACTION_RATE := 0.9
const COMPACTION_STIFFENING := 0.55


## Splits the weight over wheels in contact using suspension compression (metres).
## Loads sum to `weight` over the contacting wheels; wheels in the air carry nothing.
static func wheel_loads(compression: PackedFloat32Array, contact: PackedByteArray, weight: float) -> PackedFloat32Array:
	var loads := PackedFloat32Array()
	loads.resize(compression.size())
	var total := 0.0
	for i in compression.size():
		if contact[i] != 0:
			total += maxf(compression[i], 0.0) + LOAD_FLOOR
	if total <= 0.0:
		return loads
	for i in compression.size():
		if contact[i] != 0:
			loads[i] = weight * (maxf(compression[i], 0.0) + LOAD_FLOOR) / total
	return loads


static func traction_capacity(grip: float, load_newtons: float) -> float:
	return maxf(grip, 0.0) * GRIP_TO_MU * maxf(load_newtons, 0.0)


## Godot applies the same engine_force to every driven wheel, which is exactly an open
## differential's equal-torque split. This returns that per-wheel force after the
## differential limit: open = bounded by the weakest wheel, locked = bounded by the mean.
static func deliverable_force(demand_total: float, capacity: PackedFloat32Array, locked: bool) -> float:
	var n := capacity.size()
	if n == 0:
		return 0.0
	var best := 0.0
	var weakest := INF
	var sum := 0.0
	for c in capacity:
		best = maxf(best, c)
		weakest = minf(weakest, c)
		sum += c
	var each := demand_total / n
	if locked:
		return minf(each, sum / n * SPIN_MARGIN)
	return minf(each, maxf(weakest, best * OPEN_DIFF_BIAS) * SPIN_MARGIN)


## Bekker-style sinkage resistance (N, opposes motion): grows with load and with rut depth
## relative to wheel radius, so a deeply sunk truck can stop even when its tires still turn.
static func sinkage_resistance(load_newtons: float, softness: float, depth: float, radius: float) -> float:
	var burial := clampf(depth / maxf(radius, 0.1), 0.0, 1.5)
	var coefficient := minf(SINK_RESISTANCE * clampf(softness, 0.0, 1.0) * pow(burial, 1.3), SINK_RESISTANCE_CAP)
	return coefficient * maxf(load_newtons, 0.0)


## 0 = chassis clear of the ground, 1 = resting on it. `clearance` is metres to the soil.
static func belly_support(clearance: float) -> float:
	return clampf((0.06 - clearance) / 0.06, 0.0, 1.0)


## Weight carried by the wheels once the belly takes its share.
static func wheel_weight(total_weight: float, belly: float) -> float:
	return total_weight * (1.0 - BELLY_WEIGHT_SHARE * clampf(belly, 0.0, 1.0))


static func belly_drag_force(total_weight: float, softness: float, belly: float) -> float:
	return total_weight * BELLY_DRAG * clampf(softness, 0.0, 1.0) * clampf(belly, 0.0, 1.0)


## Soil that was driven over without digging firms up; spinning loosens nothing back.
static func compaction_gain(load_newtons: float, width: float, radius: float, slip: float) -> float:
	var area := maxf(width * radius * 0.6, 0.02)
	var pressure := clampf(load_newtons / area / 45000.0, 0.2, 3.0)
	return COMPACTION_RATE * pressure * (1.0 - clampf(slip / 2.0, 0.0, 1.0))


static func effective_softness(softness: float, compaction: float) -> float:
	return clampf(softness, 0.0, 1.0) * (1.0 - COMPACTION_STIFFENING * clampf(compaction, 0.0, 1.0))
