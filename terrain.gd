class_name MudTerrain
extends StaticBody3D
## Deformasiya olunan landşaft: təkər basdıqca palçıqlı yer batır.
## Üzərində asfalt yol (palçıq olmur) və palçıq cığırı var.

const N := 129             # tor ölçüsü (N x N nöqtə), xəritə ~192 m
const CELL := 1.5          # bir xanənin metrlə ölçüsü
const MAX_DEPTH := 0.7     # yerin ən çox batma dərinliyi
const REBUILD_INTERVAL := 0.1

const ROAD_HALF := 4.0     # yolun yarım eni (metr)
const ROAD_BLEND := 7.0    # yolun hündürlüyünün relyefə qarışma məsafəsi
const TRAIL_HALF := 3.0    # palçıq cığırının yarım eni
# dünya koordinatında (x, z) nəzarət nöqtələri
const ROAD_POINTS := [
	Vector2(-86, -60), Vector2(-53, -31), Vector2(-22, -7), Vector2(7, 7),
	Vector2(36, 22), Vector2(58, 46), Vector2(52, 70), Vector2(26, 82),
]
const TRAIL_POINTS := [
	Vector2(36, 22), Vector2(46, 2), Vector2(64, -14), Vector2(82, -34),
]

# relyef: yolun yanında hamar, uzaqda təpələr, xəritənin kənarında dağ silsiləsi
const ROAD_CORRIDOR := 40.0   # yol yamacından təpələrin tam başladığı məsafə
const MOUNTAIN_START := 52.0  # dağ silsiləsinin başladığı məsafə (mərkəzdən, max(|x|,|z|))
const MOUNTAIN_FULL := 92.0
const MIN_ROAD_HEIGHT := -1.0 # yol su səviyyəsindən yuxarıda qalsın

var h := PackedFloat32Array()     # cari hündürlük
var base := PackedFloat32Array()  # ilkin hündürlük
var soft := PackedFloat32Array()  # 0 = bərk yer, 1 = dərin palçıq

var _mesh_inst := MeshInstance3D.new()
var _shape := HeightMapShape3D.new()
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _tangents := PackedFloat32Array()
var _colors := PackedColorArray()
var _uv := PackedVector2Array()    # dünya xz (tekstur üçün)
var _uv2 := PackedVector2Array()   # (yol oxuna işarəli məsafə, yol boyu uzunluq)
var _indices := PackedInt32Array()
var _dirty := false
var _timer := 0.0
var _dirty_min := Vector2i(N, N)   # dəyişən torun sərhədləri (qismən yenilənmə üçün)
var _dirty_max := Vector2i(-1, -1)
var _big := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()

var _road := PackedVector2Array()        # sıxlaşdırılmış yol xətti
var _road_len := PackedFloat32Array()    # xəttin əvvəlindən yığılmış uzunluq
var _road_h := PackedFloat32Array()      # yolun hündürlük profili
var _trail := PackedVector2Array()


func _ready() -> void:
	_generate()
	_build_indices()
	_shape.map_width = N
	_shape.map_depth = N
	_shape.map_data = h
	var col := CollisionShape3D.new()
	col.shape = _shape
	col.scale = Vector3(CELL, 1.0, CELL)
	add_child(col)

	_mesh_inst.material_override = _make_material()
	add_child(_mesh_inst)
	_rebuild_mesh()


func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= REBUILD_INTERVAL:
		_timer = 0.0
		_dirty = false
		_shape.map_data = h
		_rebuild_mesh(false)


# --- material ---------------------------------------------------------------

const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D g_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D g_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D g_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D g_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float g_scale = 0.3;
uniform float a_scale = 0.35;
uniform float road_half = 4.0;
varying vec3 wn;
varying float wy;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 gu = UV * g_scale;
	vec2 au_ = UV * a_scale;
	vec3 gd = texture(g_diff, gu).rgb * COLOR.rgb;
	vec3 gn = texture(g_nor, gu).rgb;
	float gr = texture(g_rough, gu).r;
	float gao = texture(g_ao, gu).r;
	vec3 ad = texture(a_diff, au_).rgb;
	vec3 an = texture(a_nor, au_).rgb;
	float ar = texture(a_rough, au_).r;

	// dik yamaclarda qaya, hündürdə qar
	float slope = 1.0 - wn.y;
	float rock = smoothstep(0.20, 0.40, slope);
	vec3 rock_col = vec3(dot(gd, vec3(0.333))) * vec3(1.0, 0.97, 0.93) * 0.8;
	float snow = smoothstep(26.0, 34.0, wy) * (1.0 - smoothstep(0.35, 0.55, slope));
	gd = mix(gd, rock_col, rock);
	gd = mix(gd, vec3(0.92, 0.94, 0.98), snow);

	float u = abs(UV2.x);
	float along = UV2.y;
	float road = 1.0 - smoothstep(road_half - 0.06, road_half + 0.06, u);
	// yolun kənarında daha tünd çınqıl zolağı
	float shoulder = (1.0 - smoothstep(road_half + 0.5, road_half + 1.3, u)) * (1.0 - road);
	// sarı kənar xətləri və qırıq mərkəz xətti
	float edge_line = smoothstep(road_half - 0.62, road_half - 0.56, u)
			* (1.0 - smoothstep(road_half - 0.40, road_half - 0.34, u));
	float dash = step(fract(along / 9.0), 0.55);
	float center = (1.0 - smoothstep(0.08, 0.12, u)) * dash;
	float paint = max(edge_line, center) * road;
	vec3 yellow = vec3(0.78, 0.60, 0.07);
	vec3 asphalt = ad * 1.15;
	asphalt = mix(asphalt, yellow * (0.55 + ad.r * 1.4), paint * 0.88);

	vec3 col = mix(gd, asphalt, road);
	col = mix(col, col * 0.65, shoulder * 0.6);
	ALBEDO = col;
	ROUGHNESS = mix(gr, mix(ar, 0.85, paint), road);
	NORMAL_MAP = mix(gn, an, road);
	AO = mix(gao, 1.0, road);
	AO_LIGHT_AFFECT = 0.6;
}
"""


func _make_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = TERRAIN_SHADER
	sm.shader = shader
	sm.set_shader_parameter("g_diff", load("res://assets/tex/ground_diff.jpg"))
	sm.set_shader_parameter("g_nor", load("res://assets/tex/ground_nor_gl.jpg"))
	sm.set_shader_parameter("g_rough", load("res://assets/tex/ground_rough.jpg"))
	sm.set_shader_parameter("g_ao", load("res://assets/tex/ground_ao.jpg"))
	sm.set_shader_parameter("a_diff", load("res://assets/tex/clean_asphalt_diff_1k.jpg"))
	sm.set_shader_parameter("a_nor", load("res://assets/tex/clean_asphalt_nor_gl_1k.jpg"))
	sm.set_shader_parameter("a_rough", load("res://assets/tex/clean_asphalt_rough_1k.jpg"))
	sm.set_shader_parameter("road_half", ROAD_HALF)
	return sm


# --- yol xətti -------------------------------------------------------------

## Catmull-Rom əyrisi ilə nəzarət nöqtələrindən hamar xətt qurur.
static func _spline(pts: Array, per_seg: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in per_seg:
			var t := float(s) / per_seg
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[n - 1])
	return out


## Nöqtəyə ən yaxın xətt nöqtəsi: (məsafə, işarəli məsafə, yol boyu uzunluq, seqment indeksi, t)
static func _nearest(p: Vector2, line: PackedVector2Array, lens: PackedFloat32Array) -> Array:
	var best_d := INF
	var best_signed := 0.0
	var best_along := 0.0
	var best_i := 0
	var best_t := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var ab := line[i + 1] - a
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.0:
			t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var d := (p - (a + ab * t)).length()
		if d < best_d:
			best_d = d
			var ap := p - a
			best_signed = d * (1.0 if ab.x * ap.y - ab.y * ap.x >= 0.0 else -1.0)
			best_along = lens[i] + t * sqrt(l2)
			best_i = i
			best_t = t
	return [best_d, best_signed, best_along, best_i, best_t]


static func _lengths(line: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(line.size())
	var acc := 0.0
	for i in line.size():
		if i > 0:
			acc += line[i].distance_to(line[i - 1])
		out[i] = acc
	return out


# --- relyef ----------------------------------------------------------------

func _hill_noise() -> FastNoiseLite:
	var hills := FastNoiseLite.new()
	hills.seed = 7
	hills.frequency = 0.012
	return hills


func _raw_height(hills: FastNoiseLite, wx: float, wz: float) -> float:
	var flat := clampf((Vector2(wx, wz).length() - 8.0) / 25.0, 0.0, 1.0)
	return hills.get_noise_2d(wx, wz) * 6.0 * flat


func _generate() -> void:
	h.resize(N * N)
	base.resize(N * N)
	soft.resize(N * N)
	_uv.resize(N * N)
	_uv2.resize(N * N)
	var hills := _hill_noise()
	_big.seed = 31
	_big.frequency = 0.009
	_big.fractal_type = FastNoiseLite.FRACTAL_FBM
	_big.fractal_octaves = 4
	_ridge.seed = 47
	_ridge.frequency = 0.011
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	var mud := FastNoiseLite.new()
	mud.seed = 21
	mud.frequency = 0.02

	_road = _spline(ROAD_POINTS, 16)
	_road_len = _lengths(_road)
	_trail = _spline(TRAIL_POINTS, 12)
	var trail_len := _lengths(_trail)

	# yolun hündürlük profili: xətt boyu relyef orta qiymətlə hamarlanır
	var raw := PackedFloat32Array()
	for p in _road:
		raw.append(_raw_height(hills, p.x, p.y))
	_road_h.resize(_road.size())
	for i in _road.size():
		var s := 0.0
		var c := 0
		for k in range(maxi(i - 8, 0), mini(i + 9, _road.size())):
			s += raw[k]
			c += 1
		_road_h[i] = maxf(s / c, MIN_ROAD_HEIGHT)

	var half := (N - 1) * 0.5
	for z in N:
		for x in N:
			var wx := (x - half) * CELL
			var wz := (z - half) * CELL
			var dist := Vector2(wx, wz).length()
			var i := z * N + x
			var gentle := _raw_height(hills, wx, wz)
			# başlanğıcdan bir az aralıda palçıq sahələri
			var m := mud.get_noise_2d(wx + 40.0, wz) * 0.5 + 0.5
			var s := clampf((m - 0.45) * 5.0, 0.0, 1.0) * clampf(dist / 12.0, 0.0, 1.0)

			var p := Vector2(wx, wz)
			# palçıq cığırı
			var tr := _nearest(p, _trail, trail_len)
			var td: float = tr[0]
			s = maxf(s, 1.0 - smoothstep(TRAIL_HALF, TRAIL_HALF + 2.5, td))

			# asfalt yol
			var rd := _nearest(p, _road, _road_len)
			var d: float = rd[0]
			var seg: int = rd[3]
			var t: float = rd[4]
			var road_h := lerpf(_road_h[seg], _road_h[seg + 1], t)
			# yolun yanında hamar relyef, uzaqda təpələr və dağlar
			var far_k := smoothstep(ROAD_HALF + ROAD_BLEND, ROAD_HALF + ROAD_BLEND + ROAD_CORRIDOR, d)
			var hh := lerpf(gentle, _strong_height(wx, wz), far_k)
			var blend := 1.0 - smoothstep(ROAD_HALF + 0.5, ROAD_HALF + ROAD_BLEND, d)
			hh = lerpf(hh, road_h, blend)
			# yolda və yaxınlığında palçıq olmasın
			s *= smoothstep(ROAD_HALF + 0.8, ROAD_HALF + 3.0, d)

			h[i] = hh
			base[i] = hh
			soft[i] = s
			_uv[i] = Vector2(wx, wz)
			_uv2[i] = Vector2(rd[1], rd[2])

	# dik yamaclarda və hündürlükdə palçıq olmasın (qaya və qar)
	for z in N:
		for x in N:
			var i := z * N + x
			var gx := (h[_idx(x + 1, z)] - h[_idx(x - 1, z)]) / (2.0 * CELL)
			var gz := (h[_idx(x, z + 1)] - h[_idx(x, z - 1)]) / (2.0 * CELL)
			if Vector2(gx, gz).length() > 0.45 or h[i] > 24.0:
				soft[i] = 0.0


## Güclü relyef: yuvarlanan təpələr + xəritənin kənarında silsilə dağlar.
func _strong_height(wx: float, wz: float) -> float:
	var edge := smoothstep(MOUNTAIN_START, MOUNTAIN_FULL, maxf(absf(wx), absf(wz)))
	var rolling := maxf(_big.get_noise_2d(wx, wz) * 12.0 + 4.0, -3.0)  # çökəkliklər göl kimi qalır
	var ridge := _ridge.get_noise_2d(wx, wz) * 0.5 + 0.5
	return rolling + edge * (10.0 + ridge * 34.0)


func _idx(x: int, z: int) -> int:
	return clampi(z, 0, N - 1) * N + clampi(x, 0, N - 1)


func _build_indices() -> void:
	for z in N - 1:
		for x in N - 1:
			var a := z * N + x
			var b := a + 1
			var c := a + N
			var d := c + 1
			_indices.append_array([a, b, c, b, d, c])
	_verts.resize(N * N)
	_normals.resize(N * N)
	_tangents.resize(N * N * 4)
	_colors.resize(N * N)


## full=false olanda yalnız dəyişən hissənin vertekslərini, normallarını və rənglərini yeniləyir.
func _rebuild_mesh(full := true) -> void:
	var half := (N - 1) * 0.5
	var x0 := 0
	var z0 := 0
	var x1 := N - 1
	var z1 := N - 1
	if not full:
		x0 = maxi(_dirty_min.x - 1, 0)
		z0 = maxi(_dirty_min.y - 1, 0)
		x1 = mini(_dirty_max.x + 1, N - 1)
		z1 = mini(_dirty_max.y + 1, N - 1)
	_dirty_min = Vector2i(N, N)
	_dirty_max = Vector2i(-1, -1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * N + x
			_verts[i] = Vector3((x - half) * CELL, h[i], (z - half) * CELL)
			var dx := h[_idx(x + 1, z)] - h[_idx(x - 1, z)]
			var dz := h[_idx(x, z + 1)] - h[_idx(x, z - 1)]
			_normals[i] = Vector3(-dx, 2.0 * CELL, -dz).normalized()
			var tg := Vector3(2.0 * CELL, dx, 0.0).normalized()
			_tangents[i * 4] = tg.x
			_tangents[i * 4 + 1] = tg.y
			_tangents[i * 4 + 2] = tg.z
			_tangents[i * 4 + 3] = 1.0
			var depth := clampf((base[i] - h[i]) / MAX_DEPTH, 0.0, 1.0)
			var grass := Color(0.60, 0.80, 0.40)
			var wet := Color(0.55, 0.42, 0.30)
			var rut := Color(0.30, 0.22, 0.16)
			var c := grass.lerp(wet, clampf(soft[i] * 1.8, 0.0, 1.0))
			_colors[i] = c.lerp(rut, depth)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TANGENT] = _tangents
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_inst.mesh = mesh


## Dünya koordinatından tor indeksinə.
func _to_grid(world_pos: Vector3) -> Vector2:
	var local := to_local(world_pos)
	var half := (N - 1) * 0.5
	return Vector2(local.x / CELL + half, local.z / CELL + half)


func softness_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	return soft[z * N + x]


func depth_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	var i := z * N + x
	return base[i] - h[i]


func height_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	return h[_idx(roundi(g.x), roundi(g.y))]


## Yamacın dikliyi (0 = düz, 1 = 45 dərəcə). Ot və ağac yerləşdirmək üçün.
func slope_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	var gx := (h[_idx(x + 1, z)] - h[_idx(x - 1, z)]) / (2.0 * CELL)
	var gz := (h[_idx(x, z + 1)] - h[_idx(x, z - 1)]) / (2.0 * CELL)
	return Vector2(gx, gz).length()


## Nöqtənin asfalt yolun oxundan məsafəsi (metr). Ot və ağac yerləşdirmək üçün.
func road_distance_at(world_pos: Vector3) -> float:
	var r := _nearest(Vector2(world_pos.x, world_pos.z), _road, _road_len)
	return r[0]


## Yol üzərində başlanğıc nöqtəsi: {pos: Vector3, yaw: float}. Maşının irəlisi +Z-dir.
func road_spawn() -> Dictionary:
	var i := int(_road.size() * 0.35)
	var p := _road[i]
	var dir := (_road[i + 1] - _road[i]).normalized()
	return {"pos": Vector3(p.x, _road_h[i], p.y), "yaw": atan2(dir.x, dir.y)}


## Təkərin basdığı yeri batırır, kənarlarını bir az qaldırır.
func deform(world_pos: Vector3, radius: float, amount: float) -> void:
	var g := _to_grid(world_pos)
	var r := int(ceil(radius / CELL))
	var cx := roundi(g.x)
	var cz := roundi(g.y)
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or z < 0 or x >= N or z >= N:
				continue
			var d := Vector2(x - g.x, z - g.y).length() * CELL
			if d > radius:
				continue
			var i := z * N + x
			var falloff := 1.0 - d / radius
			var s: float = soft[i]
			if s <= 0.0:
				continue
			h[i] = maxf(h[i] - amount * falloff * s, base[i] - MAX_DEPTH)
			_dirty = true
			_dirty_min = Vector2i(mini(_dirty_min.x, x), mini(_dirty_min.y, z))
			_dirty_max = Vector2i(maxi(_dirty_max.x, x), maxi(_dirty_max.y, z))
