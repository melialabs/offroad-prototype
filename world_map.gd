class_name WorldMap
extends Control
## M toggles a route overview with the live vehicle position.

var terrain: MudTerrain
var truck: OffroadTruck
var opened := false
var _ticks := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		opened = not opened
		queue_redraw()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_ticks += delta
	if _ticks > 0.1:
		_ticks = 0.0
		queue_redraw()


func _draw() -> void:
	if terrain == null or truck == null:
		return
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	draw_string(font, Vector2(size.x - 190, 30), "M · Xəritə  /  2 × 2 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if not opened:
		return
	var side := minf(size.y - 150.0, size.x - 220.0)
	var origin := (size - Vector2.ONE * side) * 0.5
	var panel := Rect2(origin - Vector2(25, 50), Vector2(side + 260, side + 80))
	draw_rect(panel, Color(0.025, 0.04, 0.04, 0.96))
	draw_string(font, origin - Vector2(0, 20), "DAĞ YOLLARI · 2048 × 2048 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	for z in 32:
		for x in 32:
			var p := Vector3((x + 0.5) * 64.0 - 1024, 0, (z + 0.5) * 64.0 - 1024)
			var height := terrain.height_at(p)
			var color := Color(0.15, 0.29, 0.19).lerp(Color(0.58, 0.55, 0.44), clampf(height / 170.0, 0, 1))
			if height < -2.4:
				color = Color(0.10, 0.33, 0.46)
			draw_rect(Rect2(origin + Vector2(x, z) * side / 32.0, Vector2.ONE * (side / 32.0 + 0.5)), color)
	var road := PackedVector2Array()
	for p in terrain._road:
		road.append(origin + (p + Vector2.ONE * 1024) / 2048.0 * side)
	draw_polyline(road, Color(0.9, 0.86, 0.69), 3.0, true)
	var trail := PackedVector2Array()
	for p in terrain._trail:
		trail.append(origin + (p + Vector2.ONE * 1024) / 2048.0 * side)
	draw_polyline(trail, Color(0.67, 0.38, 0.18), 3.0, true)
	var row := 0
	for place in WorldLandmarks.PLACES:
		var point: Vector2 = place[1]
		var screen := origin + (point + Vector2.ONE * 1024) / 2048.0 * side
		draw_circle(screen, 5.0, Color(1, 0.68, 0.24))
		draw_string(font, screen + Vector2(7, -6), str(row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_string(font, origin + Vector2(side + 20, 30 + row * 30), "%d. %s" % [row + 1, place[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		row += 1
	var vehicle := Vector2(truck.global_position.x, truck.global_position.z)
	var current := origin + (vehicle + Vector2.ONE * 1024) / 2048.0 * side
	draw_circle(current, 6.0, Color(0.2, 0.95, 1))
	var heading := Vector2(truck.global_basis.z.x, truck.global_basis.z.z).normalized()
	draw_line(current, current + heading * 16, Color(0.2, 0.95, 1), 3.0)
	draw_string(font, origin + Vector2(side + 20, 220), "Açıq: asfalt", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.86, 0.69))
	draw_string(font, origin + Vector2(side + 20, 250), "Qəhvəyi: palçıq", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.5, 0.25))
