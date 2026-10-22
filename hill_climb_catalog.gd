class_name HillClimbCatalog
extends RefCounted
## Original authored courses on the western face of the existing eastern mountain.
const ZONE := Rect2(240, 155, 365, 285)
const DIFFICULTIES := ["Easy", "Medium", "Hard", "Extreme"]
const COLORS := [Color(0.3, 0.88, 0.64), Color(0.98, 0.78, 0.26), Color(1, 0.48, 0.20), Color(0.98, 0.25, 0.29)]
const DEFINITIONS := [
	["forest_ascent", "01 · Forest Ascent", 0, 5.5, 0.18, 65.0, [Vector2(270,190),Vector2(290,215),Vector2(320,235),Vector2(350,260),Vector2(390,280),Vector2(420,310),Vector2(440,335)]],
	["fern_ridge", "02 · Fern Ridge", 0, 5.0, 0.25, 70.0, [Vector2(270,220),Vector2(290,245),Vector2(300,275),Vector2(330,295),Vector2(365,310),Vector2(400,325),Vector2(430,345)]],
	["panorama_loop", "03 · Panorama Loop", 0, 5.0, 0.20, 75.0, [Vector2(265,255),Vector2(280,285),Vector2(295,320),Vector2(320,350),Vector2(350,365),Vector2(390,372),Vector2(425,365)]],
	["rock_garden", "04 · Rock Garden", 1, 4.2, 0.38, 80.0, [Vector2(315,180),Vector2(335,205),Vector2(355,230),Vector2(370,258),Vector2(390,275),Vector2(405,300),Vector2(430,320),Vector2(455,350)]],
	["serpent", "05 · Serpent's Ladder", 1, 3.8, 0.40, 100.0, [Vector2(355,180),Vector2(360,220),Vector2(340,245),Vector2(375,265),Vector2(355,285),Vector2(395,308),Vector2(430,335),Vector2(455,360)]],
	["water_cut", "06 · Water Cut", 1, 4.0, 0.72, 95.0, [Vector2(400,175),Vector2(420,205),Vector2(450,225),Vector2(430,245),Vector2(465,270),Vector2(450,295),Vector2(475,325),Vector2(480,355)]],
	["bog_spine", "07 · Bog Spine", 2, 3.6, 0.93, 110.0, [Vector2(445,175),Vector2(455,205),Vector2(470,230),Vector2(455,255),Vector2(480,280),Vector2(470,310),Vector2(492,350),Vector2(492,382)]],
	["cliff_balcony", "08 · Cliff Balcony", 2, 1.9, 0.36, 105.0, [Vector2(490,180),Vector2(505,210),Vector2(515,240),Vector2(535,260),Vector2(520,285),Vector2(535,310),Vector2(515,335),Vector2(492,382)]],
	["boulder_steps", "09 · Boulder Steps", 2, 3.6, 0.42, 115.0, [Vector2(535,190),Vector2(550,220),Vector2(570,250),Vector2(548,270),Vector2(565,295),Vector2(545,325),Vector2(520,350),Vector2(492,382)]],
	["summit_wall", "10 · Summit Wall", 3, 3.0, 0.64, 100.0, [Vector2(575,210),Vector2(570,240),Vector2(555,270),Vector2(530,290),Vector2(510,310),Vector2(492,335),Vector2(492,382)]],
	["razor_hairpins", "11 · Razor Hairpins", 3, 1.7, 0.50, 120.0, [Vector2(580,250),Vector2(570,280),Vector2(580,310),Vector2(550,340),Vector2(560,365),Vector2(530,395),Vector2(492,382)]],
	["last_grip", "12 · Last Grip", 3, 1.8, 0.96, 90.0, [Vector2(575,295),Vector2(560,325),Vector2(540,345),Vector2(520,360),Vector2(492,382)]],
]

static func courses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in DEFINITIONS:
		result.append({"id": row[0], "name": row[1], "difficulty": row[2], "half_width": row[3], "mud": row[4], "gold": row[5], "points": PackedVector2Array(row[6]), "enabled": true})
	# Optional bypasses reunite before the next ordered checkpoint. They exchange
	# distance for a gentler turn or a way around the largest boulder.
	result[3]["alternative"] = PackedVector2Array([Vector2(370,258),Vector2(381,255),Vector2(391,263),Vector2(390,275)])
	result[8]["alternative"] = PackedVector2Array([Vector2(548,270),Vector2(551,283),Vector2(558,296),Vector2(565,295)])
	return result

static func checkpoint_path(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		var count := maxi(1, ceili(points[i].distance_to(points[i + 1]) / 18.0))
		for k in range(1, count + 1):
			out.append(points[i].lerp(points[i + 1], float(k) / count))
	return out
