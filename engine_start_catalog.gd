class_name EngineStartCatalog
extends RefCounted
## Real recorded starts, disclosed substitutes. Catch time also drives exhaust.
const PROFILES := [
	{"id":"scout", "seconds":1.30, "source":"AC Cobra 427 · substitute"},
	{"id":"cargo", "seconds":1.20, "source":"Kia Carnival 2.9 diesel · substitute"},
	{"id":"heavy", "seconds":2.05, "source":"Ford Courier · substitute; source fuel type unspecified"},
	{"id":"niva", "seconds":1.50, "source":"Unidentified car interior · substitute"},
	{"id":"uaz_expedition", "seconds":1.50, "source":"Unidentified car interior · substitute"},
	{"id":"uaz452", "seconds":1.75, "source":"Peugeot 106 · substitute"},
	{"id":"uaz469", "seconds":1.40, "source":"Peugeot 107 · substitute"},
]
static func profile(index: int) -> Dictionary:
	return PROFILES[clampi(index,0,PROFILES.size()-1)]
static func path(index: int) -> String:
	return "res://assets/audio/engines/start_%s.wav" % profile(index)["id"]
