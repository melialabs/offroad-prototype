class_name WheelEffects
extends Node3D
## Maşın-səth vizual effektləri (fizikaya toxunmur, yalnız təkər vəziyyətini oxuyur):
## səthə görə toz (torpaq, çınqıl, ot, asfaltda yalnız sürüşmədə), su sıçraması, təkər izləri
## və maşın altında yumşaq kontakt kölgəsi. Palçıq kəsəkləri MudSpray-dədir; burada palçıq dumanı əlavə olunur.

enum Surface { ASPHALT, DIRT, GRAVEL, GRASS, MUD, WATER }

const SURFACE_DUST := {
	Surface.ASPHALT: Color(0.42, 0.42, 0.43, 0.35),
	Surface.DIRT: Color(0.58, 0.47, 0.33, 0.7),
	Surface.GRAVEL: Color(0.62, 0.6, 0.55, 0.65),
	Surface.GRASS: Color(0.5, 0.46, 0.34, 0.25),
	Surface.MUD: Color(0.25, 0.18, 0.11, 0.45),
}
const TRACK_CAPACITY := 900
const TRACK_STEP := 0.45  # m: iz parçaları arası
const TRACK_LIFE := 45.0  # s

var truck: OffroadTruck
var terrain: MudTerrain
var dust_scale := 1.0

var _dust: Array[GPUParticles3D] = []
var _splash: Array[GPUParticles3D] = []
var _tracks: MultiMesh
var _track_age := PackedFloat32Array()
var _track_strength := PackedFloat32Array()
var _track_cursor := 0
var _last_mark: Array[Vector3] = []
var _shadow: Decal
## HIGH/ULTRA: maşının ətrafını (ağaclar, yer) kuzova əks etdirən probe; yalnız yer dəyişəndə yenilənir
var _probe: ReflectionProbe
var _probe_at := Vector3.INF
var _probe_timer := 0.0


static func classify(t: MudTerrain, p: Vector3) -> int:
	if p.y < t.water_level_at(p) + 0.15:
		return Surface.WATER
	var rd := t.road_distance_fast(p)
	if rd < MudTerrain.ROAD_HALF:
		return Surface.ASPHALT
	var soft := t.softness_at(p)
	if soft > 0.62:
		return Surface.MUD
	if rd < MudTerrain.ROAD_HALF + 3.0:
		return Surface.GRAVEL  # yol çiyni
	if soft > 0.18 or t.slope_at(p) > 0.35:
		return Surface.DIRT
	return Surface.GRASS


func _ready() -> void:
	for k in 4:
		var d := _make_dust()
		add_child(d)
		_dust.append(d)
		var s := _make_splash()
		add_child(s)
		_splash.append(s)
		_last_mark.append(Vector3.INF)
	_make_tracks()
	_make_contact_shadow()
	set_reflection_probe(GraphicsQuality.vehicle_probe(GraphicsQuality.saved_level()))


func _physics_process(_delta: float) -> void:
	if truck == null or terrain == null or truck.wheels.size() < 4:
		return
	_update_shadow()
	var speed := truck.linear_velocity.length()
	for k in 4:
		var w := truck.wheels[k]
		var dust := _dust[k]
		var splash := _splash[k]
		if not w.is_in_contact() or truck.freeze:
			dust.emitting = false
			splash.emitting = false
			continue
		var p := w.get_contact_point()
		var surf := classify(terrain, p)
		var ground_speed := (truck.linear_velocity).length()
		var slip := absf(OffroadSurface.slip_speed(w.get_rpm(), w.wheel_radius, ground_speed))
		# toz: sürət və sürüşmə ilə, asfaltda yalnız güclü sürüşmədə (təkər tüstüsü)
		var amount := 0.0
		match surf:
			Surface.ASPHALT: amount = clampf((slip - 4.0) / 8.0, 0.0, 1.0)
			Surface.DIRT, Surface.GRAVEL: amount = clampf(speed / 14.0 + slip / 10.0, 0.0, 1.0)
			Surface.GRASS: amount = clampf((speed - 4.0) / 20.0 + slip / 14.0, 0.0, 0.6)
			Surface.MUD: amount = clampf(slip / 8.0 + speed / 30.0, 0.0, 0.5)
		amount *= dust_scale
		dust.global_position = p + Vector3.UP * 0.15 - truck.global_basis.z * 0.25
		dust.emitting = amount > 0.04 and surf != Surface.WATER
		if dust.emitting:
			dust.amount_ratio = amount
			var pm := dust.process_material as ParticleProcessMaterial
			pm.color = SURFACE_DUST.get(surf, Color(0.5, 0.45, 0.35, 0.4))
			pm.initial_velocity_max = 1.5 + speed * 0.12
		# su sıçraması
		var wet := surf == Surface.WATER and speed > 1.5
		splash.global_position = p + Vector3.UP * 0.1
		splash.emitting = wet
		if wet:
			splash.amount_ratio = clampf(speed / 10.0, 0.2, 1.0)
			(splash.process_material as ParticleProcessMaterial).initial_velocity_max = 2.0 + speed * 0.35
		# təkər izi: torpaq/ot/çınqıl/palçıqda həmişə, asfaltda yalnız sürüşmədə
		var mark := surf != Surface.WATER and (surf != Surface.ASPHALT or slip > 5.0)
		if mark and speed > 0.6 and _last_mark[k].distance_to(p) > TRACK_STEP:
			if _last_mark[k] != Vector3.INF and _last_mark[k].distance_to(p) < 3.0:
				_add_track(_last_mark[k], p, w.get_contact_normal(), surf)
			_last_mark[k] = p
		elif not mark:
			_last_mark[k] = Vector3.INF


func set_reflection_probe(on: bool) -> void:
	if not on:
		if _probe != null:
			_probe.queue_free()
			_probe = null
		return
	if _probe != null:
		return
	_probe = ReflectionProbe.new()
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.size = Vector3(60, 30, 60)
	_probe.max_distance = 70.0
	_probe.intensity = 1.0
	_probe.enable_shadows = false
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	_probe.mesh_lod_threshold = 4.0
	_probe.top_level = true
	add_child(_probe)
	_probe_at = Vector3.INF


func _update_probe(delta: float) -> void:
	if _probe == null or truck == null:
		return
	_probe_timer -= delta
	if _probe_timer > 0.0 or truck.global_position.distance_to(_probe_at) < 8.0:
		return
	_probe_timer = 1.5
	_probe_at = truck.global_position
	_probe.global_position = truck.global_position + Vector3(0, 1.5, 0)
	# UPDATE_ONCE yalnız dəyişiklikdə yenidən çəkilir: kiçik dəyişiklik yeniləməni tətikləyir
	_probe.max_distance = 70.0 if _probe.max_distance != 70.0 else 70.01


func _process(delta: float) -> void:
	_update_probe(delta)
	# izlər yavaş-yavaş solur
	if _tracks == null:
		return
	for i in _tracks.visible_instance_count:
		if _track_age[i] < 0.0:
			continue
		_track_age[i] += delta
		var c := _tracks.get_instance_color(i)
		c.a = clampf(1.0 - _track_age[i] / TRACK_LIFE, 0.0, 1.0) * _track_strength[i]
		_tracks.set_instance_color(i, c)


## --- toz və sıçrama ---------------------------------------------------------------------------

func _soft_puff_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _make_dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 2.4
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 8, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.25, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.4))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var alpha := Gradient.new()
	alpha.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	alpha.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	var at := GradientTexture1D.new()
	at.gradient = alpha
	pm.color_ramp = at
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _soft_puff_texture()
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 0.9
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.7
	pm.color = Color(0.82, 0.88, 0.92, 0.55)
	var alpha := Gradient.new()
	alpha.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var at := GradientTexture1D.new()
	at.gradient = alpha
	pm.color_ramp = at
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _soft_puff_texture()
	mat.roughness = 0.1
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## --- təkər izləri ---------------------------------------------------------------------------

func _make_tracks() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.albedo_texture = _track_texture()
	quad.material = mat
	_tracks = MultiMesh.new()
	_tracks.transform_format = MultiMesh.TRANSFORM_3D
	_tracks.use_colors = true
	_tracks.mesh = quad
	_tracks.instance_count = TRACK_CAPACITY
	_tracks.visible_instance_count = 0
	_track_age.resize(TRACK_CAPACITY)
	_track_strength.resize(TRACK_CAPACITY)
	_track_age.fill(-1.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _tracks
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true
	add_child(mmi)


## Protektor naxışı: eninə zolaqlar
func _track_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var tread := 0.55 + 0.45 * float((y / 4) % 2)
			var edge := clampf(minf(x, 31 - x) / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, tread * edge))
	return ImageTexture.create_from_image(img)


func _add_track(a: Vector3, b: Vector3, n: Vector3, surf: int) -> void:
	var mid := (a + b) * 0.5 + n * 0.025
	var fwd := (b - a)
	var length := fwd.length()
	if length < 0.05:
		return
	fwd /= length
	var up := n.normalized()
	var side := up.cross(fwd).normalized()
	fwd = side.cross(up).normalized()
	var width := 0.32
	var basis := Basis(side * width, up, fwd * (length + 0.05))
	var i := _track_cursor
	_tracks.set_instance_transform(i, Transform3D(basis, mid))
	# səthə görə iz gücü (alfa)
	var strength: float = {Surface.MUD: 0.7, Surface.DIRT: 0.5, Surface.GRAVEL: 0.35, Surface.GRASS: 0.3, Surface.ASPHALT: 0.4}.get(surf, 0.3)
	var tint := Color(0.12, 0.09, 0.06) if surf != Surface.ASPHALT else Color(0.05, 0.05, 0.05)
	_tracks.set_instance_color(i, Color(tint.r, tint.g, tint.b, strength))
	_track_strength[i] = strength
	_track_age[i] = 0.0
	_track_cursor = (_track_cursor + 1) % TRACK_CAPACITY
	_tracks.visible_instance_count = maxi(_tracks.visible_instance_count, i + 1)


## --- maşın altı kontakt kölgəsi ---------------------------------------------------------------

func _make_contact_shadow() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0)])
	g.offsets = PackedFloat32Array([0.35, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_shadow = Decal.new()
	_shadow.texture_albedo = tex
	_shadow.modulate = Color(1, 1, 1, 0.85)
	_shadow.upper_fade = 0.25
	_shadow.lower_fade = 0.6
	_shadow.cull_mask = 1
	_shadow.top_level = true
	add_child(_shadow)


func _update_shadow() -> void:
	var box := Vector3(2.2, 2.0, 4.6)
	if truck._col != null and truck._col.shape is BoxShape3D:
		var s := (truck._col.shape as BoxShape3D).size
		box = Vector3(s.x * 1.25, 2.0, s.z * 1.15)
	var yaw := Basis(Vector3.UP, atan2(truck.global_basis.z.x, truck.global_basis.z.z))
	_shadow.size = box
	_shadow.global_transform = Transform3D(yaw, truck.global_position + Vector3(0, -1.0, 0))
	_shadow.visible = truck.visible
