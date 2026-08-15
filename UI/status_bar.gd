extends Control
## HUD：生命/体力/魔力条 + 金币 + 时间 + 季节 + 天气

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var gold_label: Label = %GoldLabel
@onready var time_label: Label = %TimeLabel
@onready var season_label: Label = %SeasonLabel
@onready var weather_label: Label = %WeatherLabel
@onready var level_label: Label = %LevelLabel
@onready var quest_label: Label = %QuestLabel
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_name: Label = %BossName

func _process(_delta: float) -> void:
	# Boss血条
	var bosses := get_tree().get_nodes_in_group("Boss")
	if bosses.is_empty():
		boss_bar.visible = false
		boss_name.visible = false
		return
	var b := bosses[0] as Boss
	boss_bar.visible = true
	boss_name.visible = true
	boss_bar.max_value = b.hurt.max_health
	boss_bar.value = maxf(b.hurt.max_health - b.hurt.current_health, 0)
	boss_name.text = "BOSS：%s" % b.enemy_name

var player: Player

func _ready() -> void:
	Global.gold_changed.connect(_on_gold_changed)
	TimeSystem.time_tick.connect(_on_time_tick)
	TimeSystem.season_changed.connect(_on_season_changed)
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	SceneManager.level_changed.connect(_find_player)
	QuestSystem.quest_updated.connect(_on_quest_updated)
	_find_player()
	_on_gold_changed(Global.gold)
	_on_season_changed(TimeSystem.get_season())
	_on_weather_changed(WeatherSystem.weather)
	_on_quest_updated(QuestSystem.quest)

func _on_quest_updated(quest:Dictionary) -> void:
	if quest.is_empty():
		quest_label.text = ""
		return
	var done: String = "✓" if quest.get("done", false) else "%d/%d" % [quest["progress"], quest["target"]]
	quest_label.text = "任务：%s %s（%d金）" % [quest["name"], done, quest["reward"]]

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if player and not player.stats_changed.is_connected(_on_stats_changed):
		player.stats_changed.connect(_on_stats_changed)
		_on_stats_changed(player.health, player.max_health, player.stamina, player.max_stamina, player.mana, player.max_mana)
	if player and not player.level_changed.is_connected(_on_level_changed):
		player.level_changed.connect(_on_level_changed)
		_on_level_changed(player.level)

func _on_level_changed(level:int) -> void:
	level_label.text = "等级: %d | 技能: 钓%d 矿%d 农%d 采%d 战%d" % [
		level,
		Global.skills.get("fishing", 0),
		Global.skills.get("mining", 0),
		Global.skills.get("farming", 0),
		Global.skills.get("foraging", 0),
		Global.skills.get("combat", 0),
	]

func _on_stats_changed(health:int, max_health:int, stamina:int, max_stamina:int, mana:int, max_mana:int) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	mana_bar.max_value = max_mana
	mana_bar.value = mana

func _on_gold_changed(gold:int) -> void:
	gold_label.text = "金币: %d" % gold

func _on_time_tick(day:int, hour:int, minute:int, week) -> void:
	time_label.text = "%s %s %d日 %02d:%02d" % [week, TimeSystem.get_season_name(), TimeSystem.get_day_of_season(), hour, minute]

func _on_season_changed(season:int) -> void:
	season_label.text = "季节: " + TimeSystem.SEASON_NAMES[season]

func _on_weather_changed(weather:String) -> void:
	var names := {"sunny": "晴天", "rain": "雨天", "snow": "下雪", "storm": "雷暴"}
	weather_label.text = "天气: " + names.get(weather, weather)
