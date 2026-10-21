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

var _material: ShaderMaterial
var _ctrl_a_img: Image
var _ctrl_b_img: Image
var _ctrl_a_tex: ImageTexture
var _ctrl_b_tex: ImageTexture
var _grass_w := PackedFloat32Array()     # statik ot çəkisi (ctrl_b R kanalı)
var _aux_dirt := PackedFloat32Array()    # torpaq çəkisi (yol kənarı və sahələr)
var _aux_cobble := PackedFloat32Array()  # daş sahələri
var _aux_deepk := PackedFloat32Array()   # palçığın dərin hissəsi

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

	_material = _make_material()
	_mesh_inst.material_override = _material
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



func _make_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain.gdshader")
	var tex := TerrainTextures.build()
	if tex.is_empty():
		push_warning("Terrain teksturaları yüklənmədi")
	else:
		sm.set_shader_parameter("tex_albedo", tex["albedo"])
		sm.set_shader_parameter("tex_normal", tex["normal"])
		sm.set_shader_parameter("tex_height", tex["height"])
		sm.set_shader_parameter("tex_rough", tex["rough"])
	sm.set_shader_parameter("tile_m", TerrainTextures.tiles())
	sm.set_shader_parameter("layer_tint", TerrainTextures.tints())
	sm.set_shader_parameter("a_diff", load("res://assets/tex/clean_asphalt_diff_1k.jpg"))
	sm.set_shader_parameter("a_nor", load("res://assets/tex/clean_asphalt_nor_gl_1k.jpg"))
	sm.set_shader_parameter("a_rough", load("res://assets/tex/clean_asphalt_rough_1k.jpg"))
	sm.set_shader_parameter("road_half", ROAD_HALF)
	sm.set_shader_parameter("ctrl_n", float(N))
	sm.set_shader_parameter("cell", CELL)
	_ctrl_a_tex = ImageTexture.create_from_image(_ctrl_a_img)
	_ctrl_b_tex = ImageTexture.create_from_image(_ctrl_b_img)
	sm.set_shader_parameter("ctrl_a", _ctrl_a_tex)
	sm.set_shader_parameter("ctrl_b", _ctrl_b_tex)
	# makro variasiya: eyni teksturanın təkrarı görünməsin
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var nimg := noise.get_seamless_image(256, 256)
	nimg.generate_mipmaps()
	sm.set_shader_parameter("macro_noise", ImageTexture.create_from_image(nimg))
	return sm


## Hava və fəsil: yağış (islanma), qar örtüyü, buz. Hamısı 0..1. İndi yalnız görünüşdür,
## fizika 3-cü mərhələdə SurfaceType ilə bağlanacaq.
func set_surface_conditions(wet: float, snow: float, ice: float) -> void:
	_material.set_shader_parameter("wetness", clampf(wet, 0.0, 1.0))
	_material.set_shader_parameter("snow_amount", clampf(snow, 0.0, 1.0))
	_material.set_shader_parameter("ice_amount", clampf(ice, 0.0, 1.0))


## Fəsil üçün ot rəngi (məsələn payızda sarımtıl).
func set_grass_tint(tint: Color) -> void:
	_material.set_shader_parameter("grass_tint", Vector3(tint.r, tint.g, tint.b))


## Çəki xəritələrini hazır `soft`, yol və səs maskalarından qurur (generasiyadan sonra).
func _build_ctrl() -> void:
	_ctrl_a_img = Image.create(N, N, false, Image.FORMAT_RGBA8)
	_ctrl_b_img = Image.create(N, N, false, Image.FORMAT_RGBA8)
	_grass_w.resize(N * N)
	for i in N * N:
		var s := soft[i]
		var deep := s * _aux_deepk[i]
		var mud := s - deep
		var dirt := _aux_dirt[i] * (1.0 - s)
		var cobble := _aux_cobble[i] * (1.0 - s)
		var grass := clampf(1.0 - (mud + deep + dirt + cobble), 0.0, 1.0)
		_grass_w[i] = grass
		var x := i % N
		var z := i / N
		_ctrl_a_img.set_pixel(x, z, Color(dirt, mud, deep, cobble))
		_ctrl_b_img.set_pixel(x, z, Color(grass, 0.0, 0.0, 0.0))


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
	var dirt_noise := FastNoiseLite.new()
	dirt_noise.seed = 63
	dirt_noise.frequency = 0.03
	var cobble_noise := FastNoiseLite.new()
	cobble_noise.seed = 71
	cobble_noise.frequency = 0.045
	_aux_dirt.resize(N * N)
	_aux_cobble.resize(N * N)
	_aux_deepk.resize(N * N)

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
			var deep_k := smoothstep(0.85, 1.0, s)  # palçığın ən dərin hissəsi

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

			# səth qarışığı üçün köməkçi maskalar: yol kənarı torpağı, torpaq və daş sahələri
			var shoulder_w := smoothstep(ROAD_HALF + 0.3, ROAD_HALF + 0.9, d) \
					* (1.0 - smoothstep(ROAD_HALF + 2.0, ROAD_HALF + 5.0, d))
			var dn := dirt_noise.get_noise_2d(wx, wz) * 0.5 + 0.5
			var cn := cobble_noise.get_noise_2d(wx, wz) * 0.5 + 0.5
			_aux_dirt[i] = clampf(maxf(shoulder_w, smoothstep(0.58, 0.78, dn) * 0.85), 0.0, 1.0)
			_aux_cobble[i] = smoothstep(0.64, 0.80, cn) * 0.9
			_aux_deepk[i] = deep_k

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
	_build_ctrl()


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
			# iz dərinliyi çəki xəritəsinə yazılır: dərin palçıq çəkisi artır
			var depth := clampf((base[i] - h[i]) / MAX_DEPTH, 0.0, 1.0)
			_ctrl_b_img.set_pixel(x, z, Color(_grass_w[i], 0.0, depth, 0.0))
	if _ctrl_b_tex != null:
		_ctrl_b_tex.update(_ctrl_b_img)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TANGENT] = _tangents
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
