class_name WorldProps
extends Node3D
## Xəritədəki hazır modellər (assets/props): sənaye binası, köhnə anbar xarabalığı,
## karxanada torpaq və daş yığınları; asfalt boyunca aralıqlı küçə lampaları.

## sink: model dibinin yerə nə qədər basdırılacağı (m); slab: yamacda beton özül;
## hide: adında bu sözlər olan hissələr çıxarılır (məs. havada bitən elektrik kabelləri)
const PROPS := [
	# başlanğıc qarajı: həyəti olan sənaye binası
	{"model": "res://assets/props/utility_building.glb", "p": Vector2(-265, 615), "scale": 1.0, "clear": 26.0, "slab": true, "sink": 0.0, "hide": ["Wire"]},
	# mədən: köhnə anbar, torpaq və daş yığınları
	{"model": "res://assets/props/storage_building.glb", "p": Vector2(520, 250), "scale": 1.0, "clear": 13.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/dirt_mound.glb", "p": Vector2(880, 20), "scale": 0.4, "clear": 9.0, "slab": false, "sink": 0.6},
	{"model": "res://assets/props/cobble_pile.glb", "p": Vector2(860, 240), "scale": 0.32, "clear": 5.0, "slab": false, "sink": 0.1, "mean": true},
	# meşə və bataqlıqda xaraba evlər, daş ocaqlar
	{"model": "res://assets/props/new/house_ruin.glb", "p": Vector2(-620, -60), "scale": 0.42, "clear": 10.0, "slab": false, "sink": 0.3, "mean": true},
	{"model": "res://assets/props/new/house_ruin.glb", "p": Vector2(-280, 330), "scale": 0.42, "clear": 10.0, "slab": false, "sink": 0.3, "mean": true},
	{"model": "res://assets/props/new/house_ruin.glb", "p": Vector2(-200, -560), "scale": 0.42, "clear": 10.0, "slab": false, "sink": 0.3, "mean": true},
	# şəhərin kənarında paneli evlər
	{"model": "res://assets/props/city/panel_house.glb", "p": Vector2(285, -70), "scale": 1.0, "clear": 14.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/city/panel_house.glb", "p": Vector2(-200, -95), "scale": 1.0, "clear": 14.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/city/panel_house.glb", "p": Vector2(-205, 120), "scale": 1.0, "clear": 14.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/city/panel_house.glb", "p": Vector2(75, 190), "scale": 1.0, "clear": 14.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/city/panel_house.glb", "p": Vector2(90, -175), "scale": 1.0, "clear": 14.0, "slab": true, "sink": 0.0},
	# yanacaq məntəqələri: başlanğıc yolunda və şəhərin şərq çıxışında
	{"model": "res://assets/props/city/gas_station.glb", "p": Vector2(-95, 470), "scale": 0.85, "clear": 22.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/city/gas_station.glb", "p": Vector2(192, -36), "scale": 0.85, "clear": 22.0, "slab": true, "sink": 0.0},
	# mədənin şimal kənarında və gölün cənub sahilində kranlar
	{"model": "res://assets/props/city/crane.glb", "p": Vector2(690, -105), "scale": 1.0, "clear": 14.0, "slab": false, "sink": 0.6, "mean": true},
	{"model": "res://assets/props/city/crane.glb", "p": Vector2(-130, -540), "scale": 0.8, "clear": 12.0, "slab": false, "sink": 0.5, "mean": true},
	# tərk edilmiş qatar vaqonları: bataqlıq yanında və mədən yolunda
	{"model": "res://assets/props/city/improvised_house.glb", "p": Vector2(-360, 255), "scale": 1.0, "clear": 18.0, "slab": false, "sink": 0.4, "mean": true},
	{"model": "res://assets/props/city/improvised_house.glb", "p": Vector2(880, 200), "scale": 1.0, "clear": 18.0, "slab": false, "sink": 0.4, "mean": true},
	# xaraba evlərin yanında tək yolka
	{"model": "res://assets/props/plants/xmas_tree.glb", "p": Vector2(-598, -48), "scale": 1.3, "clear": 3.0, "slab": false, "sink": 0.1, "mean": true},
	{"model": "res://assets/props/plants/xmas_tree.glb", "p": Vector2(-258, 345), "scale": 1.3, "clear": 3.0, "slab": false, "sink": 0.1, "mean": true},
	{"model": "res://assets/props/plants/xmas_tree.glb", "p": Vector2(-178, -542), "scale": 1.3, "clear": 3.0, "slab": false, "sink": 0.1, "mean": true},
	{"model": "res://assets/props/new/fireplace.glb", "p": Vector2(-560, -130), "scale": 0.25, "clear": 5.0, "slab": false, "sink": 0.2, "mean": true},
	{"model": "res://assets/props/new/fireplace.glb", "p": Vector2(-150, -515), "scale": 0.25, "clear": 5.0, "slab": false, "sink": 0.2, "mean": true},
]
## Təsadüfi səpələnən obyektlər: [model, say, miqyas aralığı, bölgə, toqquşma radiusu (0 = yox)]
const SCATTER := [
	["res://assets/props/new/rock_small.glb", 140, Vector2(1.0, 3.0), "wild", 0.0],
	["res://assets/props/new/rock_part.glb", 30, Vector2(0.12, 0.28), "rocky", 2.0],
	["res://assets/props/new/fallen_tree.glb", 45, Vector2(3.5, 5.0), "forest", 0.4],
	["res://assets/props/new/river_log.glb", 20, Vector2(1.6, 2.4), "river", 0.4],
	# kanyon və mədən ətrafında quru çöl kolları, meşədə yosun/ot skanları
	["res://assets/props/plants/desert_shrubs.glb", 40, Vector2(0.35, 0.7), "rocky", 0.0],
	["res://assets/props/plants/scanned_plants.glb", 30, Vector2(0.35, 0.6), "wild", 0.0],
]
const LAMP_SPACING := 110.0
const LAMP_OFFSET := MudTerrain.ROAD_HALF + 2.3

var lamps: Array[StreetLamp] = []


static func clearing(p: Vector3) -> bool:
	for s in PROPS:
		if Vector2(p.x, p.z).distance_to(s["p"]) < float(s["clear"]):
			return true
	for e in extras:
		if Vector2(p.x, p.z).distance_to(e["p"]) < float(e["clear"]):
			return true
	return false


## Yeni modellər (assets/props/town): köhnə maşınlar və yol kənarı binalar. size: x, hündürlük, z; axis: uzun ox.
const TOWN_PROPS := {
	"necro": {"path": "res://assets/props/town/necro_car.glb", "size": Vector3(3.15, 1.53, 4.35), "axis": "z", "clear": 4.5, "car": true},
	"ural": {"path": "res://assets/props/town/ural_crane.glb", "size": Vector3(2.33, 3.01, 8.4), "axis": "z", "clear": 6.0, "car": true},
	"abandoned": {"path": "res://assets/props/town/abandoned.glb", "size": Vector3(9.84, 6.41, 9.83), "axis": "x", "clear": 13.0, "car": false},
	"concrete_1": {"path": "res://assets/props/town/concrete_1.glb", "size": Vector3(8.44, 6.74, 8.43), "axis": "x", "clear": 12.0, "car": false},
	"concrete_4": {"path": "res://assets/props/town/concrete_4.glb", "size": Vector3(8.39, 6.09, 8.48), "axis": "x", "clear": 12.0, "car": false},
	"concrete_5": {"path": "res://assets/props/town/concrete_5.glb", "size": Vector3(7.91, 6.5, 7.91), "axis": "x", "clear": 12.0, "car": false},
	"brick_shop": {"path": "res://assets/props/town/brick_shop.glb", "size": Vector3(24.2, 9.6, 7.2), "axis": "x", "clear": 17.0, "car": false},
	"row_house": {"path": "res://assets/props/town/row_house.glb", "size": Vector3(8.32, 11.16, 19.9), "axis": "z", "clear": 15.0, "car": false},
}
const ROW_HOUSE_TINT := Color(0.80, 0.66, 0.52)
## [növ, şəhərdə say, şəhərdən kənarda say]
const EXTRA_PLAN := [
	["necro", 9, 7], ["ural", 2, 3],
	["abandoned", 0, 5], ["concrete_1", 0, 2], ["concrete_4", 0, 2], ["concrete_5", 0, 2], ["brick_shop", 0, 2], ["row_house", 0, 1],
]
## Yol kənarındakı köhnə maşın və binaların yeri: terrain hazır olan kimi (bitki örtüyündən əvvəl) hesablanır ki, bitkilər təmizlənsin.
static var extras: Array = []


static func plan_extras(terrain: MudTerrain) -> void:
	extras.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9021
	var road: PackedVector2Array = terrain._road
	if road.size() < 4:
		return
	for plan in EXTRA_PLAN:
		var def: Dictionary = TOWN_PROPS[plan[0]]
		var size: Vector3 = def["size"]
		var half := maxf(size.x, size.z) * 0.5
		for in_town in [true, false]:
			var want := int(plan[1] if in_town else plan[2])
			var tries := 0
			while want > 0 and tries < 400:
				tries += 1
				var i := rng.randi_range(0, road.size() - 2)
				if terrain._road_gap[i] == 1:
					continue
				var a := road[i]
				var d := (road[i + 1] - a).normalized()
				if d.length() < 0.5:
					continue
				var inside := MapLayout._ellipse(a, MapLayout.TOWN, MapLayout.TOWN_RADII) < 0.95
				if inside != in_town:
					continue
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var nrm := Vector2(-d.y, d.x) * side
				var off := (MudTerrain.ROAD_HALF + 2.6 + rng.randf_range(0.0, 1.2)) if def["car"] else (MudTerrain.ROAD_HALF + 5.0 + half + rng.randf_range(2.0, 9.0))
				var q := a + nrm * off
				var qp := Vector3(q.x, 0, q.y)
				if terrain.road_distance_at(qp) < MudTerrain.ROAD_HALF + (1.6 if def["car"] else 3.5 + half * 0.6):
					continue
				if terrain.water_level_at(qp) != -INF:
					continue
				var ground := terrain.height_at(qp)
				if terrain.bridge_deck_above(qp, ground) > -INF or terrain.activity_clearing(qp):
					continue
				if terrain.slope_at(qp) > 0.35:
					continue
				var clear := float(def["clear"])
				var ok := true
				for s in PROPS:
					if q.distance_to(s["p"]) < float(s["clear"]) + clear * 0.6:
						ok = false
						break
				for e in extras:
					if ok and q.distance_to(e["p"]) < float(e["clear"]) + clear * 0.8:
						ok = false
				if not ok:
					continue
				# yaw: uzun ox yola paralel; avtomobilləri bəzən xaraba kimi çarpaz qoy
				var yaw := atan2(d.x, d.y) if def["axis"] == "z" else atan2(-d.y, d.x)
				if def["car"]:
					yaw += rng.randf_range(-0.22, 0.22) + (PI if rng.randf() < 0.5 else 0.0)
					if rng.randf() < 0.18:
						yaw += rng.randf_range(0.6, 1.2)
				extras.append({"kind": plan[0], "p": q, "yaw": yaw, "clear": clear})
				want -= 1


## Tekstura daşımayan (düz ağ) materialları verilmiş suvaq rəngi ilə boyayır (row_house modeli ağ gəlir).
static var _tint_cache: Dictionary = {}
static func tint_untextured(node: Node, color: Color) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			if not _tint_cache.has(mat):
				var tinted := mat.duplicate() as BaseMaterial3D
				tinted.albedo_color = color
				tinted.roughness = 0.9
				tinted.metallic = 0.0
				_tint_cache[mat] = tinted
			mi.set_surface_override_material(s, _tint_cache[mat])


## Skan modellərinin çoxu işıqsız (unlit) materialla gəlir və gecə parlayır: işıq qəbul edən surətlərlə əvəzlənir.
static var _lit_cache: Dictionary = {}
static func make_lit(node: Node) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			if not _lit_cache.has(mat):
				var lit := mat.duplicate() as BaseMaterial3D
				lit.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				lit.roughness = 1.0
				lit.metallic = 0.0
				lit.metallic_specular = 0.15
				_lit_cache[mat] = lit
			mi.set_surface_override_material(s, _lit_cache[mat])


func build(terrain: MudTerrain) -> void:
	for s in PROPS:
		_place(terrain, s)
	_place_road_lamps(terrain)
	for e in extras:
		_place_extra(terrain, e)
	_scatter(terrain)


func _place(terrain: MudTerrain, s: Dictionary) -> void:
	if not ResourceLoader.exists(s["model"]):
		return
	var model := (load(s["model"]) as PackedScene).instantiate() as Node3D
	for n in model.find_children("*", "MeshInstance3D", true, false):
		for word in s.get("hide", []):
			if str(n.name).contains(word):
				n.get_parent().remove_child(n)
				n.free()
				break
	var sc: float = s["scale"]
	# modelin dibi və mərkəzi (miqyasdan əvvəl)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := _local_xf(mi, model)
		var b: AABB = xf * mi.mesh.get_aabb()
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	var center := (lo + hi) * 0.5
	var half := Vector2(hi.x - lo.x, hi.z - lo.z) * 0.5 * sc
	var c2: Vector2 = s["p"]
	var dir := _road_dir(terrain, c2)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
	var low := INF
	var sum := 0.0
	var pts := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]
	for k in pts:
		var w: Vector3 = Vector3(c2.x, 0, c2.y) + basis * Vector3(k.x * half.x, 0, k.y * half.y)
		var hh := terrain.height_at(w)
		low = minf(low, hh)
		sum += hh
	var ground: float = (sum / pts.size() if s["slab"] or s.get("mean", false) else low) - float(s["sink"])
	var root := Node3D.new()
	root.transform = Transform3D(basis, Vector3(c2.x, ground, c2.y))
	add_child(root)
	model.scale = Vector3.ONE * sc
	model.position = -Vector3(center.x, lo.y, center.z) * sc
	root.add_child(model)
	make_lit(model)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.visibility_range_end = 900.0
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		col.shape = mi.mesh.create_trimesh_shape()
		body.add_child(col)
		mi.add_child(body)
	if s["slab"]:
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		var depth := ground - low + 0.5
		box.size = Vector3(half.x * 2.0 + 0.4, depth, half.y * 2.0 + 0.4)
		slab.mesh = box
		slab.position = Vector3(0, 0.02 - depth * 0.5, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.38, 0.35)
		mat.roughness = 1.0
		slab.material_override = mat
		root.add_child(slab)


func _place_extra(terrain: MudTerrain, e: Dictionary) -> void:
	var def: Dictionary = TOWN_PROPS[e["kind"]]
	if not ResourceLoader.exists(def["path"]):
		return
	var size: Vector3 = def["size"]
	var p: Vector2 = e["p"]
	var yaw: float = e["yaw"]
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var c := Vector3(p.x, 0, p.y)
	# yamacda avtomobil yerin meylinə uyğun əyilir; bina isə ən alçaq küncə oturub özül alır
	var hf := terrain.height_at(c + fwd * size.z * 0.4)
	var hb := terrain.height_at(c - fwd * size.z * 0.4)
	var hr := terrain.height_at(c + right * size.x * 0.4)
	var hl := terrain.height_at(c - right * size.x * 0.4)
	var root := Node3D.new()
	add_child(root)
	var inst := (load(def["path"]) as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	if e["kind"] == "row_house":
		tint_untextured(inst, ROW_HOUSE_TINT)
	var hgt: float = size.y
	if def["car"]:
		var up := Vector3((hl - hr) / (size.x * 0.8), 1.0, (hb - hf) / (size.z * 0.8)).normalized()
		var bz := fwd.slide(up).normalized()
		var bx := up.cross(bz).normalized()
		var ground := (hf + hb + hr + hl) * 0.25 - 0.06
		root.transform = Transform3D(Basis(bx, up, bz), Vector3(p.x, ground, p.y))
	else:
		var low := minf(minf(hf, hb), minf(hr, hl))
		var high := maxf(maxf(hf, hb), maxf(hr, hl))
		root.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, low - 0.15, p.y))
		var depth := high - low + 0.6
		var slab := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(size.x + 0.3, depth, size.z + 0.3)
		slab.mesh = sbox
		slab.position = Vector3(0, 0.1 - depth * 0.5, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.41, 0.4)
		mat.roughness = 1.0
		slab.material_override = mat
		root.add_child(slab)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visibility_range_end = 380.0 if def["car"] else 650.0
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, hgt, size.z)
	col.shape = shape
	col.position = Vector3(0, hgt * 0.5, 0)
	body.add_child(col)
	root.add_child(body)


## Daşlar, qayalar, yıxılmış ağaclar və kötüklər: bölgəyə uyğun təsadüfi (sabit toxumlu) yerləşdirmə,
## MultiMesh ilə (hər növ bir çəkiliş); böyüklər üçün sadə toqquşma.
func _scatter(terrain: MudTerrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	for row in SCATTER:
		var path: String = row[0]
		if not ResourceLoader.exists(path):
			continue
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		var mis := inst.find_children("*", "MeshInstance3D", true, false)
		if mis.is_empty():
			inst.free()
			continue
		var src := mis[0] as MeshInstance3D
		var mesh := src.mesh.duplicate() as Mesh
		var base_xf := _local_xf(src, inst)
		inst.free()
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				var lit := mat.duplicate() as BaseMaterial3D
				lit.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				lit.roughness = 1.0
				lit.metallic = 0.0
				mesh.surface_set_material(s, lit)
		var bottom: float = (base_xf * mesh.get_aabb()).position.y
		var xforms: Array[Transform3D] = []
		var count: int = row[1]
		var tries := 0
		while xforms.size() < count and tries < count * 40:
			tries += 1
			var q := Vector2(rng.randf_range(-930, 930), rng.randf_range(-930, 930))
			var p := Vector3(q.x, 0, q.y)
			if not _scatter_ok(terrain, p, str(row[3])):
				continue
			var sc := rng.randf_range(row[2].x, row[2].y)
			p.y = terrain.height_at(p) - bottom * sc - 0.08 * sc
			var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * sc)
			xforms.append(Transform3D(basis, p) * base_xf)
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 260.0 if float(row[4]) > 0.0 else 140.0
		mmi.name = "Scatter_" + path.get_file().get_basename()
		add_child(mmi)
		var radius: float = row[4]
		if radius > 0.0:
			var body := StaticBody3D.new()
			for xf in xforms:
				var col := CollisionShape3D.new()
				var aabb: AABB = xf * mesh.get_aabb()
				var shape := BoxShape3D.new()
				shape.size = aabb.size * Vector3(0.8, 0.85, 0.8)
				col.shape = shape
				col.position = aabb.get_center()
				body.add_child(col)
			add_child(body)


func _scatter_ok(terrain: MudTerrain, p: Vector3, region: String) -> bool:
	if HillClimbCatalog.ZONE.grow(15.0).has_point(Vector2(p.x, p.z)) or clearing(p) or BarnFinds.clearing(p):
		return false
	if terrain.road_distance_fast(p) < MudTerrain.ROAD_HALF + 4.0:
		return false
	var h := terrain.height_at(p)
	if terrain.water_level_at(p) > h - 0.6:
		return false
	var ff := MapLayout.forest_factor(p.x, p.z)
	var river_d: float = terrain._near_route(Vector2(p.x, p.z), terrain._river, terrain._river_len, terrain._river_bins)[0]
	match region:
		"wild":
			return ff > 0.0 and terrain.slope_at(p) < 0.6
		"rocky":
			return (MapLayout.CANYON.has_point(Vector2(p.x, p.z)) or h > 45.0 or (river_d > 12.0 and river_d < 40.0)) and terrain.slope_at(p) < 0.8
		"forest":
			return ff >= 1.0 and MapLayout.FOREST.has_point(Vector2(p.x, p.z)) and terrain.slope_at(p) < 0.4
		"river":
			return (river_d > 10.0 and river_d < 26.0) or MapLayout._ellipse(Vector2(p.x, p.z), MapLayout.SWAMP, MapLayout.SWAMP_RADII) < 0.9
	return false


func _local_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var node: Node = n
	while node != root and node != null:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf


## Asfalt boyunca hər LAMP_SPACING metrdən bir, növbə ilə yolun iki tərəfində.
func _place_road_lamps(terrain: MudTerrain) -> void:
	var road: PackedVector2Array = terrain._road
	var next := LAMP_SPACING * 0.5
	var travelled := 0.0
	var side := 1.0
	for i in road.size() - 1:
		if terrain._road_gap[i] == 1:
			travelled = 0.0
			next = LAMP_SPACING * 0.5
			continue
		var a := road[i]
		var b := road[i + 1]
		var seg := a.distance_to(b)
		while travelled + seg >= next:
			var t := (next - travelled) / seg
			var p := a.lerp(b, t)
			var d := (b - a).normalized()
			var nrm := Vector2(-d.y, d.x) * side
			var at := p + nrm * LAMP_OFFSET
			# kəsişmədə başqa yolun üstünə düşən lampa qoyulmur
			if terrain.road_distance_at(Vector3(at.x, 0, at.y)) > MudTerrain.ROAD_HALF + 1.5 and terrain.water_level_at(Vector3(at.x, 0, at.y)) == -INF:
				add_lamp(terrain, Vector3(at.x, 0, at.y), -nrm)
			side = -side
			next += LAMP_SPACING
		travelled += seg


## Lampa: dirək `pos`-da, qolu `toward` istiqamətinə (yola) baxır.
func add_lamp(terrain: MudTerrain, pos: Vector3, toward: Vector2) -> StreetLamp:
	var lamp := StreetLamp.new()
	var g := pos
	g.y = terrain.height_at(pos) - 0.05
	lamp.transform = Transform3D(Basis(Vector3.UP, atan2(-toward.y, toward.x)), g)
	add_child(lamp)
	lamps.append(lamp)
	return lamp


func _road_dir(terrain: MudTerrain, c: Vector2) -> Vector2:
	var best := INF
	var target := c + Vector2(0, 1)
	for p in terrain._road:
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			target = p
	return (target - c).normalized()
