extends SceneTree
## Jeep modelinin yüklənməsini və təkərlərin ayrılmasını yoxlayır.


func _initialize() -> void:
	var packed := load(JeepModel.SCENE_PATH) as PackedScene
	var raw := packed.instantiate() as Node3D
	print("RAW kök transform=", raw.transform)
	for mi in raw.find_children("*", "MeshInstance3D", true, false):
		if mi.get_aabb().position.y < 0.1 and mi.get_aabb().size.y > 1.0:
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != raw:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			print("RAW təkər mesh aabb=", mi.get_aabb(), " nisbi xf basis=", xf.basis, " origin=", xf.origin)
	raw.free()
	var j := JeepModel.new()
	var ok := j.load_model()
	print("MODEL yükləndi=", ok)
	if ok:
		print("MODEL təkər radiusu=%.3f origin=%s" % [j.wheel_radius, j.origin])
		print("MODEL ilkin yaw bucaqları (dərəcə)=", j.wheel_yaws_deg)
		print("MODEL gövdəyə qaytarılan üçbucaq=", j.static_tris)
		for k in 4:
			var m := j.wheel_meshes[k]
			print("MODEL təkər %d: mərkəz=%s üçbucaq=%d aabb=%s" % [
				k, j.wheel_centers[k], m.surface_get_array_index_len(0) / 3, m.get_aabb()])
		for k in [1, 3]:
			var arrs := j.wheel_meshes[k].surface_get_arrays(0)
			var vv: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			var bins := {}
			for p in vv:
				if Vector2(p.y, p.z).length() > 0.5:
					var b := int(floor(p.x / 0.05))
					bins[b] = int(bins.get(b, 0)) + 1
			var keys := bins.keys()
			keys.sort()
			var s := ""
			for b in keys:
				s += "%.2f:%d " % [b * 0.05, bins[b]]
			print("HIST təkər %d (xarici nöqtələr, x:say): %s" % [k, s])
		var n := 0
		for c in j.body.find_children("*", "MeshInstance3D", true, false):
			n += 1
		print("MODEL gövdə mesh sayı=", n)
	quit(0 if ok else 1)
