class_name GraphicsQuality
extends RefCounted
## Qrafika keyfiyyət profilləri (Forward+ / Metal): kölgələr, SSAO/SSIL, SDFGI, volumetrik duman, SSR,
## anti-aliasing və mesh LOD. Seçim user://offroad_settings.cfg-də ("graphics/quality") saxlanılır.
## Əsas görünüş (tonemap, duman, rəng) bütün profillərdə eynidir: Main._setup_environment.

const LEVELS := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
const DEFAULT := "MEDIUM"  # M4 1600x900: 66-100 FPS (tools/bench_graphics.gd)
const SAVE_PATH := "user://offroad_settings.cfg"

## shadow_dist: günəş kölgəsinin məsafəsi (m); atlas: kölgə xəritəsi ölçüsü; soft: yumşaq kölgə keyfiyyəti
## aa: "fxaa" | "smaa" | "taa"; lod: mesh LOD həddi (böyük = daha sadə uzaq meshlər)
const PROFILES := {
	"LOW": {"shadow_dist": 70.0, "splits": 2, "atlas": 2048, "soft": 1, "angular": 0.0,
		"ssao": false, "ssil": false, "sdfgi": false, "vol_fog": false, "ssr": false, "glow": false, "aa": "fxaa", "lod": 4.0},
	"MEDIUM": {"shadow_dist": 120.0, "splits": 4, "atlas": 4096, "soft": 2, "angular": 0.0,
		"ssao": true, "ssil": false, "sdfgi": false, "vol_fog": false, "ssr": false, "glow": true, "aa": "smaa", "lod": 2.0},
	"HIGH": {"shadow_dist": 160.0, "splits": 4, "atlas": 4096, "soft": 2, "angular": 0.0,
		"ssao": true, "ssil": false, "sdfgi": false, "vol_fog": true, "ssr": false, "glow": true, "aa": "taa", "lod": 1.0},
	"ULTRA": {"shadow_dist": 240.0, "splits": 4, "atlas": 8192, "soft": 3, "angular": 0.35,
		"ssao": true, "ssil": true, "sdfgi": true, "vol_fog": true, "ssr": true, "glow": true, "aa": "taa", "lod": 0.6},
}

static var level := ""


static func saved_level() -> String:
	if level != "":
		return level
	var cfg := ConfigFile.new()
	level = DEFAULT
	if cfg.load(SAVE_PATH) == OK:
		var v := str(cfg.get_value("graphics", "quality", DEFAULT))
		if v in LEVELS:
			level = v
	return level


static func save(lvl: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("graphics", "quality", lvl)
	cfg.save(SAVE_PATH)


static func next(lvl: String) -> String:
	return LEVELS[(LEVELS.find(lvl) + 1) % LEVELS.size()]


## Profili mühitə, günəşə və viewport-a tətbiq edir. night: gecə dumanı daha sıx olur.
static func apply(lvl: String, env: Environment, sun: DirectionalLight3D, vp: Viewport, night := false) -> void:
	if lvl not in LEVELS:
		lvl = DEFAULT
	level = lvl
	var p: Dictionary = PROFILES[lvl]
	# kölgələr: məsafəyə görə 4 split, yaxında kəskin, uzaqda yumşaq
	sun.directional_shadow_max_distance = p["shadow_dist"]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(p["splits"]) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = int(p["splits"]) == 4
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_blur = 1.0
	sun.light_angular_distance = p["angular"]
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	RenderingServer.directional_shadow_atlas_set_size(int(p["atlas"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(p["soft"]))
	# kontakt kölgəsi və ekran fəzasında dolayı işıq
	env.ssao_enabled = p["ssao"]
	# ULTRA tam ölçü, digərləri yarım ölçü (2-3 dəfə ucuz)
	var full := lvl == "ULTRA"
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH if full else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, not full, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if full else 48, 64 if full else 48)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.15
	env.ssao_ao_channel_affect = 0.0
	env.ssil_enabled = p["ssil"]
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.7
	env.ssil_normal_rejection = 1.0
	env.sdfgi_enabled = p["sdfgi"]
	if p["sdfgi"]:
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.4
		env.sdfgi_use_occlusion = true
		env.sdfgi_energy = 0.7
		env.sdfgi_bounce_feedback = 0.4
		env.sdfgi_read_sky_light = true
	env.ssr_enabled = p["ssr"]
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	# məhdud glow: yalnız fənərlər və günəş parıltısı
	env.glow_enabled = p["glow"]
	env.glow_intensity = 0.32
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# volumetrik duman: yalnız yüngül dərinlik, yaxın obyektləri örtmür
	env.volumetric_fog_enabled = p["vol_fog"]
	env.volumetric_fog_density = 0.004 if night else 0.0008
	env.volumetric_fog_albedo = Color(0.95, 0.96, 0.98) if not night else Color(0.35, 0.4, 0.5)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.4
	env.volumetric_fog_ambient_inject = 0.6
	env.volumetric_fog_sky_affect = 0.0
	# anti-aliasing və temporal sabitlik
	vp.use_taa = p["aa"] == "taa"
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if p["aa"] == "fxaa":
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	elif p["aa"] == "smaa":
		vp.screen_space_aa = _smaa_or_fxaa()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = p["lod"]
	vp.use_debanding = true


static func _smaa_or_fxaa() -> int:
	# SMAA Godot 4.5-dən var; yoxdursa FXAA
	if ClassDB.class_has_integer_constant("Viewport", "SCREEN_SPACE_AA_SMAA"):
		return ClassDB.class_get_integer_constant("Viewport", "SCREEN_SPACE_AA_SMAA")
	return Viewport.SCREEN_SPACE_AA_FXAA
