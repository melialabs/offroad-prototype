extends SceneTree
## "Grass patches" GLB-lərindən (yüzlərlə mıxlı ot yarpağı) kiçik ot topaları kəsir və vegetasiya aktivi yazır:
## assets/vegetation/grass_real_01/grass_real_01_lod0.glb, _lod1.glb (+ materials.json, textures/grass_real_01/*).
## godot --headless --path . -s res://tools/prep_grass.gd -- <squares.glb> <circle.glb>
const CELL := 0.9
const PER_FILE := 3
const TEX := 1024
const ID := "grass_real_01"
const OUT := "res://assets/vegetation/"


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var lod0 := Node3D.new()
	var lod1 := Node3D.new()
	var mats := {}
	var tag := ["sq", "ci"]
	var letters := ["a", "b", "c", "d"]
	for f in args.size():
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(args[f], st) != OK:
			print("YÜKLƏNMƏDİ ", args[f])
			quit(1)
			return
		var root := doc.generate_scene(st)
		# material: bütün meshlər eyni teksturanı paylaşır
		var mat: BaseMaterial3D
		var tris: Array = []  # {c: Vector3, v: [3 Vector3], n: [3], uv: [3], order: int}
		var ground := 1e9
		var order := 0
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var xf := mi.global_transform
			for s in mi.mesh.get_surface_count():
				if mat == null:
					mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
				var arr := mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
				for t in range(0, idx.size(), 3):
					var v := [xf * verts[idx[t]], xf * verts[idx[t + 1]], xf * verts[idx[t + 2]]]
					for k in 3:
						ground = minf(ground, (v[k] as Vector3).y)
					tris.append({"c": (v[0] + v[1] + v[2]) / 3.0, "v": v,
						"n": [xf.basis * nor[idx[t]], xf.basis * nor[idx[t + 1]], xf.basis * nor[idx[t + 2]]],
						"uv": [uvs[idx[t]], uvs[idx[t + 1]], uvs[idx[t + 2]]], "order": order})
					order += 1
		var name := str(tag[f])
		mats[name] = _export_textures(mat, name)
		# hüceyrələrə böl
		var cells := {}
		for t in tris:
			var c: Vector3 = t["c"]
			var key := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(t)
		var counts: Array[int] = []
		for k in cells:
			counts.append((cells[k] as Array).size())
		counts.sort()
		var median := counts[counts.size() / 2]
		var good: Array = []
		for k in cells:
			var cnt: int = (cells[k] as Array).size()
			if cnt < median * 0.85 or cnt > median * 1.3:
				continue
			var interior := true
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nk := Vector2i(k.x + dx, k.y + dz)
					if not cells.has(nk) or (cells[nk] as Array).size() < median * 0.5:
						interior = false
			if interior:
				good.append(k)
		print(name, ": üçbucaq=", tris.size(), " hüceyrə=", cells.size(), " median=", median, " yaxşı=", good.size())
		good.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * 7919 + a.y < b.x * 7919 + b.y)
		for i in PER_FILE:
			var key: Vector2i = good[(i * good.size()) / PER_FILE + good.size() / (PER_FILE * 2)]
			var variant := name + str(letters[i])
			for lod in 2:
				var stt := SurfaceTool.new()
				stt.begin(Mesh.PRIMITIVE_TRIANGLES)
				var center := Vector3((key.x + 0.5) * CELL, ground, (key.y + 0.5) * CELL)
				for t in cells[key]:
					if lod == 1 and (int(t["order"]) / 4) % 2 == 1:
						continue
					for k in 3:
						stt.set_normal(t["n"][k])
						stt.set_uv(t["uv"][k])
						stt.add_vertex(t["v"][k] - center)
				stt.generate_tangents()
				var mesh := stt.commit()
				var m2 := StandardMaterial3D.new()
				m2.resource_name = name
				mesh.surface_set_material(0, m2)
				var node := MeshInstance3D.new()
				node.name = "%s_%s" % [ID, variant]
				node.mesh = mesh
				var target := lod0 if lod == 0 else lod1
				target.add_child(node)
				node.owner = target
				if lod == 0:
					print("  ", variant, " lod0 üçbucaq=", (cells[key] as Array).size())
		root.queue_free()
	var js := FileAccess.open(OUT + ID + "/materials.json", FileAccess.WRITE)
	js.store_string(JSON.stringify(mats, "  "))
	js.close()
	for lod in 2:
		var holder: Node3D = lod0 if lod == 0 else lod1
		var out_doc := GLTFDocument.new()
		var out_state := GLTFState.new()
		out_doc.append_from_scene(holder, out_state)
		var err := out_doc.write_to_filesystem(out_state, OUT + "%s/%s_lod%d.glb" % [ID, ID, lod])
		print("lod", lod, " err=", err)
	quit(0)


func _export_textures(mat: BaseMaterial3D, name: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "textures/" + ID))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + ID))
	var d := {"mode": "scissor"}
	var pairs := [["diff", mat.albedo_texture, "%s_rgba.png"], ["nor", mat.normal_texture, "%s_nor.png"]]
	for p in pairs:
		var tex: Texture2D = p[1]
		if tex == null:
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		if img.get_width() > TEX:
			img.resize(TEX, TEX, Image.INTERPOLATE_LANCZOS)
		var fname: String = p[2] % name
		img.save_png(OUT + "textures/%s/%s" % [ID, fname])
		d[p[0]] = fname
	return d
