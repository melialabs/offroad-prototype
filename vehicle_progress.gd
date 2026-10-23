class_name VehicleProgress
extends RefCounted
## Açılmış texnika: köhnə qarajlarda (BarnFinds) gizlədilmiş maşınlar tapılana qədər kilidlidir.
## Saxlanır: user://offroad_progress.cfg

const SAVE_PATH := "user://offroad_progress.cfg"
## Qarajlarda tapılan texnika (SPECS indeksləri): UAZ Expedition, Bukhanka, UAZ 469
const BARN_VEHICLES := [4, 5, 6]

## Testlər öz faylını istifadə edir ki, oyunçunun tapıntılarına toxunmasın.
static var save_path := SAVE_PATH
static var _found: Array = []
static var _taken: Array = []
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		_found = cfg.get_value("barns", "found", [])
		_taken = cfg.get_value("barns", "taken", [])


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("barns", "found", _found)
	cfg.set_value("barns", "taken", _taken)
	cfg.save(save_path)


static func is_unlocked(spec: int) -> bool:
	_ensure()
	return spec not in BARN_VEHICLES or spec in _found


static func is_found(site_id: String) -> bool:
	_ensure()
	return site_id in _found


static func is_taken(site_id: String) -> bool:
	_ensure()
	return site_id in _taken


static func discover(site_id: String, spec: int) -> void:
	_ensure()
	for v in [site_id, spec]:
		if v not in _found:
			_found.append(v)
	_save()


static func take(site_id: String) -> void:
	_ensure()
	if site_id not in _taken:
		_taken.append(site_id)
	_save()


## Testlər üçün: bütün tapıntıları sıfırlayır (yalnız yaddaşda; save=true olduqda fayla da yazır).
static func reset(save := false) -> void:
	_loaded = true
	_found = []
	_taken = []
	if save:
		_save()
