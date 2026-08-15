extends Node2D
## 深度冒烟测试：加载 MainScene（含玩家/HUD/UI），测试新游戏+存档+读档

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("SMOKE: loading main scene")
	SceneManager.load_main_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	# 模拟新游戏：清档重置
	DirAccess.remove_absolute("user://abc.tres")
	Global.gold = 500
	var player := get_tree().get_first_node_in_group("Player") as Player
	print("SMOKE: player=", player)
	if player:
		player.take_damage(30)
		print("SMOKE: after damage health=", player.health)
		player.heal(10, 50, 5)
		print("SMOKE: after heal health=", player.health, " stamina=", player.stamina)
		player.try_use_stamina(20)
		print("SMOKE: after stamina use stamina=", player.stamina)
	SaveManager._save()
	print("SMOKE: saved, gold=", Global.gold)
	SaveManager._load()
	print("SMOKE: loaded, gold=", Global.gold, " day=", TimeSystem.current_day, " weather=", WeatherSystem.weather)
	if player:
		print("SMOKE: loaded health=", player.health, " stamina=", player.stamina)
	print("SMOKE: season=", TimeSystem.get_season_name(), " day_of_season=", TimeSystem.get_day_of_season())
	print("SMOKE_OK")
