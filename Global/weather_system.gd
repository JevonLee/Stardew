extends Node
## Autoload 天气系统：每天清晨根据季节随机天气，影响作物浇水需求等

signal weather_changed(weather:String)

const RAIN_CHANCE_BY_SEASON:Array[float] = [0.45, 0.25, 0.35, 0.0] # 春/夏/秋/冬
const SNOW_CHANCE_WINTER:float = 0.55

var weather:String = "sunny": ## sunny / rain / snow
	set(val):
		weather = val
		weather_changed.emit(weather)

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)
	_roll_weather()

func is_raining() -> bool:
	return weather == "rain"

func is_snowing() -> bool:
	return weather == "snow"

func _on_new_day(_day:int) -> void:
	_roll_weather()

func _roll_weather() -> void:
	var season:int = TimeSystem.get_season()
	var r:float = randf()
	if season == TimeSystem.Season.WINTER:
		weather = "snow" if r < SNOW_CHANCE_WINTER else "sunny"
	else:
		var chance:float = RAIN_CHANCE_BY_SEASON[season]
		weather = "rain" if r < chance else "sunny"
	print("天气: ", weather)
