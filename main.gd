extends Node3D

var truck: OffroadTruck
var cam: Camera3D
var hud: Label

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_col = vec3(0.16, 0.45, 0.85);
uniform vec3 hor_col = vec3(0.70, 0.86, 0.98);
uniform vec3 ground_col = vec3(0.45, 0.62, 0.40);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = EYEDIR;
	float t = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(hor_col, top_col, pow(t, 0.55));
	if (d.y < 0.0) { col = mix(hor_col, ground_col, clamp(-d.y * 6.0, 0.0, 1.0)); }
	if (d.y > 0.02) {
		vec2 uv = d.xz / (d.y + 0.15) * 1.3 + vec2(TIME * 0.004, 0.0);
		float c = smoothstep(0.50, 0.78, fbm(uv));
		c *= smoothstep(0.02, 0.2, d.y);
		vec3 cc = mix(vec3(1.0), vec3(0.78, 0.84, 0.93), smoothstep(0.5, 1.0, fbm(uv + 7.0)));
		col = mix(col, cc, c * 0.92);
	}
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float s = max(dot(d, sd), 0.0);
	col += vec3(1.0, 0.92, 0.7) * (pow(s, 600.0) * 3.0 + pow(s, 12.0) * 0.12);
	COLOR = col;
}
"""


func _ready() -> void:
	_setup_environment()

	var terrain := MudTerrain.new()
	add_child(terrain)
	_build_scenery(terrain)

	truck = OffroadTruck.new()
	truck.terrain = terrain
	add_child(truck)
	truck.position = Vector3(0, terrain.height_at(Vector3.ZERO) + 2.0, 0)

	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	add_child(cam)

	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override(&"font_size", 20)
	layer.add_child(hud)
	add_child(layer)


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = Shader.new()
	sky_mat.shader.code = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.86, 0.98)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func _build_scenery(terrain: MudTerrain) -> void:
	# uzaq zəmin və su
	var far_ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	far_ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.25)
	gm.roughness = 1.0
	far_ground.material_override = gm
	far_ground.position.y = -4.0
	add_child(far_ground)

	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(1400, 1400)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.12, 0.45, 0.62, 0.78)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.05
	wmat.metallic = 0.3
	wmat.metallic_specular = 0.9
	water.material_override = wmat
	water.position.y = -2.4
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	_build_mountains()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	_scatter_grass(terrain, rng)
	_scatter_trees(terrain, rng)


func _build_mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.9
	var segs := 72
	var radii := [230.0, 300.0, 380.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in radii.size():
		var r: float = radii[ri]
		var hmax := 55.0 + ri * 25.0
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var h0 := _peak(noise, i, ri) * hmax
			var h1 := _peak(noise, i + 1, ri) * hmax
			var hm := _peak(noise, i + 0.5, ri + 5.0) * hmax * 1.25
			var p0 := Vector3(cos(a0) * r, -6.0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, -6.0, sin(a1) * r)
			var am := (a0 + a1) * 0.5
			var rm := r - 40.0
			var pk := Vector3(cos(am) * rm, hm, sin(am) * rm)
			var t0 := Vector3(cos(a0) * (r - 20.0), h0, sin(a0) * (r - 20.0))
			var t1 := Vector3(cos(a1) * (r - 20.0), h1, sin(a1) * (r - 20.0))
			_tri(st, p0, p1, t1)
			_tri(st, p0, t1, t0)
			_tri(st, t0, t1, pk)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _peak(noise: FastNoiseLite, i: float, ri: float) -> float:
	return 0.45 + 0.55 * (noise.get_noise_2d(i * 3.7, ri * 11.0) * 0.5 + 0.5)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var mid := (a.y + b.y + c.y) / 3.0
	var col := Color(0.30, 0.50, 0.28).lerp(Color(0.50, 0.50, 0.48), clampf((mid - 20.0) / 35.0, 0.0, 1.0))
	col = col.lerp(Color(0.95, 0.97, 1.0), clampf((mid - 62.0) / 25.0, 0.0, 1.0))
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)


func _scatter_grass(terrain: MudTerrain, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var ang := k * PI / 3.0
		var dir := Vector3(cos(ang), 0, sin(ang)) * 0.12
		st.set_color(Color(0.2, 0.4, 0.12))
		st.add_vertex(-dir)
		st.set_color(Color(0.2, 0.4, 0.12))
		st.add_vertex(dir)
		st.set_color(Color(0.62, 0.85, 0.3))
		st.add_vertex(Vector3(0, 0.7, 0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	var xs: Array[Transform3D] = []
	var extent := (MudTerrain.N - 1) * 0.5 * MudTerrain.CELL - 2.0
	for n in 9000:
		var p := Vector3(rng.randf_range(-extent, extent), 0, rng.randf_range(-extent, extent))
		if p.length() < 6.0 or terrain.softness_at(p) > 0.35:
			continue
		p.y = terrain.height_at(p)
		var s := rng.randf_range(0.5, 1.1)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		xs.append(Transform3D(b, p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 90.0
	add_child(mmi)


func _scatter_trees(terrain: MudTerrain, rng: RandomNumberGenerator) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var leaf_mesh := CylinderMesh.new()
	leaf_mesh.top_radius = 0.0
	leaf_mesh.bottom_radius = 1.6
	leaf_mesh.height = 4.5
	leaf_mesh.radial_segments = 7
	leaf_mesh.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.24, 0.14)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.17, 0.46, 0.2)
	leaf_mat.roughness = 1.0
	var tt: Array[Transform3D] = []
	var lt: Array[Transform3D] = []
	var extent := (MudTerrain.N - 1) * 0.5 * MudTerrain.CELL - 3.0
	for n in 400:
		var p := Vector3(rng.randf_range(-extent, extent), 0, rng.randf_range(-extent, extent))
		if p.length() < 18.0 or terrain.softness_at(p) > 0.2:
			continue
		p.y = terrain.height_at(p)
		var s := rng.randf_range(0.8, 1.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		tt.append(Transform3D(b, p + Vector3(0, 1.0 * s, 0)))
		lt.append(Transform3D(b, p + Vector3(0, 3.95 * s, 0)))
	_add_multimesh(trunk_mesh, trunk_mat, tt)
	_add_multimesh(leaf_mesh, leaf_mat, lt)


func _add_multimesh(mesh: Mesh, mat: Material, xs: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	add_child(inst)


func _physics_process(delta: float) -> void:
	# kamera maşının arxasından yumşaq izləyir
	var back := -truck.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	var target := truck.global_position + back * 9.0 + Vector3.UP * 4.0
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-4.0 * delta))
	cam.look_at(truck.global_position + Vector3.UP * 1.0)

	var kmh := truck.linear_velocity.length() * 3.6
	hud.text = "%d km/saat   |   palçıq: %d%%\n%s\nW/S qaz-əyləc, A/D sükan, Space əl əyləci, R sıfırla, 1/2/3 texnika" % [
		kmh, int(clampf(truck.mud_level, 0.0, 1.0) * 100.0), truck.hud_text()]

	# xəritədən düşsə avtomatik sıfırla
	if Input.is_physical_key_pressed(KEY_R) or truck.global_position.y < -30.0:
		truck.linear_velocity = Vector3.ZERO
		truck.angular_velocity = Vector3.ZERO
		truck.global_position = Vector3(0, 3.0, 0)
		truck.rotation = Vector3.ZERO
