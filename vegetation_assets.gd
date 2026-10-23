class_name VegetationAssets
extends RefCounted
## assets/vegetation/<id>/<id>_lodN.glb fayllarından mesh-ləri və materialları yükləyir.
## Materiallar glb-də yalnız ad kimi var (tools/blender_optimize.py), tekstura burada təyin olunur:
##  - "foliage": alfa kart teksturası (assets/vegetation/textures/<ad>_foliage.png), alpha scissor
##  - qalan: assets/vegetation/textures/<id>/<material>_{diff,nor_gl,arm}_1k.jpg (ARM: R=AO, G=roughness, B=metal)

const ROOT := "res://assets/vegetation/"

static var _mat_cache := {}
static var _wind_materials: Array[ShaderMaterial] = []
static var _wind_shader: Shader


## Yüklənmiş bütün materiallar (fəsil rəngi üçün).
static func cached_materials() -> Array:
	return _mat_cache.values()


## {variant_name: [lod0_mesh, lod1_mesh, ...]}. glb tapılmasa boş lüğət.
static func load_species(id: String, foliage_texture: String) -> Dictionary:
	var result := {}
	var wind_bounds := {}
	var lod := 0
	while ResourceLoader.exists(ROOT + "%s/%s_lod%d.glb" % [id, id, lod]):
		var scene := load(ROOT + "%s/%s_lod%d.glb" % [id, id, lod]) as PackedScene
		var inst := scene.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var node := mi as MeshInstance3D
			var variant := _variant_of(node.name, id)
			var mesh := node.mesh
			# LODs of a variant share the same root/canopy scale. Small grass
			# meshes are only 6–20 cm high before the forest instance scale.
			if not wind_bounds.has(variant):
				wind_bounds[variant] = mesh.get_aabb()
			var bounds: AABB = wind_bounds[variant]
			var root_height := maxf(0.0,bounds.position.y)
			var plant_height := maxf(0.03,bounds.end.y-root_height)
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				var mname: String = m.resource_name if m != null else ""
				mesh.surface_set_material(s, material_for(id, mname, foliage_texture, lod,variant,plant_height,root_height))
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


static func material_for(id: String, mat_name: String, foliage_texture: String, lod: int = 0,variant: String = "",plant_height: float = 1.0,root_height: float = 0.0) -> Material:
	var key := "%s|%s|%d|%s" % [id, mat_name, lod,variant]
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
	# GPU wind on living plants; dead wood retains its original material.
	if id not in ["dead_tree_trunk","tree_stump_01"] and m.albedo_texture != null:
		if _wind_shader == null:
			_wind_shader = load("res://vegetation_wind.gdshader")
		var animated := ShaderMaterial.new()
		animated.shader = _wind_shader
		animated.resource_name = mat_name
		animated.set_shader_parameter("albedo_tex",m.albedo_texture)
		animated.set_shader_parameter("use_normal",m.normal_enabled)
		animated.set_shader_parameter("use_arm",m.ao_enabled)
		if m.normal_texture != null:
			animated.set_shader_parameter("normal_tex",m.normal_texture)
		if m.ao_texture != null:
			animated.set_shader_parameter("arm_tex",m.ao_texture)
		animated.set_shader_parameter("alpha_threshold",threshold)
		animated.set_shader_parameter("cutout",m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		animated.set_shader_parameter("vertex_tint",m.vertex_color_use_as_albedo)
		var profile := wind_profile(id)
		animated.set_shader_parameter("height_scale",plant_height)
		animated.set_shader_parameter("root_height",root_height)
		animated.set_shader_parameter("bend",profile["bend"])
		animated.set_shader_parameter("flutter",profile["flutter"])
		animated.set_shader_parameter("sway_speed",profile["speed"])
		animated.set_shader_parameter("woody",profile["woody"])
		_mat_cache[key] = animated
		_wind_materials.append(animated)
		return animated
	_mat_cache[key] = m
	return m


static func wind_profile(id: String) -> Dictionary:
	if id in ["pine_tree_01","fir_tree_01"]:
		return {"bend":.10,"flutter":.15,"speed":.85,"woody":true}
	if id in ["pine_sapling_medium","tree_small_02"]:
		return {"bend":.16,"flutter":.14,"speed":1.05,"woody":true}
	if id == "pine_sapling_small":
		return {"bend":.30,"flutter":.12,"speed":1.45,"woody":true}
	if id.begins_with("grass_"):
		return {"bend":.72,"flutter":.15,"speed":2.2,"woody":false}
	return {"bend":.45,"flutter":.16,"speed":1.7,"woody":false}


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


static func update_wind(clock: float,direction: Vector3,strength: float) -> void:
	for material in _wind_materials:
		material.set_shader_parameter("wind_clock",clock)
		material.set_shader_parameter("wind_direction",direction)
		material.set_shader_parameter("wind_strength",strength)
