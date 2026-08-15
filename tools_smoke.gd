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
	# ---- 作物系统测试（天气改手动控制，避免随机干扰）----
	if TimeSystem.time_tick_day.is_connected(WeatherSystem._on_new_day):
		TimeSystem.time_tick_day.disconnect(WeatherSystem._on_new_day)
	var level: Node2D = SceneManager.get_current_level()
	var crops_container: Node2D = level.find_child("Crops") as Node2D
	var crop_scene: PackedScene = load("res://Placeables/Crops/crop.tscn")
	var seed_radish: Item = load("res://Bag/items/seeds/萝卜种子.tres")
	var crop := crop_scene.instantiate() as Crop
	crop.crop_data = seed_radish.crop_data
	crop.cell = Vector2i(5, 5)
	crop.global_position = (level.get_node("Ground") as TileMapLayer).map_to_local(crop.cell)
	crops_container.add_child(crop)
	print("SMOKE: crop planted stage=", crop.growth_stage)
	# 浇水后过一天 → 生长
	var water_soil := level.get_node("WaterSoil") as TileMapLayer
	water_soil.set_cells_terrain_connect([crop.cell], 0, 4, true)
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
	await get_tree().process_frame
	print("SMOKE: crop after watered day stage=", crop.growth_stage)
	# 不浇水再过一天 → 不长（强制晴天）
	WeatherSystem.weather = "sunny"
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
	await get_tree().process_frame
	print("SMOKE: crop after dry day stage=", crop.growth_stage)
	# 雨天自动浇水 → 生长
	WeatherSystem.weather = "rain"
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
	await get_tree().process_frame
	print("SMOKE: crop after rain day stage=", crop.growth_stage)
	# 季节约束：秋季南瓜在春天 → 枯萎
	var seed_pumpkin: Item = load("res://Bag/items/seeds/南瓜种子.tres")
	var bad := crop_scene.instantiate() as Crop
	bad.crop_data = seed_pumpkin.crop_data
	bad.cell = Vector2i(7, 7)
	bad.global_position = (level.get_node("Ground") as TileMapLayer).map_to_local(bad.cell)
	crops_container.add_child(bad)
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
	await get_tree().process_frame
	print("SMOKE: fall crop in spring withering=", bad.withering)
	# 作物存档读档
	SaveManager._save()
	SaveManager._load()
	await get_tree().process_frame
	await get_tree().process_frame
	var crop_count: int = 0
	var restored_crop: Crop = null
	for child in crops_container.get_children():
		if child is Crop:
			crop_count += 1
			if restored_crop == null:
				restored_crop = child
	print("SMOKE: crops after load count=", crop_count, " stage=", restored_crop.growth_stage if restored_crop else -1)
	# ---- 战斗系统测试（夜晚进行，避免刷怪器白天驱散干扰）----
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	var spawner := level.get_node("EnemySpawner") as EnemySpawner
	spawner.enabled = false # 战斗单元测试期间关闭刷怪器
	var drops_node := get_node_or_null(Global.root_scene["drops"]) as Node2D
	var slime_scene: PackedScene = load("res://Combat/slime.tscn")
	var slime := slime_scene.instantiate() as Enemy
	slime.global_position = player.global_position + Vector2(60, 0)
	slime.aggro_range = 0.0 # 测试时保持静止，避免接触干扰
	slime.add_to_group("Enemies")
	level.add_child(slime)
	await get_tree().process_frame
	print("SMOKE: slime spawned, chasing=", slime.chasing, " hp=", slime.hurt.current_health)
	# 近战命中（模拟武器挥砍）
	slime.hurt.take_damage(15, player.global_position)
	print("SMOKE: slime after hit hp=", slime.hurt.current_health, " knockback=", slime.knockback_velocity.length())
	# 玩家无敌帧：连打两次只掉一次血
	player.invincible_time = 0.0
	var hp_before: int = player.health
	player.take_damage(10)
	player.take_damage(10)
	print("SMOKE: player iframes hp=", player.health, " (before=", hp_before, ")")
	# 击杀 → 掉落
	print("SMOKE: body_droped connections=", slime.hurt.body_droped.get_connections().size())
	slime.hurt.take_damage(15, player.global_position)
	print("SMOKE: after kill call dead=", slime.dead, " hp=", slime.hurt.current_health, " maxhp=", slime.hurt.max_health)
	print("SMOKE: coin_drop=", slime.coin_drop)
	await get_tree().process_frame
	await get_tree().process_frame
	var farm_fall_objects: int = 0
	for child in level.get_children():
		if child is FallObjectComponent:
			farm_fall_objects += 1
	print("SMOKE: slime dead=", slime.dead, " drops=", drops_node.get_child_count(), " farm_fall=", farm_fall_objects)
	# 箭矢命中敌人（等待死亡淡出结束，避免打到尸体）
	await get_tree().create_timer(0.5).timeout
	for child in drops_node.get_children():
		child.queue_free()
	var arrow_scene: PackedScene = load("res://Combat/arrow_projectile.tscn")
	var slime2 := slime_scene.instantiate() as Enemy
	slime2.global_position = player.global_position + Vector2(150, 0)
	slime2.aggro_range = 0.0
	level.add_child(slime2)
	await get_tree().process_frame
	var arrow = arrow_scene.instantiate()
	level.add_child(arrow)
	arrow.global_position = player.global_position + Vector2(30, 0)
	if arrow.has_method("setup"):
		arrow.setup(Vector2.RIGHT, 8)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(arrow):
		print("SMOKE: arrow alive pos=", arrow.global_position)
	else:
		print("SMOKE: arrow hit target and freed")
	print("SMOKE: slime2 after arrow hp=", slime2.hurt.current_health)
	# 刷怪器：夜晚生成、白天驱散
	spawner.enabled = true
	spawner.enemy_scenes = [slime_scene]
	spawner.spawn_interval = 0.1
	spawner.timer = 0.0
	spawner.night_only = true
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().create_timer(0.8).timeout
	print("SMOKE: spawner night enemies=", get_tree().get_nodes_in_group("Enemies").size())
	TimeSystem.set_time(TimeSystem.current_day, 12, 0)
	await get_tree().create_timer(0.8).timeout
	print("SMOKE: spawner day enemies=", get_tree().get_nodes_in_group("Enemies").size())
	spawner.enabled = false # 后续测试不再刷怪
	# ---- M3 采集与资源测试 ----
	var farm_water := level.get_node("Water") as TileMapLayer
	print("SMOKE: farm water cells=", farm_water.get_used_cells().size())
	var forage_container: Node2D = level.get_node("Forage")
	print("SMOKE: forage count=", forage_container.get_child_count())
	# 矿石节点：稿子敲3下碎掉并掉落
	var ore_scene: PackedScene = load("res://Terrain/Ores/ore_node.tscn")
	var ore := ore_scene.instantiate() as OreNode
	ore.ore_item = load("res://Bag/items/materials/铜矿石.tres")
	ore.global_position = player.global_position + Vector2(80, 0)
	level.add_child(ore)
	ore.hurt.take_damage(1, player.global_position)
	ore.hurt.take_damage(1, player.global_position)
	ore.hurt.take_damage(1, player.global_position)
	await get_tree().create_timer(0.5).timeout # 等待碎裂动画结束
	await get_tree().process_frame
	print("SMOKE: ore broken=", not is_instance_valid(ore), " drops=", drops_node.get_child_count())
	# ---- M4 矿洞测试 ----
	SceneManager.change_level("Mine", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var mine := SceneManager.get_current_level() as Mine
	if mine:
		print("SMOKE: mine ground=", (mine.get_node("Ground") as TileMapLayer).get_used_cells().size(), " ores=", (mine.get_node("Ores") as Node2D).get_child_count())
	else:
		print("SMOKE: mine FAILED")
	# 回农场
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	print("SMOKE: back to farm=", level.name)
	# ---- M6 钓鱼测试 ----
	var fishing := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	player.global_position = Vector2(60, 660) # 池塘西侧
	player.current_item = load("res://Bag/items/tools/鱼竿.tres")
	await get_tree().process_frame
	fishing._cast(player.global_position.direction_to(Vector2(192, 656)))
	await get_tree().create_timer(1.0).timeout
	print("SMOKE: bobber=", fishing.bobber != null, " flying=", fishing.bobber.flying if fishing.bobber else -1)
	if fishing.bobber:
		fishing.bobber._hook()
	await get_tree().process_frame
	print("SMOKE: fishing ui=", fishing.fishing_ui != null)
	var bag_before: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_before += 1
	if fishing.fishing_ui:
		fishing.fishing_ui._finish(true)
		await get_tree().process_frame
	var caught_fish: bool = false
	for it in player.bag_system.items:
		if it != null and it.type == Item.ItemType.Consume and it.name in ["沙丁鱼", "鲤鱼", "大嘴鲈鱼"]:
			caught_fish = true
	print("SMOKE: caught fish=", caught_fish)
	# ---- 经验等级与合成测试 ----
	var xp_before: int = player.xp
	player.gain_xp(30) # 10 + 15 → 升级两次
	print("SMOKE: level=", player.level, " xp=", player.xp, " maxhp=", player.max_health, " (xp_before=", xp_before, ")")
	# 合成：给8个木头 → 合成木剑
	for i in 8:
		var wood: Item = load("res://Bag/items/materials/wood.tres").duplicate()
		player.bag_system.add_item(wood)
	var crafting := get_node_or_null("/root/MainScene/CraftingSystem") as CraftingSystem
	var wood_sword_recipe: Recipe = load("res://Crafting/recipes/木剑.tres")
	crafting.panel._on_craft_pressed(wood_sword_recipe)
	var has_sword: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "木剑":
			has_sword = true
	var wood_left: int = 0
	for it in player.bag_system.items:
		if it != null and it.name == "木头":
			wood_left += it.quantity
	print("SMOKE: crafted sword=", has_sword, " wood_left=", wood_left)
	# ---- M7 好感度与送礼测试 ----
	var emily := level.get_node_or_null("NPC/Emily") as NPC
	if emily:
		# 先对话（不送）
		var hearts_before: float = FriendshipSystem.get_hearts("艾米丽")
		# 送礼：手持树莓
		var berry: Item = load("res://Bag/items/forage/树莓.tres")
		player.bag_system.add_item(berry.duplicate())
		player.current_item = berry.duplicate()
		player.current_item.quantity = 1
		player.bag_system.items[player.item_index] = player.current_item
		emily._give_gift(player)
		var hearts_after: float = FriendshipSystem.get_hearts("艾米丽")
		# 当天再送 → 被拒
		emily._give_gift(player)
		var hearts_final: float = FriendshipSystem.get_hearts("艾米丽")
		print("SMOKE: hearts=", hearts_before, "->", hearts_after, " blocked_second=", hearts_after == hearts_final, " gifted_today=", FriendshipSystem.friendships["艾米丽"]["gifted_today"])
		# 好感存档
		SaveManager._save()
		SaveManager._load()
		print("SMOKE: hearts after load=", FriendshipSystem.get_hearts("艾米丽"))
	else:
		print("SMOKE: emily not found")
	# ---- Boss战测试 ----
	for i in 10:
		var gel: Item = load("res://Bag/items/materials/凝胶.tres").duplicate()
		player.bag_system.add_item(gel)
	var eye_recipe: Recipe = load("res://Crafting/recipes/可疑眼球.tres")
	crafting.panel._on_craft_pressed(eye_recipe)
	var has_eye: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "可疑眼球":
			has_eye = true
			player.current_item = it
			break
	print("SMOKE: crafted eye=", has_eye)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	player.use_summon()
	await get_tree().process_frame
	var boss := level.get_node_or_null("BossEye") as Boss
	print("SMOKE: boss spawned=", boss != null)
	if boss:
		boss.hurt.take_damage(400, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: boss dead=", not is_instance_valid(boss), " drops=", drops_node.get_child_count())
	# ---- 动物/烹饪/镐升级/任务/节日测试 ----
	player.heal(999, 999, 999) # 防止被残留敌人打晕换图
	var egg_before: int = drops_node.get_child_count()
	var chicken := level.get_node_or_null("Animals/Chicken") as Animal
	if chicken:
		chicken.produced_today = false
		chicken.pet()
		chicken.pet() # 当天第二次应被拒绝
		await get_tree().process_frame
		print("SMOKE: chicken egg drop=", drops_node.get_child_count() > egg_before)
	# 烹饪：煎蛋
	player.bag_system.add_item(load("res://Bag/items/animal/鸡蛋.tres").duplicate())
	var egg_recipe: Recipe = load("res://Crafting/recipes/煎蛋.tres")
	crafting.panel._on_craft_pressed(egg_recipe)
	var has_food: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "煎蛋":
			has_food = true
	print("SMOKE: cooked egg=", has_food)
	# 镐头升级：铜镐 2 下挖碎矿石
	player.bag_system.add_item(load("res://Bag/items/tools/稿子.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/铜矿石.tres").duplicate())
	var copper_pick_recipe: Recipe = load("res://Crafting/recipes/铜镐.tres")
	crafting.panel._on_craft_pressed(copper_pick_recipe)
	var has_pick: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "铜镐":
			has_pick = true
			break
	print("SMOKE: crafted copper pick=", has_pick)
	if has_pick:
		var ore2 := ore_scene.instantiate() as OreNode
		ore2.ore_item = load("res://Bag/items/materials/铁矿石.tres")
		ore2.global_position = player.global_position + Vector2(90, 0)
		level.add_child(ore2)
		ore2.hurt.take_damage(2, player.global_position)
		ore2.hurt.take_damage(2, player.global_position)
		await get_tree().create_timer(0.5).timeout
		print("SMOKE: ore2 broken in 2 hits=", not is_instance_valid(ore2))
	# 任务：击杀任务
	QuestSystem.quest = {"type": "kill", "target": 5, "progress": 0, "reward": 150, "name": "击败敌人", "done": false}
	QuestSystem.day_rolled = TimeSystem.current_day
	var gold_before: int = Global.gold
	for i in 5:
		QuestSystem.report("kill")
	QuestSystem.report("forage") # 无关类型不应计数
	print("SMOKE: quest done=", QuestSystem.quest["done"], " gold_gain=", Global.gold - gold_before)
	# 节日：跳到春天13日（蛋节）——set_time触发day change自动检查
	forage_container = level.get_node("Forage") # 矿洞往返后农场已重建，需重新获取
	print("SMOKE: pre-festival level alive=", is_instance_valid(level), " hp=", player.health)
	TimeSystem.set_time(13, 6, 0)
	await get_tree().process_frame
	print("SMOKE: post-festival level alive=", is_instance_valid(level), " current=", SceneManager.get_current_level().name if SceneManager.get_current_level() else "none")
	var has_festival_gift: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "煎蛋":
			has_festival_gift = true
	print("SMOKE: festival day=", TimeSystem.get_day_of_season(), " gift=", has_festival_gift, " forage=", forage_container.get_child_count())
	# ---- 新敌人测试 ----
	var skel_scene: PackedScene = load("res://Combat/skeleton.tscn")
	var skel := skel_scene.instantiate() as Enemy
	skel.global_position = player.global_position + Vector2(60, 0)
	skel.aggro_range = 0.0
	level.add_child(skel)
	await get_tree().process_frame
	print("SMOKE: skeleton=", skel.enemy_name, " vframes=", skel.sprite.vframes)
	skel.hurt.take_damage(35, player.global_position)
	await get_tree().process_frame
	print("SMOKE: skeleton dead=", skel.dead)
	var deye_scene: PackedScene = load("res://Combat/demon_eye.tscn")
	var deye := deye_scene.instantiate() as Enemy
	deye.global_position = player.global_position + Vector2(-60, 0)
	deye.aggro_range = 0.0
	level.add_child(deye)
	await get_tree().process_frame
	print("SMOKE: demon eye=", deye.enemy_name)
	# Boss血条存在性
	var boss_bar := get_node_or_null("/root/MainScene/MainCanvasLayer/StatusBar") as Control
	print("SMOKE: boss bar node=", boss_bar != null)
	# ---- 矿洞多层测试 ----
	Global.mine_floor = 3
	SceneManager.change_level("Mine", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var mine3 := SceneManager.get_current_level() as Mine
	if mine3:
		var pool := mine3._ore_pool()
		var has_gold: bool = pool.has(load("res://Bag/items/materials/金矿石.tres"))
		print("SMOKE: mine floor=", mine3.floor_index, " ladders=", mine3.find_children("*", "Ladder", true, false).size(), " gold_pool=", has_gold)
	# 回农场
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 克苏鲁之脑Boss测试 ----
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var spine_recipe: Recipe = load("res://Crafting/recipes/血腥脊椎.tres")
	crafting.panel._on_craft_pressed(spine_recipe)
	var has_spine: bool = false
	var spine_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "血腥脊椎":
			has_spine = true
			spine_item = it
			break
	print("SMOKE: crafted spine=", has_spine)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	# 工具栏每帧会覆盖current_item，赋值后必须立即调用
	player.current_item = spine_item
	player.use_summon()
	await get_tree().process_frame
	var brain := level.get_node_or_null("BossBrain") as Boss
	print("SMOKE: brain spawned=", brain != null)
	if brain:
		brain.hurt.take_damage(600, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: brain dead=", not is_instance_valid(brain), " drops=", drops_node.get_child_count())
	# ---- 皮埃尔小镇NPC测试 ----
	SceneManager.change_level("Town", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var town := SceneManager.get_current_level() as Town
	var pierre := town.get_node_or_null("Pierre") as NPC
	print("SMOKE: pierre=", pierre != null, " name=", pierre.npc_display_name if pierre else "?")
	if pierre:
		var p_hearts: float = FriendshipSystem.get_hearts("皮埃尔")
		player = get_tree().get_first_node_in_group("Player")
		player.current_item = load("res://Bag/items/forage/蘑菇.tres").duplicate()
		pierre._give_gift(player)
		print("SMOKE: pierre hearts=", p_hearts, "->", FriendshipSystem.get_hearts("皮埃尔"))
	# 回农场
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 新作物数据检查 ----
	var tomato_seed: Item = load("res://Bag/items/seeds/番茄种子.tres")
	print("SMOKE: tomato seed crop_data=", tomato_seed.crop_data != null, " seasons=", tomato_seed.crop_data.allowed_seasons if tomato_seed.crop_data else "?")
	print("SMOKE_OK")
