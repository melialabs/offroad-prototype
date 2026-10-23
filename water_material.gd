class_name WaterMaterial
extends RefCounted
## water.gdshader üçün hazır materiallar: göl (təmiz, dərin) və bataqlıq gölməçəsi (bulanıq, palçıqlı).

static var _noise: NoiseTexture2D


static func make(muddy := false) -> ShaderMaterial:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.noise = n
		_noise.seamless = true
		_noise.as_normal_map = true
		_noise.bump_strength = 6.0
		_noise.width = 256
		_noise.height = 256
	var m := ShaderMaterial.new()
	m.shader = load("res://water.gdshader")
	m.set_shader_parameter("wave_noise", _noise)
	if muddy:
		m.set_shader_parameter("shallow_color", Color(0.20, 0.15, 0.08))
		m.set_shader_parameter("deep_color", Color(0.08, 0.06, 0.03))
		m.set_shader_parameter("depth_scale", 0.5)
		m.set_shader_parameter("wave_strength", 0.12)
		m.set_shader_parameter("roughness_value", 0.08)
	return m
