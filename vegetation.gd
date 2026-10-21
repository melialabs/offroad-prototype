class_name Vegetation
extends Node3D
## Biom-şüurlu meşə: ağac klasterləri, alt bitki örtüyü, ot, ölü ağac və kötüklər.
## - Deterministik: eyni toxumla eyni nəticə.
## - Hər növ/variant/hissə (chunk) üçün LOD-lara bölünmüş MultiMeshInstance3D, məsafəyə görə görünmə və sönmə.
## - Ağaclar üçün gövdə toqquşması (bir StaticBody3D, çoxlu silindr).
## - terrain.gd API-sinə yalnız oxuma müraciəti: h, soft, slope_at, road_distance_fast, softness_at.
## Fəsil üçün: apply_season_tint() foliage materiallarının rəngini dəyişir (qar üçün gələcək shader parametri hazırdır).

# kind: "tree" (toqquşma var), "under" (alt bitki), "ground" (ot), "wood" (ölü ağac, kötük)
# lod: hər LOD üçün [başlama, bitmə] məsafəsi (metr). shadow_lods: kölgə salan LOD sayı.
const SPECIES := {
	"pine": {"asset": "pine_tree_01", "foliage": "pine_spray", "kind": "tree", "scale": [0.85, 1.2],
		"trunk_r": 0.38, "lod": [[0, 38], [32, 105], [99, 230]], "shadow_lods": 1},
	"fir": {"asset": "fir_tree_01", "foliage": "fir_spray", "kind": "tree", "scale": [0.85, 1.15],
		"trunk_r": 0.40, "lod": [[0, 38], [32, 105], [99, 230]], "shadow_lods": 1},
	"sapling_m": {"asset": "pine_sapling_medium", "foliage": "pine_spray", "kind": "tree", "scale": [0.7, 1.0],
		"trunk_r": 0.22, "lod": [[0, 34], [28, 90], [84, 190]], "shadow_lods": 1},
	"broadleaf": {"asset": "tree_small_02", "foliage": "broadleaf_spray", "kind": "tree", "scale": [1.0, 1.5],
		"trunk_r": 0.2, "lod": [[0, 34], [28, 85], [79, 170]], "shadow_lods": 1},
	"sapling_s": {"asset": "pine_sapling_small", "foliage": "pine_spray", "kind": "under", "scale": [1.1, 1.8],
		"lod": [[0, 30], [24, 65]], "shadow_lods": 0},
	"shrub": {"asset": "shrub_02", "foliage": "", "kind": "under", "scale": [0.9, 1.5],
		"lod": [[0, 30], [24, 65], [59, 105]], "shadow_lods": 0},
	"shrub4": {"asset": "shrub_04", "foliage": "", "kind": "under", "scale": [2.0, 3.4],
		"lod": [[0, 28], [22, 55], [49, 90]], "shadow_lods": 0},
	"fern": {"asset": "fern_02", "foliage": "", "kind": "under", "scale": [1.4, 2.4],
		"lod": [[0, 26], [20, 55]], "shadow_lods": 0},
	"grass_m": {"asset": "grass_medium_01", "foliage": "", "kind": "ground", "scale": [2.4, 3.8],
		"lod": [[0, 26], [20, 52]], "shadow_lods": 0},
	"grass_b": {"asset": "grass_bermuda_01", "foliage": "", "kind": "ground", "scale": [2.2, 4.0],
		"lod": [[0, 22], [16, 45]], "shadow_lods": 0},
	"log": {"asset": "dead_tree_trunk", "foliage": "", "kind": "wood", "scale": [0.8, 1.6],
		"lod": [[0, 40], [34, 90], [84, 150]], "shadow_lods": 1},
	"stump": {"asset": "tree_stump_01", "foliage": "", "kind": "wood", "scale": [0.9, 1.5],
		"lod": [[0, 40], [34, 90], [84, 150]], "shadow_lods": 1},
}

const CHUNK_SIZE := {"tree": 40.0, "under": 48.0, "ground": 48.0, "wood": 48.0}
## Kölgə yalnız bu məsafəyə qədər (m) və ucuz proxy mesh ilə (növün LOD1-i) salınır.
const SHADOW_RANGE := 70.0
const FADE_MARGIN := 6.0
## LOD keçidində sönmə (VISIBILITY_RANGE_FADE_SELF) alfa-scissor yarpaqları yox edir (yalnız gövdə qalır),
## ona görə default sönməsizdir (sərt keçid, margin yalnız histerezis). Diaqnostika üçün true edilə bilər.
var use_fade := false
const WATER_LEVEL := -2.4

var terrain: MudTerrain
var stats := {}  # növ -> nümunə sayı

var _rng := RandomNumberGenerator.new()
var _assets := {}      # asset id -> {variant: [lod mesh-ləri]}
var _inst := {}        # "növ|variant|cx|cz" -> Array[Transform3D]
var _tree_cells := {}  # məkan heş-i: hüceyrə -> Array[Vector3(x, z, radius)]
var _colliders: StaticBody3D
var _n_forest := FastNoiseLite.new()
var _n_species := FastNoiseLite.new()
var _n_floor := FastNoiseLite.new()
var _n_moist := FastNoiseLite.new()
var _big_trees: Array = []  # [pos, növ, miqyas]


func build(t: MudTerrain, seed_value: int) -> void:
	terrain = t
	_rng.seed = seed_value
	_setup_noise(seed_value)
	_load_assets()
	_colliders = StaticBody3D.new()
	_colliders.name = "TreeColliders"
	add_child(_colliders)
	_place_trees()
	_place_understory()
	_place_riverbank()
	_place_wood()
	_place_grass()
	_build_nodes()
	var total := 0
	for k in stats:
		total += int(stats[k])
	stats["_cəmi"] = total
	print("VEGETATION nümunə sayı: ", stats)


## Fəsil rəngi: bütün foliage (alfa kart) materiallarına vurulur. Qış qar örtüyü üçün ayrıca shader parametri əlavə olunacaq.
func apply_season_tint(tint: Color) -> void:
	for m in VegetationAssets.cached_materials():
		if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			m.albedo_color = tint


# --- hazırlıq ------------------------------------------------------------------

func _setup_noise(s: int) -> void:
	_n_forest.seed = s + 1
	_n_forest.frequency = 0.011
	_n_forest.fractal_octaves = 3
	_n_species.seed = s + 2
	_n_species.frequency = 0.018
	_n_floor.seed = s + 3
	_n_floor.frequency = 0.05
	_n_moist.seed = s + 4
	_n_moist.frequency = 0.014


func _load_assets() -> void:
	for sp in SPECIES:
		var d: Dictionary = SPECIES[sp]
		var id: String = d["asset"]
		if _assets.has(id):
			continue
		var loaded := VegetationAssets.load_species(id, d["foliage"])
		if loaded.is_empty():
			push_warning("Vegetasiya aktivi tapılmadı: " + id)
		_assets[id] = loaded


# --- ölçü funksiyaları -----------------------------------------------------------

func _extent() -> float:
	return (MudTerrain.N - 1) * 0.5 * MudTerrain.CELL - 3.0


func _height(x: float, z: float) -> float:
	var n := MudTerrain.N
	var half := (n - 1) * 0.5
	var gx := clampf(x / MudTerrain.CELL + half, 0.0, n - 1.001)
	var gz := clampf(z / MudTerrain.CELL + half, 0.0, n - 1.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var fx := gx - x0
	var fz := gz - z0
	var h00 := terrain.h[z0 * n + x0]
	var h10 := terrain.h[z0 * n + x0 + 1]
	var h01 := terrain.h[(z0 + 1) * n + x0]
	var h11 := terrain.h[(z0 + 1) * n + x0 + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func _forest(x: float, z: float) -> float:
	return clampf((_n_forest.get_noise_2d(x, z) * 0.5 + 0.5 - 0.32) * 2.4, 0.0, 1.0)


## Rütubət: su səviyyəsinə yaxın hündürlük və ayrıca noise.
func _moist(x: float, z: float, h: float) -> float:
	var near_water := 1.0 - smoothstep(0.0, 5.0, h - WATER_LEVEL)
	var n := _n_moist.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(near_water * 0.8 + n * 0.35, 0.0, 1.0)


func _p3(x: float, z: float) -> Vector3:
	return Vector3(x, _height(x, z), z)


# --- ağaclar -------------------------------------------------------------------

func _tree_ok(x: float, z: float, h: float) -> bool:
	if absf(x) > _extent() or absf(z) > _extent():
		return false
	if h < WATER_LEVEL + 1.0 or h > 17.0:
		return false
	var p := Vector3(x, h, z)
	if terrain.road_distance_fast(p) < MudTerrain.ROAD_HALF + 5.0:
		return false
	if terrain.softness_at(p) > 0.2:
		return false
	if terrain.slope_at(p) > 0.42:
		return false
	return true


func _spacing_ok(x: float, z: float, r: float) -> bool:
	var cx := floori(x / 3.0)
	var cz := floori(z / 3.0)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := Vector2i(cx + dx, cz + dz)
			if not _tree_cells.has(key):
				continue
			for o in _tree_cells[key]:
				var ov: Vector3 = o
				var need := (r + ov.z) * 1.0 + 1.3
				if Vector2(x - ov.x, z - ov.y).length_squared() < need * need:
					return false
	return true


func _register_tree(x: float, z: float, r: float) -> void:
	var key := Vector2i(floori(x / 3.0), floori(z / 3.0))
	if not _tree_cells.has(key):
		_tree_cells[key] = []
	(_tree_cells[key] as Array).append(Vector3(x, z, r))


func _pick_tree(x: float, z: float, h: float) -> String:
	var v := _n_species.get_noise_2d(x, z) * 0.5 + 0.5
	var moist := _moist(x, z, h)
	var w_pine := 1.25 - v
	var w_fir := 0.4 + v
	var w_broad := 0.12 + 0.75 * moist
	var w_sap := 0.30
	if h > 8.0:
		w_fir *= 2.0
		w_broad *= 0.2
	var total := w_pine + w_fir + w_broad + w_sap
	var r := _rng.randf() * total
	if r < w_pine:
		return "pine"
	r -= w_pine
	if r < w_fir:
		return "fir"
	r -= w_fir
	if r < w_broad:
		return "broadleaf"
	return "sapling_m"


func _place_trees() -> void:
	var ext := _extent()
	var centers: Array = []
	var tries := 0
	while centers.size() < 70 and tries < 900:
		tries += 1
		var x := _rng.randf_range(-ext, ext)
		var z := _rng.randf_range(-ext, ext)
		var h := _height(x, z)
		if _forest(x, z) > 0.28 and _tree_ok(x, z, h):
			centers.append(Vector3(x, 0.0, z))
	for c in centers:
		var cv: Vector3 = c
		var radius := _rng.randf_range(10.0, 30.0)
		var count := int(radius * radius * 0.075 * (0.55 + _forest(cv.x, cv.z)))
		for i in count:
			var ang := _rng.randf() * TAU
			var dist := radius * sqrt(_rng.randf()) * (0.45 + 0.55 * _rng.randf())
			_try_tree(cv.x + cos(ang) * dist, cv.z + sin(ang) * dist)
	# tək-tək ağaclar (boşluqlarda seyrək)
	for i in 130:
		var x := _rng.randf_range(-ext, ext)
		var z := _rng.randf_range(-ext, ext)
		if _forest(x, z) > 0.12:
			_try_tree(x, z)


func _try_tree(x: float, z: float) -> void:
	var h := _height(x, z)
	if not _tree_ok(x, z, h):
		return
	var sp := _pick_tree(x, z, h)
	var d: Dictionary = SPECIES[sp]
	var sc := _rng.randf_range(d["scale"][0], d["scale"][1])
	var radius: float = d["trunk_r"] * sc * 4.0  # ağacın tacının yer tutma radiusu (məsafə üçün)
	if not _spacing_ok(x, z, radius * 0.5):
		return
	_register_tree(x, z, radius * 0.5)
	var pos := Vector3(x, h - 0.15, z)
	_add_instance(sp, pos, sc, true)
	_big_trees.append([pos, sp, sc])
	_add_tree_collider(pos, d["trunk_r"] * sc)


# --- alt bitki örtüyü ------------------------------------------------------------

func _under_ok(x: float, z: float, h: float, soft_limit: float) -> bool:
	if absf(x) > _extent() or absf(z) > _extent():
		return false
	if h < WATER_LEVEL + 0.35 or h > 18.0:
		return false
	var p := Vector3(x, h, z)
	if terrain.road_distance_fast(p) < MudTerrain.ROAD_HALF + 2.2:
		return false
	var s := terrain.softness_at(p)
	if s > soft_limit and _rng.randf() < clampf((s - soft_limit) * 2.5, 0.0, 1.0):
		return false  # dərin palçıqda az bitki
	if terrain.slope_at(p) > 0.62:
		return false
	return true


func _place_understory() -> void:
	for t in _big_trees:
		var pos: Vector3 = t[0]
		var n := _rng.randi_range(5, 10)
		for i in n:
			var ang := _rng.randf() * TAU
			var dist := _rng.randf_range(1.5, 8.0)
			var x := pos.x + cos(ang) * dist
			var z := pos.z + sin(ang) * dist
			var h := _height(x, z)
			if not _under_ok(x, z, h, 0.3):
				continue
			var r := _rng.randf()
			var sp := "fern"
			if r > 0.5 and r <= 0.74:
				sp = "shrub"
			elif r > 0.74 and r <= 0.84:
				sp = "shrub4"
			elif r > 0.84:
				sp = "sapling_s"
			_add_instance(sp, Vector3(x, h - 0.05, z), _scale_of(sp), false)


func _place_riverbank() -> void:
	# su səviyyəsinə yaxın nəm sahələrdə qalın ayıqulağı, kol və ot
	var ext := _extent()
	var step := 1.8
	var x := -ext
	while x < ext:
		var z := -ext
		while z < ext:
			var jx := x + _rng.randf_range(-1.0, 1.0)
			var jz := z + _rng.randf_range(-1.0, 1.0)
			var h := _height(jx, jz)
			var m := _moist(jx, jz, h)
			if m > 0.5 and h > WATER_LEVEL + 0.15 and _under_ok(jx, jz, h, 0.75):
				var r := _rng.randf()
				var sp := "fern"
				if r > 0.62:
					sp = "shrub"
				if r > 0.88:
					sp = "shrub4"
				if _rng.randf() < (m - 0.4) * 1.6:
					_add_instance(sp, Vector3(jx, h - 0.05, jz), _scale_of(sp), false)
			z += step
		x += step


# --- ölü ağac və kötüklər ----------------------------------------------------------

func _place_wood() -> void:
	for t in _big_trees:
		if _rng.randf() > 0.1:
			continue
		var pos: Vector3 = t[0]
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(2.5, 6.0)
		var x := pos.x + cos(ang) * dist
		var z := pos.z + sin(ang) * dist
		var h := _height(x, z)
		if not _under_ok(x, z, h, 0.1):
			continue
		var sp := "log" if _rng.randf() < 0.55 else "stump"
		var sc := _scale_of(sp)
		var xf := _add_instance(sp, Vector3(x, h - 0.04, z), sc, false)
		_add_wood_collider(sp, xf)


## Ölü gövdə və kötük üçün toqquşma: mesh-in LOD0 qutusuna görə (miqyas və fırlanma ilə).
func _add_wood_collider(sp: String, xf: Transform3D) -> void:
	var d: Dictionary = SPECIES[sp]
	var lods: Array = (_assets[d["asset"]] as Dictionary).values()[0]
	if lods.is_empty() or lods[0] == null:
		return
	var aabb: AABB = (lods[0] as Mesh).get_aabb()
	var col := CollisionShape3D.new()
	if sp == "stump":
		var cs := CylinderShape3D.new()
		var sx := xf.basis.get_scale()
		cs.radius = maxf(aabb.size.x * sx.x, aabb.size.z * sx.z) * 0.4
		cs.height = aabb.size.y * sx.y
		col.shape = cs
		col.transform = Transform3D(Basis(), xf * aabb.get_center())
	else:
		var bs := BoxShape3D.new()
		var sx := xf.basis.get_scale()
		bs.size = Vector3(aabb.size.x * sx.x, aabb.size.y * sx.y, aabb.size.z * sx.z) * 0.9
		col.shape = bs
		col.transform = Transform3D(xf.basis.orthonormalized(), xf * aabb.get_center())
	_colliders.add_child(col)


# --- ot -----------------------------------------------------------------------------

func _place_grass() -> void:
	var ext := _extent()
	var cell := 0.95
	var x := -ext
	while x < ext:
		var z := -ext
		while z < ext:
			var jx := x + _rng.randf_range(0.0, cell)
			var jz := z + _rng.randf_range(0.0, cell)
			var h := _height(jx, jz)
			var p := Vector3(jx, h, jz)
			if h > WATER_LEVEL + 0.25 and h < 16.0 and terrain.road_distance_fast(p) > MudTerrain.ROAD_HALF + 0.9:
				var s := terrain.softness_at(p)
				var slope := terrain.slope_at(p)
				var floor_n := _n_floor.get_noise_2d(jx, jz) * 0.5 + 0.5
				var dens := 0.30 + 0.55 * _forest(jx, jz) * floor_n + 0.4 * _moist(jx, jz, h) - s * 1.2 - slope * 0.5
				if _rng.randf() < dens and slope < 0.8:
					var sp := "grass_b" if _rng.randf() < 0.6 else "grass_m"
					_add_instance(sp, Vector3(jx, h - 0.02, jz), _scale_of(sp), false)
			z += cell
		x += cell


# --- ümumi köməkçilər ---------------------------------------------------------------

func _scale_of(sp: String) -> float:
	var d: Dictionary = SPECIES[sp]
	return _rng.randf_range(d["scale"][0], d["scale"][1])


func _add_instance(sp: String, pos: Vector3, sc: float, tilt_small: bool) -> Transform3D:
	var d: Dictionary = SPECIES[sp]
	var variants: Array = (_assets[d["asset"]] as Dictionary).keys()
	if variants.is_empty():
		return Transform3D(Basis.IDENTITY, pos)
	variants.sort()
	var variant: String = variants[_rng.randi() % variants.size()]
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	if tilt_small:
		basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.03, 0.03)) * basis
	elif d["kind"] == "under" or d["kind"] == "ground":
		basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)) * basis
	basis = basis.scaled(Vector3(sc, sc * _rng.randf_range(0.9, 1.15), sc))
	var cs: float = CHUNK_SIZE[d["kind"]]
	var key := "%s|%s|%d|%d" % [sp, variant, floori(pos.x / cs), floori(pos.z / cs)]
	if not _inst.has(key):
		_inst[key] = []
	var xf := Transform3D(basis, pos)
	(_inst[key] as Array).append(xf)
	stats[sp] = int(stats.get(sp, 0)) + 1
	return xf


func _add_tree_collider(pos: Vector3, radius: float) -> void:
	var cs := CylinderShape3D.new()
	cs.radius = maxf(radius, 0.15)
	cs.height = 5.0
	var col := CollisionShape3D.new()
	col.shape = cs
	col.position = pos + Vector3(0, 2.5, 0)
	_colliders.add_child(col)


# --- render -------------------------------------------------------------------------

func _build_nodes() -> void:
	for key in _inst:
		var parts: PackedStringArray = (key as String).split("|")
		var sp := parts[0]
		var variant := parts[1]
		var d: Dictionary = SPECIES[sp]
		var lods: Array = (_assets[d["asset"]] as Dictionary)[variant]
		var xforms: Array = _inst[key]
		for l in lods.size():
			if lods[l] == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = lods[l]
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_c%s_lod%d" % [sp, variant, (parts[2] + "_" + parts[3]).replace("-", "m"), l]
			mmi.multimesh = mm
			var rng: Array = (d["lod"] as Array)[mini(l, (d["lod"] as Array).size() - 1)]
			mmi.visibility_range_begin = float(rng[0])
			mmi.visibility_range_end = float(rng[1])
			mmi.visibility_range_begin_margin = FADE_MARGIN if rng[0] > 0 else 0.0
			mmi.visibility_range_end_margin = FADE_MARGIN
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if use_fade else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
		# kölgə proxy-si: LOD0 özü kölgə salmır (bahalıdır), əvəzinə LOD1 mesh-i yalnız kölgə üçün çəkilir
		if int(d["shadow_lods"]) > 0 and lods.size() > 1 and lods[1] != null:
			var sm := MultiMesh.new()
			sm.transform_format = MultiMesh.TRANSFORM_3D
			sm.mesh = lods[1]
			sm.instance_count = xforms.size()
			for i in xforms.size():
				sm.set_instance_transform(i, xforms[i])
			var shadow := MultiMeshInstance3D.new()
			shadow.name = "%s_%s_c%s_shadow" % [sp, variant, (parts[2] + "_" + parts[3]).replace("-", "m")]
			shadow.multimesh = sm
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shadow.visibility_range_end = SHADOW_RANGE
			shadow.visibility_range_end_margin = FADE_MARGIN
			add_child(shadow)
