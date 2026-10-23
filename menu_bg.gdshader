shader_type canvas_item;
// Animated still: slow camera drift with depth parallax, wind sway on trees/reeds, drifting fog.
// ctrl.r = depth (near = 1), ctrl.g = tree mask, ctrl.b = reed mask.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D ctrl : filter_linear;
uniform sampler2D fog_noise : repeat_enable, filter_linear;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 tex_size = vec2(1672.0, 941.0);
uniform float t = 0.0;
uniform float wind = 1.0;

void fragment() {
	// cover-fit the image into the rect
	float ta = tex_size.x / tex_size.y;
	float va = rect_size.x / rect_size.y;
	vec2 s = va > ta ? vec2(1.0, ta / va) : vec2(va / ta, 1.0);
	vec2 uv = (UV - 0.5) * s + 0.5;
	vec3 c = texture(ctrl, uv).rgb;
	// camera: slow push-in/out plus a gentle handheld drift, near layers move more
	float zoom = 1.0 / (1.03 + 0.008 * sin(t * 0.11));
	vec2 drift = vec2(sin(t * 0.21) + 0.5 * sin(t * 0.13 + 1.0), 0.7 * cos(t * 0.17)) * 0.004;
	uv = (uv - 0.5) * zoom + 0.5;
	uv += drift * (c.r - 0.4) * 2.0;
	// wind: travelling wave, gusts; amplitude grows toward the treetops
	float gust = 0.65 + 0.35 * sin(t * 0.37) * sin(t * 0.23 + 2.0);
	float wave = sin(t * 1.25 + uv.y * 8.0 + uv.x * 5.0) + 0.55 * sin(t * 2.3 + uv.x * 14.0 + uv.y * 3.0);
	float top = clamp(1.0 - uv.y * 1.6, 0.0, 1.0);
	uv.x += (c.g * top * 0.0042 + c.b * 0.0065) * wave * gust * wind;
	uv.y += (c.g * top * 0.0008 + c.b * 0.0012) * wave * gust * wind;
	vec4 col = texture(tex, uv);
	// drifting mist behind the near layers
	float n = texture(fog_noise, uv * vec2(1.6, 1.0) + vec2(t * 0.007, t * 0.002)).r;
	col.rgb = mix(col.rgb, vec3(0.86, 0.89, 0.93), clamp((n - 0.5) * 0.9, 0.0, 0.35) * (1.0 - c.r * 0.85));
	COLOR = vec4(col.rgb, 1.0);
}
