class_name MapLayout
extends RefCounted
## "Offroad Azərbaycan" xəritəsinin planı (2048 x 2048 m, x şərq, z cənub; GPS-də şimal = -z).
## Şimalda qarlı dağlar, şimal-mərkəzdə göl, göldən cənub-şərqə şəlaləli çay, şimal-şərqdə qaya kanyonu,
## şərqdə açıq mədən, mərkəzdə şəhər, qərbdə meşə zonası və palçıq bataqlığı, cənubda başlanğıc qarajı.
## Relyef, yollar, su və bölgə maskaları buradadır; MudTerrain onları istifadə edir.

# --- su ---------------------------------------------------------------------------------------
const LAKE_CENTER := Vector2(0, -650)
const LAKE_RADII := Vector2(235, 118)
const LAKE_LEVEL := 9.0
## Çay gölün şərq ucundan başlayır; hər nöqtədə su səviyyəsi (2→3 və 8→9 arası şəlalə)
const RIVER := [Vector2(215, -640), Vector2(250, -470), Vector2(290, -330), Vector2(305, -180), Vector2(320, -20),
	Vector2(345, 140), Vector2(405, 300), Vector2(500, 450), Vector2(590, 590), Vector2(680, 750),
	Vector2(760, 900), Vector2(820, 1040)]
const RIVER_LEVEL := [9.0, 8.6, 8.2, 5.0, 4.7, 4.4, 4.1, 3.8, 3.5, -1.0, -1.3, -1.6]
const RIVER_HALF := 9.0
## Kanyon çayı: kanyonun dibi ilə axıb əsas çaya qoşulur
const CREEK := [Vector2(930, -650), Vector2(810, -480), Vector2(660, -300), Vector2(490, -120), Vector2(330, -40)]
const CREEK_LEVEL := [30.0, 24.0, 16.0, 9.0, 4.7]
const CREEK_HALF := 5.0
## Şəlalələr: su səviyyəsinin kəskin düşdüyü yerlər (seqmentin 87%-i)
const WATERFALLS := [Vector2(303, -199), Vector2(668, 729), Vector2(826, -502), Vector2(680, -323), Vector2(512, -143), Vector2(351, -50)]

# --- bölgələr -----------------------------------------------------------------------------------
const TOWN := Vector2(40, 10)
const TOWN_RADII := Vector2(230, 165)
const TOWN_H := 12.0
const START := Vector2(-200, 560)
const START_RADII := Vector2(150, 95)
const START_H := 10.0
const MINE := Vector2(690, 110)
const MINE_R := 190.0
const MINE_DEPTH := 36.0
const CANYON := Rect2(540, -720, 490, 680)
const CANYON_H := 40.0
const SWAMP := Vector2(-480, 170)
const SWAMP_RADII := Vector2(250, 190)
const SWAMP_H := 7.0
const FOREST := Rect2(-700, -580, 640, 500)
const FOREST_PEAK := Vector2(540, 420) + Vector2(-880, -620)  # HillClimbCatalog.OFFSET ilə eyni

## Asfalt yollar (hər biri ayrıca xətt): əsas şimal-cənub yolu, şəhər-mədən, cənub yolu, kanyon yolu, şəhər küçələri
const ROADS := [
	[Vector2(-200, 560), Vector2(-60, 540), Vector2(40, 420), Vector2(60, 230), Vector2(40, 40), Vector2(10, -150),
		Vector2(-40, -320), Vector2(-100, -470), Vector2(40, -505), Vector2(240, -515), Vector2(400, -600),
		Vector2(480, -720), Vector2(430, -830), Vector2(520, -920), Vector2(500, -1000)],
	[Vector2(40, 40), Vector2(200, 50), Vector2(330, 70), Vector2(460, 90), Vector2(505, 100)],
	[Vector2(-60, 540), Vector2(150, 640), Vector2(380, 700), Vector2(560, 700), Vector2(700, 760), Vector2(900, 820)],
	[Vector2(505, 100), Vector2(560, -40), Vector2(620, -200), Vector2(720, -330), Vector2(820, -430)],
	[Vector2(-120, -60), Vector2(200, -60)],
	[Vector2(-120, 90), Vector2(200, 90)],
	[Vector2(-90, -130), Vector2(-90, 150)],
	[Vector2(130, -130), Vector2(130, 150)],
]
## Palçıq cığırları (bataqlıq dövrəsi, başlanğıcdan bataqlığa, meşə, kanyon, cənub-şərq meşəsi)
const TRAILS := [
	[Vector2(-650, 30), Vector2(-420, 40), Vector2(-300, 200), Vector2(-420, 340), Vector2(-620, 300), Vector2(-650, 30)],
	[Vector2(-330, 520), Vector2(-420, 400), Vector2(-480, 300)],
	[Vector2(-60, -180), Vector2(-200, -120), Vector2(-420, -120), Vector2(-660, -160), Vector2(-700, -400),
		Vector2(-600, -560), Vector2(-300, -540), Vector2(-160, -470)],
	[Vector2(600, -560), Vector2(700, -640), Vector2(860, -600), Vector2(940, -450)],
	[Vector2(560, 820), Vector2(700, 920), Vector2(860, 960)],
]
## Bataqlıq gölməçələri (x, z, radius)
const PONDS := [Vector3(-560, 110, 40), Vector3(-430, 200, 50), Vector3(-540, 270, 35), Vector3(-360, 110, 30)]

## GPS və lövhələr: [ad, mövqe]
const PLACES := [
	["Başlanğıc qarajı", Vector2(-200, 560)],
	["Şəhər", Vector2(40, 10)],
	["Göl", Vector2(0, -650)],
	["Dağ keçidi", Vector2(480, -760)],
	["Qaya kanyonu", Vector2(800, -520)],
	["Mədən", Vector2(690, 110)],
	["Meşə zonası", Vector2(-450, -330)],
	["Palçıq bataqlığı", Vector2(-480, 170)],
]


static func _ellipse(p: Vector2, c: Vector2, r: Vector2) -> float:
	var d := (p - c) / r
	return d.length()


## Bölgələrin əsas relyefi (yollar və çay kəsiyi olmadan): yolun hündürlük profili bundan hesablanır.
static func base_height(hills: FastNoiseLite, big: FastNoiseLite, ridge_n: FastNoiseLite, wx: float, wz: float) -> float:
	var p := Vector2(wx, wz)
	var ridge := ridge_n.get_noise_2d(wx, wz) * 0.5 + 0.5
	var h := 10.0 + hills.get_noise_2d(wx, wz) * 3.0 + big.get_noise_2d(wx, wz) * 4.0
	# şimal silsiləsi (qarlı zirvələr)
	var north := smoothstep(-480.0, -960.0, wz)
	h += north * north * (55.0 + ridge * 120.0) + north * 25.0 * ridge
	# xəritə kənarında dağ halqası; cənub-qərb küncündə qarlı massiv
	var edge := smoothstep(860.0, 1024.0, maxf(absf(wx), absf(wz)))
	h += edge * (30.0 + ridge * 60.0)
	h += exp(-p.distance_squared_to(Vector2(-880, 880)) / 90000.0) * 150.0
	# meşə zonasının dağı (Hill Climb parkı onun qərb yamacındadır)
	# şəhərə və bataqlığa doğru sönür ki, onların kənarında qaya divarı yaranmasın; zirvə qar xəttindən aşağıda
	var peak_mask := smoothstep(1.15, 2.1, _ellipse(p, TOWN, TOWN_RADII)) * smoothstep(1.05, 1.9, _ellipse(p, SWAMP, SWAMP_RADII))
	h += exp(-p.distance_squared_to(FOREST_PEAK) / 120000.0) * 110.0 * peak_mask
	# qaya kanyonu: hündür yayla
	var cx := smoothstep(CANYON.position.x, CANYON.position.x + 80.0, wx) * (1.0 - smoothstep(CANYON.end.x - 40.0, CANYON.end.x + 40.0, wx))
	var cz := smoothstep(CANYON.position.y - 40.0, CANYON.position.y + 40.0, wz) * (1.0 - smoothstep(CANYON.end.y - 80.0, CANYON.end.y, wz))
	h = lerpf(h, maxf(h, CANYON_H + ridge * 12.0), cx * cz)
	# göl çökəkliyi
	var le := _ellipse(p, LAKE_CENTER, LAKE_RADII)
	h = lerpf(h, LAKE_LEVEL - 6.0 + le * 4.0, 1.0 - smoothstep(0.85, 1.25, le))
	# düz sahələr: şəhər, başlanğıc qarajı, bataqlıq
	h = lerpf(h, TOWN_H, 1.0 - smoothstep(0.85, 1.15, _ellipse(p, TOWN, TOWN_RADII)))
	h = lerpf(h, START_H, 1.0 - smoothstep(0.85, 1.2, _ellipse(p, START, START_RADII)))
	h = lerpf(h, SWAMP_H + hills.get_noise_2d(wx, wz) * 1.2, 1.0 - smoothstep(0.8, 1.15, _ellipse(p, SWAMP, SWAMP_RADII)))
	# açıq mədən: pilləli çuxur
	var r := p.distance_to(MINE)
	if r < MINE_R + 30.0:
		var rim := 1.0 - smoothstep(MINE_R, MINE_R + 30.0, r)
		h = lerpf(h, 12.0, rim)
		if r < MINE_R:
			var depth := MINE_DEPTH * pow(clampf(1.0 - r / MINE_R, 0.0, 1.0), 0.75)
			var step := 6.0
			var bench := floorf(depth / step) * step + step * smoothstep(0.7, 1.0, fposmod(depth, step) / step)
			h = 12.0 - bench
	return h


## Çay və kanyon kəsiyi: verilmiş hündürlüyü su yatağına endirir (yalnız aşağı salır).
static func carve(h: float, river_d: float, river_level: float, creek_d: float, creek_level: float) -> float:
	if river_d < RIVER_HALF + 14.0:
		var bed := lerpf(river_level - 2.5, river_level + 1.2, smoothstep(RIVER_HALF * 0.6, RIVER_HALF + 12.0, river_d))
		h = minf(h, bed)
	if creek_d < CREEK_HALF + 34.0:
		# kanyon divarları: dar, dik yataq
		var bed2 := lerpf(creek_level - 2.0, creek_level + 40.0, smoothstep(CREEK_HALF * 0.6, CREEK_HALF + 30.0, creek_d))
		h = minf(h, bed2)
	return h


## Meşə sıxlığı çarpanı: meşə zonasında sıx, şəhər/başlanğıc/mədən/göl/bataqlıqda yox.
## Çılpaq torpaq/daş örtüyü (0..1): mədən, kanyon. Ot əvəzinə torpaq və çınqıl qatları.
static func bare_ground(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var dirt := 1.0 - smoothstep(MINE_R - 10.0, MINE_R + 35.0, p.distance_to(MINE))
	var cobble := dirt * 0.55
	if CANYON.grow(-30.0).has_point(p):
		dirt = maxf(dirt, 0.75)
		cobble = maxf(cobble, 0.25)
	return Vector2(dirt, cobble)


static func forest_factor(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if _ellipse(p, TOWN, TOWN_RADII) < 1.15 or _ellipse(p, START, START_RADII) < 1.2:
		return 0.0
	if p.distance_to(MINE) < MINE_R + 25.0 or _ellipse(p, LAKE_CENTER, LAKE_RADII) < 1.05:
		return 0.0
	var f := 1.0
	if FOREST.grow(-30.0).has_point(p):
		f = 1.7
	if _ellipse(p, SWAMP, SWAMP_RADII) < 1.0:
		f = 0.35
	if CANYON.has_point(p):
		f = 0.25
	return f
