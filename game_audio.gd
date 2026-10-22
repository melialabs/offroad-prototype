class_name GameAudio
extends Node
## Engine/vehicle effects are synthesized; nature ambience uses real CC0 field recordings.
## See assets/audio/CREDITS.md for authors, sources and transformations.

const SR := 22050
const ENGINE_REF_RPM := 1200.0  # mühərrik döngəsi bu rpm-də yazılıb (4 silindr: 40 Hz atəşləmə)

var truck: OffroadTruck
var main_node: Node
var enabled := true

var _engine: AudioStreamPlayer
var _growl: AudioStreamPlayer
var _starter: AudioStreamPlayer
var _road: AudioStreamPlayer
var _mud: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _bed: AudioStreamPlayer  # ətraf mühit küyü (yarpaq, külək)
var _sfx: AudioStreamPlayer  # tək zərbələr
var _bird: AudioStreamPlayer
var _tick_a: AudioStreamWAV
var _tick_b: AudioStreamWAV
var _thud: AudioStreamWAV
var _click: AudioStreamWAV
var _hoot: AudioStream
var _animal: AudioStreamPlayer3D
var _brook: AudioStreamPlayer
var _hoot_t := 12.0
var _throttle := 0.0
var _speed := 0.0
var _prev_v := Vector3.ZERO
var _prev_engine := -1
var _rng := RandomNumberGenerator.new()
var _night_mix := 0.0
var _ambient_time := 0.0
var _engine_load := 0.0
## test üçün oxunur
var last_engine_pitch := 0.0
var last_engine_db := -80.0
var last_engine_load := 0.0
var thuds := 0


func _ready() -> void:
	_rng.randomize()
	_engine = _player(_engine_loop(false), -80.0)
	_growl = _player(_engine_loop(true), -80.0)
	_starter = _player(_starter_sound(), -6.0, false)
	_road = _player(_noise_loop(1.6, 0.35, 0.02, 0.5), -80.0)
	_mud = _player(_noise_loop(1.6, 0.04, 0.0, 0.9, true), -80.0)
	_wind = _player(_noise_loop(2.4, 0.05, 0.002, 1.0), -80.0)
	_bed = _player(_recording("forest"), -80.0)
	_crickets = _player(_recording("crickets"), -80.0)
	_brook = _player(_recording("stream_brook"), -80.0)
	_sfx = _player(null, -4.0, false)
	_bird = _player(_recording("birds_dawn"), -80.0)
	_tick_a = _tick(1900.0)
	_tick_b = _tick(1300.0)
	_thud = _thud_sound()
	_click = _tick(2600.0, 0.03)
	_hoot = load("res://assets/audio/tawny_owl.ogg")
	_animal = AudioStreamPlayer3D.new()
	_animal.stream = _hoot
	_animal.unit_size = 12.0
	_animal.max_distance = 100.0
	_animal.volume_db = -9.0
	add_child(_animal)
	if truck != null:
		_prev_v = truck.linear_velocity
		truck.message.connect(func(_t: String): _play_sfx(_click, -8.0))
		truck.lights.tick.connect(_on_light_tick)
	for p in [_engine, _growl, _road, _mud, _wind, _bed, _crickets, _bird, _brook]:
		# Long field recordings should not restart with the same bird call on
		# every visit. Keep their pitch intact, with an independent loop phase.
		var offset := 0.0
		if p.stream is AudioStreamOggVorbis:
			offset = _rng.randf_range(0.0, maxf(0.0, p.stream.get_length() - 2.0))
		(p as AudioStreamPlayer).play(offset)


func set_enabled(on: bool) -> void:
	enabled = on
	AudioServer.set_bus_mute(0, not on)


func _player(stream: AudioStream, db: float, _loop: bool = true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = &"Master"
	add_child(p)
	return p


func _process(delta: float) -> void:
	if truck == null:
		return
	var night: bool = main_node != null and main_node.get("night") == true
	_night_mix = move_toward(_night_mix, 1.0 if night else 0.0, delta * 0.5)
	_update_engine(delta)
	_update_road(delta)
	_update_ambient(delta)
	# zərbə
	var dv := truck.linear_velocity - _prev_v
	_prev_v = truck.linear_velocity
	if dv.length() > 4.5 and truck.controls_enabled:
		thuds += 1
		_play_sfx(_thud, clampf(-22.0 + dv.length() * 1.6, -22.0, 2.0))


func _update_engine(delta: float) -> void:
	var st := truck.engine_state
	if st != _prev_engine:
		if st == OffroadTruck.EngineState.CRANKING:
			_starter.play()
		_prev_engine = st
	var want := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up"):
		want = 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down"):
		want = maxf(want, 0.7)
	if not truck.controls_enabled or st != OffroadTruck.EngineState.RUNNING:
		want = 0.0
	_throttle = lerpf(_throttle, want, 1.0 - exp(-6.0 * delta))
	var alive := st == OffroadTruck.EngineState.RUNNING or truck.rpm > 150.0
	var pitch := clampf(truck.rpm / ENGINE_REF_RPM, 0.3, 3.4)
	last_engine_pitch = pitch
	_engine.pitch_scale = pitch
	_growl.pitch_scale = pitch
	var body_db := -80.0
	var growl_db := -80.0
	if alive and st != OffroadTruck.EngineState.CRANKING:
		body_db = -16.0 + 7.0 * _throttle + 4.0 * clampf(truck.rpm / 3000.0, 0.0, 1.0)
		growl_db = -34.0 + 20.0 * _throttle * clampf(truck.rpm / 2200.0, 0.3, 1.0)
		if st != OffroadTruck.EngineState.RUNNING:
			var f := clampf(truck.rpm / 500.0, 0.0, 1.0)
			body_db = lerpf(-60.0, body_db, f)
			growl_db = lerpf(-80.0, growl_db, f)
	# Positive grade in the driven direction loads the engine. A descending
	# vehicle or an airborne wheel must not sound as if it is climbing.
	var contacts := 0
	for w in truck.wheels:
		if w.is_in_contact():
			contacts += 1
	var drive_direction := -1.0 if truck.gear < 0 else 1.0
	var incline := clampf(truck.global_basis.z.y * drive_direction * 2.0, 0.0, 1.0)
	var bog_load := truck.mud_level * clampf(truck.wheel_slip / 5.0, 0.0, 1.0)
	var load_target := maxf(incline, bog_load) * _throttle * float(contacts) / 4.0
	if st != OffroadTruck.EngineState.RUNNING:
		load_target = 0.0
	_engine_load = lerpf(_engine_load, load_target, 1.0 - exp(-5.0 * delta))
	last_engine_load = _engine_load
	growl_db += _engine_load * 7.0
	body_db += _engine_load * 2.0
	last_engine_db = body_db
	_engine.volume_db = body_db
	_growl.volume_db = growl_db


func _update_road(delta: float) -> void:
	var v := truck.linear_velocity
	var sp := v.length()
	_speed = lerpf(_speed, sp, 1.0 - exp(-8.0 * delta))
	var contact := 0
	for w in truck.wheels:
		if w.is_in_contact():
			contact += 1
	var grounded := contact / 4.0
	var soft := 0.0
	var on_road := false
	if truck.terrain != null:
		var p := truck.global_position
		soft = clampf(truck.terrain.softness_at(p), 0.0, 1.0)
		on_road = truck.terrain.road_distance_fast(p) < 3.4
	var amt := clampf(_speed / 14.0, 0.0, 1.0) * grounded
	var pitch := clampf(0.6 + _speed / 18.0, 0.6, 2.2)
	_road.pitch_scale = pitch
	_mud.pitch_scale = clampf(0.7 + _speed / 25.0, 0.7, 1.6)
	var road_gain := 1.0 - soft
	_road.volume_db = _db(amt * road_gain * (1.0 if on_road else 0.6)) - 12.0
	# A stationary idling engine does not churn mud; spinning wheels do.
	var churn := clampf(truck.wheel_slip / 8.0, 0.0, 1.0) * grounded
	_mud.volume_db = _db(amt * soft + 0.3 * soft * churn) - 7.0
	var wamt := clampf(_speed / 35.0, 0.0, 1.0)
	_wind.pitch_scale = 0.8 + wamt * 0.7
	var summit_wind := smoothstep(70.0, 150.0, truck.global_position.y) * 0.35
	var gust := 0.68 + 0.20 * sin(_ambient_time * 0.31) + 0.12 * sin(_ambient_time * 0.73 + 1.4)
	_wind.volume_db = _db(maxf(wamt * wamt, summit_wind * gust)) - 14.0


func _update_ambient(delta: float) -> void:
	_ambient_time += delta
	var day := 1.0 - _night_mix
	# Smooth day/night crossfade, subdued at mountain altitude. Brook follows water.
	var forest := 1.0 - smoothstep(70.0, 130.0, truck.global_position.y)
	# The forest bed also contains real daytime birds. Fade it out at night
	# rather than leaving a dawn chorus beneath the owl and crickets.
	var foliage := 0.93 + 0.07 * sin(_ambient_time * 0.17)
	_bed.volume_db = _db(day * forest * foliage) - 19.0
	_bird.volume_db = _db(day * forest) - 22.0
	_crickets.volume_db = _db(_night_mix * forest) - 22.0
	var water_distance := Vector2(truck.global_position.x + 150, truck.global_position.z + 120).length()
	_brook.volume_db = _db((1.0 - smoothstep(90.0, 230.0, water_distance)) * forest) - 24.0
	if _night_mix < 0.5 or forest < 0.2:
		_animal.stop()
	_hoot_t -= delta
	if _hoot_t <= 0.0:
		_hoot_t = _rng.randf_range(24.0, 52.0)
		if _night_mix > 0.8 and forest > 0.5:
			var angle := _rng.randf_range(0.0, TAU)
			_animal.global_position = truck.global_position + Vector3(cos(angle) * 32, 7, sin(angle) * 32)
			_animal.play()


func _recording(name: String) -> AudioStreamOggVorbis:
	var stream := load("res://assets/audio/%s.ogg" % name).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream


func _on_light_tick(on: bool) -> void:
	_play_sfx(_tick_a if on else _tick_b, -10.0)


func _play_sfx(s: AudioStream, db: float) -> void:
	# üst-üstə düşən səslər üçün ayrıca tək-atım oyunçusu
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _db(x: float) -> float:
	return linear_to_db(maxf(x, 0.0001))


# --- sintez -------------------------------------------------------------------------------

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## 1 saniyəlik dövr: 40 Hz atəşləmə tezliyinin harmonikləri + yarım-tərtib ("qeyri-bərabər" atəşləmə).
func _engine_loop(growl: bool) -> AudioStreamWAV:
	var n := SR
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 77 if growl else 31
	var parts: Array = []  # [frekans, amplituda, faza]
	var hmax := 70 if growl else 14
	for h in range(1, hmax + 1):
		var a := pow(float(h), -0.9) if not growl else (0.5 if h > 8 else 0.1)
		if growl and h <= 8:
			a *= 0.3
		if h % 2 == 0 and not growl:
			a *= 1.25
		parts.append([40.0 * h, a, r.randf() * TAU])
		if h < (30 if growl else 8):
			parts.append([40.0 * (h - 0.5), a * 0.4, r.randf() * TAU])
	var peak := 0.0001
	for i in n:
		var t := float(i) / SR
		var s := 0.0
		for p in parts:
			s += p[1] * sin(TAU * p[0] * t + p[2])
		out[i] = s
		peak = maxf(peak, absf(s))
	for i in n:
		out[i] = out[i] / peak * 0.7
	return _wav(out, true)


## Süzülmüş ağ küy dövrəsi. lp/hp: bir qütblü süzgəc əmsalları (kiçik lp = daha bas).
func _noise_loop(seconds: float, lp: float, hp: float, gain: float, crunchy: bool = false) -> AudioStreamWAV:
	var n := int(seconds * SR)
	var xf := 3000
	var r := RandomNumberGenerator.new()
	r.seed = int(lp * 1000.0) + n
	var raw := PackedFloat32Array()
	raw.resize(n + xf)
	var y1 := 0.0
	var y2 := 0.0
	var hpv := 0.0
	var peak := 0.0001
	for i in n + xf:
		var w := r.randf_range(-1.0, 1.0)
		y1 += (w - y1) * lp
		y2 += (y1 - y2) * (lp * 1.5 if lp < 0.5 else 0.7)
		var v := y2
		if hp > 0.0:
			hpv += (v - hpv) * hp
			v -= hpv
		if crunchy:  # palçıq: qeyri-bərabər "çıqqıltı" zərfi
			v *= 0.6 + 0.4 * sin(TAU * 7.0 * float(i) / SR) * sin(TAU * 3.0 * float(i) / SR + 1.0)
		raw[i] = v
		peak = maxf(peak, absf(v))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := raw[i]
		if i < xf:
			var k := float(i) / xf
			v = raw[i] * k + raw[n + i] * (1.0 - k)
		out[i] = v / peak * gain
	return _wav(out, true)


func _starter_sound() -> AudioStreamWAV:
	var n := int(0.9 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.8, 0.9, t))
		var whirr := sin(TAU * (95.0 + 60.0 * t) * t) * 0.5
		var ratchet := maxf(0.0, sin(TAU * 11.0 * t)) # mühərrikin firlanma vuruşları
		var rough := ratchet * sin(TAU * 55.0 * t) * 0.8
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.1
		out[i] = (whirr + rough + lp * 0.5) * env * 0.6
	return _wav(out, false)


func _tick(freq: float, dur: float = 0.045) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		out[i] = sin(TAU * freq * t) * exp(-t * 140.0) * 0.8
	return _wav(out, false)


func _thud_sound() -> AudioStreamWAV:
	var n := int(0.5 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.15
		out[i] = (sin(TAU * (70.0 - 35.0 * t) * t) * exp(-t * 7.0) + lp * exp(-t * 18.0) * 0.8) * 0.9
	return _wav(out, false)


func play_activity_cue(kind: String) -> void:
	match kind:
		"countdown": _play_sfx(_tick(660.0,0.1),-20.0)
		"start": _play_sfx(_tick(1320.0,0.18),-16.0)
		"checkpoint": _play_sfx(_tick(980.0,0.08),-22.0)
		"finish": _play_sfx(_tick(1760.0,0.25),-15.0)
		"fail": _play_sfx(_tick(330.0,0.18),-22.0)
