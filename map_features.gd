class_name MapFeatures
extends Node3D
## Xəritə elementləri: şəhər binaları (evlər və mərkəzdə çoxmərtəbəli binalar), çay üstündə körpülər
## (beton döşəmə, dayaqlar, məhəccər) və şəlalələrdə köpük/duman. MapLayout planına əsaslanır.

const BLOCK := 24.0
const WALLS := [Color(0.86, 0.82, 0.74), Color(0.92, 0.9, 0.86), Color(0.78, 0.74, 0.68), Color(0.8, 0.62, 0.5), Color(0.74, 0.76, 0.78)]
const ROOFS := [Color(0.5, 0.22, 0.16), Color(0.32, 0.3, 0.3), Color(0.42, 0.28, 0.2)]

var buildings := 0
var bridges := 0
var _window_tex: ImageTexture
var _wall_mats := {}


func build(terrain: MudTerrain) -> void:
	_build_town(terrain)
	_build_bridges(terrain)
	_build_waterfalls(terrain)


## --- şəhər ---------------------------------------------------------------------------------------

func _build_town(terrain: MudTerrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501
	var body := StaticBody3D.new()
	add_child(body)
	var c := MapLayout.TOWN
	var r := MapLayout.TOWN_RADII
	var x := c.x - r.x
	while x <= c.x + r.x:
		var z := c.y - r.y
		while z <= c.y + r.y:
			var p := Vector2(x + rng.randf_range(-3, 3), z + rng.randf_range(-3, 3))
			var e := MapLayout._ellipse(p, c, r)
			if e < 0.92 and terrain.road_distance_at(Vector3(p.x, 0, p.y)) > MudTerrain.ROAD_HALF + 7.0:
				# mərkəzə yaxın: çoxmərtəbəli bina; kənarda: maili damlı ev
				var tall := e < 0.42 and rng.randf() < 0.75
				_building(terrain, body, p, tall, rng)
			z += BLOCK
		x += BLOCK


func _building(terrain: MudTerrain, body: StaticBody3D, p: Vector2, tall: bool, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(9.0, 14.0) if tall else rng.randf_range(7.0, 10.0)
	var d := rng.randf_range(9.0, 13.0) if tall else rng.randf_range(7.0, 9.5)
	var floors := rng.randi_range(4, 7) if tall else rng.randi_range(1, 2)
	var hgt := floors * 3.0
	var ground := INF
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		ground = minf(ground, terrain.height_at(Vector3(p.x + k.x * w * 0.5, 0, p.y + k.y * d * 0.5)))
	var base := Vector3(p.x, ground - 0.3, p.y)
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, hgt + 0.3, d)
	walls.mesh = box
	walls.position = base + Vector3(0, (hgt + 0.3) * 0.5, 0)
	walls.material_override = _wall_material(WALLS[rng.randi() % WALLS.size()])
	walls.visibility_range_end = 900.0
	add_child(walls)
	if tall:
		var roof := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(w + 0.4, 0.4, d + 0.4)
		roof.mesh = slab
		roof.position = base + Vector3(0, hgt + 0.5, 0)
		roof.material_override = _plain(Color(0.35, 0.35, 0.36))
		add_child(roof)
	else:
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 0.8, 2.6, d + 0.8)
		roof.mesh = prism
		roof.position = base + Vector3(0, hgt + 0.3 + 1.3, 0)
		roof.material_override = _plain(ROOFS[rng.randi() % ROOFS.size()])
		add_child(roof)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, hgt + 1.5, d)
	col.shape = shape
	col.position = walls.position
	body.add_child(col)
	buildings += 1


## Divar: rəngli suvaq + 3 m-lik mərtəbələrdə pəncərə (triplanar, binalar oxlara paraleldir)
func _wall_material(color: Color) -> StandardMaterial3D:
	if _wall_mats.has(color):
		return _wall_mats[color]
	if _window_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var win := x > 16 and x < 48 and y > 14 and y < 44
				var frame := win and (x == 32 or y == 29)
				img.set_pixel(x, y, Color(0.18, 0.22, 0.26) if win and not frame else (Color(0.9, 0.9, 0.88) if frame else Color(1, 1, 1)))
		img.generate_mipmaps()
		_window_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _window_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / 3.0
	m.roughness = 0.85
	_wall_mats[color] = m
	return m


func _plain(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


## --- körpülər ---------------------------------------------------------------------------------------

func _build_bridges(terrain: MudTerrain) -> void:
	var road := terrain._road
	var concrete := _plain(Color(0.62, 0.61, 0.58))
	var rail_mat := _plain(Color(0.55, 0.56, 0.58))
	rail_mat.metallic = 0.6
	rail_mat.roughness = 0.45
	var body := StaticBody3D.new()
	add_child(body)
	var on_bridge := false
	for i in road.size() - 1:
		if terrain._road_gap[i] == 1:
			on_bridge = false
			continue
		var a := road[i]
		var b := road[i + 1]
		var mid := (a + b) * 0.5
		var rv: float = terrain._near_route(mid, terrain._river, terrain._river_len, terrain._river_bins)[0]
		var span := rv < MapLayout.RIVER_HALF + 10.0
		if not span:
			on_bridge = false
			continue
		if not on_bridge:
			bridges += 1
			on_bridge = true
		var ha := terrain._road_h[i]
		var hb := terrain._road_h[i + 1]
		var dir := Vector3(b.x - a.x, hb - ha, b.y - a.y)
		var length := dir.length()
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		var center := Vector3(mid.x, (ha + hb) * 0.5, mid.y)
		# döşəmə (asfalt lentinin altında)
		var deck := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(MudTerrain.ROAD_HALF * 2.0 + 1.2, 0.7, length + 0.05)
		deck.mesh = dm
		deck.transform = Transform3D(basis, center + Vector3(0, -0.28, 0))
		deck.material_override = concrete
		add_child(deck)
		# məhəccərlər
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.25, 0.9, length + 0.05)
			rail.mesh = rm
			rail.transform = Transform3D(basis, center + basis.x * side * (MudTerrain.ROAD_HALF + 0.45) + Vector3(0, 0.5, 0))
			rail.material_override = rail_mat
			add_child(rail)
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = rm.size
			col.shape = shape
			col.transform = rail.transform
			body.add_child(col)
		# dayaq: çayın ortasına yaxın seqmentlərdə
		if rv < MapLayout.RIVER_HALF * 0.6:
			var pillar := MeshInstance3D.new()
			var pm := BoxMesh.new()
			var ground := terrain.height_at(Vector3(mid.x, 0, mid.y))
			var ph := maxf(center.y - ground, 1.0)
			pm.size = Vector3(MudTerrain.ROAD_HALF * 2.0 - 1.0, ph, 1.2)
			pillar.mesh = pm
			pillar.transform = Transform3D(basis, Vector3(mid.x, ground + ph * 0.5 - 0.6, mid.y))
			pillar.material_override = concrete
			add_child(pillar)


## --- şəlalələr ---------------------------------------------------------------------------------------

func _build_waterfalls(terrain: MudTerrain) -> void:
	for wf in MapLayout.WATERFALLS:
		var p := Vector3(wf.x, 0, wf.y)
		var lvl := terrain.water_level_at(p)
		p.y = (lvl if lvl > -INF else terrain.height_at(p)) + 0.3
		var foam := GPUParticles3D.new()
		foam.amount = 160
		foam.lifetime = 2.2
		foam.position = p
		foam.visibility_aabb = AABB(Vector3(-15, -6, -15), Vector3(30, 14, 30))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(MapLayout.RIVER_HALF, 0.4, 2.0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 40.0
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 2.6
		pm.gravity = Vector3(0, -1.2, 0)
		pm.damping_min = 0.6
		pm.damping_max = 1.2
		pm.scale_min = 1.2
		pm.scale_max = 3.2
		pm.color = Color(0.94, 0.96, 0.98, 0.5)
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		var ft := GradientTexture1D.new()
		ft.gradient = fade
		pm.color_ramp = ft
		foam.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 1.6)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.proximity_fade_enabled = true
		mat.proximity_fade_distance = 1.0
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		mat.albedo_texture = tex
		quad.material = mat
		foam.draw_pass_1 = quad
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(foam)
