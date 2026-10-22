class_name HillClimbUI
extends Control
var activity: HillClimbActivity
var _results: PanelContainer
var _title: Label
var _summary: Label
var _detail: Label
var _next: Button
var _flash := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results = PanelContainer.new()
	_results.custom_minimum_size = Vector2(480,300)
	_results.add_theme_stylebox_override("panel",_style(Color(0.025,0.045,0.05,0.97)))
	add_child(_results)
	var margin := MarginContainer.new()
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(edge,24)
	_results.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margin.add_child(box)
	_title = _label(box,28,Color(1,0.80,0.35))
	_summary = _label(box,19,Color.WHITE)
	_detail = _label(box,15,Color(0.65,0.78,0.79))
	_button(box,"Replay  ·  R / Enter",activity.retry)
	_next = _button(box,"Next Challenge  ·  Tab",activity.next_challenge)
	_button(box,"Free Roam  ·  Backspace",activity.exit_challenge)
	activity.changed.connect(_refresh)
	activity.cue.connect(func(_kind: String): _flash = 0.5)
	_refresh()

func _label(parent: Control, pixels: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(0.5,0.75,0.72,0.25)
	return style

func _refresh() -> void:
	visible = not activity.paused
	_results.visible = activity.state in [HillClimbActivity.State.FAILED,HillClimbActivity.State.RESULTS]
	if _results.visible:
		var route: Dictionary = activity.routes[activity.active_index]
		_title.text = "%s MEDAL" % activity.result_medal.to_upper() if activity.state == HillClimbActivity.State.RESULTS else "TRY AGAIN"
		_summary.text = "%s\n%s · %s" % [route["name"],HillClimbCatalog.DIFFICULTIES[route["difficulty"]],time_text(activity.elapsed)]
		var best := activity.records.record(route["id"],activity.truck.spec_idx)
		_detail.text = ("PERSONAL BEST!\n" if activity.personal_best else "") + ("Best: %s · Completed: %d" % [time_text(best["best_time"]),best["completions"]] if activity.state == HillClimbActivity.State.RESULTS else activity.failure_reason)
		if activity.state == HillClimbActivity.State.RESULTS and not activity.failure_reason.is_empty():
			_detail.text += "\n" + activity.failure_reason
		_next.visible = activity.state == HillClimbActivity.State.RESULTS and activity.next_enabled(activity.active_index) != activity.active_index
	queue_redraw()

func _process(delta: float) -> void:
	_flash = maxf(0,_flash - delta)
	if _results.visible:
		_results.position = (get_viewport_rect().size - _results.size) * 0.5
	queue_redraw()

static func time_text(seconds: float) -> String:
	if seconds <= 0:
		return "—"
	return "%02d:%04.1f" % [int(seconds)/60,fmod(seconds,60)]

func _text(text: String, pos: Vector2, pixels: int, color: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw() -> void:
	if activity.paused:
		return
	var screen := get_viewport_rect().size
	var width := minf(510,screen.x-32)
	var x := (screen.x-width)*0.5
	if activity.state == HillClimbActivity.State.FREE_ROAM and activity.near_marker >= 0:
		var route: Dictionary = activity.routes[activity.selected_index]
		var color: Color = HillClimbCatalog.COLORS[route["difficulty"]]
		draw_style_box(_style(Color(0.025,0.045,0.05,0.94)),Rect2(x,40,width,165))
		_text("EXTREME HILL CLIMB",Vector2(x+20,70),23,color)
		_text(route["name"],Vector2(x+20,98),19)
		var best := activity.records.record(route["id"],activity.truck.spec_idx)
		_text("%s  ·  Best %s  ·  %s" % [HillClimbCatalog.DIFFICULTIES[route["difficulty"]],time_text(best["best_time"]),activity.truck.spec["name"]],Vector2(x+20,125),16)
		_text("Press E to Start" if activity.prompt_ready() else "Stop inside the circle",Vector2(x+20,153),20,color)
		if activity.markers[activity.near_marker]["hub"]:
			_text("[ / ]  Choose route · Your current vehicle is used",Vector2(x+20,181),13,Color(0.7,0.8,0.79))
	elif activity.state in [HillClimbActivity.State.COUNTDOWN,HillClimbActivity.State.RUNNING]:
		var route: Dictionary = activity.routes[activity.active_index]
		draw_style_box(_style(Color(0.025,0.045,0.05,0.93)),Rect2(x,28,width,112))
		_text(route["name"],Vector2(x+18,57),21,HillClimbCatalog.COLORS[route["difficulty"]])
		_text("%s  ·  Checkpoint %d / %d" % [time_text(activity.elapsed),activity.next_checkpoint,activity.checkpoints.size()-1],Vector2(x+18,84),19)
		_text("Gold %s  ·  R: Retry  ·  Backspace: Exit" % time_text(route["gold"]),Vector2(x+18,113),14,Color(0.7,0.8,0.79))
		var progress := float(activity.next_checkpoint-1)/maxi(1,activity.checkpoints.size()-1)
		draw_rect(Rect2(x+18,127,(width-36)*progress,3),Color(1,0.78,0.3))
		if activity.state == HillClimbActivity.State.COUNTDOWN:
			var digit := str(maxi(1,ceili(activity.countdown)))
			_text(digit,screen*0.5-Vector2(30,-20),90,Color(1,0.81,0.38))
		elif activity._off_route_time > 1.0:
			_text("Return to the route  ·  %ds" % ceili(10-activity._off_route_time),Vector2(x+20,168),18,Color(1,0.45,0.25))
		elif activity._idle_time > 10.0:
			_text("Stuck? E: AWD · Q: Low range · F: Diff · T: Tires",Vector2(x,168),16,Color(1,0.8,0.4))
	if _flash > 0 and activity.engaged():
		draw_rect(Rect2(0,0,screen.x,3),Color(1,0.83,0.4,_flash*0.7))
