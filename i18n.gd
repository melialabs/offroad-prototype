class_name I18n
extends RefCounted
## Menyu dili: İngilis (en) və Azərbaycan (az). Seçim user://offroad_settings.cfg-də saxlanılır.
## Oyun içi HUD/mesajlar hələlik Azərbaycan dilindədir; bu fayl menyunu əhatə edir.

const SAVE_PATH := "user://offroad_settings.cfg"
const LANGS := ["en", "az"]
const LANG_NAMES := {"en": "English", "az": "Azərbaycanca"}

static var lang := "en"
static var _loaded := false

## açar: [English, Azərbaycan]
const TEXT := {
	"tagline": ["Mud. Cargo. Hard roads.", "Palçıq. Yük. Çətin yollar."],
	"m_continue": ["CONTINUE", "DAVAM ET"],
	"m_start": ["START GAME", "OYUNA BAŞLA"],
	"m_restart": ["RESTART ON ROAD", "YOLA QAYIT"],
	"m_garage": ["GARAGE", "QARAJ"],
	"m_controls": ["CONTROLS", "İDARƏETMƏ"],
	"m_options": ["OPTIONS", "AYARLAR"],
	"m_quit": ["QUIT", "ÇIXIŞ"],
	"back": ["BACK", "GERİ"],
	"footer": ["Prototype", "Prototip"],
	"garage_hint": ["Garage: pick a vehicle. It is swapped instantly on the road behind.", "Qaraj: texnikanı seç. Maşın dərhal arxada yolun üstündə dəyişir."],
	"kg": ["kg", "kq"],
	"awd": ["AWD", "AWD"],
	"diff": ["diff lock", "dif. kilidi"],
	"always": ["always", "həmişə"],
	"switch": ["switchable", "açar-bağla"],
	"none": ["none", "yox"],
	"has": ["yes", "var"],
	"fullscreen": ["Fullscreen", "Tam ekran"],
	"shadows": ["Shadows", "Kölgələr"],
	"sound": ["Sound", "Səs"],
	"time": ["Time", "Vaxt"],
	"language": ["Language", "Dil"],
	"graphics": ["Graphics", "Qrafika"],
	"on": ["on", "açıq"],
	"off": ["off", "bağlı"],
	"night": ["Night", "Gecə"],
	"day": ["Day", "Gündüz"],
	# idarəetmə
	"c_drive": ["Driving", "Sürüş"],
	"c_camera": ["Camera", "Kamera"],
	"c_trans": ["Transmission", "Transmissiya"],
	"c_other": ["Other", "Digər"],
	"c_wasd_w": ["throttle / brake and reverse", "qaz / əyləc və geri"],
	"c_wasd_a": ["steering", "sükan"],
	"c_space": ["handbrake", "əl əyləci"],
	"c_r": ["return to road / Retry in an active race", "yola qaytar / aktiv yarışda Retry"],
	"c_gyb": ["winch attach-detach / select tree / hold to pull", "tros bağla-ayır / ağacı seç / basılı saxla və çək"],
	"c_i": ["engine start / stop", "mühərriki işə sal / söndür"],
	"c_l": ["headlights: off / low / high", "fənərlər: söndür / yaxın / uzaq"],
	"c_z": ["hazard lights", "qəza işıqları"],
	"c_n": ["day / night", "gündüz / gecə"],
	"c_mouse": ["orbit the camera (returns behind the car when released)", "kameranı çevir (GTA kimi, buraxanda arxaya qayıdır)"],
	"c_v": ["close / far / hood camera", "yaxın / uzaq / kapot kamerası"],
	"c_q": ["low / high range", "aşağı / yuxarı diapazon"],
	"c_e": ["AWD / start Hill Climb in a marked circle", "AWD / dayanılmış dairədə Hill Climb başlat"],
	"c_f": ["differential lock", "diferensial kilidi"],
	"c_t": ["tyre type", "təkər növü"],
	"c_nums": ["unlocked vehicles in garage order", "açılmış texnika, qaraj sırası ilə"],
	"c_m": ["enlarge / shrink the GPS map", "GPS xəritəsini böyüt / kiçilt"],
	"c_bksp": ["leave Hill Climb", "Hill Climb-dən çıx"],
	"c_brk": ["choose a route at an activity marker", "aktivlik məntəqəsində marşrut seç"],
	"c_h": ["show / hide key hints", "düymə göstərişini aç / bağla"],
	"c_esc": ["menu", "menyu"],
	"locked": ["🔒 Barn find", "🔒 Gizli qaraj"],
	"locked_hint": ["Find it in an old garage on the map (? on the GPS)", "Xəritədə köhnə qarajda tap (GPS-də ?)"],
	"barn_found": ["Barn find! %s — press C to take it", "Gizli qaraj tapıldı! %s — götürmək üçün C"],
	"barn_taken": ["%s is now yours (Garage)", "%s artıq səninlə (Qaraj)"],
	"c_c": ["take a found barn vehicle", "tapılmış maşını götür"],
	"veh_Skaut": ["Scout", "Skaut"],
	"veh_Yük maşını": ["Cargo truck", "Yük maşını"],
	"veh_Ağır tır": ["Heavy truck", "Ağır tır"],
}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved := str(cfg.get_value("ui", "language", "en"))
		if saved in LANGS:
			lang = saved


static func set_language(code: String) -> void:
	_ensure()
	if code not in LANGS:
		return
	lang = code
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("ui", "language", code)
	cfg.save(SAVE_PATH)


static func t(key: String) -> String:
	_ensure()
	var row: Array = TEXT.get(key, [key, key])
	return str(row[LANGS.find(lang)])


## Maşın adı (SPECS-də Azərbaycan dilində); tərcüməsi olmayanlar (UAZ, Lada) olduğu kimi qalır.
static func vehicle(spec_name: String) -> String:
	return t("veh_" + spec_name) if TEXT.has("veh_" + spec_name) else spec_name
