class_name WindField
extends Node
## One shared time/direction/gust drives vegetation, exhaust and recorded wind.
var night := false
var clock := 0.0
var strength := 0.18
var gust := 0.7
var direction := Vector3(0.82,0,0.57).normalized()
var velocity := Vector3.ZERO
## Hava presetindən (WeatherSystem): yağışda və buludlu havada küləyi gücləndirir, dumanda azaldır.
var weather_mul := 1.0

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	gust = 0.68 + 0.20*sin(clock*0.31) + 0.12*sin(clock*0.73+1.4)
	strength = move_toward(strength,(0.52 if night else 0.22)*gust*weather_mul,delta*0.18)
	velocity = direction * strength * 6.0
	VegetationAssets.update_wind(clock,direction,strength)
