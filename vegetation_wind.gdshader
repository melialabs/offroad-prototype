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
uniform float bend = 0.1;
uniform float height_scale = 1.0;
uniform float root_height = 0.0;
uniform float flutter = 0.15;
uniform float sway_speed = 1.0;
uniform bool woody = false;
uniform float wind_clock = 0.0;
uniform vec3 wind_direction = vec3(0.82,0.0,0.57);
uniform float wind_strength = 0.2;
void vertex() {
	// Use each variant's real LOD0 height, not a common 0.8 m grass height.
	float h = max(VERTEX.y - root_height, 0.0);
	float tip = clamp(h / max(height_scale, 0.03), 0.0, 1.0);
	float weight = pow(tip, woody ? 1.65 : 1.1);
	// World height includes instance scale. The old offset lost this scale
	// when converted back into local space, hiding almost all grass motion.
	float world_height = h * length(MODEL_MATRIX[1].xyz);
	vec3 base = MODEL_MATRIX[3].xyz;
	float phase = dot(base.xz, vec2(0.081, 0.057));
	float t = wind_clock * sway_speed;
	float wave = 0.25 + 0.65*sin(t + phase) + 0.25*sin(t*1.73 + phase*1.31);
	vec3 direction = normalize(vec3(wind_direction.x, 0.0, wind_direction.z));
	vec3 side = vec3(-direction.z, 0.0, direction.x);
	vec3 offset = direction * wave * wind_strength * bend * world_height * weight;
	// Leaf/blade flutter is separate from the coherent whole-plant bend.
	float leaf_phase = phase + dot(VERTEX, vec3(2.1, 1.3, 0.7));
	float ripple = sin(t*3.7 + leaf_phase) * 0.7 + sin(t*5.3 + leaf_phase*1.7)*0.3;
	float detail = flutter * wind_strength * min(world_height, 2.0) * weight;
	offset += side * ripple * detail;
	offset.y += sin(t*4.1 + leaf_phase) * detail * 0.18;
	// Forest instance bases are orthogonal rotation/scale. This conversion
	// supports their nonuniform scales without a per-vertex matrix inverse.
	vec3 bx = MODEL_MATRIX[0].xyz;
	vec3 by = MODEL_MATRIX[1].xyz;
	vec3 bz = MODEL_MATRIX[2].xyz;
	VERTEX += vec3(dot(offset,bx),dot(offset,by),dot(offset,bz)) /
		max(vec3(dot(bx,bx),dot(by,by),dot(bz,bz)),vec3(0.0001));
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
