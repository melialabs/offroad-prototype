extends SceneTree
## Sketchfab GLB bina/maşın modelini oyun üçün hazırlayır: seçilmiş meshləri material üzrə birləşdirir,
## real ölçüyə gətirir (uzun ox = "length"), dibi y=0, mərkəzi x=z=0 edir, teksturaları kiçildir.
## godot --headless --path . -s res://tools/prep_props.gd -- <açar> <giriş.glb> <çıxış.glb>

const CONFIGS := {
	"brick_shop": {"include": "", "scale": 1.0, "tex": 1024},
	"concrete_1": {"include": "^building 1", "scale": 1.0, "tex": 1024},
	"concrete_4": {"include": "^building 4", "scale": 1.0, "tex": 1024},
	"concrete_5": {"include": "^building 5", "scale": 1.0, "tex": 1024},
	"abandoned": {"include": "", "scale": 1.0, "tex": 1024},
	# yalnız ev gövdəsi: 250 min üçbucaqlıq bağ/dekor hissələri atılır
	"row_house": {"include": "^Group_009", "scale": 1.0, "tex": 1024, "tint": Color(0.80, 0.66, 0.52)},
	"ural": {"include": "", "length": 8.4, "tex": 512, "yaw": 0.0},
	"necro": {"include": "", "length": 4.6, "tex": 512, "yaw": 0.0},
}


func _initialize() -> void:
	run.call_deferred()


static func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != root and c != null:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _path_of(n: Node, root: Node) -> String:
	var parts: PackedStringArray = []
	var c := n
	while c != root and c != null:
		parts.insert(0, str(c.name))
		c = c.get_parent()
	return "/".join(parts)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or not CONFIGS.has(args[0]):
		print("açarlar: ", CONFIGS.keys())
		quit(2)
		return
	var cfg: Dictionary = CONFIGS[args[0]]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(args[1], st) != OK:
		print("YÜKLƏNMƏDİ")
		quit(1)
		return
	var root := doc.generate_scene(st)
	var re: RegEx = RegEx.create_from_string(str(cfg["include"])) if str(cfg["include"]) != "" else null
	var items: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		# include yalnız valideyn zəncirindəki adlardan birinə (məs. "building 1") uyğun gələrək seçir
		if re != null:
			var ok := false
			var c: Node = mi
			while c != root and c != null:
				if re.search(str(c.name)) != null:
					ok = true
					break
				c = c.get_parent()
			if not ok:
				continue
		var xf := _rel(mi, root)
		items.append({"mi": mi, "xf": xf, "aabb": xf * mi.mesh.get_aabb()})
	if items.is_empty():
		print("MESH TAPILMADI")
		quit(1)
		return
	var yaw := Basis(Vector3.UP, deg_to_rad(float(cfg.get("yaw", 0.0))))
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for it in items:
		var bb: AABB = Transform3D(yaw, Vector3.ZERO) * (it["aabb"] as AABB)
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	var size := hi - lo
	var sc := float(cfg.get("scale", 1.0))
	if cfg.has("length"):
		sc = float(cfg["length"]) / maxf(size.x, size.z)
	var origin := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var final := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO) * Transform3D(yaw, Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3.ZERO)
	final.origin = -(Transform3D(yaw, Vector3.ZERO) * origin) * sc if false else Vector3.ZERO
	var shift := Transform3D(Basis.IDENTITY, -origin)
	var xf_all := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO) * Transform3D(yaw, Vector3.ZERO) * shift
	# yaw və shift ardıcıllığı: əvvəl mərkəzlə, sonra dönmə (mərkəz yaw sonrası ölçülüb, ona görə yaw əvvəl)
	xf_all = Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO) * shift * Transform3D(yaw, Vector3.ZERO)
	var by_mat: Dictionary = {}
	var tris := 0
	for it in items:
		var mi: MeshInstance3D = it["mi"]
		var xf: Transform3D = xf_all * (it["xf"] as Transform3D)
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var key := mat.get_instance_id() if mat != null else 0
			if not by_mat.has(key):
				var stt := SurfaceTool.new()
				stt.begin(Mesh.PRIMITIVE_TRIANGLES)
				stt.set_material(mat)
				by_mat[key] = stt
			(by_mat[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var out_mesh := ArrayMesh.new()
	for key in by_mat:
		var stt: SurfaceTool = by_mat[key]
		stt.index()
		stt.commit(out_mesh)
	for s in out_mesh.get_surface_count():
		tris += out_mesh.surface_get_array_index_len(s) / 3
	var holder := Node3D.new()
	holder.name = "Prop"
	var out_mi := MeshInstance3D.new()
	out_mi.name = "Body"
	out_mi.mesh = out_mesh
	holder.add_child(out_mi)
	out_mi.owner = holder
	_shrink_textures(out_mi, int(cfg["tex"]))
	# teksturasız (düz ağ) material: suvaq rəngi ilə boyanır
	if cfg.has("tint"):
		for si in out_mesh.get_surface_count():
			var tm := out_mesh.surface_get_material(si)
			if tm is BaseMaterial3D and (tm as BaseMaterial3D).albedo_texture == null:
				var nm := (tm as BaseMaterial3D).duplicate() as BaseMaterial3D
				nm.albedo_color = cfg["tint"]
				nm.roughness = 0.9
				nm.metallic = 0.0
				out_mesh.surface_set_material(si, nm)
	# AABB dönmüş meshlərdə boşdur: dibi/mərkəzi birləşmiş meshin real sərhədinə görə yenidən qur
	var real := out_mesh.get_aabb()
	out_mi.position = Vector3(-(real.position.x + real.size.x * 0.5), -real.position.y, -(real.position.z + real.size.z * 0.5))
	var bb := real
	print("%s: tris=%d surfaces=%d size=%s base_y=%.3f" % [args[0], tris, out_mesh.get_surface_count(), bb.size, bb.position.y])
	var out_doc := GLTFDocument.new()
	var out_state := GLTFState.new()
	out_doc.append_from_scene(holder, out_state)
	var err := out_doc.write_to_filesystem(out_state, args[2])
	print("yazıldı ", args[2], " err=", err)
	quit(0 if err == OK else 1)


func _shrink_textures(mi: MeshInstance3D, max_size: int) -> void:
	var cache: Dictionary = {}
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if not (m is BaseMaterial3D):
			continue
		var bm := m as BaseMaterial3D
		# yeni nüsxə: eyni material başqa modeldə paylaşıla bilər
		for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_ROUGHNESS,
				BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
			var tex := bm.get_texture(slot)
			if tex == null:
				continue
			var key := tex.get_rid()
			if not cache.has(key):
				var img := tex.get_image()
				if img == null:
					cache[key] = tex
				else:
					if img.is_compressed():
						img.decompress()
					if maxi(img.get_width(), img.get_height()) > max_size:
						var k := float(max_size) / maxi(img.get_width(), img.get_height())
						img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
					cache[key] = ImageTexture.create_from_image(img)
			bm.set_texture(slot, cache[key])
