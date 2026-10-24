class_name WorldMap
extends Control
## GPS: aşağı solda dairəvi, maşına görə fırlanan (istiqamət yuxarı) premium mini-xəritə;
## M düyməsi bütün xəritəni (şimal yuxarı) açır. Xəritə şəkli bir dəfə relyefdən bişirilir:
## hündürlük kölgəsi, biomlar (ot, meşə, qaya, qar, palçıq, kanyon), göl/çay, yollar, cığırlar, şəhər.

var barns: BarnFinds
var activities: HillClimbActivity
var terrain: MudTerrain
var truck: OffroadTruck
var features: MapFeatures
var main_node: Node
var opened := false
## Naviqasiya hədəfi: WorldLandmarks.PLACES indeksi (-1 = yoxdur). J dövr edir, böyük xəritədə 1–8 seçir.
var target := -1
## Yol şəbəkəsi ilə marşrut (dünya xz nöqtələri) və uzunluğu (m)
var route := PackedVector2Array()
var route_length := 0.0
var _route_t := 0.0
var _adj: Array = []

const MAP_PX := 512
const WORLD := 2048.0
## Mini-xəritədə görünən sahə (dünyanın hissəsi, diametr üzrə): yavaşda yaxın, sürətdə uzaq
const SPAN_NEAR := 0.17
const SPAN_FAR := 0.32

var map_texture: ImageTexture
var _mini: ColorRect
var _mini_mat: ShaderMaterial
var _span := SPAN_NEAR
var _angle := 0.0
var _fuel: Array[Vector2] = []
var _bridges: Array[Vector2] = []
var _pulse := 0.0

const MINI_SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : source_color, filter_linear_mipmap;
uniform vec2 center_uv = vec2(0.5);
uniform float span = 0.2;
uniform float angle = 0.0;
uniform float night = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > 0.5) { discard; }
	vec2 q = vec2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
	vec2 uv = center_uv + q * span;
	vec4 t = texture(map_tex, uv);
	vec3 c = t.rgb;
	// su (alfa < 1): yavaş axan parıltı
	if (t.a < 0.99) {
		float w = sin(uv.x * 900.0 + uv.y * 600.0 + TIME * 1.6) * sin(uv.y * 700.0 - TIME * 1.1);
		c += vec3(0.05, 0.08, 0.1) * smoothstep(0.55, 1.0, w);
	}
	c *= mix(1.0, 0.62, night);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { c = vec3(0.04, 0.06, 0.06); }
	// içəri kölgə və şüşə parıltısı
	c *= mix(0.42, 1.0, smoothstep(0.5, 0.36, r));
	c += vec3(0.10) * smoothstep(0.25, 0.0, length(p - vec2(-0.16, -0.2))) * 0.6;
	// qızılı kənar halqa
	float ring = smoothstep(0.5, 0.49, r) * smoothstep(0.465, 0.478, r);
	c = mix(c, vec3(0.92, 0.78, 0.42), ring);
	float inner = smoothstep(0.466, 0.462, r) * smoothstep(0.455, 0.46, r);
	c = mix(c, vec3(0.05, 0.05, 0.04), inner * 0.8);
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mini = ColorRect.new()
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_mat = ShaderMaterial.new()
	_mini_mat.shader = Shader.new()
	_mini_mat.shader.code = MINI_SHADER
	_mini.material = _mini_mat
	_mini.show_behind_parent = true
	add_child(_mini)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_M:
		opened = not opened
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_J:
		set_target(target + 1 if target + 1 < WorldLandmarks.PLACES.size() else -1)
		get_viewport().set_input_as_handled()


## Böyük xəritə açıqkən 1–8 hədəf seçir (maşın seçimi düymələrindən əvvəl tutulur), 0 hədəfi silir.
func _input(event: InputEvent) -> void:
	if not visible or not opened or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < WorldLandmarks.PLACES.size():
		set_target(k - KEY_1)
		get_viewport().set_input_as_handled()
	elif k == KEY_0:
		set_target(-1)
		get_viewport().set_input_as_handled()


func set_target(index: int) -> void:
	target = index
	route.clear()
	route_length = 0.0
	_route_t = 0.0
	if truck != null and target >= 0:
		truck.message.emit("GPS hədəfi: " + str(WorldLandmarks.PLACES[target][0]))
	elif truck != null:
		truck.message.emit("GPS hədəfi silindi")


func _process(delta: float) -> void:
	if terrain == null or truck == null:
		return
	if map_texture == null:
		bake()
	_pulse += delta
	var speed := truck.linear_velocity.length()
	_span = lerpf(_span, lerpf(SPAN_NEAR, SPAN_FAR, clampf(speed / 30.0, 0.0, 1.0)), 1.0 - exp(-1.5 * delta))
	var h := Vector2(truck.global_basis.z.x, truck.global_basis.z.z)
	if h.length() > 0.01:
		h = h.normalized()
		_angle = lerp_angle(_angle, atan2(h.x, -h.y), 1.0 - exp(-8.0 * delta))
	var rect := _mini_rect()
	_mini.visible = not opened
	_mini.position = rect.position
	_mini.size = rect.size
	_mini_mat.set_shader_parameter("map_tex", map_texture)
	_mini_mat.set_shader_parameter("center_uv", _uv(Vector2(truck.global_position.x, truck.global_position.z)))
	_mini_mat.set_shader_parameter("span", _span)
	_mini_mat.set_shader_parameter("angle", _angle)
	_mini_mat.set_shader_parameter("night", 1.0 if main_node != null and main_node.get("night") == true else 0.0)
	_route_t -= delta
	if target >= 0 and _route_t <= 0.0:
		_route_t = 0.5
		_compute_route()
	queue_redraw()


func _scale_ui() -> float:
	return clampf(get_viewport_rect().size.y / 900.0, 0.7, 1.5)


func _mini_rect() -> Rect2:
	var s := _scale_ui()
	var d := 214.0 * s
	var vp := get_viewport_rect().size
	return Rect2(Vector2(18.0 * s, vp.y - d - 100.0 * s), Vector2(d, d))


static func _uv(w: Vector2) -> Vector2:
	return (w + Vector2.ONE * WORLD * 0.5) / WORLD


# --- xəritə şəklini bişirmək -------------------------------------------------------------------------

func bake() -> void:
	var n := MudTerrain.N
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.6, 0.75, -0.5).normalized()
	for z in MAP_PX:
		for x in MAP_PX:
			var gx := mini(x * (n - 1) / MAP_PX, n - 2)
			var gz := mini(z * (n - 1) / MAP_PX, n - 2)
			var i := gz * n + gx
			var hgt: float = terrain.h[i]
			var dx: float = terrain.h[i + 1] - hgt
			var dz: float = terrain.h[i + n] - hgt
			var normal := Vector3(-dx, MudTerrain.CELL, -dz).normalized()
			var slope := 1.0 - normal.y
			var wx := (gx - (n - 1) * 0.5) * MudTerrain.CELL
			var wz := (gz - (n - 1) * 0.5) * MudTerrain.CELL
			var p := Vector2(wx, wz)
			var col := Color(0.34, 0.47, 0.24)
			if MapLayout.FOREST.has_point(p):
				col = Color(0.20, 0.36, 0.18)
			if MapLayout.CANYON.has_point(p):
				col = col.lerp(Color(0.74, 0.55, 0.34), 0.85)
			col = col.lerp(Color(0.52, 0.49, 0.43), clampf((hgt - 40.0) / 70.0, 0.0, 1.0))
			col = col.lerp(Color(0.48, 0.45, 0.40), clampf(slope * 2.4, 0.0, 0.8))
			col = col.lerp(Color(0.38, 0.27, 0.16), clampf(float(terrain.soft[i]) * 0.85, 0.0, 0.85))
			col = col.lerp(Color(0.93, 0.95, 0.98), smoothstep(115.0, 140.0, hgt))
			if p.distance_to(MapLayout.MINE) < MapLayout.MINE_R * 0.75:
				col = col.lerp(Color(0.55, 0.50, 0.44), 0.5)
			if MapLayout._ellipse(p, MapLayout.TOWN, MapLayout.TOWN_RADII) < 0.92:
				var block := (int(floor(wx / 26.0)) + int(floor(wz / 26.0))) % 2 == 0
				col = Color(0.62, 0.60, 0.56) if block else Color(0.55, 0.53, 0.50)
			var shade := clampf(normal.dot(light) * 1.25, 0.45, 1.15)
			# 10 m-lik hündürlük xətləri (topoqrafik xəritə kimi)
			var band := floorf(hgt / 10.0)
			if band != floorf(float(terrain.h[i + 1]) / 10.0) or band != floorf(float(terrain.h[i + n]) / 10.0):
				shade *= 0.82
			img.set_pixel(x, z, Color(col.r * shade, col.g * shade, col.b * shade, 1.0))
	# göl
	for z in MAP_PX:
		for x in MAP_PX:
			var w := Vector2(x, z) / MAP_PX * WORLD - Vector2.ONE * WORLD * 0.5
			var e := MapLayout._ellipse(w, MapLayout.LAKE_CENTER, MapLayout.LAKE_RADII)
			if e < 1.0:
				var wc := Color(0.13, 0.36, 0.55).lerp(Color(0.22, 0.52, 0.72), smoothstep(1.0, 0.6, e))
				wc.a = 0.96
				img.set_pixel(x, z, wc)
	_stamp_line(img, terrain._river, terrain._river_gap, MapLayout.RIVER_HALF + 2.0, Color(0.12, 0.34, 0.52, 0.96))
	_stamp_line(img, terrain._river, terrain._river_gap, MapLayout.RIVER_HALF - 1.0, Color(0.22, 0.52, 0.72, 0.96))
	if features != null:
		for fp in features.footprints:
			var c0: Vector2 = (fp[0] as Vector2 + Vector2.ONE * WORLD * 0.5) * (MAP_PX / WORLD)
			var half: Vector2 = (fp[1] as Vector2) * 0.5 * (MAP_PX / WORLD)
			var bcol := Color(0.86, 0.82, 0.74) if fp[2] else Color(0.72, 0.46, 0.38)
			for yy in range(int(c0.y - half.y), int(c0.y + half.y) + 1):
				for xx in range(int(c0.x - half.x), int(c0.x + half.x) + 1):
					if xx >= 0 and yy >= 0 and xx < MAP_PX and yy < MAP_PX:
						img.set_pixel(xx, yy, bcol)
	_stamp_line(img, terrain._trail, terrain._trail_gap, 3.2, Color(0.47, 0.30, 0.15), 3)
	_stamp_line(img, terrain._road, terrain._road_gap, MudTerrain.ROAD_HALF + 3.5, Color(0.08, 0.08, 0.07))
	_stamp_line(img, terrain._road, terrain._road_gap, MudTerrain.ROAD_HALF + 0.5, Color(0.96, 0.88, 0.62))
	img.generate_mipmaps()
	map_texture = ImageTexture.create_from_image(img)
	_build_graph()
	# nişanlar: yanacaq məntəqələri və körpülər
	_fuel.clear()
	for prop in WorldProps.PROPS:
		if str(prop["model"]).contains("gas_station"):
			_fuel.append(prop["p"])
	_bridges.clear()
	var inside := false
	for i in terrain._road.size() - 1:
		var mid := (terrain._road[i] + terrain._road[i + 1]) * 0.5
		var rv: float = terrain._near_route(mid, terrain._river, terrain._river_len, terrain._river_bins)[0]
		var near := rv < MapLayout.RIVER_HALF + 4.0 and terrain._road_gap[i] == 0
		if near and not inside:
			_bridges.append(mid)
		inside = near


## Xətti (çay, yol, cığır) şəklə disklərlə "basır". dash > 0: qırıq xətt.
func _stamp_line(img: Image, line: PackedVector2Array, gaps: PackedByteArray, half_width: float, color: Color, dash := 0) -> void:
	var px_per_m := MAP_PX / WORLD
	var r := maxf(0.6, half_width * px_per_m)
	var step := maxf(0.5, r * 0.6) / px_per_m
	var count := 0
	for i in line.size() - 1:
		if i < gaps.size() and gaps[i] == 1:
			continue
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var k := 0.0
		while k <= length:
			count += 1
			if dash == 0 or (count / dash) % 2 == 0:
				var c := (a.lerp(b, k / maxf(length, 0.001)) + Vector2.ONE * WORLD * 0.5) * px_per_m
				for yy in range(int(c.y - r), int(c.y + r) + 1):
					for xx in range(int(c.x - r), int(c.x + r) + 1):
						if xx >= 0 and yy >= 0 and xx < MAP_PX and yy < MAP_PX and Vector2(xx + 0.5, yy + 0.5).distance_to(c) <= r:
							img.set_pixel(xx, yy, color)
			k += step


# --- çəkiliş ----------------------------------------------------------------------------------------

func _draw() -> void:
	if terrain == null or truck == null or map_texture == null:
		return
	if opened:
		_draw_full()
	else:
		_draw_mini()


## Mini-xəritə: dünya nöqtəsi -> ekran (fırlanmış, maşın mərkəzdə). Kənardan çıxırsa null
## (clamp_edge: halqanın kənarına yapışdırılır ki, uzaq yerlərin istiqaməti görünsün).
func _mini_point(w: Vector2, rect: Rect2, clamp_edge := false) -> Variant:
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var q := (_uv(w) - _uv(me)) / _span
	var p := q.rotated(-_angle)
	if p.length() > 0.44:
		if not clamp_edge:
			return null
		p = p.normalized() * 0.44
	return rect.get_center() + p * rect.size.x


func _draw_mini() -> void:
	var rect := _mini_rect()
	var s := _scale_ui()
	var font := ThemeDB.fallback_font
	var c := rect.get_center()
	var rad := rect.size.x * 0.5
	draw_circle(c + Vector2(0, 3) * s, rad + 4.0 * s, Color(0, 0, 0, 0.35))
	var mp := func(w: Vector2): return _mini_point(w, rect)
	_draw_route(mp, s)
	# kompas halqası: hər 15° cizgi, dörd əsas istiqamət
	var north := Vector2(0, -1).rotated(-_angle)
	for deg in range(0, 360, 15):
		var dir := north.rotated(deg_to_rad(deg))
		var major := deg % 90 == 0
		draw_line(c + dir * (rad - (9.0 if major else 5.0) * s), c + dir * (rad - 1.5 * s), Color(1, 1, 1, 0.75 if major else 0.35), (2.0 if major else 1.0) * s, true)
	var names := ["N", "E", "S", "W"]
	for k in 4:
		var dir := north.rotated(deg_to_rad(90.0 * k))
		var pos := c + dir * (rad + 11.0 * s)
		draw_circle(pos, 9.0 * s, Color(0.03, 0.04, 0.04, 0.85))
		_text_center(names[k], pos + Vector2(0, 5) * s, int(13 * s), Color(1.0, 0.36, 0.25) if k == 0 else Color(0.95, 0.92, 0.85))
	for b in _bridges:
		_bridge_badge(_mini_point(b, rect), s)
	for f in _fuel:
		_fuel_badge(_mini_point(f, rect), s, false)
	if barns != null:
		for site in barns.sites:
			var w: Vector2 = site["rumor"] if not site["found"] else Vector2((site["root"] as Node3D).global_position.x, (site["root"] as Node3D).global_position.z)
			_barn_badge(site, _mini_point(w, rect), s, false)
	if activities != null:
		for i in activities.markers.size():
			if activities.marker_enabled(i):
				var mk: Dictionary = activities.markers[i]
				var mpnt: Vector3 = mk["p"]
				_activity_badge(mk, _mini_point(Vector2(mpnt.x, mpnt.z), rect), s, false)
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var nearest := 0
	var nearest_d := 1e9
	for i in WorldLandmarks.PLACES.size():
		var w2: Vector2 = WorldLandmarks.PLACES[i][1]
		var d := w2.distance_to(me)
		if d < nearest_d:
			nearest_d = d
			nearest = i
		_place_icon(i, _mini_point(w2, rect), s, false)
	# hədəf görünmürsə, halqanın kənarında onun istiqaməti (bayraq)
	if target >= 0 and _mini_point(WorldLandmarks.PLACES[target][1], rect) == null:
		_place_icon(target, _mini_point(WorldLandmarks.PLACES[target][1], rect, true), s, false)
	# maşın: parlayan ox (həmişə yuxarı baxır)
	var glow := 0.5 + 0.5 * sin(_pulse * 3.0)
	draw_circle(c, (11.0 + glow * 3.0) * s, Color(0.2, 0.95, 1.0, 0.18))
	var arrow := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(7, 8) * s, c + Vector2(0, 4) * s, c + Vector2(-7, 8) * s])
	draw_colored_polygon(arrow, Color(0.2, 0.95, 1.0))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), Color(0.02, 0.1, 0.12), 1.5 * s, true)
	# məlumat zolağı: naviqasiya (hədəf varsa) və ya ən yaxın yer
	var strip := Rect2(Vector2(rect.position.x - 2.0 * s, rect.end.y + 16.0 * s), Vector2(rect.size.x + 4.0 * s, 46.0 * s))
	draw_rect(strip, Color(0.02, 0.03, 0.03, 0.82))
	var heading := fposmod(rad_to_deg(_angle), 360.0)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var compass_name: String = dirs[int(round(heading / 45.0)) % 8]
	if target >= 0 and route_length > 0.0:
		draw_rect(Rect2(strip.position, Vector2(3.0 * s, strip.size.y)), Color(0.2, 0.95, 1.0))
		var eta := route_length / maxf(8.0, truck.linear_velocity.length() if truck.linear_velocity.length() > 3.0 else 11.0)
		draw_string(font, strip.position + Vector2(12, 19) * s, "%s  %s · %s" % [_turn_hint(), str(WorldLandmarks.PLACES[target][0]), _dist_text(route_length)], HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 16.0 * s, int(13 * s), Color.WHITE)
		draw_string(font, strip.position + Vector2(12, 38) * s, "~%d dəq   %03d° %s   J: hədəf" % [maxi(1, int(ceil(eta / 60.0))), int(heading), compass_name], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(0.6, 0.9, 0.87))
	else:
		draw_rect(Rect2(strip.position, Vector2(3.0 * s, strip.size.y)), Color(0.92, 0.78, 0.42))
		draw_string(font, strip.position + Vector2(12, 19) * s, "%s  ·  %s" % [WorldLandmarks.PLACES[nearest][0], _dist_text(nearest_d)], HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 16.0 * s, int(14 * s), Color.WHITE)
		draw_string(font, strip.position + Vector2(12, 38) * s, "%03d° %s  ↑ %d m  J: hədəf  M: xəritə" % [int(heading), compass_name, int(truck.global_position.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(0.6, 0.9, 0.87))
	# miqyas: 100 m
	var bar := 100.0 / (WORLD * _span) * rect.size.x
	var bar_at := Vector2(rect.end.x - bar - 6.0 * s, rect.end.y - 8.0 * s)
	draw_line(bar_at, bar_at + Vector2(bar, 0), Color(1, 1, 1, 0.85), 2.0 * s)
	_text_center("100 m", bar_at + Vector2(bar * 0.5, -4.0 * s), int(10 * s), Color(1, 1, 1, 0.85))


func _dist_text(d: float) -> String:
	return "%d m" % int(d) if d < 1000.0 else "%.1f km" % (d / 1000.0)


func _text_center(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- böyük xəritə (M) ------------------------------------------------------------------------------

func _draw_full() -> void:
	var vp := get_viewport_rect().size
	var s := _scale_ui()
	var font := ThemeDB.fallback_font
	var side := minf(vp.y - 120.0 * s, vp.x - 360.0 * s)
	var origin := Vector2(24.0 * s, (vp.y - side) * 0.5)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(origin - Vector2(6, 6) * s, Vector2(side, side) + Vector2(12, 12) * s), Color(0.92, 0.78, 0.42))
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.04, 0.06, 0.07))
	draw_texture_rect(map_texture, Rect2(origin, Vector2(side, side)), false)
	var to_screen := func(w: Vector2) -> Vector2: return origin + _uv(w) * side
	_draw_route(to_screen, s * 1.2)
	for b in _bridges:
		_bridge_badge(to_screen.call(b), s * 1.2)
	for f in _fuel:
		_fuel_badge(to_screen.call(f), s, true)
	if barns != null:
		for site in barns.sites:
			var w: Vector2 = site["rumor"] if not site["found"] else Vector2((site["root"] as Node3D).global_position.x, (site["root"] as Node3D).global_position.z)
			_barn_badge(site, to_screen.call(w), s, true)
	if activities != null:
		for i in activities.markers.size():
			if activities.marker_enabled(i):
				var mk: Dictionary = activities.markers[i]
				var mpnt: Vector3 = mk["p"]
				_activity_badge(mk, to_screen.call(Vector2(mpnt.x, mpnt.z)), s, true)
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var panel_x := origin.x + side + 26.0 * s
	draw_rect(Rect2(Vector2(panel_x - 12.0 * s, origin.y - 6.0 * s), Vector2(320.0 * s, side + 12.0 * s)), Color(0.02, 0.03, 0.03, 0.9))
	draw_string(font, Vector2(panel_x, origin.y + 22.0 * s), "XƏRİTƏ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), Color(0.92, 0.78, 0.42))
	draw_string(font, Vector2(panel_x, origin.y + 42.0 * s), "1–8 hədəf seç · 0 sil · J dövr · M bağla", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), DIM_TEXT)
	for i in WorldLandmarks.PLACES.size():
		var w2: Vector2 = WorldLandmarks.PLACES[i][1]
		var at: Vector2 = to_screen.call(w2)
		_place_icon(i, at, s, true)
		_text_center(str(i + 1), at + Vector2(0, 22.0 * s), int(11 * s), Color.WHITE)
		var row_y := origin.y + (70.0 + i * 30.0) * s
		var selected := i == target
		if selected:
			draw_rect(Rect2(Vector2(panel_x - 6.0 * s, row_y - 18.0 * s), Vector2(300.0 * s, 26.0 * s)), Color(0.2, 0.95, 1.0, 0.16))
		_place_icon(i, Vector2(panel_x + 10.0 * s, row_y - 5.0 * s), s * 0.8, false)
		draw_string(font, Vector2(panel_x + 28.0 * s, row_y), "%d. %s" % [i + 1, WorldLandmarks.PLACES[i][0]], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s), Color(0.2, 0.95, 1.0) if selected else Color.WHITE)
		_text_right(_dist_text(w2.distance_to(me)), Vector2(panel_x + 292.0 * s, row_y), int(13 * s), DIM_TEXT)
	var y2 := origin.y + (70.0 + WorldLandmarks.PLACES.size() * 30.0 + 14.0) * s
	if target >= 0 and route_length > 0.0:
		draw_string(font, Vector2(panel_x, y2), "Marşrut: %s · %s" % [WorldLandmarks.PLACES[target][0], _dist_text(route_length)], HORIZONTAL_ALIGNMENT_LEFT, 300.0 * s, int(14 * s), Color(0.2, 0.95, 1.0))
		y2 += 26.0 * s
	var legend := [["Asfalt yol", Color(0.96, 0.88, 0.62)], ["Palçıq cığırı", Color(0.6, 0.38, 0.18)], ["Göl və çay", Color(0.22, 0.52, 0.72)],
		["Bataqlıq / palçıq", Color(0.38, 0.27, 0.16)], ["Meşə", Color(0.20, 0.36, 0.18)], ["Kanyon", Color(0.74, 0.55, 0.34)], ["Qar", Color(0.93, 0.95, 0.98)]]
	for k in legend.size():
		var col_x := panel_x + (k % 2) * 150.0 * s
		var y := y2 + (k / 2) * 22.0 * s
		draw_rect(Rect2(Vector2(col_x, y - 11.0 * s), Vector2(16, 12) * s), legend[k][1])
		draw_string(font, Vector2(col_x + 22.0 * s, y), legend[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(0.9, 0.9, 0.88))
	# maşın
	var cur: Vector2 = to_screen.call(me)
	var heading := Vector2(truck.global_basis.z.x, truck.global_basis.z.z).normalized()
	var ang := heading.angle() + PI * 0.5
	var arrow := PackedVector2Array([Vector2(0, -12), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)])
	for k in arrow.size():
		arrow[k] = cur + arrow[k].rotated(ang) * s
	draw_circle(cur, (14.0 + 3.0 * sin(_pulse * 3.0)) * s, Color(0.2, 0.95, 1.0, 0.2))
	draw_colored_polygon(arrow, Color(0.2, 0.95, 1.0))
	draw_string(font, Vector2(origin.x, origin.y + side + 22.0 * s), "X %d   Z %d   ·   2 × 2 km" % [me.x, me.y], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(0.6, 0.9, 0.87))


const DIM_TEXT := Color(0.62, 0.68, 0.74)


func _text_right(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- naviqasiya: yol şəbəkəsi qrafı və ən qısa yol --------------------------------------------------

## Qovşaqlar yol nöqtələridir; eyni xətt üzrə qonşular, xətlərin ucları digər xəttin ən yaxın nöqtəsi ilə birləşir.
func _build_graph() -> void:
	var pts := terrain._road
	_adj.clear()
	_adj.resize(pts.size())
	for i in pts.size():
		_adj[i] = []
	for i in pts.size() - 1:
		if terrain._road_gap[i] == 1:
			continue
		var d := pts[i].distance_to(pts[i + 1])
		_adj[i].append([i + 1, d])
		_adj[i + 1].append([i, d])
	for i in pts.size():
		var is_end := i == 0 or i == pts.size() - 1 or terrain._road_gap[i] == 1 or terrain._road_gap[i - 1] == 1
		if not is_end:
			continue
		var best := -1
		var best_d := 18.0
		for j in pts.size():
			if _same_line(i, j):
				continue
			var d2 := pts[i].distance_to(pts[j])
			if d2 < best_d:
				best_d = d2
				best = j
		if best >= 0:
			_adj[i].append([best, best_d])
			_adj[best].append([i, best_d])


func _same_line(a: int, b: int) -> bool:
	for k in range(mini(a, b), maxi(a, b)):
		if terrain._road_gap[k] == 1:
			return false
	return true


func _nearest_node(p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in terrain._road.size():
		var d := terrain._road[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _compute_route() -> void:
	route.clear()
	route_length = 0.0
	if target < 0 or _adj.is_empty():
		return
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var goal: Vector2 = WorldLandmarks.PLACES[target][1]
	var direct := me.distance_to(goal)
	var a := _nearest_node(me)
	var b := _nearest_node(goal)
	var off_a := me.distance_to(terrain._road[a])
	var off_b := goal.distance_to(terrain._road[b])
	var dist := {a: 0.0}
	var prev := {}
	var open: Array = [a]
	while not open.is_empty():
		var best_k := 0
		for k in open.size():
			if float(dist[open[k]]) < float(dist[open[best_k]]):
				best_k = k
		var u: int = open[best_k]
		open.remove_at(best_k)
		if u == b:
			break
		for e in _adj[u]:
			var v: int = e[0]
			var nd: float = float(dist[u]) + float(e[1])
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = u
				if v not in open:
					open.append(v)
	# yol çox dolanırsa və ya şəbəkəyə çatmırsa, düz istiqamət göstərilir (yolsuz sürüş)
	if not dist.has(b) or off_a + float(dist[b]) + off_b > direct * 1.6 + 60.0:
		route = PackedVector2Array([me, goal])
		route_length = direct
		return
	var path: Array = [b]
	while path[-1] != a:
		path.append(prev[path[-1]])
	path.reverse()
	route.append(me)
	for idx in path:
		route.append(terrain._road[idx])
	route.append(goal)
	for k in route.size() - 1:
		route_length += route[k].distance_to(route[k + 1])


## Marşrutda maşından ~45 m irəlidəki nöqtəyə görə dönmə göstərişi.
func _turn_hint() -> String:
	if route.size() < 2:
		return ""
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var acc := 0.0
	var ahead := route[route.size() - 1]
	for k in range(1, route.size()):
		acc += route[k - 1].distance_to(route[k])
		if acc > 45.0:
			ahead = route[k]
			break
	var fwd := Vector2(truck.global_basis.z.x, truck.global_basis.z.z).normalized()
	var ang := rad_to_deg(fwd.angle_to((ahead - me).normalized()))
	if absf(ang) < 25.0:
		return "↑ düz"
	if absf(ang) > 135.0:
		return "↓ geri dön"
	return "↰ sola" if ang > 0.0 else "↱ sağa"


func _draw_route(to_screen: Callable, s: float) -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for w in route:
		var at = to_screen.call(w)
		if at != null:
			pts.append(at)
		elif pts.size() > 1:
			break
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0.2, 0.95, 1.0, 0.25), 7.0 * s, true)
	draw_polyline(pts, Color(0.2, 0.95, 1.0, 0.95), 3.0 * s, true)
	# marşrut boyu axan işıq nöqtələri
	var phase := fmod(_pulse * 40.0, 24.0)
	var travelled := 0.0
	for k in pts.size() - 1:
		var seg := pts[k].distance_to(pts[k + 1])
		var t0 := phase - travelled
		while t0 < seg:
			if t0 >= 0.0:
				draw_circle(pts[k].lerp(pts[k + 1], t0 / maxf(seg, 0.001)), 1.8 * s, Color.WHITE)
			t0 += 24.0
		travelled += seg


func _flag(at: Variant, s: float) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var bob := Vector2(0, sin(_pulse * 4.0) * 1.5 * s)
	draw_line(p, p + Vector2(0, -18) * s + bob, Color.WHITE, 2.0 * s)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18) * s + bob, p + Vector2(12, -14) * s + bob, p + Vector2(0, -10) * s + bob]), Color(1.0, 0.3, 0.25))
	var ring := fmod(_pulse * 8.0, 10.0)
	draw_arc(p, (6.0 + ring) * s, 0.0, TAU, 24, Color(1.0, 0.3, 0.25, 1.0 - ring / 10.0), 1.5 * s, true)


# --- vektor ikonlar (SVG üslublu, animasiyalı) -----------------------------------------------------

## Yer növü: PLACES sırası ilə (qaraj, şəhər, göl, dağ keçidi, kanyon, mədən, meşə, bataqlıq)
const PLACE_KINDS := ["garage", "city", "lake", "pass", "canyon", "mine", "forest", "swamp"]
const PLACE_COLORS := [Color(0.95, 0.65, 0.2), Color(0.85, 0.85, 0.9), Color(0.3, 0.7, 1.0), Color(0.75, 0.85, 1.0),
	Color(0.95, 0.55, 0.3), Color(0.8, 0.7, 0.5), Color(0.35, 0.85, 0.4), Color(0.7, 0.45, 0.2)]


## Dairəvi nişan: tünd fon, rəngli halqa; glow > 0 olanda nəbz kimi parıldayır.
func _badge_bg(p: Vector2, r: float, col: Color, glow: float) -> void:
	if glow > 0.0:
		var pulse := 0.5 + 0.5 * sin(_pulse * 5.0)
		draw_circle(p, r * (1.5 + 0.35 * pulse), Color(col, 0.18 * glow + 0.12 * pulse * glow))
	draw_circle(p + Vector2(0, r * 0.12), r * 1.05, Color(0, 0, 0, 0.45))
	draw_circle(p, r, Color(0.05, 0.07, 0.08, 0.95))
	draw_arc(p, r, 0.0, TAU, 28, col, maxf(1.2, r * 0.16), true)


func _place_icon(index: int, at: Variant, s: float, big: bool) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var r := (11.0 if big else 8.5) * s
	var col: Color = PLACE_COLORS[index % PLACE_COLORS.size()]
	var is_target := index == target
	_badge_bg(p, r, col, 1.0 if is_target else 0.0)
	var k: String = PLACE_KINDS[index % PLACE_KINDS.size()]
	var u := r / 8.5
	match k:
		"garage":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 4) * u, p + Vector2(5, 4) * u, p + Vector2(5, -1) * u, p + Vector2(0, -5) * u, p + Vector2(-5, -1) * u]), col)
			for row in 3:
				draw_line(p + Vector2(-3, 0.5 + row * 1.3) * u, p + Vector2(3, 0.5 + row * 1.3) * u, Color(0.05, 0.07, 0.08), 0.8 * u)
		"city":
			draw_rect(Rect2(p + Vector2(-5, -1) * u, Vector2(3, 5) * u), col)
			draw_rect(Rect2(p + Vector2(-1.5, -5) * u, Vector2(3, 9) * u), col)
			draw_rect(Rect2(p + Vector2(2.5, -2) * u, Vector2(3, 6) * u), col)
			# pəncərələr yanıb-sönür
			var lit := int(_pulse * 2.0) % 3
			draw_rect(Rect2(p + Vector2(-0.8 + 0.0, -3.8 + lit * 2.2) * u, Vector2(1.4, 1.2) * u), Color(1, 0.9, 0.4))
		"lake":
			for w in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var x := -5.0 + i * 1.25
					pts.append(p + Vector2(x, -1.5 + w * 3.0 + sin(x * 1.3 + _pulse * 3.0) * 1.0) * u)
				draw_polyline(pts, col, 1.3 * u, true)
		"pass":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 4) * u, p + Vector2(-1.5, -4) * u, p + Vector2(1.5, 0) * u, p + Vector2(3, -2) * u, p + Vector2(6, 4) * u]), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2.6, -2) * u, p + Vector2(-1.5, -4) * u, p + Vector2(-0.4, -2) * u]), Color.WHITE)
		"canyon":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -3) * u, p + Vector2(-2, -3) * u, p + Vector2(-1, 4) * u, p + Vector2(-6, 4) * u]), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(2, -3) * u, p + Vector2(6, -3) * u, p + Vector2(6, 4) * u, p + Vector2(1, 4) * u]), col.darkened(0.25))
		"mine":
			draw_line(p + Vector2(-4, 4) * u, p + Vector2(3, -3) * u, col, 1.6 * u, true)
			draw_arc(p + Vector2(3, -3) * u, 3.5 * u, deg_to_rad(110), deg_to_rad(250), 10, Color.WHITE, 1.4 * u, true)
		"forest":
			for t in 2:
				var c := p + Vector2(-2.2 + t * 4.4, t * 0.8) * u
				var sway := sin(_pulse * 2.0 + t) * 0.6 * u
				draw_colored_polygon(PackedVector2Array([c + Vector2(sway, -5 * u), c + Vector2(3.2, 2) * u, c + Vector2(-3.2, 2) * u]), col)
				draw_line(c + Vector2(0, 2) * u, c + Vector2(0, 4) * u, Color(0.5, 0.35, 0.2), 1.0 * u)
		"swamp":
			draw_circle(p + Vector2(0, 2) * u, 4.0 * u, col.darkened(0.2))
			for b in 3:
				var age := fmod(_pulse * 0.9 + b * 0.33, 1.0)
				draw_arc(p + Vector2(-2.5 + b * 2.5, 1.5 - age * 5.0) * u, (0.6 + age) * u, 0.0, TAU, 10, Color(0.9, 0.8, 0.6, 1.0 - age), 0.8 * u, true)
	if is_target:
		_flag(p + Vector2(0, -r * 0.9), s * (1.0 if big else 0.8))


func _fuel_badge(at: Variant, s: float, big: bool) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var r := (10.0 if big else 8.0) * s
	var low := truck.fuel / maxf(1.0, float(truck.spec["fuel"])) < 0.25
	_badge_bg(p, r, Color(1.0, 0.3, 0.22), 1.0 if low else 0.0)
	var u := r / 8.0
	draw_rect(Rect2(p + Vector2(-3.5, -4) * u, Vector2(5, 8) * u), Color.WHITE)
	draw_rect(Rect2(p + Vector2(-2.6, -3) * u, Vector2(3.2, 2.2) * u), Color(1.0, 0.3, 0.22))
	draw_line(p + Vector2(1.5, -2) * u, p + Vector2(4, 0) * u, Color.WHITE, 1.1 * u)
	draw_line(p + Vector2(4, 0) * u, p + Vector2(4, 3) * u, Color.WHITE, 1.1 * u)
	if low:
		var drop := fmod(_pulse * 1.5, 1.0)
		draw_circle(p + Vector2(4, 3.5 + drop * 3.0) * u, 0.9 * u, Color(1, 0.85, 0.3, 1.0 - drop))


func _bridge_badge(at: Variant, s: float) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var u := s * 0.9
	draw_circle(p, 5.5 * u, Color(0.05, 0.07, 0.08, 0.9))
	draw_arc(p + Vector2(0, 3) * u, 4.0 * u, PI, TAU, 12, Color(0.85, 0.85, 0.85), 1.4 * u, true)
	draw_line(p + Vector2(-5, -1) * u, p + Vector2(5, -1) * u, Color(0.85, 0.85, 0.85), 1.4 * u)


func _barn_badge(site: Dictionary, at: Variant, s: float, big: bool) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var r := (10.0 if big else 8.0) * s
	if not site["found"]:
		# təxmini sahə: fırlanan qırıq halqa və "?"
		var gold := Color(0.95, 0.85, 0.4)
		var rot := _pulse * 1.2
		for k in 8:
			var a0 := rot + k * TAU / 8.0
			draw_arc(p, r * 1.35, a0, a0 + TAU / 16.0, 4, Color(gold, 0.8), 1.4 * s, true)
		_badge_bg(p, r * 0.8, gold, 0.0)
		_text_center("?", p + Vector2(0, 4.5) * s, int(12 * s), gold)
		return
	var taken: bool = site["taken"]
	var col := Color(0.55, 0.9, 0.5) if taken else Color(1.0, 0.6, 0.2)
	_badge_bg(p, r, col, 0.0 if taken else 1.0)
	var u := r / 8.0
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 4) * u, p + Vector2(5, 4) * u, p + Vector2(5, -1) * u, p + Vector2(0, -5) * u, p + Vector2(-5, -1) * u]), col)
	draw_rect(Rect2(p + Vector2(-2, 0) * u, Vector2(4, 4) * u), Color(0.05, 0.07, 0.08))
	if not taken:
		# içəridə tapılmış maşın: parıltı ulduzu
		var tw := 0.6 + 0.4 * sin(_pulse * 6.0)
		_star(p + Vector2(5.5, -5.5) * u, 2.6 * u * tw, Color(1, 0.95, 0.6))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := k * TAU / 8.0 + _pulse
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.38))
	draw_colored_polygon(pts, col)


func _activity_badge(marker: Dictionary, at: Variant, s: float, big: bool) -> void:
	if at == null:
		return
	var p: Vector2 = at
	var color: Color = HillClimbCatalog.COLORS[activities.routes[marker["route"]]["difficulty"]]
	if marker["hub"]:
		var r := (11.0 if big else 8.5) * s
		_badge_bg(p, r, color, 0.7)
		var u := r / 8.5
		# kubok
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4) * u, p + Vector2(4, -4) * u, p + Vector2(2.5, 1) * u, p + Vector2(-2.5, 1) * u]), Color(1, 0.82, 0.3))
		draw_rect(Rect2(p + Vector2(-0.8, 1) * u, Vector2(1.6, 2) * u), Color(1, 0.82, 0.3))
		draw_rect(Rect2(p + Vector2(-3, 3) * u, Vector2(6, 1.4) * u), Color(1, 0.82, 0.3))
		_star(p + Vector2(5, -5) * u, 2.0 * u * (0.6 + 0.4 * sin(_pulse * 7.0)), Color.WHITE)
	else:
		var rr := (6.5 if big else 4.5) * s
		var bob := sin(_pulse * 3.0 + p.x) * 1.0 * s
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rr + bob), p + Vector2(rr, rr * 0.8), p + Vector2(-rr, rr * 0.8)]), color)
		draw_polyline(PackedVector2Array([p + Vector2(0, -rr + bob), p + Vector2(rr, rr * 0.8), p + Vector2(-rr, rr * 0.8), p + Vector2(0, -rr + bob)]), Color(0, 0, 0, 0.6), 1.0 * s, true)
		if big:
			_text_center(str(int(marker["route"]) + 1), p + Vector2(0, rr + 10.0 * s), int(10 * s), Color.WHITE)
