extends SceneTree
## Real imported geometry/material coverage. Does not pretend to render vertices.
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print('FAIL ',label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var minimum_grass_bend := INF
	for species in Vegetation.SPECIES:
		var d: Dictionary = Vegetation.SPECIES[species]
		var variants := VegetationAssets.load_species(d['asset'],d['foliage'])
		check(not variants.is_empty(),'real species loaded: '+species)
		for variant in variants:
			var lods: Array = variants[variant]
			var bounds: AABB = lods[0].get_aabb()
			var root_y := maxf(0,bounds.position.y)
			var height := maxf(.03,bounds.end.y-root_y)
			for lod in lods:
				if lod==null:
					continue
				for surface in lod.get_surface_count():
					var material: Material = lod.surface_get_material(surface)
					if d['kind']=='wood':
						check(material is StandardMaterial3D,'dead wood stays rigid')
						continue
					check(material is ShaderMaterial,'living surface animated: '+species)
					check(is_equal_approx(material.get_shader_parameter('height_scale'),height),'all LODs use actual variant height: '+species)
					check(is_equal_approx(material.get_shader_parameter('root_height'),root_y),'actual root height: '+species)
					check(material.get_shader_parameter('albedo_tex')!=null,'original texture retained: '+species)
					if d['kind']=='ground':
						# The old generic .8 m normalization made real 6–20 cm grass
						# nearly rigid. Full-height blades must now reach full weight.
						check(height<.3,'grass fixture is genuinely small')
						var world_height: float = height*d['scale'][0]
						var bend: float = material.get_shader_parameter('bend')
						minimum_grass_bend = minf(minimum_grass_bend,world_height*bend*.22*.65)
						check(world_height*bend*.22*.65>.01,'daytime grass bend budget exceeds one centimetre')
	var wind := WindField.new()
	root.add_child(wind)
	wind.set_process(false)
	wind.advance(2.0)
	for material in VegetationAssets._wind_materials:
		check(is_equal_approx(material.get_shader_parameter('wind_clock'),2.0),'clock reaches every drawn variant/LOD')
		check(is_equal_approx(material.get_shader_parameter('wind_strength'),wind.strength),'strength reaches every drawn variant/LOD')
	var shader := VegetationAssets._wind_shader
	var uniforms: Array = shader.get_shader_uniform_list()
	check(uniforms.any(func(u):return u['name']=='root_height'),'shader parses root anchoring')
	check(uniforms.any(func(u):return u['name']=='flutter'),'shader parses leaf/blade flutter')
	print('VEGETATION WIND checks=',checks,' minimum_grass_bend_cm=',snappedf(minimum_grass_bend*100,.1),' failures=',failures.size())
	wind.free()
	quit(0 if failures.is_empty() else 1)
