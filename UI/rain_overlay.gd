extends CPUParticles2D
## 雨/雪/雷暴覆盖层：根据天气开关粒子效果，雷暴时周期性闪电闪烁

var flash_timer: float = 0.0
var storm_flash: bool = false

func _ready() -> void:
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(WeatherSystem.weather)

func _process(delta: float) -> void:
	if WeatherSystem.weather != "storm": return
	flash_timer -= delta
	if flash_timer <= 0.0:
		flash_timer = randf_range(6.0, 14.0)
		# 闪电：白色闪烁
		modulate = Color(2.5, 2.5, 2.5)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.25)

func _on_weather_changed(weather:String) -> void:
	match weather:
		"rain", "storm":
			emitting = true
			gravity = Vector2(0, 900)
			initial_velocity_min = 700.0
			initial_velocity_max = 900.0
			amount = 250
			scale_amount_min = 1.0
			scale_amount_max = 1.5
			color = Color(1, 1, 1, 0.6)
		"snow":
			emitting = true
			gravity = Vector2(0, 120)
			initial_velocity_min = 40.0
			initial_velocity_max = 90.0
			amount = 150
			scale_amount_min = 2.0
			scale_amount_max = 4.0
			color = Color(1, 1, 1, 0.9)
		_:
			emitting = false
			modulate = Color.WHITE
