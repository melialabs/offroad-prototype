shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_disabled;

// Six samples through a noisy volume, rather than an opaque circular sprite.
uniform sampler3D density_noise : filter_linear, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying float puff_age;
varying float puff_seed;
varying float puff_diameter;

void vertex() {
	puff_age = INSTANCE_CUSTOM.r;
	puff_seed = INSTANCE_CUSTOM.g;
	puff_diameter = length(MODEL_MATRIX[0].xyz);
	float angle = INSTANCE_CUSTOM.b * TAU;
	mat2 roll = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	VERTEX.xy = roll * VERTEX.xy;
	VERTEX.y *= 0.85 + INSTANCE_CUSTOM.a * 0.4;
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	MODELVIEW_MATRIX[0].xyz *= puff_diameter;
	MODELVIEW_MATRIX[1].xyz *= puff_diameter;
	MODELVIEW_MATRIX[2].xyz *= puff_diameter;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float radius_sq = dot(q, q);
	if (radius_sq >= 1.0) { discard; }
	float half_depth = sqrt(1.0 - radius_sq);
	vec3 seed = vec3(puff_seed * 7.13, puff_seed * 3.71, puff_seed * 5.97);
	vec3 advection = vec3(0.12, -0.19, 0.08) * puff_age;
	float thickness = 0.0;
	for (int i = 0; i < 6; i++) {
		float z = mix(-half_depth, half_depth, (float(i) + 0.5) / 6.0);
		vec3 p = vec3(q, z);
		float large = texture(density_noise, p * 0.46 + seed + advection).r;
		float fine = texture(density_noise, p * 1.17 + seed * 0.71 - advection * 0.8).r;
		float density = smoothstep(0.24, 0.64, large * 0.78 + fine * 0.22);
		float envelope = pow(max(0.0, 1.0 - dot(p, p)), 0.85);
		thickness += density * envelope * (2.0 * half_depth / 6.0);
	}
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_distance = -scene.z / scene.w;
	float intersection_fade = clamp((scene_distance + VERTEX.z) / max(0.12, puff_diameter * 0.22), 0.0, 1.0);
	float near_fade = smoothstep(0.15, 0.55, length(VERTEX));
	ALPHA = (1.0 - exp(-thickness * COLOR.a * 6.0)) * intersection_fade * near_fade;
	// Lit by the environment, sun and vehicle lamps. No emissive night smoke.
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	NORMAL = normalize(vec3(q * 0.12, 1.0));
	BACKLIGHT = vec3(0.45);
}
