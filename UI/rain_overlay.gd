extends CPUParticles2D
## 雨/雪覆盖层：根据天气开关粒子效果

func _ready() -> void:
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(WeatherSystem.weather)

func _on_weather_changed(weather:String) -> void:
	match weather:
		"rain":
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
