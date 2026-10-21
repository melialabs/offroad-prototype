class_name Hud
extends Control
## Aşağı HUD: mərkəzdə spidometr (km/saat), solda mühərrik dövrü və dişli, sağda yanacaq,
## yanlarda AWD, diferensial kilidi, diapazon, təkər və palçıq göstəriciləri.
## Hamısı _draw() ilə çəkilir (şəkil faylı yoxdur), ekran ölçüsünə görə miqyaslanır.

const MAX_KMH := 80.0
const MAX_RPM := 3500.0
const CYAN := Color(0.25, 0.85, 1.0)
const ORANGE := Color(1.0, 0.58, 0.12)
const RED := Color(1.0, 0.22, 0.16)
const GREEN := Color(0.4, 0.95, 0.5)
const PANEL := Color(0.04, 0.06, 0.09, 0.78)
const DIM := Color(0.62, 0.68, 0.74)
const A_START := deg_to_rad(135.0)
const A_SWEEP := deg_to_rad(270.0)

var truck: OffroadTruck
var _font: Font
var _toast := ""
var _toast_t := 0.0
var _speed_smooth := 0.0
var _rpm_smooth := 800.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


## Qısa bildiriş (məs. kamera rejimi adı).
func show_toast(text: String) -> void:
	_toast = text
	_toast_t = 1.6


func _process(delta: float) -> void:
	if truck == null:
		return
	_toast_t = maxf(_toast_t - delta, 0.0)
	_speed_smooth = lerpf(_speed_smooth, truck.linear_velocity.length() * 3.6, 1.0 - exp(-12.0 * delta))
	_rpm_smooth = lerpf(_rpm_smooth, truck.rpm, 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _draw() -> void:
	if truck == null:
		return
	var sz := get_viewport_rect().size
	var s := clampf(sz.y / 720.0, 0.7, 2.0)
	var cx := sz.x * 0.5
	var base_y := sz.y - 20.0 * s

	# arxa fon: aşağıdan yuxarıya saydamlaşan zolaq
	var band_h := 190.0 * s
	var pts := PackedVector2Array([Vector2(0, sz.y - band_h), Vector2(sz.x, sz.y - band_h), Vector2(sz.x, sz.y), Vector2(0, sz.y)])
	var cols := PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)])
	draw_polygon(pts, cols)

	_draw_speedo(Vector2(cx, base_y - 86.0 * s), 84.0 * s, s)
	_draw_rpm(Vector2(cx - 232.0 * s, base_y - 62.0 * s), 58.0 * s, s)
	_draw_fuel(Vector2(cx + 232.0 * s, base_y - 62.0 * s), 58.0 * s, s)
	_draw_left_badges(Vector2(cx - (232.0 + 66.0 + 14.0 + 188.0) * s, base_y - 118.0 * s), s)
	_draw_right_badges(Vector2(cx + 330.0 * s, base_y - 118.0 * s), s)

	# kiçik düymə göstərişi
	_text_c("W/S qaz  ·  A/D sükan  ·  Space əl əyləci  ·  V kamera  ·  Q diapazon  ·  E AWD  ·  F diferensial  ·  T təkər  ·  1/2/3 texnika  ·  R sıfırla",
		Vector2(cx, sz.y - 6.0 * s), int(11 * s), Color(1, 1, 1, 0.38))

	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.4, 0.0, 1.0)
		_text_c(_toast, Vector2(cx, base_y - 215.0 * s), int(22 * s), Color(1, 1, 1, a))


# --- spidometr -------------------------------------------------------------------

func _draw_speedo(c: Vector2, r: float, s: float) -> void:
	draw_circle(c, r + 10.0 * s, PANEL)
	draw_arc(c, r, A_START, A_START + A_SWEEP, 72, Color(1, 1, 1, 0.12), 8.0 * s, true)
	var frac := clampf(_speed_smooth / MAX_KMH, 0.0, 1.0)
	var col := CYAN.lerp(ORANGE, smoothstep(0.55, 0.85, frac)).lerp(RED, smoothstep(0.88, 1.0, frac))
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 72, col, 8.0 * s, true)
	# işarələr və rəqəmlər
	for k in range(0, int(MAX_KMH / 10.0) + 1):
		var a := A_START + A_SWEEP * (float(k) * 10.0 / MAX_KMH)
		var d := Vector2(cos(a), sin(a))
		var major := k % 2 == 0
		draw_line(c + d * (r - (14.0 if major else 9.0) * s), c + d * (r - 4.0 * s), Color(1, 1, 1, 0.75 if major else 0.4), (2.0 if major else 1.2) * s, true)
		if major:
			_text_c(str(k * 10), c + d * (r - 28.0 * s), int(11 * s), Color(1, 1, 1, 0.7))
	# əqrəb
	var na := A_START + A_SWEEP * frac
	var nd := Vector2(cos(na), sin(na))
	draw_line(c - nd * 8.0 * s, c + nd * (r - 18.0 * s), Color(1, 0.35, 0.2), 3.0 * s, true)
	draw_circle(c, 6.0 * s, Color(0.12, 0.14, 0.17))
	draw_circle(c, 3.0 * s, Color(1, 0.35, 0.2))
	# rəqəmsal sürət
	_text_c(str(int(round(_speed_smooth))), c + Vector2(0, 34.0 * s), int(40 * s), Color.WHITE)
	_text_c("km/saat", c + Vector2(0, 54.0 * s), int(12 * s), DIM)


# --- RPM və dişli ------------------------------------------------------------------

func _draw_rpm(c: Vector2, r: float, s: float) -> void:
	draw_circle(c, r + 8.0 * s, PANEL)
	draw_arc(c, r, A_START, A_START + A_SWEEP, 54, Color(1, 1, 1, 0.12), 6.0 * s, true)
	# qırmızı zona
	var red_from := 2700.0 / MAX_RPM
	draw_arc(c, r, A_START + A_SWEEP * red_from, A_START + A_SWEEP, 16, Color(RED, 0.5), 6.0 * s, true)
	var frac := clampf(_rpm_smooth / MAX_RPM, 0.0, 1.0)
	var col := GREEN.lerp(ORANGE, smoothstep(0.5, 0.74, frac)).lerp(RED, smoothstep(0.74, 0.86, frac))
	draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 54, col, 6.0 * s, true)
	var gear_txt := "R" if truck.gear < 0 else str(truck.gear)
	_text_c(gear_txt, c + Vector2(0, 10.0 * s), int(34 * s), Color.WHITE)
	_text_c("DİŞLİ", c + Vector2(0, -22.0 * s), int(10 * s), DIM)
	_text_c("%d dövr" % int(round(_rpm_smooth / 10.0) * 10.0), c + Vector2(0, 36.0 * s), int(11 * s), DIM)


# --- yanacaq -----------------------------------------------------------------------

func _draw_fuel(c: Vector2, r: float, s: float) -> void:
	var maxf := float(truck.spec["fuel"])
	var frac := clampf(truck.fuel / maxf, 0.0, 1.0)
	draw_circle(c, r + 8.0 * s, PANEL)
	draw_arc(c, r, A_START, A_START + A_SWEEP, 54, Color(1, 1, 1, 0.12), 6.0 * s, true)
	var low := frac < 0.15
	var col := RED if low else (ORANGE if frac < 0.3 else CYAN)
	if low and int(Time.get_ticks_msec() / 350) % 2 == 0:
		col = Color(RED, 0.35)
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 54, col, 6.0 * s, true)
	_text_c("%d" % int(truck.fuel), c + Vector2(0, 10.0 * s), int(32 * s), Color.WHITE)
	_text_c("YANACAQ", c + Vector2(0, -22.0 * s), int(10 * s), DIM)
	_text_c("litr  %d%%" % int(frac * 100.0), c + Vector2(0, 36.0 * s), int(11 * s), DIM)


# --- yanlardakı göstəricilər ---------------------------------------------------------

func _draw_left_badges(o: Vector2, s: float) -> void:
	var awd_always: bool = truck.spec["awd"] == "always"
	var awd_txt := "AWD  həmişə" if awd_always else ("AWD  açıq" if truck.awd_on else "AWD  bağlı")
	_badge(o, awd_txt, truck.awd_on or awd_always, s)
	var diff: String = truck.spec["diff"]
	var diff_txt := "Diferensial  yoxdur"
	var diff_on := false
	if diff != "none":
		diff_on = truck.diff_lock
		diff_txt = "Diferensial  kilidli" if diff_on else "Diferensial  açıq"
	_badge(o + Vector2(0, 34.0 * s), diff_txt, diff_on, s, diff == "none")
	_badge(o + Vector2(0, 68.0 * s), "Diapazon  aşağı" if truck.low_range else "Diapazon  yuxarı", truck.low_range, s)


func _draw_right_badges(o: Vector2, s: float) -> void:
	var tire: Dictionary = OffroadTruck.TIRES[truck.tire_idx]
	_badge(o, "Təkər  " + str(tire["name"]), true, s)
	_badge(o + Vector2(0, 34.0 * s), str(truck.spec["name"]), true, s)
	# palçıq çubuğu
	var w := 188.0 * s
	var h := 26.0 * s
	var r := Rect2(o + Vector2(0, 68.0 * s), Vector2(w, h))
	draw_rect(r, PANEL, true)
	var mud := clampf(truck.mud_level, 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(3, 3) * s, Vector2((w - 6.0 * s) * mud, h - 6.0 * s)), Color(0.62, 0.4, 0.2), true)
	_text_c("Palçıq  %d%%" % int(mud * 100.0), r.position + Vector2(w * 0.5, h * 0.5 + 4.0 * s), int(12 * s), Color.WHITE)


func _badge(pos: Vector2, text: String, on: bool, s: float, disabled: bool = false) -> void:
	var w := 188.0 * s
	var h := 26.0 * s
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r, PANEL, true)
	var accent := DIM if disabled else (CYAN if on else Color(0.35, 0.38, 0.42))
	draw_rect(Rect2(pos, Vector2(4.0 * s, h)), accent, true)
	draw_circle(pos + Vector2(16.0 * s, h * 0.5), 4.0 * s, accent)
	var tc := Color(1, 1, 1, 0.9 if on else 0.55)
	_text_l(text, pos + Vector2(28.0 * s, h * 0.5 + 4.5 * s), int(12 * s), tc)


# --- mətn köməkçiləri ------------------------------------------------------------------

func _text_c(text: String, pos: Vector2, size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text_l(text, Vector2(pos.x - w * 0.5, pos.y), size, color)


func _text_l(text: String, pos: Vector2, size: int, color: Color) -> void:
	# kölgə + mətn
	draw_string(_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, color.a * 0.6))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
