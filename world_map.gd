class_name WorldMap
extends Control
## Bottom-left GPS is always visible; M expands the same map.

var activities: HillClimbActivity
var terrain: MudTerrain
var truck: OffroadTruck
var opened := false
var _ticks := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
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
	var viewport_size := get_viewport_rect().size
	var scale_ui := clampf(viewport_size.y / 900.0, 0.7, 1.5)
	var side := minf(viewport_size.y - 180.0, viewport_size.x - 300.0) if opened else 206.0 * scale_ui
	var origin := Vector2(14.0 * scale_ui, viewport_size.y - side - 42.0 * scale_ui)
	var panel := Rect2(origin - Vector2(4, 25) * scale_ui, Vector2(side + (240.0 if opened else 8.0 * scale_ui), side + 52.0 * scale_ui))
	draw_rect(panel, Color(0.025, 0.04, 0.04, 0.96))
	draw_string(font, origin - Vector2(0, 7) * scale_ui, "GPS · N ↑   M: xəritə", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * scale_ui), Color.WHITE)
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
		if opened:
			draw_string(font, screen + Vector2(7, -6), str(row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			draw_string(font, origin + Vector2(side + 20, 30 + row * 30), "%d. %s" % [row + 1, place[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		row += 1
	_draw_activities(origin,side)
	var vehicle := Vector2(truck.global_position.x, truck.global_position.z)
	var current := origin + (vehicle + Vector2.ONE * 1024) / 2048.0 * side
	draw_circle(current, 6.0, Color(0.2, 0.95, 1))
	var heading := Vector2(truck.global_basis.z.x, truck.global_basis.z.z).normalized()
	draw_line(current, current + heading * 16, Color(0.2, 0.95, 1), 3.0)
	draw_string(font, origin + Vector2(0, side + 19 * scale_ui), "X %d   Z %d · 2 km" % [vehicle.x, vehicle.y], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * scale_ui), Color(0.6, 0.9, 0.87))
	for swamp in MudTerrain.SWAMPS:
		var mark := origin + (Vector2(swamp.x, swamp.y) + Vector2.ONE * 1024) / 2048.0 * side
		draw_circle(mark, maxf(3.0, swamp.z / 2048.0 * side), Color(0.26, 0.14, 0.05, 0.8))
	if opened:
		draw_string(font, origin + Vector2(side + 20, 220), "Açıq: asfalt", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.86, 0.69))
		draw_string(font, origin + Vector2(side + 20, 250), "Qəhvəyi: bataqlıq", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.5, 0.25))
		if activities != null:
			draw_string(font,origin+Vector2(side+20,280),"▲ Hill Climb · 12 routes",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1,0.78,0.3))


func _draw_activities(origin: Vector2, side: float) -> void:
	if activities == null:
		return
	for i in activities.markers.size():
		if not activities.marker_enabled(i):
			continue
		var marker: Dictionary = activities.markers[i]
		var p: Vector3 = marker["p"]
		var at := origin + (Vector2(p.x,p.z)+Vector2.ONE*1024)/2048.0*side
		var color: Color = HillClimbCatalog.COLORS[activities.routes[marker["route"]]["difficulty"]]
		var radius := 5.0 if opened or marker["hub"] else 2.8
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,radius),at+Vector2(-radius,radius)]),color)
		if opened:
			draw_string(ThemeDB.fallback_font,at+Vector2(6,0),"HC" if marker["hub"] else str(int(marker["route"])+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	if activities.engaged():
		var route: Dictionary = activities.routes[activities.active_index]
		var line := PackedVector2Array()
		for p in route["points"]:
			line.append(origin+(p+Vector2.ONE*1024)/2048.0*side)
		draw_polyline(line,Color(1,0.75,0.24),2.5,true)
		if route.has("alternative"):
			var bypass := PackedVector2Array()
			for p in route["alternative"]:
				bypass.append(origin+(p+Vector2.ONE*1024)/2048.0*side)
			draw_polyline(bypass,Color(0.4,0.9,0.7),2,true)
		if activities.next_checkpoint < activities.checkpoints.size():
			var p: Vector3 = activities.checkpoints[activities.next_checkpoint]
			draw_circle(origin+(Vector2(p.x,p.z)+Vector2.ONE*1024)/2048.0*side,5,Color.WHITE)
