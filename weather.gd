class_name WeatherSystem
extends Node
## Hava presetləri: günəşli, buludlu-soyuq, dumanlı, yağışlı. Gündüz/gecə əsas dəyərləri
## (Main.set_night) üzərində işləyir; keçid yumşaqdır. Səma shader-i, duman, günəş, rəng, yağış
## hissəcikləri, yerdəki sıçrayışlar, yer nəmliyi, külək və yağış səsi buradan idarə olunur.
## Bütün rəqəmlər görünüş üçün seçilib; real meteoroloji ölçü deyil.

const IDS := ["sunny", "cloudy", "fog", "rain", "storm"]
const NAME_KEYS := {"sunny": "w_sunny", "cloudy": "w_cloudy", "fog": "w_fog", "rain": "w_rain", "storm": "w_storm"}
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
		"soft": 0.0, "rain": 0.0, "wet": 0.0, "wind": 1.0, "dust": 1.0, "storm": 0.0},
	"cloudy": {"sun": 0.34, "sun_col": Color(0.80, 0.88, 1.0), "amb": 1.12, "sat": 0.74, "con": 0.97,
		"fog_col": Color(0.60, 0.67, 0.75), "fog_mix": 0.85, "fog_add": 0.20, "fog_begin": 60.0, "fog_end": 2600.0, "fog_curve": 1.4, "vol": 0.0004,
		"cover": 1.0, "cdark": 0.12, "haze": 0.25, "overcast": Color(0.58, 0.64, 0.72), "haze_col": Color(0.62, 0.69, 0.77),
		"soft": 2.2, "rain": 0.0, "wet": 0.10, "wind": 1.4, "dust": 0.8, "storm": 0.0},
	"fog": {"sun": 0.26, "sun_col": Color(0.92, 0.94, 1.0), "amb": 1.0, "sat": 0.66, "con": 0.92,
		"fog_col": Color(0.74, 0.77, 0.80), "fog_mix": 1.0, "fog_add": 0.96, "fog_begin": 3.0, "fog_end": 380.0, "fog_curve": 0.8, "vol": 0.012,
		"cover": 0.85, "cdark": 0.0, "haze": 0.95, "overcast": Color(0.72, 0.75, 0.78), "haze_col": Color(0.74, 0.77, 0.80),
		"soft": 2.8, "rain": 0.0, "wet": 0.40, "wind": 0.35, "dust": 0.6, "storm": 0.0},
	"rain": {"sun": 0.20, "sun_col": Color(0.78, 0.86, 1.0), "amb": 0.95, "sat": 0.78, "con": 0.97,
		"fog_col": Color(0.44, 0.49, 0.55), "fog_mix": 0.95, "fog_add": 0.55, "fog_begin": 20.0, "fog_end": 1100.0, "fog_curve": 1.1, "vol": 0.0015,
		"cover": 1.0, "cdark": 0.75, "haze": 0.55, "overcast": Color(0.40, 0.44, 0.50), "haze_col": Color(0.42, 0.47, 0.53),
		"soft": 3.0, "rain": 1.0, "wet": 1.0, "wind": 1.7, "dust": 0.2, "storm": 0.0},
	# fırtına: ağır yağış, çox güclü külək, qara bulud, şimşək və ildırım
	"storm": {"sun": 0.12, "sun_col": Color(0.74, 0.82, 1.0), "amb": 0.82, "sat": 0.70, "con": 1.0,
		"fog_col": Color(0.26, 0.30, 0.36), "fog_mix": 0.97, "fog_add": 0.70, "fog_begin": 15.0, "fog_end": 650.0, "fog_curve": 1.0, "vol": 0.002,
		"cover": 1.0, "cdark": 1.0, "haze": 0.60, "overcast": Color(0.30, 0.33, 0.39), "haze_col": Color(0.30, 0.34, 0.40),
		"soft": 3.0, "rain": 1.0, "wet": 1.0, "wind": 3.3, "dust": 0.1, "storm": 1.0},
}

const WET_RISE := 0.035   # saniyədə: yağışda yer ~30 san-də islanır
const WET_FALL := 0.010   # quruma ~100 san
const SPLASH_COUNT := 640
const RAIN_DROPS := 12000
const RAIN_FAR_DROPS := 16000

var main: Node
var id := "sunny"
## 0..1, yerin ıslaqlığı (terrain shader-ə, sürtünməyə və tozlanmaya verilir)
var wet := 0.0
## 0..1, hazırkı yağış intensivliyi (yağış səsi, hissəciklər)
var rain_level := 0.0
var _last_rain_sent := -1.0

var _cur: Dictionary = PRESETS["sunny"].duplicate()
var _target: Dictionary = PRESETS["sunny"]
var _dirty := true
var _rain: GPUParticles3D
var _rain_mat: ShaderMaterial
var _rain_far: GPUParticles3D
var _rain_far_mat: ShaderMaterial
var _splash: MultiMeshInstance3D
var _splash_mm: MultiMesh
var _splash_mat: StandardMaterial3D
var _bolt_glow: MeshInstance3D
var _bolt_glow_mat: StandardMaterial3D
var _bolt_light: OmniLight3D
## Damcı yerə dəyəndə qalxan kiçik su tacı (şaquli billboard)
var _crown_mm: MultiMesh
var _crown_mat: StandardMaterial3D
var _s_pos := PackedVector3Array()
var _s_age := PackedFloat32Array()
var _s_cursor := 0
var _s_credit := 0.0
var _rng := RandomNumberGenerator.new()
var _last_wet_sent := -1.0
## Testlər üçün: hazırkı kameranı əvəz edir
var camera_override: Camera3D

## Şimşək: 0..1 parıltı, səmadakı istiqamət, nəbz cədvəli [başlama, güc, sönmə], vaxt
var flash := 0.0
var _flash_dir := Vector3(0.0, 0.35, 1.0)
var _pulses: Array = []
var _flash_clock := -1.0
var _flash_end := 0.0
var _flash_scale := 1.0
var _next_strike := 2.0
var _thunder_queue: Array = []
var strikes := 0
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D


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
	_build_bolt_node()


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
	_update_lightning(delta)
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
	if absf(rain_level - _last_rain_sent) > 0.01 and main.get("_terrain") != null:
		_last_rain_sent = rain_level
		main._terrain.set_rain(rain_level)
	var storm := float(_cur["storm"])
	if main.get("audio") != null:
		main.audio.rain = rain_level * (1.0 + 0.35 * storm)
		main.audio.storm = storm
	if main.get("wind") != null:
		# fırtınada külək nəfəsləri: ləng dalğa ilə güclənib zəifləyir
		var gusts := 1.0 + storm * 0.32 * sin(main.wind.clock * 0.8) * sin(main.wind.clock * 0.37 + 1.0)
		main.wind.weather_mul = float(_cur["wind"]) * gusts
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
		env.ambient_light_energy = float(b["amb"]) * float(c["amb"]) + flash * 1.4
		sun.light_energy += flash * 2.4 * _flash_scale
		sun.light_color = sun.light_color.lerp(Color(0.80, 0.88, 1.0), clampf(flash, 0.0, 1.0) * 0.85)
	var level := GraphicsQuality.saved_level()
	var profile: Dictionary = GraphicsQuality.PROFILES.get(level, GraphicsQuality.PROFILES[GraphicsQuality.DEFAULT])
	sun.light_angular_distance = maxf(float(profile["angular"]), float(c["soft"]))
	env.adjustment_saturation = float(b["sat"]) * float(c["sat"])
	env.adjustment_contrast = 1.05 * float(c["con"])
	var fog_mix := float(c["fog_mix"])
	var weather_fog: Color = (c["fog_col"] as Color) * dark
	weather_fog.a = 1.0
	env.fog_light_color = (b["fog_col"] as Color).lerp(weather_fog, fog_mix)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.72, 0.80, 1.0), clampf(flash, 0.0, 1.0) * 0.5)
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
	sky.set_shader_parameter("flash", flash)
	sky.set_shader_parameter("flash_dir", _flash_dir)
	sky.set_shader_parameter("cloud_dark", float(c["cdark"]))
	sky.set_shader_parameter("haze", float(c["haze"]))
	var oc: Color = c["overcast"]
	var hc: Color = c["haze_col"]
	sky.set_shader_parameter("overcast_col", Vector3(oc.r, oc.g, oc.b))
	sky.set_shader_parameter("haze_col", Vector3(hc.r, hc.g, hc.b))
	if _rain_mat != null:
		var lum := lerpf(1.0, 0.30, 1.0 if night else 0.0) * (0.55 + 0.45 * minf(float(c["sun"]) * 2.0, 1.0))
		var tint := Vector3(0.62 * lum + 0.05, 0.67 * lum + 0.06, 0.75 * lum + 0.08)
		_rain_mat.set_shader_parameter("tint", tint)
		_rain_far_mat.set_shader_parameter("tint", tint)
		_splash_mat.albedo_color = Color(0.85 * lum + 0.05, 0.9 * lum + 0.06, 1.0 * lum + 0.08, 0.7)
		_crown_mat.albedo_color = Color(0.85 * lum + 0.05, 0.9 * lum + 0.06, 1.0 * lum + 0.08, 0.75)


# --- yağış ----------------------------------------------------------------------------------

func _build_rain() -> void:
	var shader := load("res://rain_drop.gdshader") as Shader
	# yaxın qat: kameranın ətrafında iri, aydın damcılar
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = shader
	_rain_mat.set_shader_parameter("opacity", 0.42)
	_rain_mat.set_shader_parameter("near_fade_start", 1.2)
	_rain_mat.set_shader_parameter("near_fade_end", 2.6)
	_rain_mat.set_shader_parameter("far_fade_start", 14.0)
	_rain_mat.set_shader_parameter("far_fade_end", 21.0)
	_rain = _make_rain_layer(_rain_mat, Vector2(0.007, 0.55), Vector3(20.0, 0.3, 20.0), RAIN_DROPS, 9.0)
	# uzaq qat: dərinlik verən sıx, zəif "yağış pərdəsi"
	_rain_far_mat = ShaderMaterial.new()
	_rain_far_mat.shader = shader
	_rain_far_mat.set_shader_parameter("opacity", 0.16)
	_rain_far_mat.set_shader_parameter("near_fade_start", 12.0)
	_rain_far_mat.set_shader_parameter("near_fade_end", 18.0)
	_rain_far_mat.set_shader_parameter("far_fade_start", 48.0)
	_rain_far_mat.set_shader_parameter("far_fade_end", 62.0)
	_rain_far = _make_rain_layer(_rain_far_mat, Vector2(0.03, 1.5), Vector3(60.0, 0.5, 60.0), RAIN_FAR_DROPS, 16.0)


func _make_rain_layer(mat: ShaderMaterial, size: Vector2, box: Vector3, amount: int, drop: float) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = box
	proc.direction = Vector3(0.12, -1.0, 0.07).normalized()
	proc.spread = 2.5
	proc.initial_velocity_min = 19.0
	proc.initial_velocity_max = 26.0
	proc.gravity = Vector3.ZERO
	proc.particle_flag_align_y = true
	proc.scale_min = 0.7
	proc.scale_max = 1.15
	var layer := GPUParticles3D.new()
	layer.process_material = proc
	layer.draw_pass_1 = quad
	layer.amount = amount
	layer.lifetime = (drop + 4.0) / 22.0
	layer.preprocess = layer.lifetime
	layer.local_coords = false
	layer.set_meta("drop", drop)
	layer.visibility_aabb = AABB(Vector3(-box.x - 20, -drop - 15, -box.z - 20), Vector3(box.x * 2 + 40, drop + 30, box.z * 2 + 40))
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.top_level = true
	layer.emitting = false
	add_child(layer)
	return layer


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

	var burst_g := Gradient.new()
	burst_g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	burst_g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var burst := GradientTexture2D.new()
	burst.gradient = burst_g
	burst.fill = GradientTexture2D.FILL_RADIAL
	burst.fill_from = Vector2(0.5, 1.0)
	burst.fill_to = Vector2(1.0, 0.6)
	burst.width = 32
	burst.height = 32
	_crown_mat = StandardMaterial3D.new()
	_crown_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crown_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crown_mat.albedo_texture = burst
	_crown_mat.vertex_color_use_as_albedo = true
	_crown_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_crown_mat.billboard_keep_scale = true
	_crown_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.7)
	var cq := QuadMesh.new()
	cq.size = Vector2(1, 1)
	cq.center_offset = Vector3(0, 0.5, 0)
	cq.material = _crown_mat
	_crown_mm = MultiMesh.new()
	_crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	_crown_mm.use_colors = true
	_crown_mm.mesh = cq
	_crown_mm.instance_count = SPLASH_COUNT
	for i in SPLASH_COUNT:
		_crown_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_crown_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var crown := MultiMeshInstance3D.new()
	crown.multimesh = _crown_mm
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crown.custom_aabb = _splash.custom_aabb
	_splash.add_child(crown)


func _camera() -> Camera3D:
	if camera_override != null:
		return camera_override
	return get_viewport().get_camera_3d()


const SPLASH_LIFE := 0.30
const SPLASH_RADIUS := 17.0


func _update_rain(delta: float) -> void:
	var cam := _camera()
	var active := rain_level > 0.01 and cam != null
	var storm_k := float(_cur["storm"])
	var w := Vector3.ZERO
	if main != null and main.get("wind") != null:
		w = main.wind.direction * main.wind.strength
	for layer: GPUParticles3D in [_rain, _rain_far]:
		layer.emitting = active
		layer.amount_ratio = clampf(rain_level * (0.64 + 0.36 * storm_k), 0.05, 1.0)
		var pm := layer.process_material as ParticleProcessMaterial
		pm.initial_velocity_min = 19.0 + 6.0 * storm_k
		pm.initial_velocity_max = 26.0 + 8.0 * storm_k
		# küləkdə damcılar maili düşür; fırtınada ara-sıra yayılma artır
		pm.direction = Vector3(w.x * 0.55 + 0.05, -1.0, w.z * 0.55 + 0.03).normalized()
		pm.spread = 2.5 + 4.0 * storm_k
	_splash.visible = active or _splash_alive()
	if cam == null:
		return
	var origin := cam.global_position
	# yağış həcmini kameranın bir az qabağına sürüşdür ki, sürətlə gedəndə boş yer görünməsin
	var ahead := -cam.global_basis.z * Vector3(1, 0, 1)
	for layer: GPUParticles3D in [_rain, _rain_far]:
		var lead := 6.0 if layer == _rain else 20.0
		layer.global_position = origin + ahead.normalized() * lead + Vector3(0.0, float(layer.get_meta("drop")), 0.0) - Vector3(w.x, 0.0, w.z) * 0.25
	_splash.global_transform = Transform3D.IDENTITY
	var terrain: MudTerrain = main.get("_terrain") if main != null else null
	if active:
		_s_credit += delta * 900.0 * rain_level * (1.0 + 0.5 * storm_k)
		while _s_credit >= 1.0:
			_s_credit -= 1.0
			var angle := _rng.randf_range(0.0, TAU)
			var r := SPLASH_RADIUS * sqrt(_rng.randf())
			var p := Vector3(origin.x + cos(angle) * r, 0.0, origin.z + sin(angle) * r)
			if terrain != null:
				var ground := terrain.height_at(p)
				# körpü altına yağış yağmır; çay/göldə dairələr su səthində olur
				if terrain.bridge_deck_above(p, ground) > -INF:
					continue
				p.y = maxf(ground, terrain.water_level_at(p)) + 0.02
			else:
				p.y = origin.y - 1.5
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
			_crown_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		# tac: ilk 35%-də qalxır, sonra çökür
		var ct := clampf(t / 0.35, 0.0, 1.0)
		var ch := 0.11 * sin(ct * PI) + 0.001
		_crown_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.05 + 0.07 * ct, ch, 1.0)), _s_pos[i]))
		_crown_mm.set_instance_color(i, Color(1, 1, 1, 1.0 - ct))
		var radius := lerpf(0.04, 0.26, sqrt(t))
		_splash_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0)), _s_pos[i]))
		_splash_mm.set_instance_color(i, Color(1, 1, 1, (1.0 - t) * (1.0 - t)))


func _splash_alive() -> bool:
	for i in SPLASH_COUNT:
		if _s_age[i] < SPLASH_LIFE:
			return true
	return false


# --- şimşək və ildırım --------------------------------------------------------------------

func _build_bolt_node() -> void:
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.disable_fog = true
	_bolt_mat.albedo_color = Color(4.0, 4.5, 6.0)
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.top_level = true
	_bolt.visible = false
	add_child(_bolt)
	# geniş yumşaq hələ: şimşəyin ətrafındakı nəm havanın parıltısı
	_bolt_glow_mat = StandardMaterial3D.new()
	_bolt_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_glow_mat.disable_fog = true
	_bolt_glow = MeshInstance3D.new()
	_bolt_glow.material_override = _bolt_glow_mat
	_bolt_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt_glow.top_level = true
	_bolt.add_child(_bolt_glow)
	# yerə dəyən nöqtədə qısa işıq: ətrafı və yağışı ağardır
	_bolt_light = OmniLight3D.new()
	_bolt_light.omni_range = 400.0
	_bolt_light.light_color = Color(0.7, 0.8, 1.0)
	_bolt_light.shadow_enabled = false
	_bolt_light.light_energy = 0.0
	_bolt_light.top_level = true
	add_child(_bolt_light)


## Şimşək vurur: qövs, səma parıltısı, günəşin istiqaməti və gecikməli ildırım. Testlər də çağırır.
func strike(forced_distance := 0.0) -> void:
	var cam := _camera()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var base_az := atan2(fwd.z, fwd.x)
	# əksər şimşəklər baxış istiqamətinə yaxın düşür ki, görünsün
	var az := base_az + (_rng.randf_range(-1.05, 1.05) if _rng.randf() < 0.75 else _rng.randf_range(-PI, PI))
	var near := _rng.randf() < 0.18
	var dist := forced_distance if forced_distance > 0.0 else (_rng.randf_range(250.0, 450.0) if near else _rng.randf_range(600.0, 1300.0))
	_flash_dir = Vector3(cos(az), 0.35, sin(az)).normalized()
	_flash_scale = lerpf(1.0, 0.55, clampf((dist - 250.0) / 1000.0, 0.0, 1.0))
	_build_bolt(cam.global_position, az, dist)
	_pulses.clear()
	var t := 0.0
	for i in _rng.randi_range(2, 4):
		var amp := 1.0 if i == 0 else _rng.randf_range(0.35, 0.9)
		_pulses.append([t, amp, _rng.randf_range(0.045, 0.09)])
		t += _rng.randf_range(0.07, 0.2)
	_flash_end = t + 0.5
	_flash_clock = 0.0
	strikes += 1
	# günəş işığı qısa müddətə şimşəyin tərəfindən gəlir: kölgələr oynayır
	var sun: DirectionalLight3D = main.get("_sun") if main != null else null
	if sun != null and not main.garage_active:
		var f := Vector3(-cos(az), -0.8, -sin(az)).normalized()
		sun.global_transform = Transform3D(Basis.looking_at(f, Vector3.UP), sun.global_position)
	_thunder_queue.append([dist / 343.0, dist])
	_dirty = true


func _update_lightning(delta: float) -> void:
	if float(_cur["storm"]) > 0.5:
		_next_strike -= delta
		if _next_strike <= 0.0:
			strike()
			_next_strike = _rng.randf_range(4.0, 13.0)
	for i in range(_thunder_queue.size() - 1, -1, -1):
		_thunder_queue[i][0] = float(_thunder_queue[i][0]) - delta
		if float(_thunder_queue[i][0]) <= 0.0:
			if main != null and main.get("audio") != null:
				main.audio.play_thunder(float(_thunder_queue[i][1]))
			_thunder_queue.remove_at(i)
	var f := 0.0
	if _flash_clock >= 0.0:
		_flash_clock += delta
		for p in _pulses:
			var dt := _flash_clock - float(p[0])
			if dt >= 0.0:
				f = maxf(f, float(p[1]) * exp(-dt / float(p[2])))
		if _flash_clock > _flash_end:
			_flash_clock = -1.0
			f = 0.0
			_restore_sun_direction()
	if absf(f - flash) > 0.003 or (f == 0.0 and flash != 0.0):
		flash = f
		_dirty = true
	_bolt.visible = _flash_clock >= 0.0 and flash > 0.18
	if _bolt.visible:
		_bolt_mat.albedo_color = Color(5.0, 5.6, 8.0) * clampf(flash, 0.35, 1.0)
		_bolt_glow_mat.albedo_color = Color(0.55, 0.65, 1.0, 0.35 * clampf(flash, 0.0, 1.0))
	if _bolt_light != null:
		_bolt_light.light_energy = flash * 5.0 * _flash_scale
	if _rain_mat != null:
		_rain_mat.set_shader_parameter("flash", flash)
		_rain_far_mat.set_shader_parameter("flash", flash)


func _restore_sun_direction() -> void:
	var sun: DirectionalLight3D = main.get("_sun") if main != null else null
	if sun == null or main.garage_active:
		return
	sun.rotation_degrees = Vector3(-38, 150, 0) if main.night else Vector3(-42, -30, 0)


func _build_bolt(origin: Vector3, az: float, dist: float) -> void:
	var horiz := Vector3(cos(az), 0.0, sin(az))
	var right := Vector3(-horiz.z, 0.0, horiz.x)
	var center := Vector3(origin.x, 0.0, origin.z) + horiz * dist
	var terrain: MudTerrain = main.get("_terrain") if main != null else null
	var ground_y := (terrain.height_at(center) if terrain != null else origin.y - 20.0)
	var top_y := maxf(origin.y, ground_y) + 380.0
	var scale := clampf(dist / 500.0, 0.6, 2.2)
	var pts := _jagged(Vector3(center.x, top_y, center.z), Vector3(center.x, ground_y, center.z), right, 26.0 * scale, 5)
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var halo := SurfaceTool.new()
	halo.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(core, pts, right, 4.5 * scale, 1.6 * scale)
	_ribbon(halo, pts, right, 26.0 * scale, 12.0 * scale)
	# budaqlar: əsas kanaldan ayrılıb ikiqat azalan, daha nazik, yana əyilən qollar
	for b in _rng.randi_range(4, 7):
		var idx := _rng.randi_range(4, pts.size() - 12)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var from: Vector3 = pts[idx]
		var to := from + Vector3(0.0, -_rng.randf_range(70.0, 170.0), 0.0) * scale + right * side * _rng.randf_range(40.0, 120.0) * scale
		var branch := _jagged(from, to, right, 10.0 * scale, 4)
		_ribbon(core, branch, right, 2.0 * scale, 0.5 * scale)
		_ribbon(halo, branch, right, 9.0 * scale, 3.0 * scale)
	_bolt.mesh = core.commit()
	_bolt_glow.mesh = halo.commit()
	if _bolt_light != null:
		_bolt_light.global_position = Vector3(center.x, ground_y + 60.0, center.z) - horiz * minf(dist * 0.35, 200.0)


## Orta nöqtəni təsadüfi yana sürüşdürməklə (midpoint displacement) təbii əyri-üyrü xətt qurur.
func _jagged(a: Vector3, b: Vector3, right: Vector3, amp: float, levels: int) -> Array[Vector3]:
	var pts: Array[Vector3] = [a, b]
	var a_amp := amp
	for l in levels:
		var nxt: Array[Vector3] = []
		for k in pts.size() - 1:
			nxt.append(pts[k])
			var mid := (pts[k] + pts[k + 1]) * 0.5
			nxt.append(mid + right * _rng.randf_range(-a_amp, a_amp) + Vector3(0.0, 0.0, 0.0))
		nxt.append(pts[pts.size() - 1])
		pts = nxt
		a_amp *= 0.55
	return pts


func _ribbon(st: SurfaceTool, pts: Array[Vector3], right: Vector3, w_top: float, w_bottom: float) -> void:
	var n := pts.size() - 1
	for i in n:
		var wa := lerpf(w_top, w_bottom, float(i) / n) * 0.5
		var wb := lerpf(w_top, w_bottom, float(i + 1) / n) * 0.5
		var a := pts[i]
		var b := pts[i + 1]
		var a0 := a - right * wa
		var a1 := a + right * wa
		var b0 := b - right * wb
		var b1 := b + right * wb
		for v in [a0, a1, b0, a1, b1, b0]:
			st.add_vertex(v)
