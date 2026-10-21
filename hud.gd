class_name Hud
extends Control
## Aşağı HUD, iki künc bloku: solda spidometr + AWD/diferensial/diapazon, sağda təkər/texnika/palçıq + dövr və yanacaq.
## Mərkəz boşdur ki, yol və maşın görünsün. Hamısı _draw() ilə çəkilir, ekran ölçüsünə görə miqyaslanır.
## Düymə göstərişi ilk 16 saniyə görünür, sonra H ilə açılıb-bağlanır.

const MAX_KMH := 80.0
const MAX_RPM := 3500.0
const CYAN := Color(0.25, 0.85, 1.0)
const ORANGE := Color(1.0, 0.58, 0.12)
const RED := Color(1.0, 0.22, 0.16)
const GREEN := Color(0.4, 0.95, 0.5)
const PANEL := Color(0.03, 0.05, 0.08, 0.62)
const PILL := Color(0.08, 0.1, 0.14, 0.85)
const DIM := Color(0.62, 0.68, 0.74)
const A_START := deg_to_rad(135.0)
const A_SWEEP := deg_to_rad(270.0)

var truck: OffroadTruck
var _font: Font
var _toast := ""
var _toast_t := 0.0
var _speed_smooth := 0.0
var _rpm_smooth := 800.0
var _t := 0.0
var _hints_forced := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


## Qısa bildiriş (məs. kamera rejimi adı).
func show_toast(text: String) -> void:
	_toast = text
	_toast_t = 1.6


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_hints_forced = not _hints_forced


func _process(delta: float) -> void:
	if truck == null or not visible:
		return
	_t += delta
	_toast_t = maxf(_toast_t - delta, 0.0)
	_speed_smooth = lerpf(_speed_smooth, truck.linear_velocity.length() * 3.6, 1.0 - exp(-12.0 * delta))
	_rpm_smooth = lerpf(_rpm_smooth, truck.rpm, 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _panel(r: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(int(14))
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	draw_style_box(sb, r)


func _draw() -> void:
	if truck == null:
		return
	var sz := get_viewport_rect().size
	var s := clampf(sz.y / 900.0, 0.7, 1.5)
	var m := 14.0 * s
	var h := 112.0 * s
	var y0 := sz.y - m - h
	var gap := 10.0 * s
	var pill_w := 156.0 * s
	var speedo_r := 54.0 * s
	var small_r := 36.0 * s

	# sol blok: spidometr + AWD / diferensial / diapazon
	var lw := 14.0 * s + (speedo_r + 8.0 * s) * 2.0 + gap + pill_w + 14.0 * s
	var left := Rect2(m, y0, lw, h)
	_panel(left)
	var sc := Vector2(left.position.x + 14.0 * s + speedo_r + 8.0 * s, y0 + h * 0.5)
	_draw_speedo(sc, speedo_r, s)
	_draw_left_badges(Vector2(sc.x + speedo_r + 8.0 * s + gap, y0 + (h - 78.0 * s) * 0.5), pill_w, s)

	# sağ blok: təkər / texnika / palçıq + dövr və yanacaq
	var rw := 14.0 * s + pill_w + gap + (small_r + 6.0 * s) * 2.0 * 2.0 + gap + 14.0 * s
	var right := Rect2(sz.x - m - rw, y0, rw, h)
	_panel(right)
	_draw_right_badges(Vector2(right.position.x + 14.0 * s, y0 + (h - 78.0 * s) * 0.5), pill_w, s)
	var rc := Vector2(right.position.x + 14.0 * s + pill_w + gap + small_r + 6.0 * s, y0 + h * 0.5)
	_draw_rpm(rc, small_r, s)
	_draw_fuel(rc + Vector2((small_r + 6.0 * s) * 2.0 + 0.0, 0.0), small_r, s)

	# mərkəz: mühərrik / fənər / qəza işığı göstəriciləri
	var bw := 104.0 * s
	var bx := sz.x * 0.5 - (bw * 3.0 + gap * 2.0) * 0.5
	var by := sz.y - m - 22.0 * s - 14.0 * s
	var eng_txt := "Mühərrik"
	var eng_on: bool = truck.engine_state == OffroadTruck.EngineState.RUNNING
	if truck.engine_state == OffroadTruck.EngineState.CRANKING:
		eng_txt = "İşə düşür..."
	elif not eng_on:
		eng_txt = "Mühərrik: I"
	_badge(Vector2(bx, by), bw, eng_txt, eng_on, s)
	var hl: int = truck.lights.headlight_mode
	_badge(Vector2(bx + bw + gap, by), bw, ["Fənər söndü", "Yaxın fənər", "Uzaq fənər"][hl], hl > 0, s)
	var haz_on: bool = truck.lights.hazard
	_badge(Vector2(bx + (bw + gap) * 2.0, by), bw, "Qəza işığı", haz_on and int(Time.get_ticks_msec() / 400) % 2 == 0, s)
	if truck.engine_state == OffroadTruck.EngineState.OFF:
		var pa := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		_text_c("Mühərriki işə salmaq üçün I düyməsinə bas", Vector2(sz.x * 0.5, by - 12.0 * s), int(16 * s), Color(1, 0.8, 0.3, pa))

	# düymə göstərişi: ilk 16 saniyə, sonra H ilə
	var hint_a := 0.5 if _hints_forced else clampf((16.0 - _t) / 3.0, 0.0, 1.0) * 0.5
	if hint_a > 0.01:
		_text_c("W/S qaz  ·  A/D sükan  ·  Space əl əyləci  ·  Siçan kamera  ·  V rejim  ·  I mühərrik  ·  L fənər  ·  Z qəza  ·  N gecə  ·  Q diapazon  ·  E AWD  ·  F diferensial  ·  T təkər  ·  Esc menyu  ·  H göstəriş",
			Vector2(sz.x * 0.5, sz.y - 7.0 * s), int(11 * s), Color(1, 1, 1, hint_a))

	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.4, 0.0, 1.0)
		_text_c(_toast, Vector2(sz.x * 0.5, sz.y - m - h - 18.0 * s), int(22 * s), Color(1, 1, 1, a))


# --- spidometr -------------------------------------------------------------------

func _draw_speedo(c: Vector2, r: float, s: float) -> void:
	draw_circle(c, r + 6.0 * s, Color(0, 0, 0, 0.35))
	draw_arc(c, r, A_START, A_START + A_SWEEP, 72, Color(1, 1, 1, 0.12), 6.0 * s, true)
	var frac := clampf(_speed_smooth / MAX_KMH, 0.0, 1.0)
	var col := CYAN.lerp(ORANGE, smoothstep(0.55, 0.85, frac)).lerp(RED, smoothstep(0.88, 1.0, frac))
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 72, col, 6.0 * s, true)
	for k in range(0, int(MAX_KMH / 10.0) + 1):
		var a := A_START + A_SWEEP * (float(k) * 10.0 / MAX_KMH)
		var d := Vector2(cos(a), sin(a))
		var major := k % 2 == 0
		draw_line(c + d * (r - (10.0 if major else 6.0) * s), c + d * (r - 3.0 * s), Color(1, 1, 1, 0.7 if major else 0.35), (1.6 if major else 1.0) * s, true)
		if major:
			_text_c(str(k * 10), c + d * (r - 20.0 * s) + Vector2(0, 3.0 * s), int(9 * s), Color(1, 1, 1, 0.65))
	var na := A_START + A_SWEEP * frac
	var nd := Vector2(cos(na), sin(na))
	draw_line(c - nd * 5.0 * s, c + nd * (r - 12.0 * s), Color(1, 0.35, 0.2), 2.4 * s, true)
	draw_circle(c, 4.5 * s, Color(0.12, 0.14, 0.17))
	draw_circle(c, 2.2 * s, Color(1, 0.35, 0.2))
	_text_c(str(int(round(_speed_smooth))), c + Vector2(0, 28.0 * s), int(26 * s), Color.WHITE)
	_text_c("km/saat", c + Vector2(0, 41.0 * s), int(9 * s), DIM)


# --- RPM və dişli ------------------------------------------------------------------

func _draw_rpm(c: Vector2, r: float, s: float) -> void:
	draw_arc(c, r, A_START, A_START + A_SWEEP, 54, Color(1, 1, 1, 0.12), 5.0 * s, true)
	var red_from := 2700.0 / MAX_RPM
	draw_arc(c, r, A_START + A_SWEEP * red_from, A_START + A_SWEEP, 16, Color(RED, 0.5), 5.0 * s, true)
	var frac := clampf(_rpm_smooth / MAX_RPM, 0.0, 1.0)
	var col := GREEN.lerp(ORANGE, smoothstep(0.5, 0.74, frac)).lerp(RED, smoothstep(0.74, 0.86, frac))
	draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 54, col, 5.0 * s, true)
	var gear_txt := "R" if truck.gear < 0 else str(truck.gear)
	_text_c(gear_txt, c + Vector2(0, 9.0 * s), int(26 * s), Color.WHITE)
	_text_c("DİŞLİ", c + Vector2(0, -16.0 * s), int(8 * s), DIM)
	_text_c("%d" % int(round(_rpm_smooth / 10.0) * 10.0), c + Vector2(0, r + 12.0 * s), int(9 * s), DIM)


# --- yanacaq -----------------------------------------------------------------------

func _draw_fuel(c: Vector2, r: float, s: float) -> void:
	var maxf := float(truck.spec["fuel"])
	var frac := clampf(truck.fuel / maxf, 0.0, 1.0)
	draw_arc(c, r, A_START, A_START + A_SWEEP, 54, Color(1, 1, 1, 0.12), 5.0 * s, true)
	var low := frac < 0.15
	var col := RED if low else (ORANGE if frac < 0.3 else CYAN)
	if low and int(Time.get_ticks_msec() / 350) % 2 == 0:
		col = Color(RED, 0.35)
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 54, col, 5.0 * s, true)
	_text_c("%d" % int(truck.fuel), c + Vector2(0, 9.0 * s), int(24 * s), Color.WHITE)
	_text_c("YANACAQ", c + Vector2(0, -16.0 * s), int(8 * s), DIM)
	_text_c("litr", c + Vector2(0, r + 12.0 * s), int(9 * s), DIM)


# --- yan göstəricilər ----------------------------------------------------------------

func _draw_left_badges(o: Vector2, w: float, s: float) -> void:
	var awd_always: bool = truck.spec["awd"] == "always"
	var awd_txt := "AWD həmişə" if awd_always else ("AWD açıq" if truck.awd_on else "AWD bağlı")
	_badge(o, w, awd_txt, truck.awd_on or awd_always, s)
	var diff: String = truck.spec["diff"]
	var diff_txt := "Diferensial yox"
	var diff_on := false
	if diff != "none":
		diff_on = truck.diff_lock
		diff_txt = "Dif. kilidli" if diff_on else "Dif. açıq"
	_badge(o + Vector2(0, 28.0 * s), w, diff_txt, diff_on, s, diff == "none")
	_badge(o + Vector2(0, 56.0 * s), w, "Aşağı diapazon" if truck.low_range else "Yuxarı diapazon", truck.low_range, s)


func _draw_right_badges(o: Vector2, w: float, s: float) -> void:
	var tire: Dictionary = OffroadTruck.TIRES[truck.tire_idx]
	_badge(o, w, "Təkər: " + str(tire["name"]), true, s)
	_badge(o + Vector2(0, 28.0 * s), w, str(truck.spec["name"]), true, s)
	var h := 22.0 * s
	var r := Rect2(o + Vector2(0, 56.0 * s), Vector2(w, h))
	draw_rect(r, PILL, true)
	var mud := clampf(truck.mud_level, 0.0, 1.0)
	draw_rect(Rect2(r.position + Vector2(2, 2) * s, Vector2((w - 4.0 * s) * mud, h - 4.0 * s)), Color(0.62, 0.4, 0.2, 0.9), true)
	_text_c("Palçıq %d%%" % int(mud * 100.0), r.position + Vector2(w * 0.5, h * 0.5 + 4.0 * s), int(10 * s), Color.WHITE)


func _badge(pos: Vector2, w: float, text: String, on: bool, s: float, disabled: bool = false) -> void:
	var h := 22.0 * s
	draw_rect(Rect2(pos, Vector2(w, h)), PILL, true)
	var accent := DIM if disabled else (CYAN if on else Color(0.35, 0.38, 0.42))
	draw_rect(Rect2(pos, Vector2(3.0 * s, h)), accent, true)
	draw_circle(pos + Vector2(13.0 * s, h * 0.5), 3.2 * s, accent)
	_text_l(text, pos + Vector2(23.0 * s, h * 0.5 + 4.0 * s), int(10 * s), Color(1, 1, 1, 0.92 if on else 0.55))


# --- mətn köməkçiləri ------------------------------------------------------------------

func _text_c(text: String, pos: Vector2, size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text_l(text, Vector2(pos.x - w * 0.5, pos.y), size, color)


func _text_l(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, color.a * 0.6))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
