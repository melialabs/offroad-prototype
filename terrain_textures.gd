class_name TerrainTextures
extends RefCounted
## Poly Haven CC0 teksturalarından (assets/tex/terrain/) dörd Texture2DArray qurur:
## albedo, normal (OpenGL), height, roughness. Sıra terrain.gdshader-dəki layer indeksləri ilə eynidir.

const DIR := "res://assets/tex/terrain/"
const SIZE := 1024

## id: Poly Haven adı, tile: bir təkrarın metrlə ölçüsü.
const LAYERS := [
	{"id": "rocks_ground_08", "tile": 2.5},        # 0 torpaq yol
	{"id": "brown_mud_02", "tile": 2.0},           # 1 palçıq
	{"id": "brown_mud_03", "tile": 2.0},           # 2 dərin palçıq
	{"id": "ganges_river_pebbles", "tile": 2.0},   # 3 daşlı səth
	{"id": "rocky_terrain_02", "tile": 3.0},       # 4 ot (yosunlu daşlı torpaq)
	{"id": "snow_02", "tile": 3.0},                # 5 qar
	{"id": "rock_ground", "tile": 5.0},            # 6 qaya yamac
]


## İstinad lövhəsinin palitrasına uyğun isti-soyuq ton düzəlişi (layer sırası ilə).
const TINTS := [
	Vector3(1.18, 0.98, 0.80),  # 0 torpaq yol
	Vector3(1.40, 1.00, 0.76),  # 1 palçıq
	Vector3(1.30, 0.95, 0.74),  # 2 dərin palçıq
	Vector3(1.05, 1.00, 0.95),  # 3 daş
	Vector3(1.00, 1.00, 1.00),  # 4 ot
	Vector3(1.00, 1.00, 1.03),  # 5 qar
	Vector3(1.00, 0.97, 0.93),  # 6 qaya
]


static func tints() -> PackedVector3Array:
	return PackedVector3Array(TINTS)


static func tiles() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for l in LAYERS:
		out.append(float(l["tile"]))
	return out


## {albedo, normal, height, rough: Texture2DArray}. Fayl tapılmasa boş lüğət qaytarır.
static func build() -> Dictionary:
	var sets := {"albedo": [], "normal": [], "height": [], "rough": []}
	for l in LAYERS:
		var id: String = l["id"]
		var maps := {
			"albedo": [id + "_diff_1k.jpg", Image.FORMAT_RGB8],
			"normal": [id + "_nor_gl_1k.jpg", Image.FORMAT_RGB8],
			"height": [id + "_disp_1k.jpg", Image.FORMAT_L8],
			"rough": [id + "_rough_1k.jpg", Image.FORMAT_L8],
		}
		for key in maps:
			var img := _load_image(DIR + maps[key][0], maps[key][1])
			if img == null:
				push_warning("Tekstura tapılmadı: " + DIR + maps[key][0])
				return {}
			sets[key].append(img)
	var out := {}
	for key in sets:
		var arr := Texture2DArray.new()
		var imgs: Array[Image] = []
		for im in sets[key]:
			imgs.append(im)
		if arr.create_from_images(imgs) != OK:
			push_warning("Texture2DArray yaradıla bilmədi: " + key)
			return {}
		out[key] = arr
	return out


static func _load_image(path: String, format: Image.Format) -> Image:
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_width() != SIZE or img.get_height() != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img.convert(format)
	img.generate_mipmaps()
	return img
