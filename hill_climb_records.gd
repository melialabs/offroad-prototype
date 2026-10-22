class_name HillClimbRecords
extends RefCounted
## Independent, versioned save file. Preserve unknown sections and refuse to
## overwrite an unreadable save. Atomic replacement retains the preceding backup.
var path := "user://hill_climb_records.cfg"
var data := ConfigFile.new()
var load_error := OK
var last_error := OK

func load_records() -> int:
	load_error = data.load(path)
	if load_error == ERR_FILE_NOT_FOUND:
		load_error = OK
	return load_error

func record(route: String, vehicle: int) -> Dictionary:
	var section := "records/%s/%d" % [route, vehicle]
	var best = data.get_value(section, "best_time", 0.0)
	if not (best is float or best is int) or not is_finite(float(best)) or float(best) < 0:
		best = 0.0
	var completions = data.get_value(section,"completions",0)
	if not completions is int:
		completions = 0
	return {"best_time": float(best), "medal": str(data.get_value(section, "medal", "—")), "completions": maxi(0, completions)}

func enabled(route: String) -> bool:
	return bool(data.get_value("enabled", route, true))

func set_enabled(route: String, on: bool) -> int:
	data.set_value("enabled", route, on)
	return _save()

func complete(route: String, vehicle: int, seconds: float, medal: String) -> int:
	if seconds <= 0 or not is_finite(seconds):
		return ERR_INVALID_DATA
	var old := record(route, vehicle)
	var section := "records/%s/%d" % [route, vehicle]
	data.set_value(section, "completions", int(old["completions"]) + 1)
	if old["best_time"] <= 0 or seconds < old["best_time"]:
		data.set_value(section, "best_time", seconds)
		data.set_value(section, "medal", medal)
	return _save()

func _save() -> int:
	if load_error != OK:
		last_error = load_error
		return last_error
	data.set_value("meta", "version", 1)
	var pending := path + ".tmp"
	last_error = data.save(pending)
	if last_error != OK:
		return last_error
	if FileAccess.file_exists(path):
		last_error = DirAccess.copy_absolute(path, path + ".bak")
		if last_error != OK:
			DirAccess.remove_absolute(pending)
			return last_error
	last_error = DirAccess.rename_absolute(pending, path)
	return last_error
