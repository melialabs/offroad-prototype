extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func snapshot(vegetation: Vegetation) -> Dictionary:
	var result := {}
	for key in vegetation._inst:
		var outside: Array[Transform3D] = []
		for xf: Transform3D in vegetation._inst[key]:
			if not HillClimbCatalog.ZONE.grow(12).has_point(Vector2(xf.origin.x,xf.origin.z)):
				outside.append(xf)
		if not outside.is_empty():
			result[key] = outside
	return result
func run() -> void:
	var original := {}
	var failures := 0
	for enabled in [false,true]:
		ProjectSettings.set_setting("offroad/hill_climb_enabled",enabled)
		var terrain := MudTerrain.new()
		root.add_child(terrain)
		var vegetation := Vegetation.new()
		root.add_child(vegetation)
		vegetation.build(terrain,1234)
		var current := snapshot(vegetation)
		if not enabled:
			original = current
		else:
			if current.size() != original.size():
				failures += 1
			for key in original:
				if not current.has(key) or current[key] != original[key]:
					failures += 1
		vegetation.free()
		terrain.free()
	ProjectSettings.set_setting("offroad/hill_climb_enabled",true)
	print("HILL FOREST outside_chunk_groups=%d failures=%d" % [original.size(),failures])
	quit(0 if failures==0 else 1)
