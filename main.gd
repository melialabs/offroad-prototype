extends Node3D

var activities: HillClimbActivity
var truck: OffroadTruck
var cam: ChaseCamera
var world_map: WorldMap
var hud: Hud
var menu: MainMenu
var audio: GameAudio
var wind: WindField
var vegetation: Vegetation
var winch: WinchRecovery
var exhaust: ExhaustSmoke
var _menu_open := false
var _sun: DirectionalLight3D
var _terrain: MudTerrain
var _env: Environment
var _sky_mat: ShaderMaterial
var night := false

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_col = vec3(0.16, 0.45, 0.85);
uniform vec3 hor_col = vec3(0.70, 0.86, 0.98);
uniform vec3 ground_col = vec3(0.45, 0.62, 0.40);
uniform float night = 0.0;
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
		col = mix(col, cc * mix(1.0, 0.07, night), c * mix(0.92, 0.6, night));
	}
	if (night > 0.0 && d.y > 0.0) {
		vec2 sp = d.xz / (d.y + 0.35) * 55.0;
		vec2 cell = floor(sp);
		float h = hash(cell);
		vec2 f = fract(sp) - 0.5;
		float star = step(0.93, h) * smoothstep(0.22, 0.0, length(f)) * (0.5 + 0.5 * hash(cell + 3.1));
		col += vec3(0.85, 0.9, 1.0) * star * night * smoothstep(0.0, 0.25, d.y);
	}
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float s = max(dot(d, sd), 0.0);
	vec3 disc = mix(vec3(1.0, 0.92, 0.7), vec3(0.75, 0.85, 1.0), night);
	col += disc * (pow(s, mix(600.0, 1500.0, night)) * mix(3.0, 2.2, night) + pow(s, 12.0) * mix(0.12, 0.05, night));
	COLOR = col;
}
"""


func _ready() -> void:
	_setup_environment()
	wind = WindField.new()
	add_child(wind)

	var terrain := MudTerrain.new()
	add_child(terrain)
	_terrain = terrain
	_build_scenery(terrain)

	truck = OffroadTruck.new()
	truck.terrain = terrain
	add_child(truck)
	_place_on_road()
	winch = WinchRecovery.new()
	winch.truck = truck
	winch.forest = vegetation
	add_child(winch)
	exhaust = ExhaustSmoke.new()
	exhaust.truck = truck
	exhaust.wind = wind
	add_child(exhaust)

	cam = ChaseCamera.new()
	cam.target = truck
	cam.terrain = terrain
	add_child(cam)

	audio = GameAudio.new()
	audio.truck = truck
	audio.main_node = self
	audio.wind = wind
	add_child(audio)

	var layer := CanvasLayer.new()
	hud = Hud.new()
	hud.truck = truck
	layer.add_child(hud)
	add_child(layer)
	var map_layer := CanvasLayer.new()
	world_map = WorldMap.new()
	world_map.terrain = terrain
	world_map.truck = truck
	map_layer.add_child(world_map)
	add_child(map_layer)
	cam.mode_changed.connect(hud.show_toast)
	truck.message.connect(hud.show_toast)

	if terrain.hill_zone != null:
		activities = HillClimbActivity.new()
		activities.terrain = terrain
		activities.truck = truck
		activities.main_node = self
		add_child(activities)
		var park := HillClimbWorld.new()
		park.activity = activities
		park.terrain = terrain
		add_child(park)
		var activity_layer := CanvasLayer.new()
		activity_layer.layer = 5
		var activity_ui := HillClimbUI.new()
		activity_ui.activity = activities
		activity_layer.add_child(activity_ui)
		add_child(activity_layer)
		world_map.activities = activities
		activities.cue.connect(audio.play_activity_cue)

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	menu = MainMenu.new()
	menu.main = self
	menu.truck = truck
	menu_layer.add_child(menu)
	add_child(menu_layer)
	menu.start_requested.connect(_start_new_game)
	menu.resume_requested.connect(_close_menu)
	menu.restart_requested.connect(_restart_from_menu)
	menu.quit_requested.connect(get_tree().quit)
	# menyu yalnız oyun əsas səhnə kimi açılanda görünür (testlər main.tscn-i alt düyün kimi yükləyir)
	_maybe_open_menu.call_deferred()


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	_sky_mat = sky_mat
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
	env.fog_density = 0.00065
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _build_scenery(terrain: MudTerrain) -> void:
	# uzaq zəmin və su
	var far_ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4200, 4200)
	far_ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.25)
	gm.roughness = 1.0
	far_ground.material_override = gm
	far_ground.position.y = -4.0
	add_child(far_ground)

	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(4200, 4200)
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
	var landmarks := WorldLandmarks.new()
	add_child(landmarks)
	landmarks.build(terrain)
	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.use_fade = OS.get_cmdline_user_args().has("fade")
	vegetation.build(terrain, 1234)


func _build_mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.9
	var segs := 72
	var radii := [1450.0, 1750.0, 2100.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in radii.size():
		var r: float = radii[ri]
		var hmax := 180.0 + ri * 55.0
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


## Maşını asfalt yolun üzərinə, yolun istiqamətində qoyur.
const GARAGE_SCENE := "res://assets/garage/garage.glb"
## Qaraj otağı dünyadan çox yuxarıda qurulur (10 x 6 x 4 m); mənbə modeli: assets/garage/garage.glb
const GARAGE_POS := Vector3(0.0, 900.0, 0.0)
const GARAGE_SPOT := Vector3(0.3, 0.9, 1.4)  # maşının dayanacağı yer (çuxurun üstü), otağa görə
var garage: Node3D
var garage_active := false
var _saved_light := Vector2.ZERO  # günəş və ambient enerjisi (qarajdan çıxanda bərpa)


func _build_garage() -> void:
	if garage != null or not ResourceLoader.exists(GARAGE_SCENE):
		return
	garage = Node3D.new()
	garage.position = GARAGE_POS
	var room := (load(GARAGE_SCENE) as PackedScene).instantiate() as Node3D
	garage.add_child(room)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.4, 0.6, 6.4)
	shape.shape = box
	shape.position = Vector3(0, -0.3, 0)
	floor_body.add_child(shape)
	garage.add_child(floor_body)
	for p in [Vector3(-3.0, 3.3, 0.0), Vector3(1.0, 3.3, 0.0), Vector3(3.8, 3.3, 0.0), Vector3(-1.0, 3.3, -2.2), Vector3(-1.0, 3.3, 2.2)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.95, 0.85)
		l.light_energy = 1.6
		l.omni_range = 7.5
		garage.add_child(l)
	garage.visible = false
	add_child(garage)


## Qaraj səhifəsi: maşın qarajın içinə qoyulur, kamera otağın içində fırlanır.
func enter_garage() -> void:
	_build_garage()
	if garage == null or garage_active:
		return
	garage_active = true
	garage.visible = true
	_saved_light = Vector2(_sun.light_energy, _env.ambient_light_energy)
	_sun.light_energy = 0.0
	_env.ambient_light_energy = 0.28
	cam.garage_center = GARAGE_POS + GARAGE_SPOT
	cam.garage_mode = true
	_park_in_garage()


func leave_garage() -> void:
	if not garage_active:
		return
	garage_active = false
	garage.visible = false
	cam.garage_mode = false
	_restore_world_light()
	_place_on_road()


func _restore_world_light() -> void:
	_sun.light_energy = _saved_light.x
	_env.ambient_light_energy = _saved_light.y


func _park_in_garage() -> void:
	if winch != null:
		winch.detach()
	if exhaust != null:
		exhaust.reset()
	truck.linear_velocity = Vector3.ZERO
	truck.angular_velocity = Vector3.ZERO
	# irəli (+Z) otağın +X ucuna (rulon qapıya) baxır
	truck.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), GARAGE_POS + GARAGE_SPOT + Vector3(0, 0.6, 0))
	cam.snap()


func _place_on_road() -> void:
	if winch != null:
		winch.detach()
	if exhaust != null:
		exhaust.reset()
	var sp := _terrain.road_spawn()
	truck.linear_velocity = Vector3.ZERO
	truck.angular_velocity = Vector3.ZERO
	truck.rotation = Vector3(0, sp["yaw"], 0)
	truck.global_position = sp["pos"] + Vector3(0, 2.0, 0)


## Oyunda siçan tutulur (kamera üçün), menyuda sərbəstdir. Testlərdə (alt düyün kimi yüklənəndə) toxunulmur.
func _set_mouse_capture(on: bool) -> void:
	if get_tree().current_scene != self:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _maybe_open_menu() -> void:
	if get_tree().current_scene == self:
		_open_menu(false)


func _open_menu(game_running: bool) -> void:
	_menu_open = true
	_set_mouse_capture(false)
	truck.controls_enabled = false
	cam.menu_orbit = true
	hud.visible = false
	world_map.visible = false
	menu.open(game_running)
	if activities != null:
		activities.set_menu_paused(true)


func _close_menu() -> void:
	if garage_active:
		garage_active = false
		garage.visible = false
		cam.garage_mode = false
		_restore_world_light()
	_menu_open = false
	cam.reset_mouse_look()
	_set_mouse_capture(true)
	truck.controls_enabled = true
	cam.menu_orbit = false
	cam.snap()
	hud.visible = true
	world_map.visible = true
	menu.close()
	if activities != null:
		activities.set_menu_paused(false)


func _start_new_game() -> void:
	truck.stop_engine()
	_close_menu()


func _restart_from_menu() -> void:
	if activities != null:
		activities.exit_challenge()
	_place_on_road()
	truck.stop_engine()
	_close_menu()


## Menyudan texnika seçimi: texnika dəyişir və yolun üstünə qoyulur.
func select_vehicle(i: int) -> void:
	if activities != null:
		activities.exit_challenge()
	truck.apply_spec(i)
	if garage_active:
		_park_in_garage()
	else:
		_place_on_road()


## Gündüz / gecə rejimi. Gecə: ulduzlu səma, zəif ay işığı, qaranlıq duman; fənərlər avtomatik yanır.
func set_night(on: bool) -> void:
	night = on
	wind.night = on
	_sky_mat.set_shader_parameter("night", 1.0 if on else 0.0)
	if on:
		_sky_mat.set_shader_parameter("top_col", Vector3(0.008, 0.015, 0.05))
		_sky_mat.set_shader_parameter("hor_col", Vector3(0.05, 0.08, 0.16))
		_sky_mat.set_shader_parameter("ground_col", Vector3(0.015, 0.025, 0.03))
		_sun.rotation_degrees = Vector3(-38, 150, 0)
		_sun.light_color = Color(0.55, 0.68, 1.0)
		_sun.light_energy = 0.22
		_env.ambient_light_energy = 0.16
		_env.fog_light_color = Color(0.05, 0.08, 0.15)
		_env.fog_density = 0.0035
		_env.adjustment_saturation = 0.85
		if truck.lights.headlight_mode == 0:
			truck.lights.set_headlights(1)
	else:
		_sky_mat.set_shader_parameter("top_col", Vector3(0.16, 0.45, 0.85))
		_sky_mat.set_shader_parameter("hor_col", Vector3(0.70, 0.86, 0.98))
		_sky_mat.set_shader_parameter("ground_col", Vector3(0.45, 0.62, 0.40))
		_sun.rotation_degrees = Vector3(-42, -30, 0)
		_sun.light_color = Color(1.0, 0.95, 0.85)
		_sun.light_energy = 1.3
		_env.ambient_light_energy = 0.7
		_env.fog_light_color = Color(0.72, 0.86, 0.98)
		_env.fog_density = 0.00065
		_env.adjustment_saturation = 1.15
		if truck.lights.headlight_mode != 0:
			truck.lights.set_headlights(0)


func set_sound(on: bool) -> void:
	audio.set_enabled(on)


func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func set_shadows(on: bool) -> void:
	_sun.shadow_enabled = on


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().current_scene != self or _menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		set_night(not night)
		hud.show_toast("Gecə rejimi" if night else "Gündüz rejimi")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_open_menu(true)


func _physics_process(_delta: float) -> void:
	if activities != null and activities.engaged():
		return
	# xəritədən düşsə avtomatik sıfırla
	if (Input.is_physical_key_pressed(KEY_R) and not _menu_open) or truck.global_position.y < -30.0 or absf(truck.global_position.x) > 1010.0 or absf(truck.global_position.z) > 1010.0:
		_place_on_road()
		cam.snap()
