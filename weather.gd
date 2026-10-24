class_name WeatherSystem
extends Node
## Hava presetləri: günəşli, buludlu-soyuq, dumanlı, yağışlı. Gündüz/gecə əsas dəyərləri
## (Main.set_night) üzərində işləyir; keçid yumşaqdır. Səma shader-i, duman, günəş, rəng, yağış
## hissəcikləri, yerdəki sıçrayışlar, yer nəmliyi, külək və yağış səsi buradan idarə olunur.
## Bütün rəqəmlər görünüş üçün seçilib; real meteoroloji ölçü deyil.

const IDS := ["sunny", "cloudy", "fog", "rain"]
const NAME_KEYS := {"sunny": "w_sunny", "cloudy": "w_cloudy", "fog": "w_fog", "rain": "w_rain"}
const SAVE_PATH := "user://offroad_settings.cfg"

## Gündüz / gecə əsas dəyərləri: main.gd-dəki DAY_* / set_night() ilə eyni.
const BASE_DAY := {"sun": 1.55, "sun_col": Color(1.0, 0.95, 0.85), "amb": 0.62, "sat": 1.08,
	"fog_col": Color(0.66, 0.77, 0.88), "density": 0.00065, "fog_begin": 90.0, "fog_end": 4200.0, "vol": 0.0008}
const BASE_NIGHT := {"sun": 0.22, "sun_col": Color(0.55, 0.68, 1.0), "amb": 0.16, "sat": 0.85,
	"fog_col": Color(0.05, 0.08, 0.15), "density": 0.0035, "fog_begin": 90.0, "fog_end": 900.0, "vol": 0.004}

## sun/amb/sat/con: vuruq əmsalları; sun_col: günəş rəngi vuruğu; fog_*: duman (mix=0..1 əsas rəngi əvəz etmə;
## FOG_MODE_DEPTH-də fog_density maksimum qeyri-şəffaflıqdır, ona görə fog_add 0..1 aralığındadır);
## cover: səma örtüyü (0 = ilkin səma, 1 = tam bulud); cdark: yağış buludunun tündlüyü; haze: səmanın dumanlanması;
## soft: günəş kölgəsinin yumşaqlığı (bucaq); rain: yağış intensivliyi; wet: yerin ıslanma hədəfi; wind: külək əmsalı.
const PRESETS := {
	"sunny": {"sun": 1.0, "sun_col": Color(1, 1, 1), "amb": 1.0, "sat": 1.0, "con": 1.0,
		"fog_col": Color(0.66, 0.77, 0.88), "fog_mix": 0.0, "fog_add": 0.0, "fog_begin": 90.0, "fog_end": 4200.0, "fog_curve": 1.6, "vol": 0.0,
		"cover": 0.0, "cdark": 0.0, "haze": 0.0, "overcast": Color(0.62, 0.66, 0.72), "haze_col": Color(0.70, 0.78, 0.86),
		"soft": 0.0, "rain": 0.0, "wet": 0.0, "wind": 1.0, "dust": 1.0},
	"cloudy": {"sun": 0.34, "sun_col": Color(0.80, 0.88, 1.0), "amb": 1.12, "sat": 0.74, "con": 0.97,
		"fog_col": Color(0.60, 0.67, 0.75), "fog_mix": 0.85, "fog_add": 0.20, "fog_begin": 60.0, "fog_end": 2600.0, "fog_curve": 1.4, "vol": 0.0004,
		"cover": 1.0, "cdark": 0.12, "haze": 0.25, "overcast": Color(0.58, 0.64, 0.72), "haze_col": Color(0.62, 0.69, 0.77),
		"soft": 2.2, "rain": 0.0, "wet": 0.10, "wind": 1.4, "dust": 0.8},
	"fog": {"sun": 0.26, "sun_col": Color(0.92, 0.94, 1.0), "amb": 1.0, "sat": 0.66, "con": 0.92,
		"fog_col": Color(0.74, 0.77, 0.80), "fog_mix": 1.0, "fog_add": 0.96, "fog_begin": 3.0, "fog_end": 380.0, "fog_curve": 0.8, "vol": 0.012,
		"cover": 0.85, "cdark": 0.0, "haze": 0.95, "overcast": Color(0.72, 0.75, 0.78), "haze_col": Color(0.74, 0.77, 0.80),
		"soft": 2.8, "rain": 0.0, "wet": 0.40, "wind": 0.35, "dust": 0.6},
	"rain": {"sun": 0.20, "sun_col": Color(0.78, 0.86, 1.0), "amb": 0.95, "sat": 0.78, "con": 0.97,
		"fog_col": Color(0.44, 0.49, 0.55), "fog_mix": 0.95, "fog_add": 0.55, "fog_begin": 20.0, "fog_end": 1100.0, "fog_curve": 1.1, "vol": 0.0015,
		"cover": 1.0, "cdark": 0.75, "haze": 0.55, "overcast": Color(0.40, 0.44, 0.50), "haze_col": Color(0.42, 0.47, 0.53),
		"soft": 3.0, "rain": 1.0, "wet": 1.0, "wind": 1.7, "dust": 0.2},
}

const WET_RISE := 0.035   # saniyədə: yağışda yer ~30 san-də islanır
const WET_FALL := 0.010   # quruma ~100 san
const SPLASH_COUNT := 420
const RAIN_DROPS := 9000

var main: Node
var id := "sunny"
## 0..1, yerin ıslaqlığı (terrain shader-ə, sürtünməyə və tozlanmaya verilir)
var wet := 0.0
## 0..1, hazırkı yağış intensivliyi (yağış səsi, hissəciklər)
var rain_level := 0.0

var _cur: Dictionary = PRESETS["sunny"].duplicate()
var _target: Dictionary = PRESETS["sunny"]
var _dirty := true
var _rain: GPUParticles3D
var _rain_mat: StandardMaterial3D
var _splash: MultiMeshInstance3D
var _splash_mm: MultiMesh
var _splash_mat: StandardMaterial3D
var _s_pos := PackedVector3Array()
var _s_age := PackedFloat32Array()
var _s_cursor := 0
var _s_credit := 0.0
var _rng := RandomNumberGenerator.new()
var _last_wet_sent := -1.0
## Testlər üçün: hazırkı kameranı əvəz edir
var camera_override: Camera3D


static func saved() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var v := str(cfg.get_value("game", "weather", "sunny"))
		if v in IDS:
			return v
	return "sunny"


static func save(weather_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("game", "weather", weather_id)
	cfg.save(SAVE_PATH)


static func next_id(current: String) -> String:
	return IDS[(IDS.find(current) + 1) % IDS.size()]


func _ready() -> void:
	_rng.seed = 4242
	_build_rain()
	_build_splash()


## instant: menyu ilə seçim yumşaq keçir; oyun açılışında dərhal tətbiq olunur.
func set_preset(weather_id: String, instant := false) -> void:
	if weather_id not in IDS:
		weather_id = "sunny"
	id = weather_id
	_target = PRESETS[id]
	if instant:
		_cur = _target.duplicate()
		wet = float(_target["wet"])
	_dirty = true
	if instant:
		_step(0.0)


func apply() -> void:
	_dirty = true
	_step(0.0)


func _process(delta: float) -> void:
	_step(delta)
	_update_rain(delta)


func _step(delta: float) -> void:
	if delta > 0.0:
		var k := 1.0 - exp(-delta / 2.4)
		for key in _target:
			var a: Variant = _cur[key]
			var b: Variant = _target[key]
			if a is Color:
				if not (a as Color).is_equal_approx(b):
					_cur[key] = (a as Color).lerp(b, k)
					_dirty = true
			elif absf(float(a) - float(b)) > 0.0004:
				_cur[key] = lerpf(float(a), float(b), k)
				_dirty = true
			elif float(a) != float(b):
				_cur[key] = b
				_dirty = true
		var goal := float(_target["wet"])
		if wet < goal:
			wet = minf(goal, wet + WET_RISE * delta)
		elif wet > goal:
			wet = maxf(goal, wet - WET_FALL * delta)
	rain_level = float(_cur["rain"])
	if main == null:
		return
	if wet != _last_wet_sent:
		_last_wet_sent = wet
		if main.get("_terrain") != null:
			main._terrain.set_surface_conditions(wet, 0.0, 0.0)
		if main.get("wheel_fx") != null:
			main.wheel_fx.dust_wet_factor = float(_cur["dust"]) * (1.0 - 0.85 * wet)
	if main.get("audio") != null:
		main.audio.rain = rain_level
	if main.get("wind") != null:
		main.wind.weather_mul = float(_cur["wind"])
	if _dirty:
		_dirty = false
		_apply_environment()


func _apply_environment() -> void:
	var env: Environment = main.get("_env")
	var sun: DirectionalLight3D = main.get("_sun")
	var sky: ShaderMaterial = main.get("_sky_mat")
	if env == null or sun == null or sky == null:
		return
	var night: bool = main.night
	var b: Dictionary = BASE_NIGHT if night else BASE_DAY
	var c := _cur
	var dark := 0.07 if night else 1.0  # gecə duman/bulud rəngi qaralır
	if not main.garage_active:
		# gecə: ay işığı buludlardan gündüz günəşi qədər kəskin zəifləmir
		var sun_mul := lerpf(1.0, float(c["sun"]), 0.5) if night else float(c["sun"])
		sun.light_energy = float(b["sun"]) * sun_mul
		sun.light_color = (b["sun_col"] as Color) * (c["sun_col"] as Color)
		env.ambient_light_energy = float(b["amb"]) * float(c["amb"])
	var level := GraphicsQuality.saved_level()
	var profile: Dictionary = GraphicsQuality.PROFILES.get(level, GraphicsQuality.PROFILES[GraphicsQuality.DEFAULT])
	sun.light_angular_distance = maxf(float(profile["angular"]), float(c["soft"]))
	env.adjustment_saturation = float(b["sat"]) * float(c["sat"])
	env.adjustment_contrast = 1.05 * float(c["con"])
	var fog_mix := float(c["fog_mix"])
	var weather_fog: Color = (c["fog_col"] as Color) * dark
	weather_fog.a = 1.0
	env.fog_light_color = (b["fog_col"] as Color).lerp(weather_fog, fog_mix)
	env.fog_density = float(b["density"]) + float(c["fog_add"])
	env.fog_depth_begin = minf(float(b["fog_begin"]), float(c["fog_begin"]))
	env.fog_depth_end = minf(float(b["fog_end"]), float(c["fog_end"]))
	env.fog_depth_curve = float(c["fog_curve"])
	env.fog_sky_affect = lerpf(0.12, 0.7, float(c["haze"]))
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = float(b["vol"]) + float(c["vol"])
		env.volumetric_fog_albedo = env.fog_light_color.lerp(Color.WHITE, 0.25)
	var cover := float(c["cover"])
	sky.set_shader_parameter("cloud_cover", cover)
	sky.set_shader_parameter("cloud_dark", float(c["cdark"]))
	sky.set_shader_parameter("haze", float(c["haze"]))
	var oc: Color = c["overcast"]
	var hc: Color = c["haze_col"]
	sky.set_shader_parameter("overcast_col", Vector3(oc.r, oc.g, oc.b))
	sky.set_shader_parameter("haze_col", Vector3(hc.r, hc.g, hc.b))
	if _rain_mat != null:
		var lum := lerpf(1.0, 0.30, 1.0 if night else 0.0) * (0.55 + 0.45 * minf(float(c["sun"]) * 2.0, 1.0))
		_rain_mat.albedo_color = Color(0.80 * lum + 0.06, 0.86 * lum + 0.07, 0.95 * lum + 0.09, 0.5)
		_splash_mat.albedo_color = Color(0.85 * lum + 0.05, 0.9 * lum + 0.06, 1.0 * lum + 0.08, 0.7)


# --- yağış ----------------------------------------------------------------------------------

func _build_rain() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var streak := GradientTexture2D.new()
	streak.gradient = gradient
	streak.fill = GradientTexture2D.FILL_LINEAR
	streak.fill_from = Vector2(0, 0)
	streak.fill_to = Vector2(0, 1)
	streak.width = 4
	streak.height = 64

	_rain_mat = StandardMaterial3D.new()
	_rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_mat.albedo_texture = streak
	_rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_rain_mat.billboard_keep_scale = true
	_rain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rain_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_rain_mat.distance_fade_min_distance = 24.0
	_rain_mat.distance_fade_max_distance = 5.0
	_rain_mat.albedo_color = Color(0.8, 0.86, 0.95, 0.6)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.010, 0.7)
	quad.material = _rain_mat

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(20.0, 0.3, 20.0)
	proc.direction = Vector3(0.12, -1.0, 0.07).normalized()
	proc.spread = 2.5
	proc.initial_velocity_min = 19.0
	proc.initial_velocity_max = 26.0
	proc.gravity = Vector3.ZERO
	proc.particle_flag_align_y = true
	proc.scale_min = 0.7
	proc.scale_max = 1.15

	_rain = GPUParticles3D.new()
	_rain.process_material = proc
	_rain.draw_pass_1 = quad
	_rain.amount = RAIN_DROPS
	_rain.lifetime = 0.55
	_rain.preprocess = 0.55
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-40, -22, -40), Vector3(80, 30, 80))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.top_level = true
	_rain.emitting = false
	add_child(_rain)


func _build_splash() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var ring := GradientTexture2D.new()
	ring.gradient = gradient
	ring.fill = GradientTexture2D.FILL_RADIAL
	ring.fill_from = Vector2(0.5, 0.5)
	ring.fill_to = Vector2(1.0, 0.5)
	ring.width = 64
	ring.height = 64

	_splash_mat = StandardMaterial3D.new()
	_splash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash_mat.albedo_texture = ring
	_splash_mat.vertex_color_use_as_albedo = true
	_splash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_splash_mat.no_depth_test = false
	_splash_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.7)

	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = _splash_mat

	_splash_mm = MultiMesh.new()
	_splash_mm.transform_format = MultiMesh.TRANSFORM_3D
	_splash_mm.use_colors = true
	_splash_mm.mesh = quad
	_splash_mm.instance_count = SPLASH_COUNT
	_s_pos.resize(SPLASH_COUNT)
	_s_age.resize(SPLASH_COUNT)
	for i in SPLASH_COUNT:
		_s_age[i] = 9.0
		_splash_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_splash_mm.set_instance_color(i, Color(1, 1, 1, 0))
	_splash = MultiMeshInstance3D.new()
	_splash.multimesh = _splash_mm
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splash.top_level = true
	_splash.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	add_child(_splash)


func _camera() -> Camera3D:
	if camera_override != null:
		return camera_override
	return get_viewport().get_camera_3d()


const SPLASH_LIFE := 0.30
const SPLASH_RADIUS := 17.0


func _update_rain(delta: float) -> void:
	var cam := _camera()
	var active := rain_level > 0.01 and cam != null
	_rain.emitting = active
	_rain.amount_ratio = clampf(rain_level, 0.05, 1.0)
	_splash.visible = active or _splash_alive()
	if cam == null:
		return
	var origin := cam.global_position
	_rain.global_position = origin + Vector3(0.0, 9.0, 0.0)
	if main != null and main.get("wind") != null:
		var w: Vector3 = main.wind.direction * main.wind.strength
		(_rain.process_material as ParticleProcessMaterial).direction = Vector3(w.x * 0.35 + 0.05, -1.0, w.z * 0.35 + 0.03).normalized()
	_splash.global_transform = Transform3D.IDENTITY
	var terrain: MudTerrain = main.get("_terrain") if main != null else null
	if active:
		_s_credit += delta * 520.0 * rain_level
		while _s_credit >= 1.0:
			_s_credit -= 1.0
			var angle := _rng.randf_range(0.0, TAU)
			var r := SPLASH_RADIUS * sqrt(_rng.randf())
			var p := Vector3(origin.x + cos(angle) * r, 0.0, origin.z + sin(angle) * r)
			p.y = (terrain.height_at(p) if terrain != null else origin.y - 1.5) + 0.02
			_s_pos[_s_cursor] = p
			_s_age[_s_cursor] = 0.0
			_s_cursor = (_s_cursor + 1) % SPLASH_COUNT
	for i in SPLASH_COUNT:
		if _s_age[i] >= SPLASH_LIFE:
			continue
		_s_age[i] += delta
		var t := clampf(_s_age[i] / SPLASH_LIFE, 0.0, 1.0)
		if t >= 1.0:
			_splash_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var radius := lerpf(0.04, 0.26, sqrt(t))
		_splash_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0)), _s_pos[i]))
		_splash_mm.set_instance_color(i, Color(1, 1, 1, (1.0 - t) * (1.0 - t)))


func _splash_alive() -> bool:
	for i in SPLASH_COUNT:
		if _s_age[i] < SPLASH_LIFE:
			return true
	return false
