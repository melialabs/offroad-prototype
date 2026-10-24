shader_type spatial;
// Yağış damcısı: sürət boyunca uzanan, kameraya dönən nazik zolaq. Fənərlər və şimşək onu işıqlandırır,
// hər damcının parlaqlığı/uzunluğu fərqlidir, yaxın və uzaq qatlar məsafəyə görə sönür.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, ambient_light_disabled, specular_disabled;

uniform vec3 tint : source_color = vec3(0.75, 0.80, 0.88);
uniform float opacity = 0.35;
uniform float near_fade_start = 0.0;   // bu məsafədən yaxın görünmür (uzaq qat üçün)
uniform float near_fade_end = 0.5;
uniform float far_fade_start = 18.0;
uniform float far_fade_end = 26.0;
uniform float flash = 0.0;   // şimşək parıltısı: bütün damcılar bir anlıq ağarır

varying float v_rand;
varying float v_dist;

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	vec3 axis_raw = MODEL_MATRIX[1].xyz;
	float len = length(axis_raw);
	vec3 axis = axis_raw / max(len, 1e-4);
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - center);
	vec3 side = cross(axis, to_cam);
	float sl = length(side);
	side = sl > 1e-4 ? side / sl : vec3(1.0, 0.0, 0.0);
	v_rand = hash1(float(INSTANCE_ID) + 0.5);
	float stretch = mix(0.65, 1.35, hash1(float(INSTANCE_ID) * 1.7 + 3.0));
	vec3 world = center + side * VERTEX.x * width + axis * VERTEX.y * len * stretch;
	v_dist = distance(world, CAMERA_POSITION_WORLD);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(to_cam, 0.0)).xyz;
}

void fragment() {
	// eninə yumşaq kənar, uclara doğru incələn və quyruqda sönən zolaq (hərəkət bulanıqlığı)
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = UV.y;
	float body = smoothstep(0.0, 0.35, along) * (1.0 - smoothstep(0.75, 1.0, along));
	float a = pow(across, 1.6) * body;
	float fade = smoothstep(near_fade_start, near_fade_end, v_dist) * (1.0 - smoothstep(far_fade_start, far_fade_end, v_dist));
	ALBEDO = vec3(0.7);
	EMISSION = tint * mix(0.75, 1.25, v_rand) + vec3(0.9, 0.95, 1.2) * flash * 1.6;
	ALPHA = a * (opacity + flash * 0.25) * mix(0.45, 1.0, v_rand) * fade;
}

void light() {
	// su damcısı işığı əsasən irəli səpir: kameraya doğru gələn işıq (arxa işıq) daha parlaq görünür
	float forward = pow(clamp(dot(-LIGHT, VIEW), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (0.35 + 7.0 * forward);
}
