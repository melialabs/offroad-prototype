class_name Hud
extends Control
## Vehicle-specific instruments in the lower-right; GPS remains lower-left.
## Mərkəz boşdur ki, yol və maşın görünsün. Hamısı _draw() ilə çəkilir, ekran ölçüsünə görə miqyaslanır.
## Düymə göstərişi ilk 16 saniyə görünür, sonra H ilə açılıb-bağlanır.

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
	_speed_smooth = lerpf(_speed_smooth, Vector2(truck.linear_velocity.x, truck.linear_velocity.z).length() * 3.6, 1.0 - exp(-12.0 * delta))
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
	var s := minf(clampf(sz.y / 900.0, 0.7, 1.5),maxf(0.45,(sz.x-250.0)/670.0))
	var m := 14.0 * s
	# Kompakt premium panel (aşağı sağ): solda sürət halqası, ortada dişli + RPM LED zolağı + yanacaq,
	# altda bütün vəziyyət çipləri bir sırada. Ekranın ortası və aşağı sol (GPS) boş qalır.
	var pw := 372.0 * s
	var ph := 128.0 * s
	var panel := Rect2(Vector2(sz.x - m - pw, sz.y - m - ph - 14.0 * s), Vector2(pw, ph))
	var y0 := panel.position.y
	var h := ph
	_panel(panel)
	draw_rect(Rect2(panel.position + Vector2(14, 0) * s, Vector2(pw - 28.0 * s, 2.0 * s)), Color(0.92, 0.78, 0.42, 0.85))
	var o := panel.position
	var tire_name := str(OffroadTruck.TIRES[truck.tire_idx]["name"])
	_text_l("%s  ·  %s təkər" % [str(truck.spec["name"]).to_upper(), tire_name.to_lower()], o + Vector2(14, 18) * s, int(10 * s), DIM)
	if truck.mud_level > 0.01:
		var mud := clampf(truck.mud_level, 0.0, 1.0)
		var mb := Rect2(o + Vector2(pw / s - 96.0, 10.0) * s, Vector2(82, 5) * s)
		draw_rect(mb, PILL)
		draw_rect(Rect2(mb.position, Vector2(mb.size.x * mud, mb.size.y)), Color(0.62, 0.4, 0.2))
		_text_l("PALÇIQ", mb.position + Vector2(-40, 6) * s, int(8 * s), DIM)
	_draw_speed_ring(o + Vector2(62, 66) * s, 40.0 * s, s)
	_draw_gear_rpm(o + Vector2(118, 32) * s, s)
	_draw_fuel_bar(o + Vector2(118, 78) * s, s)
	# vəziyyət çipləri
	var chips := []
	var eng_on: bool = truck.engine_state == OffroadTruck.EngineState.RUNNING
	chips.append(["MÜH" if truck.engine_state != OffroadTruck.EngineState.CRANKING else "...", eng_on])
	var hl: int = truck.lights.headlight_mode
	chips.append([["FƏNƏR", "YAXIN", "UZAQ"][hl], hl > 0])
	chips.append(["QƏZA", truck.lights.hazard and int(Time.get_ticks_msec() / 400) % 2 == 0])
	var awd_always: bool = truck.spec["awd"] == "always"
	chips.append(["4×4", truck.awd_on or awd_always])
	chips.append(["DİF", truck.spec["diff"] != "none" and truck.diff_lock])
	chips.append(["LOW", truck.low_range])
	var cw := (pw - 28.0 * s - 5.0 * 5.0 * s) / 6.0
	for k in chips.size():
		_chip(o + Vector2(14.0 * s + k * (cw + 5.0 * s), ph - 26.0 * s), cw, chips[k][0], chips[k][1], s)
	var gap := 10.0 * s
	var bx := panel.position.x
	var bw := pw / 3.0
	var by := y0
	if truck.engine_state == OffroadTruck.EngineState.OFF:
		var pa := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		_text_c("Mühərriki işə salmaq üçün I düyməsinə bas", Vector2(bx + (bw * 3.0) * 0.5, by - 10.0 * s), int(14 * s), Color(1, 0.8, 0.3, pa))

	# düymə göstərişi: ilk 16 saniyə, sonra H ilə
	var hint_a := 0.5 if _hints_forced else clampf((16.0 - _t) / 3.0, 0.0, 1.0) * 0.5
	if hint_a > 0.01:
		_text_c("W/S qaz  ·  A/D sükan  ·  Space əl əyləci  ·  Siçan kamera  ·  V rejim  ·  I mühərrik  ·  L fənər  ·  Z qəza  ·  N gecə  ·  Q diapazon  ·  E AWD  ·  F diferensial  ·  T təkər  ·  R bərpa  ·  M xəritə  ·  Esc menyu  ·  G tros  ·  Y ağac  ·  B çək  ·  H göstəriş",
			Vector2(sz.x * 0.5, sz.y - 7.0 * s), int(11 * s), Color(1, 1, 1, hint_a))

	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.4, 0.0, 1.0)
		_text_c(_toast, Vector2(sz.x * 0.5, sz.y - m - h - 65.0 * s), int(22 * s), Color(1, 1, 1, a))


# --- kompakt göstəricilər ---------------------------------------------------------

func _draw_speed_ring(c: Vector2, r: float, s: float) -> void:
	var frac := clampf(_speed_smooth / speed_scale(), 0.0, 1.0)
	draw_circle(c, r + 4.0 * s, Color(0, 0, 0, 0.3))
	draw_arc(c, r, A_START, A_START + A_SWEEP, 64, Color(1, 1, 1, 0.10), 4.0 * s, true)
	var col := CYAN.lerp(ORANGE, smoothstep(0.6, 0.85, frac)).lerp(RED, smoothstep(0.9, 1.0, frac))
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 64, col, 4.0 * s, true)
		var tip := A_START + A_SWEEP * frac
		draw_circle(c + Vector2(cos(tip), sin(tip)) * r, 3.2 * s, Color.WHITE)
	_text_c(str(int(round(_speed_smooth))), c + Vector2(0, 9.0 * s), int(30 * s), Color.WHITE)
	_text_c("km/h", c + Vector2(0, 24.0 * s), int(9 * s), DIM)


func _draw_gear_rpm(o: Vector2, s: float) -> void:
	var box := Rect2(o, Vector2(38, 38) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.95)
	sb.set_corner_radius_all(int(8 * s))
	sb.border_color = Color(0.92, 0.78, 0.42, 0.7)
	sb.set_border_width_all(maxi(1, int(1.5 * s)))
	draw_style_box(sb, box)
	var gear_txt := "R" if truck.gear < 0 else str(truck.gear)
	if truck.shift_remaining > 0.0:
		gear_txt = "·"
	_text_c(gear_txt, box.get_center() + Vector2(0, 8.0 * s), int(22 * s), Color.WHITE)
	if truck.low_range:
		_text_c("L", box.position + Vector2(31, 11) * s, int(8 * s), ORANGE)
	# RPM: seqmentli LED zolağı, qırmızı zona redline-dan sonra
	var segs := 22
	var bar_x := o.x + 48.0 * s
	var bar_w := 190.0 * s
	var seg_w := bar_w / segs
	var max_rpm := rpm_scale()
	var frac := clampf(_rpm_smooth / max_rpm, 0.0, 1.0)
	var red_from := float(truck.powertrain["redline"]) / max_rpm
	for k in segs:
		var f := (k + 0.5) / segs
		var lit := f <= frac
		var col := GREEN.lerp(ORANGE, smoothstep(0.5, 0.72, f))
		if f >= red_from - 0.05:
			col = RED
		draw_rect(Rect2(Vector2(bar_x + k * seg_w, o.y + 8.0 * s), Vector2(seg_w - 2.0 * s, 12.0 * s)), col if lit else Color(col, 0.13))
	_text_l("%d RPM" % int(round(_rpm_smooth / 50.0) * 50.0), Vector2(bar_x, o.y + 34.0 * s), int(9 * s), DIM)


func _draw_fuel_bar(o: Vector2, s: float) -> void:
	var frac := clampf(truck.fuel / float(truck.spec["fuel"]), 0.0, 1.0)
	var low := frac < 0.15
	var col := RED if low else (ORANGE if frac < 0.3 else CYAN)
	if low and int(Time.get_ticks_msec() / 350) % 2 == 0:
		col = Color(RED, 0.35)
	_text_l("YANACAQ", o + Vector2(0, 8) * s, int(8 * s), DIM)
	var bar := Rect2(o + Vector2(48, 1) * s, Vector2(146, 7) * s)
	draw_rect(bar, PILL)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), col)
	_text_l("%d L" % int(truck.fuel), o + Vector2(200, 9) * s, int(10 * s), Color.WHITE)


func _chip(pos: Vector2, w: float, text: String, on: bool, s: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CYAN, 0.18) if on else Color(0.08, 0.1, 0.14, 0.85)
	sb.set_corner_radius_all(int(6 * s))
	sb.border_color = CYAN if on else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	draw_style_box(sb, Rect2(pos, Vector2(w, 18.0 * s)))
	_text_c(text, pos + Vector2(w * 0.5, 13.0 * s), int(9 * s), Color.WHITE if on else Color(1, 1, 1, 0.45))


# --- spidometr -------------------------------------------------------------------

func _draw_speedo(c: Vector2, r: float, s: float) -> void:
	var max_kmh := speed_scale()
	draw_circle(c, r + 6.0 * s, Color(0, 0, 0, 0.35))
	draw_arc(c, r, A_START, A_START + A_SWEEP, 72, Color(1, 1, 1, 0.12), 6.0 * s, true)
	var frac := clampf(_speed_smooth / max_kmh, 0.0, 1.0)
	var col := CYAN.lerp(ORANGE, smoothstep(0.55, 0.85, frac)).lerp(RED, smoothstep(0.88, 1.0, frac))
	if frac > 0.003:
		draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 72, col, 6.0 * s, true)
	for k in range(0, int(max_kmh / 10.0) + 1):
		var a := A_START + A_SWEEP * (float(k) * 10.0 / max_kmh)
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
	_text_c("KM/H", c + Vector2(0, 41.0 * s), int(9 * s), DIM)


# --- RPM və dişli ------------------------------------------------------------------

func _draw_rpm(c: Vector2, r: float, s: float) -> void:
	var max_rpm := rpm_scale()
	draw_arc(c, r, A_START, A_START + A_SWEEP, 54, Color(1, 1, 1, 0.12), 5.0 * s, true)
	var red_from := float(truck.powertrain["redline"]) / max_rpm
	for mark in range(0,int(max_rpm/1000.0)+1):
		var angle := A_START+A_SWEEP*float(mark)*1000.0/max_rpm
		var direction := Vector2(cos(angle),sin(angle))
		draw_line(c+direction*(r-7.0*s),c+direction*(r-2.0*s),DIM,1.0*s,true)
	draw_arc(c, r, A_START + A_SWEEP * red_from, A_START + A_SWEEP, 16, Color(RED, 0.5), 5.0 * s, true)
	var frac := clampf(_rpm_smooth / max_rpm, 0.0, 1.0)
	var col := GREEN.lerp(ORANGE, smoothstep(0.5, 0.74, frac)).lerp(RED, smoothstep(0.74, 0.86, frac))
	draw_arc(c, r, A_START, A_START + A_SWEEP * frac, 54, col, 5.0 * s, true)
	var gear_txt := "R" if truck.gear < 0 else str(truck.gear)
	if truck.shift_remaining > 0.0:
		gear_txt = "·"
	_text_c(gear_txt, c + Vector2(0, 9.0 * s), int(26 * s), Color.WHITE)
	_text_c("DİŞLİ", c + Vector2(0, -16.0 * s), int(8 * s), DIM)
	_text_c("%d RPM" % int(round(_rpm_smooth / 10.0) * 10.0), c + Vector2(0, r + 12.0 * s), int(9 * s), DIM)


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


func speed_scale() -> float:
	return ceilf(float(truck.powertrain["top"]) / 20.0) * 20.0


func rpm_scale() -> float:
	return ceilf(float(truck.powertrain["redline"]) / 1000.0) * 1000.0
