class_name MudTerrain
extends StaticBody3D
## Deformasiya olunan landşaft: təkər basdıqca palçıqlı yer batır.
## Üzərində asfalt yol (palçıq olmur) və palçıq cığırı var.

const N := 513             # 512 cells x 4 m = 2048 m on each side
const CELL := 4.0          # coarse world grid; road has a separate smooth ribbon
const DETAIL_UNDERFLOOR := 1.60
const MAX_DEPTH := 1.15     # yerin ən çox batma dərinliyi
const REBUILD_INTERVAL := 0.1
const CHUNK_CELLS := 32
const ROUTE_BIN := 64.0
var pre_hill_h := PackedFloat32Array()
var pre_hill_soft := PackedFloat32Array()
var hill_zone: HillClimbZone
var _chunks := {}
var _road_bins := {}
var _trail_bins := {}
const DETAIL_SIZE := 16.0
var _fine_patches := {}
var _rut_cache := {}
var _compaction_cache := {}
var _detail_center := Vector2i(99999, 99999)
const SWAMPS := [Vector3(-365, -425, 24), Vector3(-318, -230, 30), Vector3(-270, 22, 25)]


const ROAD_HALF := 4.0     # yolun yarım eni (metr)
const ROAD_BLEND := 7.0    # yolun hündürlüyünün relyefə qarışma məsafəsi
const TRAIL_HALF := 3.0    # palçıq cığırının yarım eni
# dünya koordinatında (x, z) nəzarət nöqtələri
const ROAD_POINTS := [
	Vector2(-780, -720), Vector2(-450, -760), Vector2(-100, -700),
	Vector2(120, -460), Vector2(500, -520), Vector2(780, -250),
	Vector2(650, 0), Vector2(770, 140), Vector2(650, 210),
	Vector2(800, 290), Vector2(680, 360), Vector2(740, 450), Vector2(550, 600),
	Vector2(180, 760), Vector2(-80, 580), Vector2(-350, 780),
	Vector2(-700, 600), Vector2(-780, 200), Vector2(-580, -80),
	Vector2(-780, -360), Vector2(-780, -720),
]
const TRAIL_POINTS := [
	Vector2(-450, -760), Vector2(-380, -500), Vector2(-330, -300),
	Vector2(-330, -160), Vector2(-290, 30), Vector2(140, 80), Vector2(300, 300), Vector2(550, 600),
]

# relyef: yolun yanında hamar, uzaqda təpələr, xəritənin kənarında dağ silsiləsi
const ROAD_CORRIDOR := 40.0   # yol yamacından təpələrin tam başladığı məsafə
const MOUNTAIN_START := 850.0  # dağ silsiləsinin başladığı məsafə (mərkəzdən, max(|x|,|z|))
const MOUNTAIN_FULL := 1024.0
const MIN_ROAD_HEIGHT := -1.0 # yol su səviyyəsindən yuxarıda qalsın

var h := PackedFloat32Array()     # cari hündürlük
var base := PackedFloat32Array()  # ilkin hündürlük
var soft := PackedFloat32Array()  # 0 = bərk yer, 1 = dərin palçıq

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
var road_dist := PackedFloat32Array()    # hər təpənin asfalt yol oxuna məsafəsi (metr), bitki yerləşdirməsi üçün sürətli

var _road := PackedVector2Array()        # sıxlaşdırılmış yol xətti
var _road_len := PackedFloat32Array()    # xəttin əvvəlindən yığılmış uzunluq
var _road_h := PackedFloat32Array()      # yolun hündürlük profili
var _trail_len := PackedFloat32Array()
var _trail := PackedVector2Array()


func _ready() -> void:
	if ProjectSettings.get_setting("offroad/hill_climb_enabled", true):
		hill_zone = HillClimbZone.new()
	_generate()
	_build_indices()
	_material = _make_material()
	_rebuild_mesh()
	_build_swamp_water()



func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= REBUILD_INTERVAL:
		_timer = 0.0
		_dirty = false
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
	for patch in _fine_patches.values():
		var mat: ShaderMaterial = patch._mesh.material_override
		mat.set_shader_parameter("wetness", clampf(wet, 0, 1))
		mat.set_shader_parameter("snow_amount", clampf(snow, 0, 1))
		mat.set_shader_parameter("ice_amount", clampf(ice, 0, 1))


## Fəsil üçün ot rəngi (məsələn payızda sarımtıl).
func set_grass_tint(tint: Color) -> void:
	_material.set_shader_parameter("grass_tint", Vector3(tint.r, tint.g, tint.b))
	for patch in _fine_patches.values():
		patch._mesh.material_override.set_shader_parameter("grass_tint", Vector3(tint.r, tint.g, tint.b))


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
	var p := Vector2(wx, wz)
	var mountain := exp(-p.distance_squared_to(Vector2(540, 420)) / 120000.0) * 155.0
	mountain += exp(-p.distance_squared_to(Vector2(-650, 530)) / 100000.0) * 100.0
	mountain += exp(-p.distance_squared_to(Vector2(650, -540)) / 75000.0) * 72.0
	var lake := exp(-p.distance_squared_to(Vector2(-150, -120)) / 24000.0) * 26.0
	return 7.0 + mountain - lake + hills.get_noise_2d(wx, wz) * 3.5


## Index only nearby route segments; far-away terrain does not need exact road UVs.
func _route_index(line: PackedVector2Array, reach: float) -> Dictionary:
	var bins := {}
	for i in line.size() - 1:
		var lo := line[i].min(line[i + 1]) - Vector2.ONE * reach
		var hi := line[i].max(line[i + 1]) + Vector2.ONE * reach
		for z in range(floori(lo.y / ROUTE_BIN), floori(hi.y / ROUTE_BIN) + 1):
			for x in range(floori(lo.x / ROUTE_BIN), floori(hi.x / ROUTE_BIN) + 1):
				var key := Vector2i(x, z)
				if not bins.has(key):
					bins[key] = []
				bins[key].append(i)
	return bins


func _near_route(p: Vector2, line: PackedVector2Array, lens: PackedFloat32Array, bins: Dictionary) -> Array:
	var key := Vector2i(floori(p.x / ROUTE_BIN), floori(p.y / ROUTE_BIN))
	var best := [10000.0, 10000.0, 0.0, 0, 0.0]
	for i: int in bins.get(key, []):
		var ab := line[i + 1] - line[i]
		var t := clampf((p - line[i]).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(line[i] + ab * t)
		if d < best[0]:
			var ap := p - line[i]
			best = [d, d * (1.0 if ab.cross(ap) >= 0.0 else -1.0), lens[i] + t * ab.length(), i, t]
	return best


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
	road_dist.resize(N * N)

	_road = _spline(ROAD_POINTS, 12)
	_road_len = _lengths(_road)
	_trail = _spline(TRAIL_POINTS, 10)
	_trail_len = _lengths(_trail)
	var trail_len := _trail_len
	_road_bins = _route_index(_road, 100.0)
	_trail_bins = _route_index(_trail, 24.0)

	# yolun hündürlük profili: xətt boyu relyef orta qiymətlə hamarlanır
	var raw := PackedFloat32Array()
	for p in _road:
		raw.append(_raw_height(hills, p.x, p.y))
	_road_h.resize(_road.size())
	for i in _road.size():
		var s := 0.0
		var c := 0
		for k in range(maxi(i - 2, 0), mini(i + 3, _road.size())):
			s += raw[k]
			c += 1
		_road_h[i] = maxf(s / c, MIN_ROAD_HEIGHT)

	# Limit the paved route to a driveable 10 percent grade in both directions.
	for pass_index in 4:
		for i in range(1, _road.size()):
			var rise := _road[i].distance_to(_road[i - 1]) * 0.10
			_road_h[i] = clampf(_road_h[i], _road_h[i - 1] - rise, _road_h[i - 1] + rise)
		for i in range(_road.size() - 2, -1, -1):
			var rise := _road[i].distance_to(_road[i + 1]) * 0.10
			_road_h[i] = clampf(_road_h[i], _road_h[i + 1] - rise, _road_h[i + 1] + rise)
	_road_h[_road_h.size() - 1] = _road_h[0]
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
			var tr := _near_route(p, _trail, trail_len, _trail_bins)
			var td: float = tr[0]
			s = maxf(s, 1.0 - smoothstep(TRAIL_HALF, TRAIL_HALF + 2.5, td))
			for swamp in SWAMPS:
				var basin := 1.0 - smoothstep(swamp.z * 0.6, swamp.z, p.distance_to(Vector2(swamp.x, swamp.y)))
				s = maxf(s, basin)
				deep_k = maxf(deep_k, basin)

			# asfalt yol
			var rd := _near_route(p, _road, _road_len, _road_bins)
			var d: float = rd[0]
			var seg: int = rd[3]
			var t: float = rd[4]
			var road_h := lerpf(_road_h[seg], _road_h[seg + 1], t)
			# yolun yanında hamar relyef, uzaqda təpələr və dağlar
			var far_k := smoothstep(ROAD_HALF + ROAD_BLEND, ROAD_HALF + ROAD_BLEND + ROAD_CORRIDOR, d)
			var hh := lerpf(gentle, _strong_height(wx, wz), far_k)
			var blend := 1.0 - smoothstep(ROAD_HALF + 0.5, ROAD_HALF + ROAD_BLEND, d)
			# Flat, shallow basins keep swamp water and soft ground at a believable level.
			for swamp in SWAMPS:
				var basin := 1.0 - smoothstep(swamp.z * 0.50, swamp.z, p.distance_to(Vector2(swamp.x, swamp.y)))
				var swamp_h := _raw_height(hills, swamp.x, swamp.y) - 0.45
				hh = lerpf(hh, swamp_h, basin * (1.0 - blend))
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
			road_dist[i] = d

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
			if Vector2(gx, gz).length() > 0.45 or h[i] > 70.0:
				soft[i] = 0.0
	if hill_zone != null:
		pre_hill_h = h.duplicate()
		pre_hill_soft = soft.duplicate()
		hill_zone.sculpt(self)
	_build_ctrl()


## Güclü relyef: yuvarlanan təpələr + xəritənin kənarında silsilə dağlar.
func _strong_height(wx: float, wz: float) -> float:
	var edge := smoothstep(MOUNTAIN_START, MOUNTAIN_FULL, maxf(absf(wx), absf(wz)))
	var ridge := _ridge.get_noise_2d(wx, wz) * 0.5 + 0.5
	return _raw_height(_big, wx, wz) + ridge * 8.0 + edge * (35.0 + ridge * 70.0)



func _idx(x: int, z: int) -> int:
	return clampi(z, 0, N - 1) * N + clampi(x, 0, N - 1)


func _build_indices() -> void:
	# Shared topology for 128 m terrain chunks. Only changed chunks are rebuilt.
	var stride := CHUNK_CELLS + 1
	for z in CHUNK_CELLS:
		for x in CHUNK_CELLS:
			var a := z * stride + x
			_indices.append_array([a, a + 1, a + stride, a + 1, a + stride + 1, a + stride])
	_verts.resize(N * N)
	_normals.resize(N * N)
	_tangents.resize(N * N * 4)


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

	for cz in range(maxi(z0 - 1, 0) / CHUNK_CELLS, mini(z1 / CHUNK_CELLS, (N - 2) / CHUNK_CELLS) + 1):
		for cx in range(maxi(x0 - 1, 0) / CHUNK_CELLS, mini(x1 / CHUNK_CELLS, (N - 2) / CHUNK_CELLS) + 1):
			_build_chunk(cx, cz)


func _build_chunk(cx: int, cz: int) -> void:
	var key := Vector2i(cx, cz)
	var n := CHUNK_CELLS + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var heights := PackedFloat32Array()
	for z in n:
		for x in n:
			var i := (cz * CHUNK_CELLS + z) * N + cx * CHUNK_CELLS + x
			var underfloor := _detail_floor(_uv[i])
			vertices.append(_verts[i] - Vector3.UP * underfloor)
			normals.append(_normals[i])
			tangents.append_array(_tangents.slice(i * 4, i * 4 + 4))
			uv.append(_uv[i])
			uv2.append(_uv2[i])
			heights.append(h[i] - underfloor)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not _chunks.has(key):
		var mi := MeshInstance3D.new()
		mi.name = "Terrain_%d_%d" % [cx, cz]
		mi.material_override = _material
		mi.visibility_range_end = 2000.0
		mi.visibility_range_end_margin = 40.0
		add_child(mi)
		var shape := HeightMapShape3D.new()
		shape.map_width = n
		shape.map_depth = n
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3((cx * CHUNK_CELLS + CHUNK_CELLS * 0.5 - (N - 1) * 0.5) * CELL, 0, (cz * CHUNK_CELLS + CHUNK_CELLS * 0.5 - (N - 1) * 0.5) * CELL)
		collider.scale = Vector3(CELL, 1, CELL)
		add_child(collider)
		_chunks[key] = {"mesh": mi, "shape": shape}
	(_chunks[key]["mesh"] as MeshInstance3D).mesh = mesh
	(_chunks[key]["shape"] as HeightMapShape3D).map_data = heights


## Dünya koordinatından tor indeksinə.
func _to_grid(world_pos: Vector3) -> Vector2:
	var local := to_local(world_pos)
	var half := (N - 1) * 0.5
	return Vector2(local.x / CELL + half, local.z / CELL + half)


func softness_at(world_pos: Vector3) -> float:
	var patch = _fine_patches.get(_detail_key(world_pos))
	if patch != null:
		return patch.soft_at(world_pos)
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	return soft[z * N + x]


func depth_at(world_pos: Vector3) -> float:
	var patch = _fine_patches.get(_detail_key(world_pos))
	if patch != null:
		return patch.depth_at(world_pos) + maxf(0.0, sample_grid(base,world_pos) - base_height_at(world_pos))
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	var i := z * N + x
	return base[i] - h[i]


func height_at(world_pos: Vector3) -> float:
	var patch = _fine_patches.get(_detail_key(world_pos))
	if patch != null:
		return patch.height_at(world_pos)
	return sample_grid(h, world_pos)


## Yamacın dikliyi (0 = düz, 1 = 45 dərəcə). Ot və ağac yerləşdirmək üçün.
func slope_at(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	var gx := (h[_idx(x + 1, z)] - h[_idx(x - 1, z)]) / (2.0 * CELL)
	var gz := (h[_idx(x, z + 1)] - h[_idx(x, z - 1)]) / (2.0 * CELL)
	return Vector2(gx, gz).length()


## Sürətli (O(1)) yol məsafəsi: ən yaxın təpənin qiyməti. Çox sayda nöqtə üçün (bitki yerləşdirməsi).
func road_distance_fast(world_pos: Vector3) -> float:
	var g := _to_grid(world_pos)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= N or z >= N:
		return 1000.0
	var approximate := road_dist[z * N + x]
	if approximate < 16.0:
		return _near_route(Vector2(world_pos.x, world_pos.z), _road, _road_len, _road_bins)[0]
	return approximate


## Nöqtənin asfalt yolun oxundan məsafəsi (metr), dəqiq amma yavaş (hər seqmentə baxır).
func road_distance_at(world_pos: Vector3) -> float:
	var r := _nearest(Vector2(world_pos.x, world_pos.z), _road, _road_len)
	return r[0]


## Yol üzərində başlanğıc nöqtəsi: {pos: Vector3, yaw: float}. Maşının irəlisi +Z-dir.
func road_spawn() -> Dictionary:
	var i := 2
	var p := _road[i]
	var dir := (_road[i + 1] - _road[i]).normalized()
	return {"pos": Vector3(p.x, _road_h[i], p.y), "yaw": atan2(dir.x, dir.y)}


## Fırlanmadan yuvarlanan təkərin altındakı torpağı sıxlaşdırır.
func compact(world_pos: Vector3, radius: float, amount: float) -> void:
	if amount <= 0.0 or road_distance_fast(world_pos) < ROAD_HALF + 0.6:
		return
	for patch in _fine_patches.values():
		patch.compact(world_pos, radius, amount)


## Təkərin basdığı yeri batırır.
func deform(world_pos: Vector3, radius: float, amount: float) -> void:
	if amount <= 0.0 or road_distance_fast(world_pos) < ROAD_HALF + 0.6:
		return
	if not _fine_patches.is_empty():
		for patch in _fine_patches.values():
			patch.dig(world_pos, radius, amount)
		return
	var g := _to_grid(world_pos)
	radius = maxf(radius, CELL * 0.85)
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


func sample_grid(values: PackedFloat32Array, p: Vector3) -> float:
	var g := _to_grid(p)
	var x := floori(g.x)
	var z := floori(g.y)
	return lerpf(lerpf(values[_idx(x, z)], values[_idx(x + 1, z)], g.x - x),
		lerpf(values[_idx(x, z + 1)], values[_idx(x + 1, z + 1)], g.x - x), g.y - z)


func _detail_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / DETAIL_SIZE), floori(p.z / DETAIL_SIZE))


# A 3 x 3 moving window gives wheel ruts a 25 cm collision grid. Far ruts
# are retained in a bounded session cache, without tessellating the 2 km world.
func prepare_mud(p: Vector3) -> void:
	var center := _detail_key(p)
	if center == _detail_center:
		return
	_detail_center = center
	var changed: Array[Vector2i] = []
	for key: Vector2i in _fine_patches.keys():
		if absi(key.x - center.x) > 1 or absi(key.y - center.y) > 1:
			_rut_cache[key] = _fine_patches[key].depths.duplicate()
			_compaction_cache[key] = _fine_patches[key].compaction.duplicate()
			_fine_patches[key].free()
			_fine_patches.erase(key)
			changed.append(key)
	while _rut_cache.size() > 256:
		var oldest = _rut_cache.keys()[0]
		_rut_cache.erase(oldest)
		_compaction_cache.erase(oldest)
	for z in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var key := Vector2i(x, z)
			if not _fine_patches.has(key):
				var patch := MudPatch.new()
				patch.terrain = self
				patch.tile = key
				if _rut_cache.has(key):
					patch.depths = _rut_cache[key].duplicate()
				_fine_patches[key] = patch
				add_child(patch)
				changed.append(key)
	# Reconcile shared samples after cache eviction or re-entry beside newer ruts.
	for key in _fine_patches:
		var patch: MudPatch = _fine_patches[key]
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: MudPatch = _fine_patches.get(key + direction)
			if other == null:
				continue
			for i in MudPatch.SIDE:
				var a: int = i * MudPatch.SIDE + 64 if direction == Vector2i.RIGHT else 64 * MudPatch.SIDE + i
				var b: int = i * MudPatch.SIDE if direction == Vector2i.RIGHT else i
				var shared := maxf(patch.depths[a], other.depths[b])
				if not is_equal_approx(patch.depths[a], shared) or not is_equal_approx(other.depths[b], shared):
					patch.depths[a] = shared
					other.depths[b] = shared
					patch._dirty = true
					other._dirty = true
	# Only coarse chunks overlapped by the old/new window need underfloor updates.
	var dirty_chunks := {}
	for key in changed:
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var world := Vector2(key.x + dx, key.y + dz) * DETAIL_SIZE
				var grid := (world + Vector2.ONE * 1024.0) / (CELL * CHUNK_CELLS)
				var ck := Vector2i(floori(grid.x), floori(grid.y))
				if _chunks.has(ck):
					dirty_chunks[ck] = true
	for ck in dirty_chunks:
		_build_chunk(ck.x, ck.y)


func _detail_floor(p: Vector2) -> float:
	# Keep the outside edge at its original height; the active fine meshes cover
	# the lowered coarse collider. No invisible hard surface remains in the ruts.
	var lo := Vector2(_detail_center.x - 1, _detail_center.y - 1) * DETAIL_SIZE
	var hi := lo + Vector2.ONE * DETAIL_SIZE * 3.0
	var edge := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.y - lo.y, hi.y - p.y))
	return DETAIL_UNDERFLOOR * smoothstep(0.0, CELL, edge)


func _build_swamp_water() -> void:
	for swamp in SWAMPS:
		var p := Vector3(swamp.x, 0, swamp.y)
		var mi := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = swamp.z * 0.47
		disk.bottom_radius = disk.top_radius
		disk.height = 0.012
		disk.radial_segments = 48
		mi.mesh = disk
		mi.position = Vector3(p.x, sample_grid(base, p) + 0.09, p.z)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.10, 0.045, 0.68)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.14
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func base_height_at(p: Vector3) -> float:
	var height := sample_grid(base, p)
	if hill_zone != null and HillClimbCatalog.ZONE.has_point(Vector2(p.x,p.z)):
		var rut := hill_zone.initial_rut(Vector2(p.x,p.z))
		if rut < -0.001 and road_distance_fast(p) >= 18.0 and _near_route(Vector2(p.x,p.z), _trail, _trail_len, _trail_bins)[0] >= 6.0:
			height += rut
	return height


func activity_clearing(p: Vector3) -> bool:
	return (hill_zone != null and hill_zone.clearing(Vector2(p.x,p.z))) or BarnFinds.clearing(p) or WorldProps.clearing(p)


# Vegetation placement consumes the same original values and random sequence.
# Local pruning/relocation happens after placement, preserving the outside forest.
func vegetation_heights() -> PackedFloat32Array:
	return h if pre_hill_h.is_empty() else pre_hill_h

func vegetation_softness_at(p: Vector3) -> float:
	if pre_hill_soft.is_empty():
		return softness_at(p)
	var g := _to_grid(p)
	return pre_hill_soft[_idx(roundi(g.x),roundi(g.y))]

func vegetation_slope_at(p: Vector3) -> float:
	if pre_hill_h.is_empty():
		return slope_at(p)
	var g := _to_grid(p)
	var x := roundi(g.x)
	var z := roundi(g.y)
	return Vector2(pre_hill_h[_idx(x+1,z)]-pre_hill_h[_idx(x-1,z)],pre_hill_h[_idx(x,z+1)]-pre_hill_h[_idx(x,z-1)]).length()/(2.0*CELL)
