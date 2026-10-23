shader_type spatial;
// Çoxsəthli terrain: 7 layer (Texture2DArray) + asfalt yol overlay-i.
// Çəki xəritəsi (ctrl_a, ctrl_b) vertex ölçüsündədir, sərhədlər height-əsaslı qarışdırma ilə təbiiləşir.
// Layer sırası: 0 torpaq yol, 1 palçıq, 2 dərin palçıq, 3 daşlı səth, 4 ot, 5 qar, 6 qaya yamac.

uniform sampler2DArray tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ctrl_a : filter_linear, repeat_disable;   // R torpaq, G palçıq, B dərin palçıq, A daş
uniform sampler2D ctrl_b : filter_linear, repeat_disable;   // R ot, G -, B iz dərinliyi (dinamik)
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;

uniform sampler2D a_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float tile_m[7];            // hər layer üçün bir tekstura təkrarının metrlə ölçüsü
uniform vec3 layer_tint[7];         // hər layer üçün rəng tonu (istinad palitrasına uyğunlaşdırma)
uniform bool detail_surface = false;
uniform float asphalt_tile = 2.9;
uniform float road_half = 4.0;
uniform float ctrl_n = 129.0;
uniform float cell = 1.5;

uniform float wetness : hint_range(0.0, 1.0) = 0.0;       // yağış
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;   // qar örtüyü
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;    // buz
uniform vec3 grass_tint = vec3(1.0);                      // fəsil rəngi

varying vec3 wn;
varying vec3 wpos;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 world = wpos.xz;
	vec2 dxw = dFdx(world);
	vec2 dyw = dFdy(world);
	// yamacda üfüqi proyeksiya uzanır, ona görə qaya layer-i dominant oxa görə proyeksiya olunur
	vec2 cp = abs(wn.x) > abs(wn.z) ? wpos.zy : wpos.xy;
	vec2 dxc = dFdx(cp);
	vec2 dyc = dFdy(cp);

	vec2 cuv = (world / cell + vec2((ctrl_n - 1.0) * 0.5)) / ctrl_n + vec2(0.5 / ctrl_n);
	vec4 ca = texture(ctrl_a, cuv);
	vec4 cb = texture(ctrl_b, cuv);
	if (detail_surface) { cb.b = max(cb.b, COLOR.r); }

	float slope = 1.0 - wn.y;
	float cliff = smoothstep(0.20, 0.40, slope);
	float up = smoothstep(0.55, 0.85, wn.y);
	float mn = texture(macro_noise, world * 0.03).r;
	float snow = snow_amount * up * smoothstep(0.25, 0.6, mn + snow_amount * 0.5);

	// çəkilər
	float ground_k = (1.0 - cliff) * (1.0 - snow);
	float w[7];
	w[0] = ca.r * ground_k;
	w[1] = ca.g * ground_k;
	w[2] = (ca.b + cb.b * 1.5) * ground_k;
	w[3] = ca.a * ground_k;
	w[4] = cb.r * ground_k;
	w[5] = snow * (1.0 - cliff * 0.6);
	w[6] = cliff * (1.0 - snow);

	// 1-ci keçid: albedo və height (yalnız çəkisi olan layer-lər)
	vec3 alb[7];
	float hgt[7];
	float hmax = -1.0;
	for (int i = 0; i < 7; i++) {
		alb[i] = vec3(0.0);
		hgt[i] = 0.0;
		if (w[i] > 0.01) {
			vec2 uv = world / tile_m[i];
			vec2 gx = dxw / tile_m[i];
			vec2 gy = dyw / tile_m[i];
			if (i == 6) {
				uv = cp / tile_m[i];
				gx = dxc / tile_m[i];
				gy = dyc / tile_m[i];
			}
			alb[i] = textureGrad(tex_albedo, vec3(uv, float(i)), gx, gy).rgb;
			hgt[i] = textureGrad(tex_height, vec3(uv, float(i)), gx, gy).r;
			hmax = max(hmax, w[i] + hgt[i] * 0.7);
		}
	}
	float bw[7];
	float tw = 0.0;
	for (int i = 0; i < 7; i++) {
		bw[i] = 0.0;
		if (w[i] > 0.01) {
			bw[i] = max(w[i] + hgt[i] * 0.7 - (hmax - 0.35), 0.0);
			tw += bw[i];
		}
	}
	tw = max(tw, 0.0001);

	// 2-ci keçid: normal və roughness yalnız aktiv layer-lər üçün
	vec3 albedo = vec3(0.0);
	vec2 nxy = vec2(0.0);
	float rough = 0.0;
	for (int i = 0; i < 7; i++) {
		if (bw[i] > 0.0) {
			float b = bw[i] / tw;
			vec2 uv = world / tile_m[i];
			vec2 gx = dxw / tile_m[i];
			vec2 gy = dyw / tile_m[i];
			if (i == 6) {
				uv = cp / tile_m[i];
				gx = dxc / tile_m[i];
				gy = dyc / tile_m[i];
			}
			vec3 a = alb[i] * layer_tint[i];
			if (i == 4) {
				a *= grass_tint;
			}
			albedo += a * b;
			vec4 nr = textureGrad(tex_normal, vec3(uv, float(i)), gx, gy);
			float nk = (i == 6) ? 0.5 : 1.0;   // qaya proyeksiyası tangent çərçivəsinə uyğun deyil
			nxy += (nr.rg * 2.0 - 1.0) * b * nk;
			rough += textureGrad(tex_rough, vec3(uv, float(i)), gx, gy).r * b;
		}
	}
	// makro variasiya: eyni teksturanın təkrarı görünməsin
	albedo *= mix(0.82, 1.18, texture(macro_noise, world * 0.011 + vec2(0.37)).r);

	// yağış: ümumi islanma və palçıq çökəkliklərində gölməçə
	float mud_mask = clamp(ca.g + ca.b + cb.b, 0.0, 1.0);
	float mud_h = (hgt[1] * w[1] + hgt[2] * w[2]) / max(w[1] + w[2], 0.001);
	float local_wet = max(wetness, clamp(ca.b * 0.8 + cb.b * 0.9, 0.0, 0.9));
	float puddle = local_wet * mud_mask * (1.0 - smoothstep(local_wet * 0.55 - 0.05, local_wet * 0.55 + 0.08, mud_h));
	albedo *= 1.0 - 0.30 * wetness;
	albedo *= mix(1.0, 0.55, puddle);
	rough = mix(rough, rough * 0.55, wetness * 0.6);
	rough = mix(rough, 0.05, puddle);
	nxy *= 1.0 - puddle * 0.9;

	// asfalt yol (UV2: yol oxuna işarəli məsafə, yol boyu uzunluq)
	vec2 au_ = world / asphalt_tile;
	vec3 ad = texture(a_diff, au_).rgb;
	vec3 an = texture(a_nor, au_).rgb;
	float ar = texture(a_rough, au_).r;
	float u = abs(UV2.x);
	float along = UV2.y;
	float road = 1.0 - smoothstep(road_half - 0.06, road_half + 0.06, u);
	float shoulder = (1.0 - smoothstep(road_half + 0.5, road_half + 1.3, u)) * (1.0 - road);
	float edge_line = smoothstep(road_half - 0.62, road_half - 0.56, u)
			* (1.0 - smoothstep(road_half - 0.40, road_half - 0.34, u));
	float dash = step(fract(along / 9.0), 0.55);
	float center = (1.0 - smoothstep(0.08, 0.12, u)) * dash;
	float paint = max(edge_line, center) * road;
	vec3 yellow = vec3(0.78, 0.60, 0.07);
	// real asfalt: tünd, bir az isti boz (albedo ~0.12-0.2), mavi çalar yox
	vec3 asphalt = ad * vec3(0.86, 0.85, 0.82);
	asphalt = mix(asphalt, yellow * (0.55 + ad.r * 1.4), paint * 0.88);
	asphalt *= 1.0 - 0.40 * wetness;
	float asphalt_rough = mix(ar, 0.85, paint);
	asphalt_rough = mix(asphalt_rough, 0.12, wetness * 0.8);
	vec2 an_xy = an.rg * 2.0 - 1.0;

	// qar yolun üstündə nazik (yol hərəkətlə təmizlənir)
	float road_snow = snow_amount * 0.2 * road * up;
	asphalt = mix(asphalt, vec3(0.9, 0.92, 0.96), road_snow);

	vec3 col = mix(albedo, asphalt, road);
	col = mix(col, col * 0.65, shoulder * 0.6);
	float r_out = mix(rough, asphalt_rough, road);
	vec2 n_out = mix(nxy, an_xy, road);

	// buz: yolda və donmuş palçıqda
	float ice = ice_amount * clamp(road + mud_mask, 0.0, 1.0);
	col = mix(col, vec3(0.38, 0.54, 0.70), ice * 0.8);
	r_out = mix(r_out, 0.06, ice);
	n_out *= 1.0 - ice * 0.85;

	float nz = sqrt(max(1.0 - dot(n_out, n_out), 0.0));
	ALBEDO = col;
	ROUGHNESS = clamp(r_out, 0.03, 1.0);
	NORMAL_MAP = vec3(n_out * 0.5 + 0.5, nz * 0.5 + 0.5);
	SPECULAR = 0.5 + 0.25 * max(wetness, ice);
}
