class_name WinchRecovery
extends Node3D
## Bounded physical winch: only indexed standing trunks can be selected.
## G attach/detach, Y choose another nearby tree, hold B to reel in.
const RANGE := 30.0
const MAX_LENGTH := 40.0
const REEL_SPEED := 1.1
var truck: OffroadTruck
var forest: Vegetation
var attached := false
var anchor: Dictionary = {}
var candidates: Array = []
var selected := 0
var rest_length := 0.0
var tension := 0.0
var pulling := false
var reeling_input := false
var _hook := Vector3.ZERO
var _overload := 0.0
var _last_position := Vector3.ZERO
var _draw_timer := 0.0
var _cable: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _target: MeshInstance3D
var _label: Label

func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.48,0.43,0.3)
	_cable = MeshInstance3D.new()
	_cable.mesh = _mesh
	_cable.material_override = _material
	_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable)
	_target = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.3,1.0,0.6)
	sphere.material = glow
	_target.mesh = sphere
	_target.visible = false
	add_child(_target)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position = Vector2(-330,108)
	_label.size = Vector2(660,65)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x",2)
	_label.add_theme_constant_override("shadow_offset_y",2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)
	truck.vehicle_changed.connect(func(_i): detach())
	_last_position = truck.global_position

func _unhandled_input(event: InputEvent) -> void:
	if truck == null or not truck.controls_enabled or truck.freeze:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_G:
		if attached:
			detach()
			truck.message.emit("Tros ayrıldı")
		else:
			if candidates.is_empty():
				find_targets()
			if not attach_selected():
				truck.message.emit("30 m məsafədə tros üçün açıq, möhkəm ağac tapılmadı")
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_Y and not attached:
		if candidates.is_empty():
			find_targets()
		elif not candidates.is_empty():
			selected = (selected+1)%candidates.size()
		show_target()
		get_viewport().set_input_as_handled()

func hook_position() -> Vector3:
	return truck.to_global(_hook)

func find_targets() -> void:
	candidates.clear()
	selected = 0
	if forest == null:
		return
	for item in forest.winch_anchors(truck.global_position,RANGE):
		if candidates.size() >= 16:
			break
		if line_clear(truck.global_position+Vector3.UP*0.2,item):
			candidates.append(item)
	show_target()

func line_clear(from: Vector3,item: Dictionary) -> bool:
	if not is_instance_valid(item.get("collider")):
		return false
	var query := PhysicsRayQueryParameters3D.create(from,item["point"],1,[truck.get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider := item["collider"] as CollisionShape3D
	var body := collider.get_parent() as CollisionObject3D
	return result["collider"] == body and body.shape_owner_get_owner(body.shape_find_owner(result["shape"])) == collider

func show_target() -> void:
	_target.visible = not candidates.is_empty()
	if _target.visible:
		_target.global_position = candidates[selected]["point"]

func attach_selected() -> bool:
	if candidates.is_empty() or selected >= candidates.size():
		return false
	var item: Dictionary = candidates[selected]
	var direction: Vector3 = item["point"]-truck.global_position
	var front := direction.dot(truck.global_basis.z) >= 0.0
	var box := truck._col.shape as BoxShape3D
	_hook = truck._col.position+Vector3(0,-box.size.y*0.35,(box.size.z*0.5+0.08)*(1.0 if front else -1.0))
	var distance := hook_position().distance_to(item["point"])
	if distance < 2.0 or distance > RANGE or not line_clear(hook_position(),item):
		return false
	anchor = item
	rest_length = distance+0.15
	attached = true
	_overload = 0.0
	_last_position = truck.global_position
	truck.message.emit("Tros bağlandı · B basılı saxla · G ayır")
	return true

func detach() -> void:
	attached = false
	pulling = false
	reeling_input = false
	tension = 0.0
	anchor = {}
	candidates.clear()
	if is_instance_valid(_target):
		_target.visible = false
	_mesh.clear_surfaces()

func _physics_process(delta: float) -> void:
	if truck == null:
		return
	var moved := truck.global_position.distance_to(_last_position)
	_last_position = truck.global_position
	if attached and (moved > 8.0 or not is_instance_valid(anchor.get("collider"))):
		detach()
	if not attached:
		if not candidates.is_empty() and truck.global_position.distance_to(candidates[selected]["point"]) > RANGE:
			detach()
		return
	if not truck.controls_enabled or truck.freeze:
		pulling = false
		return
	var point := hook_position()
	var offset: Vector3 = anchor["point"]-point
	var distance := offset.length()
	if distance > MAX_LENGTH or not line_clear(point,anchor):
		detach()
		truck.message.emit("Tros ayrıldı: maneə və ya məsafə")
		return
	pulling = (reeling_input or Input.is_physical_key_pressed(KEY_B)) and truck.engine_state == OffroadTruck.EngineState.RUNNING and truck.fuel > 0
	if pulling:
		rest_length = maxf(1.8,rest_length-REEL_SPEED*delta)
	var direction := offset/maxf(distance,0.001)
	var extension := maxf(0.0,distance-rest_length)
	var velocity := truck.linear_velocity+truck.angular_velocity.cross(point-truck.global_position)
	var desired := maxf(0.0,extension*45000.0-velocity.dot(direction)*4500.0) if extension > 0.0 else 0.0
	var rated := truck.mass*9.8*1.65
	_overload = _overload+delta if desired > rated*1.8 else maxf(0,_overload-delta*2)
	if _overload > 1.0:
		detach()
		truck.message.emit("Tros həddən artıq gərildi · yenidən bağla")
		return
	tension = minf(desired,rated)
	if tension > 0:
		truck.apply_force(direction*tension,point-truck.global_position)
	if pulling:
		truck.fuel = maxf(0,truck.fuel-delta*0.003)

func _process(delta: float) -> void:
	if truck == null:
		return
	_label.visible = truck.controls_enabled and (attached or not candidates.is_empty())
	_target.visible = _label.visible and not candidates.is_empty()
	if attached:
		_label.text = "TROS · %.1f m · %.0f%% gərginlik\nB: çək  ·  G: ayır%s" % [hook_position().distance_to(anchor["point"]),tension/(truck.mass*9.8*1.65)*100," · Mühərriki I ilə işə sal" if truck.engine_state != OffroadTruck.EngineState.RUNNING else ""]
	elif not candidates.is_empty():
		_label.text = "AĞAC %d/%d · G: tros bağla · Y: ağacı dəyiş" % [selected+1,candidates.size()]
	_draw_timer -= delta
	if attached and _draw_timer <= 0:
		_draw_timer = 0.05
		_draw_cable()

func _draw_cable() -> void:
	_mesh.clear_surfaces()
	var a := to_local(hook_position())
	var b := to_local(anchor["point"])
	var slack := clampf(rest_length-a.distance_to(b),0,2.0)
	_material.albedo_color = Color(0.5,0.46,0.35).lerp(Color(1,0.3,0.1),tension/(truck.mass*9.8*1.65))
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 16:
		for fraction in [float(i)/16.0,float(i+1)/16.0]:
			var p := a.lerp(b,fraction)
			p.y -= sin(fraction*PI)*(0.04+slack*0.5)
			_mesh.surface_add_vertex(p)
	_mesh.surface_end()
