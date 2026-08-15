extends Node
## Autoload 天气系统：每天清晨根据季节随机天气，影响作物浇水需求等

signal weather_changed(weather:String)

const RAIN_CHANCE_BY_SEASON:Array[float] = [0.45, 0.25, 0.35, 0.0] # 春/夏/秋/冬
const SNOW_CHANCE_WINTER:float = 0.55
const STORM_CHANCE_SUMMER:float = 0.3 ## 夏天降雨升级为雷暴的概率
const THUNDER = preload("res://AudioSystem/thunder.wav") ## 程序生成雷声音效

var weather:String = "sunny": ## sunny / rain / snow / storm
	set(val):
		weather = val
		weather_changed.emit(weather)

var thunder_timer: float = 0.0 ## 距下次雷声的秒数

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)
	_roll_weather()

func _process(delta: float) -> void:
	if weather != "storm": return
	thunder_timer -= delta
	if thunder_timer <= 0.0:
		_play_thunder()

## 播放一声雷鸣并安排下一次
func _play_thunder() -> void:
	thunder_timer = randf_range(4.0, 10.0)
	AudioManager.play_sfx(THUNDER)

func is_raining() -> bool:
	return weather == "rain" or weather == "storm"

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
		if r < chance:
			# 夏天降雨有概率升级为雷暴
			if season == TimeSystem.Season.SUMMER and randf() < STORM_CHANCE_SUMMER:
				weather = "storm"
			else:
				weather = "rain"
		else:
			weather = "sunny"
	print("天气: ", weather)
