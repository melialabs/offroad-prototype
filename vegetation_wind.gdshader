shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform bool use_arm = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform bool cutout = true;
uniform bool vertex_tint = false;
uniform float roughness_value = 0.85;
uniform float bend = 0.018;
uniform float height_scale = 1.0;
uniform float wind_clock = 0.0;
uniform vec3 wind_direction = vec3(0.82,0.0,0.57);
uniform float wind_strength = 0.2;
void vertex() {
	// MODEL_MATRIX includes the MultiMesh instance transform: phases remain
	// coherent across chunks and LODs. Trunk bases/roots stay pinned.
	vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float height = max(VERTEX.y,0.0);
	float weight = clamp(height/max(height_scale,0.1),0.0,1.0);
	float phase = dot(world.xz,vec2(0.075,0.053));
	float sway = sin(wind_clock*1.25+phase)*0.7+sin(wind_clock*2.17+phase*1.8)*0.3;
	vec3 offset = wind_direction * sway * wind_strength * bend * height * weight;
	// Convert the world wind back into local coordinates; rotated/scaled
	// instances still sway in the same direction. No per-instance CPU update.
	VERTEX += inverse(mat3(MODEL_MATRIX))*offset;
}
void fragment() {
	vec4 tex = texture(albedo_tex,UV)*tint;
	if (vertex_tint) { tex *= COLOR; }
	ALBEDO = tex.rgb;
	ROUGHNESS = roughness_value;
	if (use_normal) { NORMAL_MAP = texture(normal_tex,UV).rgb; }
	if (use_arm) { vec3 arm = texture(arm_tex,UV).rgb; ROUGHNESS = arm.g; AO = arm.r; }
	if (cutout) { ALPHA = tex.a; ALPHA_SCISSOR_THRESHOLD = alpha_threshold; }
	BACKLIGHT = cutout ? vec3(0.18,0.22,0.12) : vec3(0.0);
}
