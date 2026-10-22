extends SceneTree
## Səs sistemi: yaradılır, mühərrik tonu rpm-ə görə dəyişir, söndürülü mühərrik səssizdir,
## zərbə sayılır, sintez olunan axınlar boş deyil.
## godot --headless --path . -s res://tests/audio_test.gd

var main: Node
var frames := 0
var failures: Array[String] = []
var pitch_idle := 0.0
var t0 := 0


func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _physics_process(_delta: float) -> bool:
	frames += 1
	var a: GameAudio = main.audio
	var t: OffroadTruck = main.truck
	if frames == 5:
		_check(a != null, "GameAudio yoxdur")
		# axınlar boş olmamalıdır
		for p in [a._engine, a._growl, a._road, a._mud, a._wind, a._starter]:
			var s := (p as AudioStreamPlayer).stream as AudioStreamWAV
			_check(s != null and s.data.size() > 4000, "boş axın")
			if s != null:
				var peak := 0
				for i in range(0, s.data.size() - 1, 2):
					peak = maxi(peak, absi(s.data.decode_s16(i)))
				_check(peak > 500, "axın səssizdir (peak=%d)" % peak)
		for p in [a._bed, a._crickets, a._bird, a._brook]:
			_check(p.stream is AudioStreamOggVorbis and p.stream.get_length() > 10.0, "real nature recording loads")
			_check(p.stream.loop, "nature recording loops")
		_check(a._animal.stream.get_length() > 5.0, "recorded owl loads")
		t.stop_engine()
	if frames == 40:
		_check(a.last_engine_db < -40.0, "söndürülü mühərrik səssiz olmalıdır: %.1f" % a.last_engine_db)
		t.toggle_engine()
		Input.action_press(&"ui_up")
	if frames == 140:
		pitch_idle = a.last_engine_pitch
		_check(a.last_engine_db > -30.0, "işləyən mühərrik eşidilməlidir: %.1f" % a.last_engine_db)
	if frames == 400:
		_check(a.last_engine_pitch > pitch_idle + 0.1, "rpm artanda ton qalxmalıdır: %.2f -> %.2f" % [pitch_idle, a.last_engine_pitch])
		t.linear_velocity = Vector3(0, 0, 20)
	if frames == 403:
		t.linear_velocity = Vector3.ZERO
	if frames == 410:
		_check(a.thuds >= 1, "zərbə səsi işləməlidir")
		t.lights.toggle_hazard()
	if frames == 480:
		for m in failures:
			print("FAIL ", m)
		print("AUDIO TEST: uğursuzluq=%d (yüklənmə+test %d ms)" % [failures.size(), Time.get_ticks_msec() - t0])
		quit(0 if failures.is_empty() else 1)
	return false
