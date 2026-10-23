shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
// Göl və gölməçə suyu: baxış bucağına görə Fresnel əksi (səma, SSR), animasiyalı dalğa normalları,
// dərinliyə görə rəng/şəffaflıq (sahildə dib görünür), yüksək parlaqlıq.
uniform vec3 shallow_color : source_color = vec3(0.26, 0.33, 0.28);
uniform vec3 deep_color : source_color = vec3(0.03, 0.09, 0.11);
uniform float depth_scale = 2.2;
uniform float wave_strength = 0.35;
uniform float wave_speed = 0.035;
uniform float roughness_value = 0.04;
uniform sampler2D wave_noise : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world.xz * 0.06;
	vec3 n1 = texture(wave_noise, uv + TIME * wave_speed * vec2(1.0, 0.6)).rgb;
	vec3 n2 = texture(wave_noise, uv * 1.9 - TIME * wave_speed * vec2(0.7, 1.1)).rgb;
	NORMAL_MAP = normalize(mix(vec3(0.5, 0.5, 1.0), (n1 + n2) * 0.5, wave_strength));
	// dərinlik: suyun səthi ilə arxadakı dib arasındakı məsafə
	float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 back = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	back.xyz /= back.w;
	float thickness = clamp((VERTEX.z - back.z) / depth_scale, 0.0, 1.0);
	ALBEDO = mix(shallow_color, deep_color, thickness);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALPHA = clamp(mix(0.35, 0.92, thickness) + fresnel * 0.5, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = roughness_value;
}
