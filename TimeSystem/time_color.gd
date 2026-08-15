extends CanvasModulate
class_name TimeColor

var weeks:Array = ["星期一","星期二","星期三","星期四","星期五","星期六","星期天"]

@export var init_day:int:
	set(val):
		init_day = val
		TimeSystem.initial_day = val
		TimeSystem.set_initial_time()
		
@export var init_hour:int:
	set(val):
		init_hour = val
		TimeSystem.initial_hour = val
		TimeSystem.set_initial_time()
		
@export var init_minite:int:
	set(val):
		init_minite = val
		TimeSystem.initial_minute = val
		TimeSystem.set_initial_time()
		
@export_range(0,6) var init_week:int:
	set(val):
		init_week = val
		TimeSystem.inital_week = weeks[val]
		
@export var day_night_gradient:GradientTexture1D

## 季节色调（春/夏/秋/冬）
const SEASON_TINTS:Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.03, 1.03, 0.94),
	Color(1.06, 0.95, 0.82),
	Color(0.92, 0.95, 1.05),
]
var season_tint:Color = Color.WHITE

func _ready() -> void:
	TimeSystem.game_time.connect(on_game_time)
	TimeSystem.season_changed.connect(_on_season_changed)
	_on_season_changed(TimeSystem.get_season())

func _on_season_changed(season:int) -> void:
	season_tint = SEASON_TINTS[clampi(season, 0, 3)]

func on_game_time(time:float):
	#设置滤镜,下面这一堆数值计算会让sample_value值在0-1变化,对应的是0-12小时
	var sample_value = 0.5 * (sin(time - PI * 0.5) + 1.0) #让滤镜和time时间对应
	color = day_night_gradient.gradient.sample(sample_value) * season_tint
