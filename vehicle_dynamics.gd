class_name VehicleDynamics
extends RefCounted
## Tuned prototype powertrains, not certified manufacturer performance figures.
## Wheel/suspension/contact physics stay in OffroadTruck. All rates use seconds.
const PROFILES := [
	{"id":"scout", "idle":720.0, "redline":5600.0, "peak_rpm":3300.0, "torque":340.0, "up":4600.0, "down":1600.0, "final":4.10, "gears":[3.83,2.33,1.44,1.0,0.79], "reverse":3.65, "low":2.72, "response":5.0, "shift":0.24, "top":135.0, "drag":0.75},
	{"id":"cargo", "idle":650.0, "redline":3200.0, "peak_rpm":1800.0, "torque":650.0, "up":2700.0, "down":1100.0, "final":4.88, "gears":[5.72,3.24,2.10,1.35,1.0,0.78], "reverse":5.20, "low":2.0, "response":2.7, "shift":0.45, "top":100.0, "drag":1.25},
	{"id":"heavy", "idle":600.0, "redline":2600.0, "peak_rpm":1400.0, "torque":1250.0, "up":2200.0, "down":900.0, "final":5.43, "gears":[7.10,4.80,3.40,2.45,1.80,1.32,1.0,0.82], "reverse":6.20, "low":1.80, "response":1.8, "shift":0.62, "top":85.0, "drag":1.9},
	{"id":"niva", "idle":850.0, "redline":6000.0, "peak_rpm":3400.0, "torque":140.0, "up":5000.0, "down":1900.0, "final":4.10, "gears":[3.67,2.10,1.36,1.0,0.82], "reverse":3.53, "low":2.135, "response":4.4, "shift":0.32, "top":130.0, "drag":0.60},
]

static func for_vehicle(index: int) -> Dictionary:
	if index < PROFILES.size():
		return PROFILES[maxi(index,0)]
	# Retain the appended UAZs with their existing stronger gameplay engines.
	var p: Dictionary = PROFILES[0].duplicate(true)
	p["id"] = ["uaz_expedition","uaz452","uaz469"][clampi(index-4,0,2)]
	p["torque"] = [520.0,430.0,400.0][clampi(index-4,0,2)]
	p["top"] = 115.0
	return p

static func torque_at(profile: Dictionary, rpm: float) -> float:
	if rpm >= float(profile["redline"]):
		return 0.0
	var peak := float(profile["peak_rpm"])
	var width := peak if rpm < peak else float(profile["redline"]) - peak
	var offset := (rpm - peak) / maxf(1.0,width)
	return float(profile["torque"]) * clampf(1.0 - 0.48 * offset * offset,0.40,1.0)
