class_name GameAudio
extends Node
## Recorded independent engine banks and nature recordings; synthesized foley is labeled.
## See assets/audio/CREDITS.md for authors, sources and transformations.

const SR := 22050

var truck: OffroadTruck
var main_node: Node
var wind: WindField
var _wind_trees: AudioStreamPlayer
var enabled := true

var engine_bank: VehicleEngineAudio
var _load: AudioStreamPlayer
var _gravel: AudioStreamPlayer
var _impact_cooldown := 0.0
var _engine: AudioStreamPlayer
var _growl: AudioStreamPlayer
var _starter: AudioStreamPlayer
var _stopper: AudioStreamPlayer
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
var _rain: AudioStreamPlayer
## 0..1, WeatherSystem yazır
var rain := 0.0
var storm := 0.0
var _thunder: Array = [null, null, null]
var thunders := 0
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
	engine_bank = VehicleEngineAudio.new()
	add_child(engine_bank)
	engine_bank.select_vehicle(truck.spec_idx if truck != null else 0)
	_engine = engine_bank.idle
	_growl = engine_bank.rev
	_load = engine_bank.load_layer
	_starter = _player(load(EngineStartCatalog.path(truck.spec_idx if truck != null else 0)), -13.0, false)
	_stopper = _player(load("res://assets/audio/engines/stop_v8.wav"), -16.0, false)
	_road = _player(_noise_loop(1.6, 0.35, 0.02, 0.5), -80.0)
	_mud = _player(_effect_loop("mud_foley"), -80.0)
	_gravel = _player(_effect_loop("gravel_roll"), -80.0)
	_wind_trees = _player(_recording("wind_trees"),-80.0)
	_wind = _player(_noise_loop(2.4, 0.05, 0.002, 1.0), -80.0)
	_bed = _player(_recording("forest"), -80.0)
	_crickets = _player(_recording("crickets"), -80.0)
	_brook = _player(_recording("stream_brook"), -80.0)
	# yağış: sintez olunmuş geniş zolaqlı səs-küy (həqiqi yazı yoxdur)
	_rain = _player(_noise_loop(3.2, 0.82, 0.18, 1.0), -80.0)
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
		truck.gear_changed.connect(func(_old: int,_new: int):
			engine_bank.shift()
			_play_sfx(_click,-23.0)
		)
		truck.vehicle_changed.connect(_on_vehicle_changed)
	for p in [_road, _mud, _gravel, _wind_trees, _wind, _bed, _crickets, _bird, _brook, _rain]:
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
	_impact_cooldown = maxf(0.0,_impact_cooldown-delta)
	if dv.length() > 4.5 and truck.controls_enabled and _impact_cooldown <= 0.0:
		_impact_cooldown = 0.18
		thuds += 1
		_play_sfx(_thud, clampf(-22.0 + dv.length() * 1.6, -22.0, 2.0))


func _update_engine(delta: float) -> void:
	var st := truck.engine_state
	if st != _prev_engine:
		if st == OffroadTruck.EngineState.CRANKING:
			_stopper.stop()
			_starter.play()
		elif st == OffroadTruck.EngineState.OFF and _prev_engine == OffroadTruck.EngineState.RUNNING:
			_starter.stop()
			_stopper.play()
		_prev_engine = st
	if st != OffroadTruck.EngineState.CRANKING and _starter.playing:
		_starter.volume_db = move_toward(_starter.volume_db,-80.0,delta*480.0)
		if _starter.volume_db < -70.0:
			_starter.stop()
	elif st == OffroadTruck.EngineState.CRANKING:
		_starter.volume_db = -13.0
	var want := truck.throttle
	if not truck.controls_enabled or st != OffroadTruck.EngineState.RUNNING:
		want = 0.0
	_throttle = lerpf(_throttle, want, 1.0 - exp(-6.0 * delta))
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
	engine_bank.update(delta,truck,_throttle,_engine_load)
	last_engine_pitch = _growl.pitch_scale
	last_engine_db = maxf(_engine.volume_db,maxf(_growl.volume_db,_load.volume_db))


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
	# The synthetic low-passed noise "road" layer (pitch rising with speed) sounded like a wind drone; kept silent.
	_road.volume_db = -80.0
	_gravel.volume_db = _db(amt * road_gain * (0.0 if on_road else 0.8)) - 17.0
	_gravel.pitch_scale = clampf(0.8+_speed/30.0,0.8,1.5)
	# A stationary idling engine does not churn mud; spinning wheels do.
	var churn := clampf(truck.wheel_slip / 8.0, 0.0, 1.0) * grounded
	_mud.volume_db = _db(amt * soft + 0.3 * soft * churn) - 7.0
	# Environmental wind only: driving speed must not add a rushing-wind layer.
	var summit_wind := smoothstep(70.0, 150.0, truck.global_position.y) * 0.35
	var gust := 0.68 + 0.20 * sin(_ambient_time * 0.31) + 0.12 * sin(_ambient_time * 0.73 + 1.4)
	# fırtına küləyi hərəkət edəndə də eşidilir
	_wind.volume_db = _db(maxf(summit_wind * gust * _wind_still(), storm * 0.6 * gust)) - 14.0
	_wind.pitch_scale = 1.0 + 0.07 * storm * sin(_ambient_time * 0.9)


# Wind is only audible while the truck is parked; it fades out once driving.
func _wind_still() -> float:
	return 1.0 - smoothstep(1.0, 4.0, _speed)


func _update_ambient(delta: float) -> void:
	_ambient_time = wind.clock if wind != null else _ambient_time+delta
	var tree_wind := wind.strength if wind != null else (0.35 if _night_mix > 0.5 else 0.12)
	_wind_trees.volume_db = _db(tree_wind*(0.75+0.25*_night_mix)*_wind_still())-12.0
	var day := 1.0 - _night_mix
	# Smooth day/night crossfade, subdued at mountain altitude. Brook follows water.
	var forest := 1.0 - smoothstep(70.0, 130.0, truck.global_position.y)
	# The forest bed also contains real daytime birds. Fade it out at night
	# rather than leaving a dawn chorus beneath the owl and crickets.
	var foliage := 0.93 + 0.07 * sin(_ambient_time * 0.17)
	var dry := 1.0 - 0.85 * rain  # yağışda quşlar, cırcıramalar və meşə küyü boğulur
	_bed.volume_db = _db(day * forest * foliage * dry) - 19.0
	_bird.volume_db = _db(day * forest * dry) - 22.0
	_crickets.volume_db = _db(_night_mix * forest * dry) - 22.0
	_rain.volume_db = _db(rain) - 17.0
	# ən yaxın su: göl (ellips kənarı) və ya çay
	var tp := Vector2(truck.global_position.x, truck.global_position.z)
	var water_distance := maxf(0.0, (MapLayout._ellipse(tp, MapLayout.LAKE_CENTER, MapLayout.LAKE_RADII) - 1.0) * MapLayout.LAKE_RADII.y)
	if truck.terrain != null and not truck.terrain._river.is_empty():
		water_distance = minf(water_distance, truck.terrain._near_route(tp, truck.terrain._river, truck.terrain._river_len, truck.terrain._river_bins)[0])
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


## İldırım: məsafəyə görə yaxın (çaqqıltı + gurultu), orta və uzaq (yalnız gurultu).
func play_thunder(distance: float) -> void:
	var kind := 0 if distance < 500.0 else (1 if distance < 1000.0 else 2)
	if _thunder[kind] == null:
		_thunder[kind] = _thunder_sound(kind)
	var db := lerpf(-1.0, -12.0, clampf((distance - 250.0) / 1100.0, 0.0, 1.0))
	thunders += 1
	_play_sfx(_thunder[kind], db)


## Sintez olunmuş ildırım (həqiqi yazı yoxdur): qəhvəyi küy gurultusu + yaxında qısa çaqqıltı.
func _thunder_sound(kind: int) -> AudioStreamWAV:
	var dur := [5.5, 6.5, 7.5][kind] as float
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 700 + kind
	var lp1 := 0.0
	var lp2 := 0.0
	var crack_lp := 0.0
	var crack_gain := [1.0, 0.45, 0.0][kind] as float
	var rumble_lp := [0.030, 0.020, 0.014][kind] as float
	var peak := 0.0001
	for i in n:
		var t := float(i) / SR
		var w := r.randf_range(-1.0, 1.0)
		lp1 += (w - lp1) * rumble_lp
		lp2 += (lp1 - lp2) * rumble_lp * 2.0
		var env := (1.0 - exp(-t / 0.3)) * exp(-t / (dur * 0.30))
		var roll := 0.62 + 0.38 * sin(t * 5.3 + 1.9 * sin(t * 1.4)) * sin(t * 2.1 + 0.6)
		var v := lp2 * 9.0 * env * roll
		if crack_gain > 0.0 and t < 0.45:
			crack_lp += (w - crack_lp) * 0.55
			v += crack_lp * crack_gain * exp(-t * 11.0) * 1.6
		out[i] = v
		peak = maxf(peak, absf(v))
	for i in n:
		out[i] = out[i] / peak * 0.9
	return _wav(out, false)


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


func _effect_loop(name: String) -> AudioStreamWAV:
	var stream := load("res://assets/audio/engines/%s.wav" % name).duplicate() as AudioStreamWAV
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	return stream


func _on_vehicle_changed(index: int) -> void:
	engine_bank.select_vehicle(index)
	_throttle = 0.0
	_engine_load = 0.0
	_prev_v = truck.linear_velocity
	_prev_engine = truck.engine_state
	_starter.stop()
	_stopper.stop()
	var identity := "v8" if index == 0 else "petrol"
	_starter.stream = load(EngineStartCatalog.path(index))
	_stopper.stream = load("res://assets/audio/engines/stop_%s.wav" % identity)
