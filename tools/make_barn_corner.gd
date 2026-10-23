extends SceneTree
## Köhnə qaraj skanında sağ ön künc (+X, +Z) deşikdir. Sağlam sol ön küncün (-X, +Z) üçbucaqlarını
## götürür, X üzrə güzgüləyir və assets/barn/corner_fill.res kimi saxlayır (BarnFinds kökünün koordinatında).
## godot --headless --path . -s res://tools/make_barn_corner.gd
const REGION_MIN := Vector3(-2.45, -0.2, 2.15)
const REGION_MAX := Vector3(-1.55, 2.45, 2.95)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var pivot := Node3D.new()
	pivot.rotation.y = BarnFinds.MODEL_YAW
	pivot.position = BarnFinds.PIVOT_OFFSET
	root3.add_child(pivot)
	var model: Node3D = load(BarnFinds.MODEL).instantiate()
	model.scale = Vector3.ONE * BarnFinds.SCALE
	model.position = -BarnFinds.MODEL_GROUND * BarnFinds.SCALE - BarnFinds.MODEL_CENTER
	pivot.add_child(model)
	await process_frame
	var by_mat := {}  # material -> SurfaceTool
	var kept := 0
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var mat := mi.mesh.surface_get_material(s)
			if mi.get_surface_override_material(s) != null:
				mat = mi.get_surface_override_material(s)
			for t in range(0, idx.size(), 3):
				var a := xf * v[idx[t]]
				var b := xf * v[idx[t + 1]]
				var c := xf * v[idx[t + 2]]
				var m := (a + b + c) / 3.0
				if m.x < REGION_MIN.x or m.x > REGION_MAX.x or m.y < REGION_MIN.y or m.y > REGION_MAX.y or m.z < REGION_MIN.z or m.z > REGION_MAX.z:
					continue
				if not by_mat.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					by_mat[mat] = st
				var stt: SurfaceTool = by_mat[mat]
				# güzgü: x -> -x, sarğı istiqaməti dəyişir (a, c, b)
				for k in [0, 2, 1]:
					var p: Vector3 = [a, b, c][k]
					stt.set_uv(uv[idx[t + k]])
					stt.add_vertex(Vector3(-p.x, p.y, p.z))
				kept += 1
	var mesh := ArrayMesh.new()
	for mat in by_mat:
		var stt: SurfaceTool = by_mat[mat]
		stt.generate_normals()
		stt.commit(mesh)
	print("corner triangles ", kept, " surfaces ", mesh.get_surface_count())
	print("save ", ResourceSaver.save(mesh, "res://assets/barn/corner_fill.res"))
	quit()
