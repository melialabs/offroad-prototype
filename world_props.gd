class_name WorldProps
extends Node3D
## Xəritədəki hazır modellər (assets/props): sənaye binası, köhnə anbar xarabalığı,
## karxanada torpaq və daş yığınları; asfalt boyunca aralıqlı küçə lampaları.

## sink: model dibinin yerə nə qədər basdırılacağı (m); slab: yamacda beton özül
const PROPS := [
	{"model": "res://assets/props/utility_building.glb", "p": Vector2(-715, -645), "scale": 1.0, "clear": 26.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/storage_building.glb", "p": Vector2(-520, -130), "scale": 1.0, "clear": 13.0, "slab": true, "sink": 0.0},
	{"model": "res://assets/props/dirt_mound.glb", "p": Vector2(560, -465), "scale": 0.4, "clear": 9.0, "slab": false, "sink": 0.6},
	{"model": "res://assets/props/cobble_pile.glb", "p": Vector2(520, -495), "scale": 0.32, "clear": 5.0, "slab": false, "sink": 0.1, "mean": true},
]
const LAMP_SPACING := 110.0
const LAMP_OFFSET := MudTerrain.ROAD_HALF + 2.3

var lamps: Array[StreetLamp] = []


static func clearing(p: Vector3) -> bool:
	for s in PROPS:
		if Vector2(p.x, p.z).distance_to(s["p"]) < float(s["clear"]):
			return true
	return false


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


func _place(terrain: MudTerrain, s: Dictionary) -> void:
	if not ResourceLoader.exists(s["model"]):
		return
	var model := (load(s["model"]) as PackedScene).instantiate() as Node3D
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
		var a := road[i]
		var b := road[i + 1]
		var seg := a.distance_to(b)
		while travelled + seg >= next:
			var t := (next - travelled) / seg
			var p := a.lerp(b, t)
			var d := (b - a).normalized()
			var nrm := Vector2(-d.y, d.x) * side
			var at := p + nrm * LAMP_OFFSET
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
