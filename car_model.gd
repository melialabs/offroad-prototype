class_name CarModel
extends RefCounted
## tools/blender_vehicle_prep.py ilə hazırlanmış maşın GLB-sini yükləyir.
## Fayl: "Body" və 4 təkər (W_RL, W_RR, W_FL, W_FR); mənşə yerdə, mərkəzdə, irəli +Z.
## Sıra: 0 = arxa (-x), 1 = arxa (+x), 2 = ön (-x), 3 = ön (+x) (JeepModel ilə eyni).

const WHEEL_NAMES := ["W_RL", "W_RR", "W_FL", "W_FR"]

var body: Node3D
var wheel_meshes: Array[Mesh] = []
var wheel_centers: Array[Vector3] = []  # yer səviyyəsində, gövdə mərkəzinə görə (y yerdən)
var wheel_radius := 0.3
var length := 4.0
var width := 1.8
## Modelin öz fənər meshləri (Blender-də L_HEAD_N/P, L_TAIL_N/P kimi ayrılıb); mərkəzləri maşın koordinatındadır
var head_lamps: Array[MeshInstance3D] = []
var tail_lamps: Array[MeshInstance3D] = []
var head_lamp_pos: Array[Vector3] = []
var tail_lamp_pos: Array[Vector3] = []


func load_model(path: String, origin_height: float) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var root := packed.instantiate() as Node3D
	if root == null:
		return false
	VehicleMaterials.tune(root)
	var radius_sum := 0.0
	for i in 4:
		var n := root.find_child(WHEEL_NAMES[i], true, false) as MeshInstance3D
		if n == null:
			root.free()
			return false
		var aabb := n.get_aabb()
		var c := n.transform.origin  # mənşə təkər mərkəzindədir (Blender-də origin_set)
		wheel_centers.append(c - Vector3(0, origin_height, 0))
		radius_sum += aabb.size.y * 0.5
		# təkər meshini düyündən ayır (mərkəzdə qalır)
		wheel_meshes.append(n.mesh)
		n.get_parent().remove_child(n)
		n.free()
	wheel_radius = radius_sum / 4.0
	var bd := root.find_child("Body", true, false) as MeshInstance3D
	if bd != null:
		var bb := bd.get_aabb()
		length = bb.size.z
		width = bb.size.x
	root.position = Vector3(0, -origin_height, 0)
	body = root
	for sd in ["N", "P"]:
		var h := root.find_child("L_HEAD_" + sd, true, false) as MeshInstance3D
		if h != null:
			head_lamps.append(h)
			head_lamp_pos.append(_lamp_anchor(h, root, true))
		var t := root.find_child("L_TAIL_" + sd, true, false) as MeshInstance3D
		if t != null:
			tail_lamps.append(t)
			tail_lamp_pos.append(_lamp_anchor(t, root, false))
	return true


static func _lamp_anchor(lamp: MeshInstance3D, root: Node3D, front: bool) -> Vector3:
	var xf := Transform3D.IDENTITY
	var node: Node = lamp
	while node != root:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	var bounds: AABB = xf * lamp.get_aabb()
	var point := bounds.get_center()
	point.z = bounds.end.z + 0.015 if front else bounds.position.z - 0.015
	return root.transform * point
