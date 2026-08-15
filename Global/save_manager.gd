extends Node
## Autoload
## 从save_component获取需要存档的数据
## 然后用save_data封装数据，最后在用此脚本写到硬盘中

const SAVE_PATH:String = "user://abc.tres"

func _get_save_components() -> Array[SaveComponent]:
	var result:Array[SaveComponent] = []
	for node in get_tree().get_nodes_in_group("SaveComponents"):
		if node is SaveComponent:
			result.append(node)
	return result

func _save() -> void:
	var save_data := SaveData.new()
	#nodes：每个SaveComponent保存一份（修复原来覆盖写入的bug）
	var save_components := _get_save_components()
	for save_component in save_components:
		save_data.components.append(save_component.get_save_data())
	#player
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player:
		save_data.player_inventory = player.bag_system
		save_data.player_stats = {
			"health": player.health,
			"stamina": player.stamina,
			"mana": player.mana,
			"level": player.level,
			"xp": player.xp,
			"xp_to_next": player.xp_to_next,
		}
	#全局
	save_data.gold = Global.gold
	save_data.day = TimeSystem.current_day
	save_data.weather = WeatherSystem.weather
	save_data.friendships = FriendshipSystem.friendships
	save_data.quest = QuestSystem.quest
	save_data.quest_day = QuestSystem.day_rolled
	ResourceSaver.save(save_data, SAVE_PATH)
	print("存档完成")

func _load() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		push_warning("没有存档文件")
		Global.show_message("没有存档！")
		return
	var save_data := ResourceLoader.load(SAVE_PATH) as SaveData
	if save_data == null:
		return
	#nodes
	var save_components := _get_save_components()
	for i in save_components.size():
		if i < save_data.components.size():
			save_components[i].set_save_data(save_data.components[i])
	#player_inventory与状态
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player:
		if save_data.player_inventory:
			player.bag_system = save_data.player_inventory
			player.sync_inventory()
		var stats:Dictionary = save_data.player_stats
		player.health = int(stats.get("health", player.max_health))
		player.stamina = int(stats.get("stamina", player.max_stamina))
		player.mana = int(stats.get("mana", player.max_mana))
		player.level = int(stats.get("level", 1))
		player.xp = int(stats.get("xp", 0))
		player.xp_to_next = int(stats.get("xp_to_next", 10))
		player.stats_changed.emit(player.health, player.max_health, player.stamina, player.max_stamina, player.mana, player.max_mana)
	#全局
	Global.gold = save_data.gold
	TimeSystem.set_time(maxi(save_data.day, 1), 6, 0)
	if WeatherSystem:
		WeatherSystem.weather = save_data.weather
	if save_data.friendships.size() > 0:
		FriendshipSystem.friendships = save_data.friendships
	if save_data.quest.size() > 0:
		QuestSystem.quest = save_data.quest
		QuestSystem.day_rolled = save_data.quest_day
	print("读档完成")
