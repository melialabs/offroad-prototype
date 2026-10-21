extends SceneTree
## Optimallaşdırılmış bitki mesh-lərinin önbaxışı: LOD-lar yan-yana, düz zəmin üzərində.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/vegetation_preview.gd -- <id> <foliage_texture>
## Nümunə: -- pine_tree_01 pine_spray

var frames := 0
var species := {}
var id := "pine_tree_01"
var foliage := "pine_spray"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		id = args[0]
	if args.size() > 1:
		foliage = args[1]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.4, 0.22)
	ground.material_override = gm
	root.add_child(ground)

	species = VegetationAssets.load_species(id, foliage)
	print("PREVIEW türlər=", species.keys())
	var variants: Array = species.keys()
	variants.sort()
	var x := 0.0
	var max_h := 1.0
	var max_w := 1.0
	for v in variants:
		var lods: Array = species[v]
		var size: Vector3 = lods[0].get_aabb().size
		max_h = maxf(max_h, size.y)
		max_w = maxf(max_w, maxf(size.x, size.z))
	var step := max_w * 1.15
	for v in variants:
		var lods: Array = species[v]
		for l in lods.size():
			var mi := MeshInstance3D.new()
			mi.mesh = lods[l]
			mi.position = Vector3(x, 0, -l * step * 1.1)
			root.add_child(mi)
			var sz: Vector3 = lods[l].get_aabb().size
			print("PREVIEW %s lod%d üçbucaq=%d ölçü=(%.2f, %.2f, %.2f) m" % [v, l, _tris(lods[l]), sz.x, sz.y, sz.z])
		x += step
	var mid := (x - step) * 0.5
	var dist := maxf(max_h * 2.4, (x) * 0.9 + 4.0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(mid, max_h * 0.45 + 0.4, dist), Vector3(mid, max_h * 0.4, 0.0))


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		n += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 40:
		quit(0)
	return false
