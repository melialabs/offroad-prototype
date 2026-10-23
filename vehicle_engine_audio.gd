class_name VehicleEngineAudio
extends Node
## Independent recorded banks. All are clearly labeled substitutes, not OEM recordings.
## Loop reference RPMs are playback tuning anchors, not measured capture metadata.
const BANKS := [
	{"id":"scout", "label":"Substitute · AC Cobra 427 / Joseph Sardin"},
	{"id":"cargo", "label":"Substitute · Iveco Daily 3.0 / Joseph Sardin"},
	{"id":"heavy", "label":"Substitute · unidentified truck / Joseph Sardin"},
	{"id":"niva", "label":"Substitute · unidentified retro car #2 / DenisChardonnet"},
]
var idle: AudioStreamPlayer
var rev: AudioStreamPlayer
var load_layer: AudioStreamPlayer
var index := -1
var source_label := ""
var mix := Vector3(1,0,0)
var gain := 0.0
var shift_dip := 0.0
var _cache: Dictionary = {}

func _ready() -> void:
	idle = _make_player()
	rev = _make_player()
	load_layer = _make_player()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	add_child(p)
	return p

func select_vehicle(vehicle: int) -> void:
	# Additional UAZs retain a disclosed petrol substitute; original four have
	# different actual source recordings, not six differently pitched copies.
	var selected := vehicle if vehicle < BANKS.size() else 0
	if index == selected:
		return
	index = selected
	source_label = BANKS[index]["label"]
	gain = 0.0
	mix = Vector3(1,0,0)
	shift_dip = 0.0
	var players := [idle,rev,load_layer]
	for i in 3:
		var path := "res://assets/audio/engines/%s_%s.wav" % [BANKS[index]["id"],["idle","rev","load"][i]]
		if not _cache.has(path):
			var stream := load(path).duplicate() as AudioStreamWAV
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			_cache[path] = stream
		players[i].stop()
		players[i].stream = _cache[path]
		players[i].volume_db = -80.0
		players[i].play()

func shift() -> void:
	shift_dip = 1.0

func update(delta: float, truck: OffroadTruck, throttle: float, engine_load: float) -> void:
	select_vehicle(truck.spec_idx)
	var profile := truck.powertrain
	var base := float(profile["idle"])
	var span := float(profile["redline"]) - base
	var n := clampf((truck.rpm-base)/span,0.0,1.0)
	var mid := smoothstep(0.04,0.50,n)
	var loaded := clampf(throttle*(0.35+0.65*engine_load)*smoothstep(0.04,0.5,n),0,0.9)
	var target := Vector3((1.0-mid)*(1.0-loaded),mid*(1.0-loaded),loaded)
	mix = mix.lerp(target,1.0-exp(-9.0*delta))
	var on := truck.engine_state == OffroadTruck.EngineState.RUNNING
	gain = move_toward(gain,1.0 if on else 0.0,delta*(5.0 if on else 7.0))
	shift_dip = move_toward(shift_dip,0.0,delta/0.26)
	var envelope := gain*(1.0-0.72*shift_dip)
	# Constant-power layer blends and band-specific pitch keep recordings
	# credible over a wide engine range without pitching one idle loop 8x.
	var anchors := Vector3(base,base+span*0.38,base+span*0.70)
	var players := [idle,rev,load_layer]
	for i in 3:
		var p: AudioStreamPlayer = players[i]
		var pitch := clampf(truck.rpm/anchors[i],0.65,1.8)
		p.pitch_scale = lerpf(p.pitch_scale,pitch,1.0-exp(-14.0*delta))
		p.volume_db = linear_to_db(maxf(0.0001,sqrt(maxf(0.0,mix[i]))*envelope)) - 13.0

func _exit_tree() -> void:
	for player in [idle,rev,load_layer]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_cache.clear()
