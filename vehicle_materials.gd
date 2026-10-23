class_name VehicleMaterials
extends RefCounted
## Maşın modellərinin PBR materiallarını düzəldir. glTF-də metal teksturası olmadıqda metallic=1/roughness=1
## standart gəlir və boyalı kuzov tutqun metal kimi görünür. Ad üzrə: boya (lak qatı), şüşə, rezin, disk/xrom,
## salon/şassi. Metal/roughness teksturası olan materiallara toxunulmur.

const GLASS := ["glass", "window"]
const RUBBER := ["tire", "tyre", "rubber", "whel", "wheel"]
const METAL := ["rim", "chrome", "mirror", "disk"]
const PAINT := ["paint", "body", "base"]
const INNER := ["interior", "chassis", "rama", "other", "accessor", "plastic", "radiator", "roof", "number"]


static func tune(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var name := str(mi.name).to_lower()
			var over := mi.get_surface_override_material(s) as BaseMaterial3D
			var src := over if over != null else mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null or src.has_meta("vehicle_tuned"):
				continue
			var m := src.duplicate() as BaseMaterial3D
			if not _apply(m, (src.resource_name + " " + name).to_lower()):
				continue
			m.set_meta("vehicle_tuned", true)
			# mesh-in özünə yazılır: təkər meshləri sonradan ayrı düyünlərə köçürülür
			if over != null:
				mi.set_surface_override_material(s, m)
			else:
				mi.mesh.surface_set_material(s, m)


static func _has(name: String, words: Array) -> bool:
	for w in words:
		if name.contains(w):
			return true
	return false


static func _apply(m: BaseMaterial3D, name: String) -> bool:
	var has_mr := m.metallic_texture != null or m.roughness_texture != null
	if _has(name, GLASS):
		m.metallic = 0.0
		m.roughness = 0.04
		m.metallic_specular = 0.5
		if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.45
		return true
	if _has(name, RUBBER) and not _has(name, METAL):
		if has_mr:
			return false
		m.metallic = 0.0
		m.roughness = 0.9
		m.metallic_specular = 0.3
		return true
	if _has(name, METAL):
		m.metallic = maxf(m.metallic, 0.9)
		m.roughness = clampf(m.roughness, 0.12, 0.35)
		return true
	if has_mr:
		return false
	if _has(name, PAINT):
		# dielektrik boya + nazik lak: səma və ətraf mühit lak qatında əks olunur
		m.metallic = 0.0
		m.roughness = 0.42
		m.metallic_specular = 0.5
		m.clearcoat_enabled = true
		m.clearcoat = 0.55
		m.clearcoat_roughness = 0.18
		return true
	if _has(name, INNER) or m.metallic >= 0.99:
		m.metallic = 0.0
		m.roughness = 0.75
		return true
	return false
