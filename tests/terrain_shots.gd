extends SceneTree
## Vizual yoxlama: seçilmiş səthə kamera qoyur, hava şərtini tətbiq edir.
## godot --path . --write-movie out.png --fixed-fps 30 -s res://tests/terrain_shots.gd -- <preset>
## preset: road, mud, deep, dirt, cobble, grass, cliff, wet, snow, ice

# [yer, yağış, qar, buz]
const PRESETS := {
	"road": ["road", 0.0, 0.0, 0.0],
	"mud": ["mud", 0.0, 0.0, 0.0],
	"deep": ["deep", 0.0, 0.0, 0.0],
	"dirt": ["dirt", 0.0, 0.0, 0.0],
	"cobble": ["cobble", 0.0, 0.0, 0.0],
	"grass": ["grass", 0.0, 0.0, 0.0],
	"cliff": ["cliff", 0.0, 0.0, 0.0],
	"ruts": ["mud", 0.0, 0.0, 0.0],
	"wet": ["road", 1.0, 0.0, 0.0],
	"wet_mud": ["mud", 1.0, 0.0, 0.0],
	"snow": ["road", 0.0, 1.0, 0.0],
	"ice": ["road", 0.0, 0.0, 1.0],
}

var main: Node
var terrain: MudTerrain
var frames := 0
var preset := "road"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		preset = args[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		terrain = main._terrain
		main.truck.freeze = true
		main.truck.global_position = Vector3(0, 300, 0)
		main.hud.visible = false
		var cfg: Array = PRESETS[preset]
		terrain.set_surface_conditions(cfg[1], cfg[2], cfg[3])
		var target := _find(cfg[0])
		if preset == "ruts":
			_make_ruts(target)
		var cam := Camera3D.new()
		cam.fov = 60.0
		cam.far = 1500.0
		root.add_child(cam)
		cam.make_current()
		var offset := Vector3(5.0, 3.0, 5.0)
		if preset == "ruts":
			offset = Vector3(-2.0, 1.6, 2.6)  # izlərə yaxından baxış
		cam.global_position = target + offset
		cam.look_at(target)
	if frames == 30 and preset == "ruts":
		var c := _find("mud")
		var g := terrain._to_grid(c)
		var px := terrain._ctrl_b_img.get_pixel(roundi(g.x), roundi(g.y))
		print("RUT depth=%.2f soft=%.2f ctrl_b=%s mesh_y=%.2f h=%.2f" % [
			terrain.depth_at(c), terrain.softness_at(c), px, terrain._verts[roundi(g.y) * MudTerrain.N + roundi(g.x)].y, terrain.height_at(c)])
	if frames == 40:
		quit(0)
	return false


func _find(kind: String) -> Vector3:
	var half := (MudTerrain.N - 1) * 0.5
	var best := Vector3.ZERO
	var found := false
	for i in MudTerrain.N * MudTerrain.N:
		var p := Vector3((i % MudTerrain.N - half) * MudTerrain.CELL, terrain.h[i],
				(i / MudTerrain.N - half) * MudTerrain.CELL)
		if Vector2(p.x, p.z).length() > 85.0:
			continue
		var ok := false
		match kind:
			"mud":
				ok = terrain.soft[i] > 0.5 and terrain._aux_deepk[i] < 0.2 and terrain.slope_at(p) < 0.2
			"deep":
				ok = terrain.soft[i] > 0.9 and terrain._aux_deepk[i] > 0.8 and terrain.slope_at(p) < 0.2
			"dirt":
				ok = terrain._aux_dirt[i] > 0.8 and terrain.soft[i] < 0.05 \
						and terrain.road_distance_at(p) > 8.0 and terrain.slope_at(p) < 0.2
			"cobble":
				ok = terrain._aux_cobble[i] > 0.7 and terrain.soft[i] < 0.05 and terrain.slope_at(p) < 0.2
			"grass":
				ok = terrain._grass_w[i] > 0.95 and terrain.slope_at(p) < 0.15 \
						and terrain.road_distance_at(p) > 12.0
			"cliff":
				ok = terrain.slope_at(p) > 0.7 and terrain.height_at(p) < 20.0
		if ok:
			best = p
			found = true
			break
	if kind == "road" or not found:
		var sp := terrain.road_spawn()
		var rp: Vector3 = sp["pos"]
		return rp
	return best


## İki paralel təkər izi: deformasiyanı bir neçə keçidlə tətbiq edir.
func _make_ruts(center: Vector3) -> void:
	for pass_i in 8:
		for k in 50:
			var along := -2.5 + k * 0.1
			terrain.deform(center + Vector3(along, 0.0, -0.6), 1.0, 0.1)
			terrain.deform(center + Vector3(along, 0.0, 0.6), 1.0, 0.1)
