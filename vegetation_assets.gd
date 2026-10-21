class_name VegetationAssets
extends RefCounted
## assets/vegetation/<id>/<id>_lodN.glb fayllarından mesh-ləri və materialları yükləyir.
## Materiallar glb-də yalnız ad kimi var (tools/blender_optimize.py), tekstura burada təyin olunur:
##  - "foliage": alfa kart teksturası (assets/vegetation/textures/<ad>_foliage.png), alpha scissor
##  - qalan: assets/vegetation/textures/<id>/<material>_{diff,nor_gl,arm}_1k.jpg (ARM: R=AO, G=roughness, B=metal)

const ROOT := "res://assets/vegetation/"

static var _mat_cache := {}


## Yüklənmiş bütün materiallar (fəsil rəngi üçün).
static func cached_materials() -> Array:
	return _mat_cache.values()


## {variant_name: [lod0_mesh, lod1_mesh, ...]}. glb tapılmasa boş lüğət.
static func load_species(id: String, foliage_texture: String) -> Dictionary:
	var result := {}
	var lod := 0
	while ResourceLoader.exists(ROOT + "%s/%s_lod%d.glb" % [id, id, lod]):
		var scene := load(ROOT + "%s/%s_lod%d.glb" % [id, id, lod]) as PackedScene
		var inst := scene.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var node := mi as MeshInstance3D
			var variant := _variant_of(node.name, id)
			var mesh := node.mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				var mname: String = m.resource_name if m != null else ""
				mesh.surface_set_material(s, material_for(id, mname, foliage_texture, lod))
			if not result.has(variant):
				result[variant] = []
			(result[variant] as Array).resize(lod + 1)
			result[variant][lod] = mesh
		inst.free()
		lod += 1
	return result


static func _variant_of(node_name: String, id: String) -> String:
	var n := node_name
	if n.begins_with(id + "_"):
		n = n.substr(id.length() + 1)
	# Blender eyni adlı obyektlərə ".001" əlavə edir (glb-də "_001"), variant adı ilk hissədir
	return n.split("_")[0].split(".")[0]


## Uzaq LOD-larda alfa mip-ləri seyrəlir, scissor həddi aşağı salınır ki, yarpaq yox olmasın.
const ALPHA_THRESHOLD := [0.5, 0.38, 0.26]


static func material_for(id: String, mat_name: String, foliage_texture: String, lod: int = 0) -> Material:
	var key := "%s|%s|%d" % [id, mat_name, lod]
	var threshold: float = ALPHA_THRESHOLD[mini(lod, ALPHA_THRESHOLD.size() - 1)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	if mat_name == "foliage":
		m.albedo_texture = load(ROOT + "textures/%s_foliage.png" % foliage_texture)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = threshold
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP  # yarpaq arxadan işıqlanmış görünsün
		m.backlight_enabled = true
		m.backlight = Color(0.25, 0.3, 0.15)
	else:
		var files := _material_files(id, mat_name)
		var base := ROOT + "textures/%s/" % id
		if files.get("diff", "") != "":
			m.albedo_texture = load(base + files["diff"])
		if files.get("nor", "") != "":
			m.normal_enabled = true
			m.normal_texture = load(base + files["nor"])
		if files.get("arm", "") != "":
			var arm := load(base + files["arm"])
			m.roughness_texture = arm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.ao_enabled = true
			m.ao_texture = arm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if files.get("mode", "") == "scissor":
			# alfa kartlı bitki (kol, ayıqulağı, ot): albedo RGBA-dır, hər iki üzü çəkilir
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = threshold
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			m.backlight_enabled = true
			m.backlight = Color(0.25, 0.3, 0.15)
		else:
			m.cull_mode = BaseMaterial3D.CULL_BACK
	_mat_cache[key] = m
	return m


## assets/vegetation/<id>/materials.json: material adı -> {diff, nor, arm} fayl adları (optimizator yazır).
static func _material_files(id: String, mat_name: String) -> Dictionary:
	var path := ROOT + "%s/materials.json" % id
	if not ResourceLoader.exists(path):
		return {}
	var j := load(path) as JSON
	if j == null or not (j.data is Dictionary):
		return {}
	var d: Dictionary = j.data
	return d.get(mat_name, {})
