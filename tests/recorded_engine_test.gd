extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ",label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var t := OffroadTruck.new()
	root.add_child(t)
	t.set_physics_process(false)
	t.freeze = true
	var a := VehicleEngineAudio.new()
	root.add_child(a)
	for index in 6:
		t.apply_spec(index)
		a.select_vehicle(index)
		for player in [a.idle,a.rev,a.load_layer]:
			check(player.stream is AudioStreamWAV and player.stream.get_length() > 0.4,"recording loads: %d" % index)
			check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"loop enabled: %d" % index)
			var bytes: PackedByteArray = player.stream.data
			check(abs(bytes.decode_s16(0)-bytes.decode_s16(bytes.size()-2))<4000,"crossfaded loop boundary: %d" % index)
			check(player.playing,"continuous loop playback: %d" % index)
		t.engine_state = OffroadTruck.EngineState.RUNNING
		t.rpm = t.powertrain["idle"]
		a.update(1.0,t,0,0)
		check(a.mix.x>.9 and a.idle.volume_db > -25,"recorded idle dominates: %d" % index)
		t.rpm = t.powertrain["redline"]*.85
		a.update(1.0,t,1,1)
		check(a.mix.z>.8 and a.load_layer.volume_db > -25,"recorded load dominates: %d" % index)
		check(a.rev.pitch_scale > 1.0,"RPM changes playback pitch: %d" % index)
		a.shift()
		a.update(.01,t,1,1)
		check(a.shift_dip>.8,"gear change ducks engine envelope: %d" % index)
		t.engine_state = OffroadTruck.EngineState.OFF
		a.update(1.0,t,0,0)
		check(a.idle.volume_db < -75 and a.rev.volume_db < -75 and a.load_layer.volume_db < -75,"all engine layers mute when off: %d" % index)
		await create_timer(0.05).timeout
		check(a.source_label.begins_with("Substitute"),"honest source identity: %d" % index)
		var hud := Hud.new()
		hud.truck = t
		check(hud.speed_scale() >= float(t.powertrain["top"]),"vehicle-specific speed scale: %d" % index)
		check(hud.rpm_scale() >= float(t.powertrain["redline"]),"vehicle-specific tach scale: %d" % index)
		hud.free()
	# Identity checks use different source-bank prefixes; resources are duplicated
	# to keep loop settings local, so resource_path is intentionally empty.
	check(a._cache.size()==18,"six separate idle/rev/load sample triplets")
	a.free()
	t.free()
	await create_timer(0.15).timeout
	print("RECORDED ENGINE TEST failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
