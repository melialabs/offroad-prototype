extends SceneTree
## Sketchfab / FBX / OBJ maşın modelini oyun üçün hazırlayır (Blender olmadan, Godot ilə):
##  - bütün meshləri birləşdirir: "Body" + 4 təkər (W_RL, W_RR, W_FL, W_FR), təkər mənşəyi təkər mərkəzində
##  - metrə çevirir (real uzunluq), irəli +Z, yer y=0, mərkəz x=z=0
##  - teksturaları max ölçüyə kiçildir, GLB yazır
## İstifadə: godot --headless --path <iş qovluğu> -s res://prep_vehicle.gd -- <açar> <giriş> <çıxış.glb>
## Açarlar: CONFIGS-də. Təkərlər material/ad regex-i ilə seçilir və 4 künclə bölünür.

const CONFIGS := {
	# length: real uzunluq (m); yaw: Y oxu ətrafında dönmə (derece, irəli +Z olsun deyə); tex: max tekstur ölçüsü
	# wheel_mat / wheel_name: təkər meshlərini seçən regex; drop_mat / drop_name: atılan meshlər (interyer və s.)
	"g63": {"length": 4.87, "yaw": 0.0, "tex": 1024,
		"wheel_mat": "Wheel1A", "wheel_name": "", "drop_mat": "(?i)interior|engine", "drop_name": "",
		# lamps: fənər şüşələri ayrıca L_HEAD_N/P (ön) və L_TAIL_N/P (arxa) olur ki, oyunda öz şüşəsi yansın
		"lamps": "LightA_Material1|^red_glass$"},
	"brabus": {"length": 4.87, "yaw": 0.0, "tex": 512,
		"wheel_mat": "(?i)Tire_Shader", "wheel_name": "", "drop_mat": "(?i)leather|plastic|interior|IntWindows", "drop_name": ""},
	# Hilux OBJ: dörd təkər bir obyektdədir (Rims + Tires), üçbucaq səviyyəsində künclərə bölünür
	"hilux": {"length": 5.33, "yaw": 0.0, "tex": 1024,
		"wheel_mat": "^(Rims|Tires)$", "wheel_name": "", "drop_mat": "^InteriorAll$", "drop_name": ""},
	# Crossroad pickup FBX (skinli): "Wheels" materialı dörd təkəri daşıyır
	"pickup": {"length": 5.3, "yaw": 0.0, "rot": Vector3(90, 0, 0), "tex": 1024,
		"wheel_mat": "(?i)^Wheels$", "wheel_name": "", "drop_mat": "", "drop_name": "",
		# FBX teksturaları ayrıca gəlir: material adı -> qovluq/prefiks (4-cü arqument: tekstur kökü)
		"tex_sets": {"Toyota_postAP": "Body/T_RSG_Crossroad_Pickup_Clean", "Details": "Details/T_RSG_Truck_01_Clean",
			"Equipment": "Equipment/T_RSG_Buggy_Equipment_Clean", "Hull": "Hull/T_RSG_Buggy_Body_Clean",
			"Wheels": "Wheels/T_RSG_Buggy_Wheels_Clean"}},
}

var cfg: Dictionary
var xforms: Dictionary = {}


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


func _load_scene(path: String) -> Node:
	var ext := path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(path, st) != OK:
			return null
		return doc.generate_scene(st)
	if ext == "fbx":
		var fdoc := FBXDocument.new()
		var fst := FBXState.new()
		if fdoc.append_from_file(path, fst) != OK:
			return null
		return fdoc.generate_scene(fst)
	var res := load(path)
	if res is PackedScene:
		return (res as PackedScene).instantiate()
	if res is Mesh:
		var holder := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.name = path.get_file().get_basename()
		mi.mesh = res
		holder.add_child(mi)
		return holder
	return null


func _mat_names(mi: MeshInstance3D) -> String:
	var out: PackedStringArray = []
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		out.append(m.resource_name if m != null else "")
	return "|".join(out)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or not CONFIGS.has(args[0]):
		print("istifadə: <açar> <giriş> <çıxış.glb>; açarlar: ", CONFIGS.keys())
		quit(2)
		return
	cfg = CONFIGS[args[0]]
	var root := _load_scene(args[1])
	if root == null:
		print("YÜKLƏNMƏDİ ", args[1])
		quit(1)
		return
	var wheel_mat := RegEx.create_from_string(str(cfg["wheel_mat"])) if str(cfg["wheel_mat"]) != "" else null
	var wheel_name := RegEx.create_from_string(str(cfg["wheel_name"])) if str(cfg["wheel_name"]) != "" else null
	var drop_mat := RegEx.create_from_string(str(cfg["drop_mat"])) if str(cfg["drop_mat"]) != "" else null
	var drop_name := RegEx.create_from_string(str(cfg["drop_name"])) if str(cfg["drop_name"]) != "" else null

	if cfg.has("tex_sets") and args.size() > 3:
		_apply_tex_sets(root, cfg["tex_sets"], args[3])
	var rot := Basis(Vector3.UP, deg_to_rad(float(cfg["yaw"])))
	if cfg.has("rot"):
		# ox düzəlişi (məs. Z-yuxarı FBX): dərəcə ilə Euler
		var r: Vector3 = cfg["rot"]
		rot = rot * Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z)))
	var body_items: Array = []
	var wheel_items: Array = []
	var dropped := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var src := n as MeshInstance3D
		var xf := Transform3D(rot, Vector3.ZERO) * _rel(src, root)
		# çox materiallı mesh (məs. OBJ) hər səthə ayrılır ki, təkər/gövdə ayrı seçilsin
		for mi in _explode(src):
			var mats := _mat_names(mi)
			if (drop_mat != null and drop_mat.search(mats) != null) or (drop_name != null and drop_name.search(src.name) != null):
				dropped += 1
				continue
			var is_wheel := (wheel_mat != null and wheel_mat.search(mats) != null) or (wheel_name != null and wheel_name.search(str(src.name)) != null)
			var item := {"mi": mi, "xf": xf, "aabb": xf * mi.mesh.get_aabb()}
			(wheel_items if is_wheel else body_items).append(item)
	print("body meshes=", body_items.size(), " wheel meshes=", wheel_items.size(), " dropped=", dropped)
	wheel_items = _split_combined_wheels(wheel_items)
	var lamp_items: Array = []
	if cfg.has("lamps"):
		var lamp_re := RegEx.create_from_string(str(cfg["lamps"]))
		for i in range(body_items.size() - 1, -1, -1):
			if lamp_re.search(_mat_names(body_items[i]["mi"])) != null:
				lamp_items.append(body_items[i])
				body_items.remove_at(i)
	# ehtiyat təkər (yuxarıda, kuzovda) gövdəyə qalır: mərkəzi digər təkərlərdən xeyli yüksəkdir
	var ys: Array[float] = []
	var hs: Array[float] = []
	for it in wheel_items:
		ys.append((it["aabb"] as AABB).get_center().y)
		hs.append((it["aabb"] as AABB).size.y)
	ys.sort()
	hs.sort()
	var median_y := ys[ys.size() / 2]
	var median_r := hs[hs.size() / 2] * 0.5
	for i in range(wheel_items.size() - 1, -1, -1):
		var cy := (wheel_items[i]["aabb"] as AABB).get_center().y
		if absf(cy - median_y) > median_r * 0.8:
			body_items.append(wheel_items[i])
			wheel_items.remove_at(i)
			print("ehtiyat/kənar təkər gövdəyə qaldı (y=%.3f)" % cy)
	if wheel_items.is_empty():
		print("TƏKƏR TAPILMADI")
		quit(1)
		return

	# ümumi ölçü: yalnız gövdə + təkərlər
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for it in body_items + wheel_items:
		var bb: AABB = it["aabb"]
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	var size := hi - lo
	# irəli +Z: uzun üfüqi ox Z olmalıdır
	print("raw size=", size)
	var scale_f := float(cfg["length"]) / maxf(size.z, size.x)
	var swap_xz := size.x > size.z
	if swap_xz:
		print("UZUN OX X-DƏDİR: cfg.yaw 90 yoxlayın")
	# təkər qruplaşdırma: 4 künc (x işarəsi, z işarəsi), mərkəzə görə
	var wc := Vector3.ZERO
	for it in wheel_items:
		wc += (it["aabb"] as AABB).get_center()
	wc /= wheel_items.size()
	var groups: Array = [[], [], [], []]  # RL, RR, FL, FR (x<0 sol), z<0 arxa
	for it in wheel_items:
		var c: Vector3 = (it["aabb"] as AABB).get_center()
		var front := 1 if c.z > wc.z else 0
		var right := 1 if c.x > wc.x else 0
		groups[front * 2 + right].append(it)
	# disk, tormoz diski və s.: təkərin həcmi içində qalan gövdə meshləri həmin təkərə keçir
	var gboxes: Array[AABB] = []
	for g in 4:
		var gb := AABB()
		for k in groups[g].size():
			var bb: AABB = groups[g][k]["aabb"]
			gb = bb if k == 0 else gb.merge(bb)
		gboxes.append(gb.grow(gb.size.length() * 0.02))
	var moved := 0
	for i in range(body_items.size() - 1, -1, -1):
		var bb: AABB = body_items[i]["aabb"]
		for g in 4:
			if groups[g].size() > 0 and gboxes[g].encloses(bb):
				groups[g].append(body_items[i])
				body_items.remove_at(i)
				moved += 1
				break
	print("təkərə keçən hissələr=", moved)
	for g in 4:
		print("təkər qrupu ", ["W_RL", "W_RR", "W_FL", "W_FR"][g], ": ", groups[g].size(), " mesh")

	# təkər mərkəzləri və radius (qrup bbox)
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for g in 4:
		var glo := Vector3(1e9, 1e9, 1e9)
		var ghi := Vector3(-1e9, -1e9, -1e9)
		for it in groups[g]:
			var bb: AABB = it["aabb"]
			glo = glo.min(bb.position)
			ghi = ghi.max(bb.end)
		centers.append((glo + ghi) * 0.5)
		radii.append((ghi - glo).y * 0.5 * scale_f)
	# yer: təkərlərin ən aşağı nöqtəsi
	var ground := 1e9
	for g in 4:
		ground = minf(ground, centers[g].y - radii[g] / scale_f)
	var body_lo := Vector3(1e9, 1e9, 1e9)
	var body_hi := Vector3(-1e9, -1e9, -1e9)
	for it in body_items:
		var bb: AABB = it["aabb"]
		body_lo = body_lo.min(bb.position)
		body_hi = body_hi.max(bb.end)
	var origin := Vector3((lo.x + hi.x) * 0.5, ground, (lo.z + hi.z) * 0.5)
	var final := Transform3D(Basis.from_scale(Vector3.ONE * scale_f), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -origin)

	# probe=<regex>: uyğun hissələrin son koordinatını çap edir (məs. işlənmiş qaz borusu)
	for a in args:
		if a.begins_with("probe="):
			var pr := RegEx.create_from_string("(?i)" + a.substr(6))
			for it in body_items:
				var mi: MeshInstance3D = it["mi"]
				if pr.search(str(mi.name) + "|" + _mat_names(mi)) != null:
					var fb: AABB = final * (it["aabb"] as AABB)
					print("PROBE %s [%s] lo=%s hi=%s" % [mi.name, _mat_names(mi), fb.position, fb.end])
	if args.has("probe_rear"):
		var minz := 1e9
		for it in body_items:
			minz = minf(minz, (final * (it["aabb"] as AABB)).position.z)
		for it in body_items:
			var fb: AABB = final * (it["aabb"] as AABB)
			if fb.size.length() < 1.2 and fb.position.z < minz + 0.7 and fb.end.y < 0.8:
				print("REAR %s [%s] lo=%s hi=%s" % [(it["mi"] as MeshInstance3D).name, _mat_names(it["mi"]).substr(0, 40), fb.position, fb.end])
	var new_root := Node3D.new()
	new_root.name = "Car"
	if not lamp_items.is_empty():
		var lamp_groups := {"L_HEAD_N": [], "L_HEAD_P": [], "L_TAIL_N": [], "L_TAIL_P": []}
		var mid_x := (lo.x + hi.x) * 0.5
		var front_z := hi.z - size.z * 0.12
		var rear_z := lo.z + size.z * 0.12
		# bir mesh çox fənəri (və tavan işıqlarını) daşıya bilər: üçbucaqlar ön/arxa uca görə bölünür, qalanı gövdədə qalır
		for it in lamp_items:
			var parts := _split_tris(it, func(c: Vector3) -> String:
				if c.z > front_z:
					return "L_HEAD_" + ("P" if c.x > mid_x else "N")
				if c.z < rear_z:
					return "L_TAIL_" + ("P" if c.x > mid_x else "N")
				return "")
			for key in parts:
				if key == "":
					body_items.append(parts[key])
				else:
					lamp_groups[key].append(parts[key])
		for key in lamp_groups:
			if lamp_groups[key].is_empty():
				continue
			var lmi := MeshInstance3D.new()
			lmi.name = key
			lmi.mesh = _merge(lamp_groups[key], final, Vector3.ZERO)
			new_root.add_child(lmi)
			lmi.owner = new_root
			print("%s: %d hissə, mərkəz %s" % [key, lamp_groups[key].size(), lmi.get_aabb().get_center()])
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = _merge(body_items, final, Vector3.ZERO)
	new_root.add_child(body_mi)
	body_mi.owner = new_root
	var names := ["W_RL", "W_RR", "W_FL", "W_FR"]
	for g in 4:
		var wc_final := final * centers[g]
		var wmi := MeshInstance3D.new()
		wmi.name = names[g]
		wmi.mesh = _merge(groups[g], final, wc_final)
		wmi.position = wc_final
		new_root.add_child(wmi)
		wmi.owner = new_root
		print("%s center=(%.3f %.3f %.3f) radius=%.3f" % [names[g], wc_final.x, wc_final.y, wc_final.z, radii[g]])
	var tris := 0
	for m in [body_mi.mesh]:
		for s in (m as ArrayMesh).get_surface_count():
			tris += (m as ArrayMesh).surface_get_array_index_len(s) / 3
	print("body triangles=", tris, " surfaces=", (body_mi.mesh as ArrayMesh).get_surface_count())
	_shrink_textures(new_root, int(cfg["tex"]))
	var bbf: AABB = body_mi.get_aabb()
	print("FINAL body size=", bbf.size, " wheel base=", (centers[2] - centers[0]).length() * scale_f, " track=", absf(centers[1].x - centers[0].x) * scale_f)

	var out_doc := GLTFDocument.new()
	var out_state := GLTFState.new()
	out_doc.append_from_scene(new_root, out_state)
	var err := out_doc.write_to_filesystem(out_state, args[2])
	print("yazıldı ", args[2], " err=", err)
	quit(0 if err == OK else 1)


## Eyni materialı olan hissələri birləşdirir; mərkəz (təkər üçün) çıxılır.
func _merge(items: Array, final: Transform3D, center: Vector3) -> ArrayMesh:
	var by_mat: Dictionary = {}
	for it in items:
		var mi: MeshInstance3D = it["mi"]
		var xf: Transform3D = final * (it["xf"] as Transform3D)
		xf.origin -= center
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var key := mat.get_instance_id() if mat != null else 0
			if not by_mat.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				by_mat[key] = st
			(by_mat[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var out := ArrayMesh.new()
	for key in by_mat:
		var st: SurfaceTool = by_mat[key]
		st.index()
		st.commit(out)
	return out


func _shrink_textures(node: Node, max_size: int) -> void:
	var cache: Dictionary = {}
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is MeshInstance3D):
			continue
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if not (m is BaseMaterial3D):
				continue
			var bm := m as BaseMaterial3D
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


## Bir meshdə bir neçə təkər varsa (OBJ/FBX), üçbucaqları dörd küncə bölür.
func _split_combined_wheels(items: Array) -> Array:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for it in items:
		lo = lo.min((it["aabb"] as AABB).position)
		hi = hi.max((it["aabb"] as AABB).end)
	var span := hi - lo
	var center := (lo + hi) * 0.5
	var out: Array = []
	for it in items:
		var bb: AABB = it["aabb"]
		if bb.size.x < span.x * 0.6 and bb.size.z < span.z * 0.6:
			out.append(it)
			continue
		var mi: MeshInstance3D = it["mi"]
		var xf: Transform3D = it["xf"]
		var tools: Array = [{}, {}, {}, {}]
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
			var mat := mi.mesh.surface_get_material(s)
			for t in range(0, idx.size(), 3):
				var c := xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
				var q := (2 if c.z > center.z else 0) + (1 if c.x > center.x else 0)
				var dict: Dictionary = tools[q]
				if not dict.has(s):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					dict[s] = st
				for k in 3:
					_add_vertex(dict[s], arr, idx[t + k])
		for q in 4:
			var m := ArrayMesh.new()
			for key in tools[q]:
				var st2: SurfaceTool = tools[q][key]
				st2.index()
				st2.commit(m)
			if m.get_surface_count() == 0:
				continue
			var part := MeshInstance3D.new()
			part.mesh = m
			out.append({"mi": part, "xf": xf, "aabb": xf * m.get_aabb()})
		print("bölündü: ", mi.name)
	return out


static func _add_vertex(st: SurfaceTool, arr: Array, i: int) -> void:
	if arr[Mesh.ARRAY_NORMAL] != null:
		st.set_normal(arr[Mesh.ARRAY_NORMAL][i])
	if arr[Mesh.ARRAY_TEX_UV] != null:
		st.set_uv(arr[Mesh.ARRAY_TEX_UV][i])
	if arr[Mesh.ARRAY_TEX_UV2] != null:
		st.set_uv2(arr[Mesh.ARRAY_TEX_UV2][i])
	if arr[Mesh.ARRAY_COLOR] != null:
		st.set_color(arr[Mesh.ARRAY_COLOR][i])
	st.add_vertex(arr[Mesh.ARRAY_VERTEX][i])


## Sümüklü (skin) meshi sadə meshə çevirir ki, GLB-də skin qalmasın.
static func _plain(mesh: Mesh) -> Mesh:
	var needs := false
	for s in mesh.get_surface_count():
		if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES:
			needs = true
	if not needs:
		return mesh
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


static func _explode(src: MeshInstance3D) -> Array:
	var mesh := _plain(src.mesh)
	if mesh.get_surface_count() <= 1:
		var single := MeshInstance3D.new()
		single.name = src.name
		single.mesh = mesh
		return [single]
	var out: Array = []
	for s in mesh.get_surface_count():
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
		m.surface_set_material(0, mesh.surface_get_material(s))
		var part := MeshInstance3D.new()
		part.name = src.name
		part.mesh = m
		out.append(part)
	return out


func _load_tex(path: String, srgb_max: int) -> ImageTexture:
	var img := Image.load_from_file(path)
	if img == null:
		return null
	if maxi(img.get_width(), img.get_height()) > srgb_max:
		img.resize(srgb_max, srgb_max * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Material adına görə PBR dəstindən (BaseColor/Normal/Metallic/Roughness/AO) yeni material qurur.
func _apply_tex_sets(root: Node, sets: Dictionary, base_dir: String) -> void:
	var built: Dictionary = {}
	var size := int(cfg["tex"])
	for key in sets:
		var pre: String = base_dir.path_join(sets[key])
		var m := StandardMaterial3D.new()
		m.resource_name = key
		m.albedo_texture = _load_tex(pre + "_BaseColor.png", size)
		var n := _load_tex(pre + "_Normal.png", size)
		if n != null:
			m.normal_enabled = true
			m.normal_texture = n
		var mt := _load_tex(pre + "_Metallic.png", size)
		if mt != null:
			m.metallic = 1.0
			m.metallic_texture = mt
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		var rg := _load_tex(pre + "_Roughness.png", size)
		if rg != null:
			m.roughness = 1.0
			m.roughness_texture = rg
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		var ao := _load_tex(pre + "_AO.png", size)
		if ao != null:
			m.ao_enabled = true
			m.ao_texture = ao
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		built[key] = m
	var stack: Array = [root]
	var replaced := 0
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null:
			var mesh := (nd as MeshInstance3D).mesh
			for sidx in mesh.get_surface_count():
				var old := mesh.surface_get_material(sidx)
				if old != null and built.has(old.resource_name):
					mesh.surface_set_material(sidx, built[old.resource_name])
					replaced += 1
	print("tekstur dəsti tətbiq olundu: ", replaced, " səth")


## Üçbucaqları classifier(mərkəz) açarına görə ayrı meshlərə bölür (açar "" = qalan hissə).
func _split_tris(it: Dictionary, classifier: Callable) -> Dictionary:
	var mi: MeshInstance3D = it["mi"]
	var xf: Transform3D = it["xf"]
	var tools: Dictionary = {}
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		for t in range(0, idx.size(), 3):
			var c := xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
			var key: String = classifier.call(c)
			if not tools.has(key):
				tools[key] = {}
			if not tools[key].has(s):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mi.mesh.surface_get_material(s))
				tools[key][s] = st
			for k in 3:
				_add_vertex(tools[key][s], arr, idx[t + k])
	var out: Dictionary = {}
	for key in tools:
		var m := ArrayMesh.new()
		for sidx in tools[key]:
			var st2: SurfaceTool = tools[key][sidx]
			st2.index()
			st2.commit(m)
		var part := MeshInstance3D.new()
		part.name = mi.name
		part.mesh = m
		out[key] = {"mi": part, "xf": xf, "aabb": xf * m.get_aabb()}
	return out
