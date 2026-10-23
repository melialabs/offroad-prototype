extends SceneTree
## Hazır GLB-ni oyuna hazırlayır: teksturaları kiçildir, çox ağır meshləri sadələşdirir (meshoptimizer LOD).
## godot --headless --path . -s res://tools/prepare_prop.gd -- SOURCE.glb res://assets/props/OUT.glb MAX_TRIS MAX_TEX [merge]
## merge: bütün hissələri material üzrə bir meshə birləşdirir (çox kiçik hissəli skanlar üçün).
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var src := args[0]
	var dst := args[1]
	var max_tris := int(args[2])
	var max_tex := int(args[3])
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(src, st)
	if err != OK:
		print("LOAD FAILED ", err)
		quit(1)
		return
	var images := st.images
	for i in images.size():
		var img := (images[i] as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var s := maxi(img.get_width(), img.get_height())
		if s > max_tex:
			var f := float(max_tex) / s
			img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
		images[i] = ImageTexture.create_from_image(img)
	st.images = images
	var scene: Node3D = doc.generate_scene(st)
	if args.size() > 4 and args[4] == "merge":
		scene = _merge(scene)
	var total := 0
	var mis := scene.find_children("*", "MeshInstance3D", true, false)
	for n in mis:
		total += _tris((n as MeshInstance3D).mesh)
	var ratio := minf(1.0, float(max_tris) / maxf(1.0, total))
	print("source tris ", total, " target ratio ", ratio)
	var after := 0
	if ratio < 0.98:
		for n in mis:
			var mi := n as MeshInstance3D
			mi.mesh = _simplify(mi.mesh, ratio)
	for n in mis:
		after += _tris((n as MeshInstance3D).mesh)
	print("result tris ", after)
	var out := GLTFDocument.new()
	out.image_format = "JPEG"
	out.lossy_quality = 0.85
	var os := GLTFState.new()
	out.append_from_scene(scene, os)
	print("write ", out.write_to_filesystem(os, dst))
	quit()

func _merge(scene: Node3D) -> Node3D:
	root.add_child(scene)
	var tools := {}
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := scene.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				tools[mat] = st
			(tools[mat] as SurfaceTool).append_from(mi.mesh, s, xf)
	var mesh := ArrayMesh.new()
	for mat in tools:
		(tools[mat] as SurfaceTool).index()
		(tools[mat] as SurfaceTool).commit(mesh)
	root.remove_child(scene)
	var out := Node3D.new()
	out.name = scene.name
	var mi2 := MeshInstance3D.new()
	mi2.name = "Merged"
	mi2.mesh = mesh
	out.add_child(mi2)
	return out


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t

func _simplify(m: Mesh, ratio: float) -> Mesh:
	var out := ArrayMesh.new()
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		var mat := m.surface_get_material(s)
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mat)
		im.generate_lods(25.0, 60.0, [])
		var full := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for l in im.get_surface_lod_count(0):
			var idx := im.get_surface_lod_indices(0, l)
			if idx.size() >= 3:
				best = idx
				if float(idx.size()) / full <= ratio:
					break
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, best))
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out

## Yalnız istifadə olunan təpələri saxlayır.
func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var remap := {}
	var new_idx := PackedInt32Array()
	new_idx.resize(idx.size())
	var order := PackedInt32Array()
	for i in idx.size():
		var v := idx[i]
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		new_idx[i] = remap[v]
	var res := []
	res.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		var a = arrays[k]
		if a == null or k == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if k == Mesh.ARRAY_TANGENT or k == Mesh.ARRAY_BONES or k == Mesh.ARRAY_WEIGHTS:
			per = 4
		var src_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if a.size() != src_count * per:
			continue
		var dst = a.duplicate()
		dst.resize(order.size() * per)
		for i in order.size():
			for c in per:
				dst[i * per + c] = a[order[i] * per + c]
		res[k] = dst
	res[Mesh.ARRAY_INDEX] = new_idx
	return res
