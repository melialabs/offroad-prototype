class_name MainMenu
extends Control
## Ana menyu: oyun başlayanda (və Esc ilə oyun içində) açılır. Arxa planda dünya və maşın
## yavaş fırlanan kamera ilə görünür. Səhifələr: ana, texnika seçimi, idarəetmə, ayarlar.
## Klaviatura (yuxarı/aşağı/Enter/Esc) və siçanla idarə olunur.

signal start_requested
signal resume_requested
signal restart_requested
signal quit_requested

const CYAN := Color(0.25, 0.85, 1.0)
const ORANGE := Color(1.0, 0.58, 0.12)
const BTN_W := 360.0

var main: Node  # set_fullscreen(), set_shadows(), select_vehicle() metodları
var truck: OffroadTruck
var in_game := false

var _pages := {}
var _page := "main"
var _vehicle_buttons: Array[Button] = []
var _btn_start: Button
var _btn_restart: Button
var _btn_fullscreen: Button
var _btn_shadows: Button
var _btn_night: Button
var _btn_sound: Button
var _sound := true
var _fullscreen := false
var _shadows := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open(game_running: bool) -> void:
	in_game = game_running
	_btn_start.text = "Davam et" if in_game else "Oyuna başla"
	_btn_restart.visible = in_game
	_refresh_vehicle_buttons()
	_show_page("main")
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _page != "main":
			_show_page("main")
		elif in_game:
			resume_requested.emit()


# --- qurulum -----------------------------------------------------------------------

func _build() -> void:
	# solda tünd, sağa doğru şəffaflaşan fon
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.05, 0.92), Color(0.02, 0.03, 0.05, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.anchor_right = 0.62
	bg.offset_right = 0.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # sütun düymə enində qalsın, arxa plan görünsün
	margin.add_child(col)

	var title := Label.new()
	title.text = "OFFROAD"
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var accent := ColorRect.new()
	accent.color = ORANGE
	accent.custom_minimum_size = Vector2(110, 5)
	col.add_child(accent)
	var sub := Label.new()
	sub.text = "Palçıq. Yük. Çətin yollar."
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	col.add_child(spacer)

	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(holder)
	_pages["main"] = _build_main()
	_pages["vehicle"] = _build_vehicle()
	_pages["controls"] = _build_controls()
	_pages["settings"] = _build_settings()
	for k in _pages:
		holder.add_child(_pages[k])

	var footer := Label.new()
	footer.text = "Prototip  ·  Godot 4.4"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 90
	footer.offset_top = -34
	add_child(footer)


func _build_main() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_btn_start = _button("Oyuna başla", _on_start)
	v.add_child(_btn_start)
	_btn_restart = _button("Yenidən başla (yolun üstünə)", func(): restart_requested.emit())
	v.add_child(_btn_restart)
	v.add_child(_button("Qaraj", func(): _show_page("vehicle")))
	v.add_child(_button("İdarəetmə", func(): _show_page("controls")))
	v.add_child(_button("Ayarlar", func(): _show_page("settings")))
	v.add_child(_button("Çıxış", func(): quit_requested.emit()))
	return v


func _build_vehicle() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = "Qaraj: texnikanı seç. Maşın dərhal arxada yolun üstündə dəyişir."
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for i in OffroadTruck.SPECS.size():
		var b := _button("", func(): _select_vehicle(i), 84.0)
		_vehicle_buttons.append(b)
		grid.add_child(b)
	v.add_child(_button("Geri", func(): _show_page("main")))
	return v


func _build_controls() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var rows := [
		["Sürüş", ""],
		["W / S", "qaz / əyləc və geri"],
		["A / D", "sükan"],
		["Space", "əl əyləci"],
		["R", "maşını yolun üstünə qaytar"],
		["I", "mühərriki işə sal / söndür"],
		["L", "fənərlər: söndür / yaxın / uzaq"],
		["Z", "qəza işıqları"],
		["N", "gündüz / gecə"],
		["Kamera", ""],
		["V", "yaxın / uzaq / kapot kamerası"],
		["Transmissiya", ""],
		["Q", "aşağı / yuxarı diapazon"],
		["E", "AWD aç / bağla"],
		["F", "diferensial kilidi"],
		["T", "təkər növü"],
		["Digər", ""],
		["1 – 6", "texnika (Skaut, Yük maşını, Ağır tır, Niva, 2107, 2106)"],
		["H", "düymə göstərişini aç / bağla"],
		["Esc", "menyu"],
	]
	for r in rows:
		if r[1] == "":
			var t := Label.new()
			t.text = r[0]
			t.add_theme_font_size_override("font_size", 17)
			t.add_theme_color_override("font_color", ORANGE)
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(0, 6)
			v.add_child(pad)
			v.add_child(t)
		else:
			var line := HBoxContainer.new()
			var k := Label.new()
			k.text = r[0]
			k.custom_minimum_size = Vector2(120, 0)
			k.add_theme_font_size_override("font_size", 16)
			k.add_theme_color_override("font_color", CYAN)
			var d := Label.new()
			d.text = r[1]
			d.add_theme_font_size_override("font_size", 16)
			d.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			line.add_child(k)
			line.add_child(d)
			v.add_child(line)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(0, 10)
	v.add_child(pad2)
	v.add_child(_button("Geri", func(): _show_page("main")))
	return v


func _build_settings() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_btn_fullscreen = _button("", _toggle_fullscreen)
	v.add_child(_btn_fullscreen)
	_btn_shadows = _button("", _toggle_shadows)
	v.add_child(_btn_shadows)
	_btn_night = _button("", _toggle_night)
	v.add_child(_btn_night)
	_btn_sound = _button("", _toggle_sound)
	v.add_child(_btn_sound)
	v.add_child(_button("Geri", func(): _show_page("main")))
	_refresh_settings()
	return v


# --- hərəkət ---------------------------------------------------------------------------

func _on_start() -> void:
	if in_game:
		resume_requested.emit()
	else:
		start_requested.emit()


func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	if main != null:
		main.set_fullscreen(_fullscreen)
	_refresh_settings()


func _toggle_sound() -> void:
	_sound = not _sound
	if main != null:
		main.set_sound(_sound)
	_refresh_settings()


func _toggle_night() -> void:
	if main != null:
		main.set_night(not main.night)
	_refresh_settings()


func _toggle_shadows() -> void:
	_shadows = not _shadows
	if main != null:
		main.set_shadows(_shadows)
	_refresh_settings()


func _show_page(p: String) -> void:
	_page = p
	for k in _pages:
		(_pages[k] as Control).visible = (k == p)
	var first := _first_button(_pages[p])
	if first != null:
		first.grab_focus()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).visible:
			return c
		if c is GridContainer:
			var f := _first_button(c)
			if f != null:
				return f
	return null


func _select_vehicle(i: int) -> void:
	if main != null:
		main.select_vehicle(i)
	_refresh_vehicle_buttons()


func _refresh_vehicle_buttons() -> void:
	for i in _vehicle_buttons.size():
		var sp: Dictionary = OffroadTruck.SPECS[i]
		var awd: String = {"always": "həmişə", "switch": "açar-bağla"}.get(sp["awd"], "yox")
		var diff: String = {"none": "yoxdur", "switch": "var", "always": "həmişə"}.get(sp["diff"], "yox")
		var cur := truck != null and truck.spec_idx == i
		_vehicle_buttons[i].text = "%s%s\nKütlə %d kq  ·  moment %d N·m  ·  yanacaq %d L\nAWD: %s  ·  diferensial kilidi: %s" % [
			"✓ " if cur else "", sp["name"], int(sp["mass"]), int(sp["torque"]), int(sp["fuel"]), awd, diff]


func _refresh_settings() -> void:
	_btn_fullscreen.text = "Tam ekran:  " + ("açıq" if _fullscreen else "bağlı")
	_btn_shadows.text = "Kölgələr:  " + ("açıq" if _shadows else "bağlı")
	var is_night: bool = main != null and main.night
	_btn_sound.text = "Səs:  " + ("açıq" if _sound else "bağlı")
	_btn_night.text = "Vaxt:  " + ("Gecə" if is_night else "Gündüz")


# --- düymə üslubu -------------------------------------------------------------------------

func _style(bg: Color, border: Color, accent_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = accent_w
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _button(text: String, on_press: Callable, height: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BTN_W, height)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(Color(0.05, 0.07, 0.1, 0.78), Color(1, 1, 1, 0.08), 1))
	b.add_theme_stylebox_override("hover", _style(Color(0.07, 0.16, 0.22, 0.92), CYAN, 5))
	b.add_theme_stylebox_override("focus", _style(Color(0.07, 0.16, 0.22, 0.92), CYAN, 5))
	b.add_theme_stylebox_override("pressed", _style(Color(0.1, 0.28, 0.36, 0.95), CYAN, 5))
	b.pressed.connect(on_press)
	return b
