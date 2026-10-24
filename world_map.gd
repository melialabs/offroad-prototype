class_name WorldMap
extends Control
## GPS: aşağı solda dairəvi, maşına görə fırlanan (istiqamət yuxarı) premium mini-xəritə;
## M düyməsi bütün xəritəni (şimal yuxarı) açır. Xəritə şəkli bir dəfə relyefdən bişirilir:
## hündürlük kölgəsi, biomlar (ot, meşə, qaya, qar, palçıq, kanyon), göl/çay, yollar, cığırlar, şəhər.

var barns: BarnFinds
var activities: HillClimbActivity
var terrain: MudTerrain
var truck: OffroadTruck
var opened := false

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
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > 0.5) { discard; }
	vec2 q = vec2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
	vec2 uv = center_uv + q * span;
	vec3 c = texture(map_tex, uv).rgb;
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
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		opened = not opened
		queue_redraw()
		get_viewport().set_input_as_handled()


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
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGB8)
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
			img.set_pixel(x, z, Color(col.r * shade, col.g * shade, col.b * shade))
	# göl
	for z in MAP_PX:
		for x in MAP_PX:
			var w := Vector2(x, z) / MAP_PX * WORLD - Vector2.ONE * WORLD * 0.5
			var e := MapLayout._ellipse(w, MapLayout.LAKE_CENTER, MapLayout.LAKE_RADII)
			if e < 1.0:
				img.set_pixel(x, z, Color(0.13, 0.36, 0.55).lerp(Color(0.22, 0.52, 0.72), smoothstep(1.0, 0.6, e)))
	_stamp_line(img, terrain._river, terrain._river_gap, MapLayout.RIVER_HALF + 2.0, Color(0.12, 0.34, 0.52))
	_stamp_line(img, terrain._river, terrain._river_gap, MapLayout.RIVER_HALF - 1.0, Color(0.22, 0.52, 0.72))
	_stamp_line(img, terrain._trail, terrain._trail_gap, 3.2, Color(0.47, 0.30, 0.15), 3)
	_stamp_line(img, terrain._road, terrain._road_gap, MudTerrain.ROAD_HALF + 3.5, Color(0.08, 0.08, 0.07))
	_stamp_line(img, terrain._road, terrain._road_gap, MudTerrain.ROAD_HALF + 0.5, Color(0.96, 0.88, 0.62))
	img.generate_mipmaps()
	map_texture = ImageTexture.create_from_image(img)
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
		var col := Color(1.0, 0.36, 0.25) if k == 0 else Color(0.95, 0.92, 0.85)
		draw_circle(pos, 9.0 * s, Color(0.03, 0.04, 0.04, 0.85))
		_text_center(names[k], pos + Vector2(0, 5) * s, int(13 * s), col)
	for b in _bridges:
		var bp = _mini_point(b, rect)
		if bp != null:
			draw_rect(Rect2(bp - Vector2(3, 3) * s, Vector2(6, 6) * s), Color(0.85, 0.85, 0.85))
	for f in _fuel:
		_fuel_icon(_mini_point(f, rect), s)
	_draw_barns_with(func(w: Vector2): return _mini_point(w, rect), s * 0.85)
	_draw_activities_with(func(w: Vector2): return _mini_point(w, rect), s * 0.85, false)
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	var nearest := ""
	var nearest_d := 1e9
	var nearest_w := me
	for place in WorldLandmarks.PLACES:
		var w: Vector2 = place[1]
		var d := w.distance_to(me)
		if d < nearest_d:
			nearest_d = d
			nearest = place[0]
			nearest_w = w
		_pin(_mini_point(w, rect), s)
	# ən yaxın yer görünmürsə, halqanın kənarında onun istiqaməti
	if _mini_point(nearest_w, rect) == null:
		_pin(_mini_point(nearest_w, rect, true), s)
	# maşın: parlayan ox (həmişə yuxarı baxır)
	var glow := 0.5 + 0.5 * sin(_pulse * 3.0)
	draw_circle(c, (11.0 + glow * 3.0) * s, Color(0.2, 0.95, 1.0, 0.18))
	var arrow := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(7, 8) * s, c + Vector2(0, 4) * s, c + Vector2(-7, 8) * s])
	draw_colored_polygon(arrow, Color(0.2, 0.95, 1.0))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), Color(0.02, 0.1, 0.12), 1.5 * s, true)
	# məlumat zolağı: ən yaxın yer, kurs, hündürlük
	var strip := Rect2(Vector2(rect.position.x - 2.0 * s, rect.end.y + 16.0 * s), Vector2(rect.size.x + 4.0 * s, 46.0 * s))
	draw_rect(strip, Color(0.02, 0.03, 0.03, 0.82))
	draw_rect(Rect2(strip.position, Vector2(3.0 * s, strip.size.y)), Color(0.92, 0.78, 0.42))
	var heading := fposmod(rad_to_deg(_angle), 360.0)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var compass_name: String = dirs[int(round(heading / 45.0)) % 8]
	draw_string(font, strip.position + Vector2(12, 19) * s, "%s  ·  %s" % [nearest, _dist_text(nearest_d)], HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 16.0 * s, int(14 * s), Color.WHITE)
	draw_string(font, strip.position + Vector2(12, 38) * s, "%03d° %s   ↑ %d m   M: xəritə" % [int(heading), compass_name, int(truck.global_position.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(0.6, 0.9, 0.87))
	# miqyas: 100 m
	var bar := 100.0 / (WORLD * _span) * rect.size.x
	var bar_at := Vector2(rect.end.x - bar - 6.0 * s, rect.end.y - 8.0 * s)
	draw_line(bar_at, bar_at + Vector2(bar, 0), Color(1, 1, 1, 0.85), 2.0 * s)
	_text_center("100 m", bar_at + Vector2(bar * 0.5, -4.0 * s), int(10 * s), Color(1, 1, 1, 0.85))


func _dist_text(d: float) -> String:
	return "%d m" % int(d) if d < 1000.0 else "%.1f km" % (d / 1000.0)


func _pin(at: Variant, s: float) -> void:
	if at == null:
		return
	var p: Vector2 = at
	draw_circle(p + Vector2(0, -6) * s, 5.5 * s, Color(1, 0.68, 0.24))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4) * s, p + Vector2(4, -4) * s, p]), Color(1, 0.68, 0.24))
	draw_circle(p + Vector2(0, -6) * s, 2.2 * s, Color(0.15, 0.08, 0.02))


func _fuel_icon(at: Variant, s: float) -> void:
	if at == null:
		return
	var p: Vector2 = at
	draw_circle(p, 7.5 * s, Color(0.85, 0.15, 0.12))
	draw_rect(Rect2(p + Vector2(-3.0, -4.0) * s, Vector2(5.0, 8.0) * s), Color.WHITE)
	draw_line(p + Vector2(2.0, -2.0) * s, p + Vector2(4.0, 1.5) * s, Color.WHITE, 1.5 * s)


func _text_center(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- böyük xəritə (M) ------------------------------------------------------------------------------

func _draw_full() -> void:
	var vp := get_viewport_rect().size
	var s := _scale_ui()
	var font := ThemeDB.fallback_font
	var side := minf(vp.y - 120.0 * s, vp.x - 340.0 * s)
	var origin := Vector2(24.0 * s, (vp.y - side) * 0.5)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(origin - Vector2(6, 6) * s, Vector2(side, side) + Vector2(12, 12) * s), Color(0.92, 0.78, 0.42))
	draw_texture_rect(map_texture, Rect2(origin, Vector2(side, side)), false)
	var to_screen := func(w: Vector2) -> Vector2: return origin + _uv(w) * side
	for b in _bridges:
		draw_rect(Rect2(to_screen.call(b) - Vector2(3, 3) * s, Vector2(6, 6) * s), Color(0.9, 0.9, 0.9))
	for f in _fuel:
		_fuel_icon(to_screen.call(f), s)
	_draw_barns_with(to_screen, s)
	_draw_activities_with(to_screen, s, true)
	var row := 0
	var panel_x := origin.x + side + 26.0 * s
	draw_rect(Rect2(Vector2(panel_x - 12.0 * s, origin.y - 6.0 * s), Vector2(300.0 * s, side + 12.0 * s)), Color(0.02, 0.03, 0.03, 0.88))
	draw_string(font, Vector2(panel_x, origin.y + 22.0 * s), "XƏRİTƏ · M: bağla", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * s), Color(0.92, 0.78, 0.42))
	var me := Vector2(truck.global_position.x, truck.global_position.z)
	for place in WorldLandmarks.PLACES:
		var w: Vector2 = place[1]
		var at: Vector2 = to_screen.call(w)
		_pin(at, s)
		_text_center(str(row + 1), at + Vector2(0, -14) * s, int(12 * s), Color.WHITE)
		draw_string(font, Vector2(panel_x, origin.y + (56.0 + row * 26.0) * s), "%d. %s  ·  %s" % [row + 1, place[0], _dist_text(w.distance_to(me))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s), Color.WHITE)
		row += 1
	var legend_y := origin.y + (70.0 + row * 26.0) * s
	var legend := [["Asfalt yol", Color(0.96, 0.88, 0.62)], ["Palçıq cığırı", Color(0.6, 0.38, 0.18)], ["Göl və çay", Color(0.22, 0.52, 0.72)],
		["Bataqlıq / palçıq", Color(0.38, 0.27, 0.16)], ["Meşə", Color(0.20, 0.36, 0.18)], ["Kanyon", Color(0.74, 0.55, 0.34)], ["Qar", Color(0.93, 0.95, 0.98)]]
	for k in legend.size():
		var y := legend_y + k * 22.0 * s
		draw_rect(Rect2(Vector2(panel_x, y - 11.0 * s), Vector2(16, 12) * s), legend[k][1])
		draw_string(font, Vector2(panel_x + 24.0 * s, y), legend[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.9, 0.9, 0.88))
	var y2 := legend_y + legend.size() * 22.0 * s + 8.0 * s
	_fuel_icon(Vector2(panel_x + 8.0 * s, y2 - 5.0 * s), s * 0.8)
	draw_string(font, Vector2(panel_x + 24.0 * s, y2), "Yanacaq məntəqəsi", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.9, 0.9, 0.88))
	draw_rect(Rect2(Vector2(panel_x + 5.0 * s, y2 + 12.0 * s), Vector2(6, 6) * s), Color(0.9, 0.9, 0.9))
	draw_string(font, Vector2(panel_x + 24.0 * s, y2 + 20.0 * s), "Körpü", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.9, 0.9, 0.88))
	if activities != null:
		var enabled_count := 0
		for route_index in activities.routes.size():
			if activities.route_enabled(route_index):
				enabled_count += 1
		draw_string(font, Vector2(panel_x, y2 + 46.0 * s), "▲ Hill Climb · %d marşrut" % enabled_count, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(1, 0.78, 0.3))
	var cur: Vector2 = to_screen.call(me)
	var heading := Vector2(truck.global_basis.z.x, truck.global_basis.z.z).normalized()
	var ang := heading.angle() + PI * 0.5
	var arrow := PackedVector2Array([Vector2(0, -12), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)])
	for k in arrow.size():
		arrow[k] = cur + arrow[k].rotated(ang) * s
	draw_circle(cur, 14.0 * s, Color(0.2, 0.95, 1.0, 0.2))
	draw_colored_polygon(arrow, Color(0.2, 0.95, 1.0))
	draw_string(font, Vector2(origin.x, origin.y + side + 22.0 * s), "X %d   Z %d   ·   2 × 2 km" % [me.x, me.y], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(0.6, 0.9, 0.87))


## Köhnə qarajlar: tapılmamışlar təxmini "şayiə" dairəsi, tapılanlar ev işarəsi.
func _draw_barns_with(to_screen: Callable, s: float) -> void:
	if barns == null:
		return
	for site in barns.sites:
		if not site["found"]:
			var at = to_screen.call(site["rumor"])
			if at == null:
				continue
			draw_arc(at, 9.0 * s, 0.0, TAU, 24, Color(0.95, 0.85, 0.4, 0.85), 1.6 * s, true)
			_text_center("?", at + Vector2(0, 5) * s, int(13 * s), Color(0.95, 0.85, 0.4))
		else:
			var p: Vector3 = (site["root"] as Node3D).global_position
			var at2 = to_screen.call(Vector2(p.x, p.z))
			if at2 == null:
				continue
			var col := Color(0.55, 0.9, 0.5) if site["taken"] else Color(1.0, 0.6, 0.2)
			var q: Vector2 = at2
			draw_colored_polygon(PackedVector2Array([q + Vector2(-5, 4) * s, q + Vector2(5, 4) * s, q + Vector2(5, -2) * s, q + Vector2(0, -7) * s, q + Vector2(-5, -2) * s]), col)


func _draw_activities_with(to_screen: Callable, s: float, labels: bool) -> void:
	if activities == null:
		return
	for i in activities.markers.size():
		if not activities.marker_enabled(i):
			continue
		var marker: Dictionary = activities.markers[i]
		var p: Vector3 = marker["p"]
		var at = to_screen.call(Vector2(p.x, p.z))
		if at == null:
			continue
		var color: Color = HillClimbCatalog.COLORS[activities.routes[marker["route"]]["difficulty"]]
		var radius := (5.0 if labels or marker["hub"] else 3.2) * s
		var q: Vector2 = at
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -radius), q + Vector2(radius, radius), q + Vector2(-radius, radius)]), color)
		if labels:
			draw_string(ThemeDB.fallback_font, q + Vector2(6, 0) * s, "HC" if marker["hub"] else str(int(marker["route"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color.WHITE)
	if activities.engaged():
		var route: Dictionary = activities.routes[activities.active_index]
		var pts := PackedVector2Array()
		for rp in route["points"]:
			var a = to_screen.call(rp)
			if a != null:
				pts.append(a)
		if pts.size() > 1:
			draw_polyline(pts, Color(1, 0.75, 0.24), 2.5 * s, true)
		if activities.next_checkpoint < activities.checkpoints.size():
			var cp: Vector3 = activities.checkpoints[activities.next_checkpoint]
			var at3 = to_screen.call(Vector2(cp.x, cp.z))
			if at3 != null:
				draw_circle(at3, 5.0 * s, Color.WHITE)
