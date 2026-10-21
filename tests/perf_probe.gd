extends SceneTree
## Performans ölçməsi (pəncərəli rejim, vsync söndürülür): orta kadr vaxtı, 99-cu faiz və FPS.
## godot --path . -s res://tests/perf_probe.gd -- [kadr sayı] [preset: road|mud]
## Başsız (--headless) rejimdə mənasızdır, çünki render yoxdur.

const WARMUP := 90
var main: Node
var frames := 0
var total_frames := 600
var samples: Array[float] = []
var last_us := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		total_frames = int(args[0])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Input.action_press(&"ui_up")


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if frames > WARMUP:
		samples.append((now - last_us) / 1000.0)
	last_us = now
	frames += 1
	if frames >= WARMUP + total_frames:
		samples.sort()
		var sum := 0.0
		for s in samples:
			sum += s
		var avg := sum / samples.size()
		var p99: float = samples[int(samples.size() * 0.99)]
		var win := DisplayServer.window_get_size()
		print("PERF pəncərə=%dx%d kadr=%d orta=%.2f ms (%.0f FPS) p99=%.2f ms (%.0f FPS) ən pis=%.2f ms" % [
			win.x, win.y, samples.size(), avg, 1000.0 / avg, p99, 1000.0 / p99, samples[samples.size() - 1]])
		quit(0)
	return false
