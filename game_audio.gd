class_name GameAudio
extends Node
## Proseduraldır: bütün səslər işə düşəndə koddan sintez olunur (fayl və lisenziya yoxdur).
## Mühərrik (rpm-ə görə ton), starter, təkər/yol küyü (asfalt, torpaq, palçıq), külək,
## zərbə, qəza işığının tıqqıltısı, gündüz quş cikkiltisi və gecə sirçanaqları.
## Səslər real səs qeydləri deyil, sintezdir: ton və tənzimləmə qulaqla dəqiqləşdirilməlidir.

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
var _birds: Array[AudioStreamWAV] = []
var _hoot: AudioStreamWAV
var _bird_t := 2.0
var _hoot_t := 12.0
var _throttle := 0.0
var _speed := 0.0
var _prev_v := Vector3.ZERO
var _prev_engine := -1
var _rng := RandomNumberGenerator.new()
var _night_mix := 0.0
## test üçün oxunur
var last_engine_pitch := 0.0
var last_engine_db := -80.0
var thuds := 0


func _ready() -> void:
	_rng.seed = 4242
	_engine = _player(_engine_loop(false), -80.0)
	_growl = _player(_engine_loop(true), -80.0)
	_starter = _player(_starter_sound(), -6.0, false)
	_road = _player(_noise_loop(1.6, 0.35, 0.02, 0.5), -80.0)
	_mud = _player(_noise_loop(1.6, 0.04, 0.0, 0.9, true), -80.0)
	_wind = _player(_noise_loop(2.4, 0.05, 0.002, 1.0), -80.0)
	_bed = _player(_noise_loop(3.0, 0.03, 0.001, 1.0), -80.0)
	_crickets = _player(_cricket_loop(), -80.0)
	_sfx = _player(null, -4.0, false)
	_bird = _player(null, -14.0, false)
	_tick_a = _tick(1900.0)
	_tick_b = _tick(1300.0)
	_thud = _thud_sound()
	_click = _tick(2600.0, 0.03)
	for k in 4:
		_birds.append(_chirp(_rng.randf_range(2400.0, 4200.0), _rng.randf_range(0.18, 0.4), k))
	_hoot = _hoot_sound()
	if truck != null:
		_prev_v = truck.linear_velocity
		truck.message.connect(func(_t: String): _play_sfx(_click, -8.0))
		truck.lights.tick.connect(_on_light_tick)
	for p in [_engine, _growl, _road, _mud, _wind, _bed, _crickets]:
		(p as AudioStreamPlayer).play()


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
	_mud.volume_db = _db(amt * soft + 0.12 * soft * clampf(truck.rpm / 3000.0, 0.0, 1.0) * grounded) - 7.0
	var wamt := clampf(_speed / 35.0, 0.0, 1.0)
	_wind.pitch_scale = 0.8 + wamt * 0.7
	_wind.volume_db = _db(wamt * wamt) - 14.0


func _update_ambient(delta: float) -> void:
	var day := 1.0 - _night_mix
	_bed.volume_db = _db(0.35 + 0.2 * day) - 30.0
	_bed.pitch_scale = 0.9 + 0.1 * _night_mix
	_crickets.volume_db = _db(_night_mix) - 22.0
	_bird_t -= delta
	if _bird_t <= 0.0:
		_bird_t = _rng.randf_range(1.5, 6.0)
		if day > 0.6:
			_bird.stream = _birds[_rng.randi() % _birds.size()]
			_bird.pitch_scale = _rng.randf_range(0.85, 1.25)
			_bird.volume_db = _rng.randf_range(-20.0, -12.0)
			_bird.play()
	_hoot_t -= delta
	if _hoot_t <= 0.0:
		_hoot_t = _rng.randf_range(10.0, 25.0)
		if _night_mix > 0.8:
			_play_sfx(_hoot, -22.0)


func _on_light_tick(on: bool) -> void:
	_play_sfx(_tick_a if on else _tick_b, -10.0)


func _play_sfx(s: AudioStreamWAV, db: float) -> void:
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


## Sirçanaq: ~4.3 kHz tonun sürətli partlayışları.
func _cricket_loop() -> AudioStreamWAV:
	var n := SR * 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var gate := maxf(0.0, sin(TAU * 26.0 * t))  # saniyədə 26 vuruş
		gate *= smoothstep(0.0, 0.1, fmod(t, 0.5)) * (1.0 - smoothstep(0.35, 0.45, fmod(t, 0.5)))
		var tone := sin(TAU * 4300.0 * t) + 0.3 * sin(TAU * 8600.0 * t)
		out[i] = tone * gate * 0.35
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


func _chirp(base: float, dur: float, variant: int) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var u := t / dur
		var f := base * (1.0 + 0.25 * sin(TAU * (6.0 + variant * 3.0) * u) + 0.3 * u * (1.0 if variant % 2 == 0 else -1.0))
		phase += TAU * f / SR
		var env := sin(PI * u)
		env *= 0.5 + 0.5 * maxf(0.0, sin(TAU * (3.0 + variant) * u))  # bir neçə notaya bölür
		out[i] = sin(phase) * env * 0.5
	return _wav(out, false)


func _hoot_sound() -> AudioStreamWAV:
	var n := int(1.6 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var env := 0.0
		for st in [0.0, 0.55, 1.1]:
			var u: float = t - st
			if u >= 0.0 and u < 0.35:
				env = maxf(env, sin(PI * u / 0.35))
		var f := 380.0 - 40.0 * fmod(t, 0.55)
		out[i] = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.4
	return _wav(out, false)
