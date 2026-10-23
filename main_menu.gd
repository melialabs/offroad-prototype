class_name MainMenu
extends Control
## Ana menyu: oyun başlayanda tam ekran şəkillə (loqo + sağda menyu), oyun içində Esc ilə isə dünyanın
## üstündə sis fonu ilə açılır. Səhifələr: ana, qaraj, idarəetmə, ayarlar. İki dil: EN / AZ (I18n).
## Klaviatura (yuxarı/aşağı/Enter/Esc) və siçanla idarə olunur.

signal start_requested
signal resume_requested
signal restart_requested
signal quit_requested

const INK := Color(0.09, 0.10, 0.11)
const RUST := Color(0.70, 0.27, 0.04)
const FOG := Color(0.87, 0.89, 0.91)
const BTN_W := 400.0
const BG_PATH := "res://assets/ui/menu_bg.jpg"
const LOGO_PATH := "res://assets/ui/menu_logo.png"
const BG_SHADER := "res://menu_bg.gdshader"
const BG_CTRL_PATH := "res://assets/ui/menu_bg_ctrl.png"

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
var _btn_lang: Button
var _sound := true
var _fullscreen := false
var _shadows := true

var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _clock := 0.0
var _fog: TextureRect
var _panel: PanelContainer
var _holder: VBoxContainer
var _lang_buttons := {}
var _footer: Label
var _logo: TextureRect
var _tagline: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open(game_running: bool) -> void:
	in_game = game_running
	_bg.visible = not in_game and _page != "vehicle"
	_fog.visible = true
	_fog.anchor_left = 0.4 if in_game else 0.66
	_fog.modulate.a = 1.0 if in_game else 0.7
	_btn_start.text = I18n.t("m_continue") if in_game else I18n.t("m_start")
	_btn_restart.visible = in_game
	_refresh_vehicle_buttons()
	_show_page("main")
	visible = true


func _process(delta: float) -> void:
	if not visible or in_game or _bg_mat == null:
		return
	_clock += delta
	_bg_mat.set_shader_parameter("t", _clock)
	_bg_mat.set_shader_parameter("rect_size", _bg.size)


## Rüzgarla sağa doğru süzülən sis zərrəcikləri və tozlar.
func _make_drift_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 380)
	p.position = Vector2(640, 360)
	p.direction = Vector2(1, 0.25)
	p.spread = 25.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(14, 6)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.8
	p.color = Color(1, 1, 1, 0.45)
	p.local_coords = false
	return p


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
	# başlanğıc ekranı: tam ekran şəkil (təsvir kadrı doldurur, kənarlar kəsilir)
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(BG_PATH):
		var sm := ShaderMaterial.new()
		sm.shader = load(BG_SHADER)
		sm.set_shader_parameter("tex", load(BG_PATH))
		sm.set_shader_parameter("ctrl", load(BG_CTRL_PATH))
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 3
		var nt := NoiseTexture2D.new()
		nt.noise = noise
		nt.seamless = true
		nt.width = 512
		nt.height = 512
		sm.set_shader_parameter("fog_noise", nt)
		_bg.material = sm
		_bg_mat = sm
	add_child(_bg)
	_bg.add_child(_make_drift_particles())

	# oyun içində: sağa doğru qalınlaşan sis (dünya görünür qalır)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(FOG, 0.0), Color(FOG, 0.88)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	_fog = TextureRect.new()
	_fog.texture = gt
	_fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog.stretch_mode = TextureRect.STRETCH_SCALE
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.anchor_left = 0.4
	add_child(_fog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_left", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	_panel = PanelContainer.new()
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	_logo = TextureRect.new()
	var logo := _logo
	if ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(BTN_W, 197)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo)
	var sub := Label.new()
	_tagline = sub
	sub.name = "Tagline"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(INK, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	col.add_child(spacer)

	_holder = VBoxContainer.new()
	_holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(_holder)

	# dil seçimi: yuxarı sağ küncdə EN | AZ
	var langbox := HBoxContainer.new()
	langbox.add_theme_constant_override("separation", 4)
	langbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	langbox.offset_left = -170
	langbox.offset_right = -24
	langbox.offset_top = 16
	add_child(langbox)
	for code in I18n.LANGS:
		var lb := Button.new()
		lb.text = str(code).to_upper()
		lb.flat = true
		lb.focus_mode = Control.FOCUS_NONE
		lb.add_theme_font_size_override("font_size", 16)
		lb.pressed.connect(func(): _set_language(code))
		langbox.add_child(lb)
		_lang_buttons[code] = lb

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_footer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_footer.add_theme_constant_override("outline_size", 4)
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_footer.offset_left = 36
	_footer.offset_top = -34
	add_child(_footer)
	_populate()


## Səhifələri cari dildə (yenidən) qurur.
func _populate() -> void:
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	_pages.clear()
	_vehicle_buttons.clear()
	_pages["main"] = _build_main()
	_pages["vehicle"] = _build_vehicle()
	_pages["controls"] = _controls_scroll()
	_pages["settings"] = _build_settings()
	for k in _pages:
		_holder.add_child(_pages[k])
	(_panel.get_child(0).get_node("Tagline") as Label).text = I18n.t("tagline")
	_footer.text = I18n.t("footer") + "  ·  Godot 4.7"
	for code in _lang_buttons:
		var active: bool = code == I18n.lang
		var lb: Button = _lang_buttons[code]
		lb.add_theme_color_override("font_color", RUST if active else Color(INK, 0.7))
		lb.add_theme_color_override("font_hover_color", RUST)
		lb.add_theme_color_override("font_pressed_color", RUST)
		lb.add_theme_color_override("font_focus_color", RUST)
	_btn_start.text = I18n.t("m_continue") if in_game else I18n.t("m_start")
	_btn_restart.visible = in_game
	_refresh_vehicle_buttons()
	_refresh_settings()
	_show_page(_page if _pages.has(_page) else "main")


func _set_language(code: String) -> void:
	I18n.set_language(code)
	_populate()


func _build_main() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_btn_start = _main_button(I18n.t("m_start"), _on_start)
	v.add_child(_btn_start)
	_btn_restart = _main_button(I18n.t("m_restart"), func(): restart_requested.emit())
	v.add_child(_btn_restart)
	v.add_child(_main_button(I18n.t("m_garage"), func(): _show_page("vehicle")))
	v.add_child(_main_button(I18n.t("m_controls"), func(): _show_page("controls")))
	v.add_child(_main_button(I18n.t("m_options"), func(): _show_page("settings")))
	v.add_child(_main_button(I18n.t("m_quit"), func(): quit_requested.emit()))
	return v


func _build_vehicle() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = I18n.t("garage_hint")
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(INK, 0.75))
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BTN_W + 20.0, clampf(get_viewport_rect().size.y - 230, 260, 560))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	v.add_child(scroll)
	for i in OffroadTruck.SPECS.size():
		var b := _card_button("", func(): _select_vehicle(i), 96.0)
		var thumb := "res://assets/ui/car_%d.png" % i
		if ResourceLoader.exists(thumb):
			b.icon = load(thumb)
			b.expand_icon = false
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_constant_override("icon_max_width", 150)
			b.add_theme_constant_override("h_separation", 14)
			b.add_theme_font_size_override("font_size", 16)
		b.visible = i not in OffroadTruck.HIDDEN_SPECS
		_vehicle_buttons.append(b)
		grid.add_child(b)
	v.add_child(_card_button(I18n.t("back"), func(): _show_page("main"), 48.0))
	return v


func _build_controls() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var rows := [
		["c_drive", ""],
		["W / S", "c_wasd_w"],
		["A / D", "c_wasd_a"],
		["Space", "c_space"],
		["R", "c_r"],
		["G / Y / B", "c_gyb"],
		["I", "c_i"],
		["L", "c_l"],
		["Z", "c_z"],
		["N", "c_n"],
		["c_camera", ""],
		["Mouse", "c_mouse"],
		["V", "c_v"],
		["c_trans", ""],
		["Q", "c_q"],
		["E", "c_e"],
		["F", "c_f"],
		["T", "c_t"],
		["c_other", ""],
		["1 – 6", "c_nums"],
		["C", "c_c"],
		["M", "c_m"],
		["Backspace", "c_bksp"],
		["[ / ]", "c_brk"],
		["H", "c_h"],
		["Esc", "c_esc"],
	]
	for r in rows:
		if r[1] == "":
			var t := Label.new()
			t.text = I18n.t(r[0])
			t.add_theme_font_size_override("font_size", 18)
			t.add_theme_color_override("font_color", RUST)
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(0, 6)
			v.add_child(pad)
			v.add_child(t)
		else:
			var line := HBoxContainer.new()
			var k := Label.new()
			k.text = r[0]
			k.custom_minimum_size = Vector2(130, 0)
			k.add_theme_font_size_override("font_size", 16)
			k.add_theme_color_override("font_color", INK)
			var d := Label.new()
			d.text = I18n.t(r[1])
			d.add_theme_font_size_override("font_size", 16)
			d.add_theme_color_override("font_color", Color(INK, 0.85))
			line.add_child(k)
			line.add_child(d)
			v.add_child(line)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(0, 10)
	v.add_child(pad2)
	v.add_child(_card_button(I18n.t("back"), func(): _show_page("main"), 48.0))
	return v


func _build_settings() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_btn_fullscreen = _card_button("", _toggle_fullscreen, 52.0)
	v.add_child(_btn_fullscreen)
	_btn_shadows = _card_button("", _toggle_shadows, 52.0)
	v.add_child(_btn_shadows)
	_btn_night = _card_button("", _toggle_night, 52.0)
	v.add_child(_btn_night)
	_btn_sound = _card_button("", _toggle_sound, 52.0)
	v.add_child(_btn_sound)
	_btn_lang = _card_button("", _cycle_language, 52.0)
	v.add_child(_btn_lang)
	v.add_child(_card_button(I18n.t("back"), func(): _show_page("main"), 48.0))
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


func _cycle_language() -> void:
	_set_language(I18n.LANGS[(I18n.LANGS.find(I18n.lang) + 1) % I18n.LANGS.size()])


func _show_page(p: String) -> void:
	var was_garage := _page == "vehicle"
	_page = p
	if main != null and main.has_method("enter_garage"):
		if p == "vehicle":
			main.enter_garage()
		elif was_garage:
			main.leave_garage()
	_bg.visible = not in_game and p != "vehicle"
	_fog.visible = p != "vehicle"
	_logo.visible = p != "vehicle"
	_tagline.visible = p != "vehicle"
	for k in _pages:
		(_pages[k] as Control).visible = (k == p)
	# ana səhifədə panel şəffaf, alt səhifələrdə sis fonlu kart
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(FOG, 0.0 if p == "main" else (0.82 if p == "vehicle" else 0.93))
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(0 if p == "main" else 22)
	_panel.add_theme_stylebox_override("panel", sb)
	var first := _first_button(_pages[p])
	if first != null:
		first.grab_focus()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).visible:
			return c
		if c is GridContainer or c is ScrollContainer or c is VBoxContainer:
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
		var awd: String = I18n.t(str({"always": "always", "switch": "switch"}.get(sp["awd"], "none")))
		var diff: String = I18n.t(str({"none": "none", "switch": "has", "always": "always"}.get(sp["diff"], "none")))
		var cur := truck != null and truck.spec_idx == i
		var bank: Dictionary = VehicleEngineAudio.BANKS[i if i < VehicleEngineAudio.BANKS.size() else 0]
		_vehicle_buttons[i].tooltip_text = str(bank["label"])
		_vehicle_buttons[i].text = "%s%s\n%d %s  ·  %d N·m  ·  %d L\n%s: %s  ·  %s: %s" % [
			"✓ " if cur else "", I18n.vehicle(str(sp["name"])), int(sp["mass"]), I18n.t("kg"),
			int(VehicleDynamics.for_vehicle(i)["torque"]), int(sp["fuel"]), I18n.t("awd"), awd, I18n.t("diff"), diff]
		var unlocked := VehicleProgress.is_unlocked(i)
		_vehicle_buttons[i].disabled = not unlocked
		_vehicle_buttons[i].modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.55)
		if not unlocked:
			_vehicle_buttons[i].text = "%s\n???\n%s" % [I18n.t("locked"), I18n.t("locked_hint")]


func _refresh_settings() -> void:
	var is_night: bool = main != null and main.night
	_btn_fullscreen.text = "%s:  %s" % [I18n.t("fullscreen"), I18n.t("on" if _fullscreen else "off")]
	_btn_shadows.text = "%s:  %s" % [I18n.t("shadows"), I18n.t("on" if _shadows else "off")]
	_btn_sound.text = "%s:  %s" % [I18n.t("sound"), I18n.t("on" if _sound else "off")]
	_btn_night.text = "%s:  %s" % [I18n.t("time"), I18n.t("night" if is_night else "day")]
	_btn_lang.text = "%s:  %s" % [I18n.t("language"), I18n.LANG_NAMES[I18n.lang]]


# --- düymə üslubu -------------------------------------------------------------------------

func _flat(bg: Color, left: int = 0, border: Color = Color(0, 0, 0, 0), margin_left: float = 20.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.border_width_left = left
	sb.set_corner_radius_all(2)
	sb.content_margin_left = margin_left
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Ana səhifə: şəffaf, tünd yazı; seçiləndə tünd zolaq, ağ yazı və sağda ›
func _main_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BTN_W, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var on := _flat(Color(0.08, 0.08, 0.09, 0.93), 0, Color(0, 0, 0, 0), 20.0)
	b.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 20.0))
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("focus", on)
	b.add_theme_stylebox_override("pressed", on)
	var chev := Label.new()
	chev.text = "›"
	chev.add_theme_font_size_override("font_size", 28)
	chev.add_theme_color_override("font_color", Color.WHITE)
	chev.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chev.offset_left = -34
	chev.offset_right = -12
	chev.offset_top = -20
	chev.offset_bottom = 20
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.visible = false
	b.add_child(chev)
	var sync := func(): chev.visible = b.has_focus() or b.is_hovered()
	b.focus_entered.connect(sync)
	b.focus_exited.connect(sync)
	b.mouse_entered.connect(sync)
	b.mouse_exited.connect(sync)
	b.pressed.connect(on_press)
	return b


## Alt səhifələr (qaraj, ayarlar): yarımşəffaf ağ kart, tünd yazı
func _card_button(text: String, on_press: Callable, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BTN_W, height)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var on := _flat(Color(0.08, 0.08, 0.09, 0.93), 0, Color(0, 0, 0, 0), 20.0)
	b.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.5), 0, Color(0, 0, 0, 0.14), 20.0))
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("focus", on)
	b.add_theme_stylebox_override("pressed", on)
	b.pressed.connect(on_press)
	return b


func _controls_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, clampf(get_viewport_rect().size.y - 380, 220, 380))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_build_controls())
	return scroll
