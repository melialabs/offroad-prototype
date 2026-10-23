class_name StreetLamp
extends Node3D
## Küçə lampası: gecə lampa başlığı yanır və yerə konus işıq salır. "street_lamps" qrupundadır;
## main.set_night() hamısını birlikdə yandırır/söndürür.

const MODEL := "res://assets/props/street_lamp.glb"
const SCALE := 0.42
const MODEL_BASE_Y := -7.67  # modeldə dirəyin dibi
const BULB := Vector3(2.12, 6.05, 0.46)  # modeldə lampa başlığının mərkəzi (miqyasdan əvvəl)

var _light: SpotLight3D
var _bulb_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("street_lamps")
	if not ResourceLoader.exists(MODEL):
		return
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	model.position = Vector3(0, -MODEL_BASE_Y * SCALE, 0)
	add_child(model)
	WorldProps.make_lit(model)
	# ən kiçik mesh lampa başlığının şüşəsidir: gecə işıq saçır
	var smallest: MeshInstance3D = null
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.visibility_range_end = 450.0
		if smallest == null or mi.mesh.get_aabb().size.length() < smallest.mesh.get_aabb().size.length():
			smallest = mi
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(1.0, 0.92, 0.75)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.82, 0.55)
	if smallest != null:
		smallest.material_override = _bulb_mat
	_light = SpotLight3D.new()
	_light.position = BULB * SCALE + Vector3(0, -MODEL_BASE_Y * SCALE - 0.1, 0)
	_light.rotation_degrees = Vector3(-90, 0, 0)
	_light.spot_range = 17.0
	_light.spot_angle = 62.0
	_light.spot_attenuation = 0.8
	_light.light_energy = 7.0
	_light.light_color = Color(1.0, 0.84, 0.6)
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 140.0
	_light.distance_fade_length = 40.0
	add_child(_light)
	var main := get_tree().current_scene
	set_lit(main != null and main.get("night") == true)
	# dirək: nazik toqquşma
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.14
	cyl.height = 5.6
	col.shape = cyl
	col.position = Vector3(0, 2.8, 0)
	body.add_child(col)
	add_child(body)


func set_lit(on: bool) -> void:
	if _light == null:
		return
	_light.visible = on
	_bulb_mat.emission_energy_multiplier = 4.0 if on else 0.0
