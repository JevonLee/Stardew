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
	# 镐头升级：先熔炼铜锭，再合成铜镐（2 下挖碎矿石）
	player.bag_system.add_item(load("res://Bag/items/tools/稿子.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/铜矿石.tres").duplicate())
	var copper_bar_recipe: Recipe = load("res://Crafting/recipes/铜锭.tres")
	crafting.panel._on_craft_pressed(copper_bar_recipe)
	crafting.panel._on_craft_pressed(copper_bar_recipe) # 10矿石 → 2铜锭
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
	# 秋16星露谷博览会
	TimeSystem.set_time(72, 6, 0)
	await get_tree().process_frame
	var has_fair_cake: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "蛋糕":
			has_fair_cake = true
	print("SMOKE: fair day=", TimeSystem.get_day_of_season(), " cake=", has_fair_cake)
	# 冬25冬星节
	TimeSystem.set_time(109, 6, 0)
	await get_tree().process_frame
	var has_winter_fish: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "蜜汁烤鱼":
			has_winter_fish = true
	print("SMOKE: winter star day=", TimeSystem.get_day_of_season(), " gift=", has_winter_fish)
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
	# ---- 宝石掉落测试 ----
	var ore3 := ore_scene.instantiate() as OreNode
	ore3.ore_item = load("res://Bag/items/materials/金矿石.tres")
	ore3.gem_item = load("res://Bag/items/materials/紫水晶.tres")
	ore3.gem_chance = 1.0
	ore3.global_position = player.global_position + Vector2(100, 0)
	level.add_child(ore3)
	ore3.hurt.take_damage(3, player.global_position)
	await get_tree().create_timer(0.5).timeout
	var gem_dropped: bool = false
	for child in drops_node.get_children():
		if child is FallObjectComponent and child.item != null and child.item.name == "紫水晶":
			gem_dropped = true
	print("SMOKE: gem drop=", gem_dropped)
	# ---- 村民日程测试 ----
	var emily2 := level.get_node_or_null("NPC/Emily") as NPC
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	var emily_anim: String = ""
	if emily2 and emily2.get_node("AnimatedSprite2D"):
		emily_anim = (emily2.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation
	print("SMOKE: emily night anim=", emily_anim)
	# ---- 图鉴与动物测试 ----
	CollectionSystem.record_fish("沙丁鱼")
	CollectionSystem.record_kill("史莱姆")
	CollectionSystem.record_item("木头")
	SaveManager._save()
	SaveManager._load()
	print("SMOKE: collection fish=", CollectionSystem.fish_caught.has("沙丁鱼"), " kills=", CollectionSystem.enemies_killed.get("史莱姆", 0), " items=", CollectionSystem.items_collected.size())
	var sheep := level.get_node_or_null("Animals/Sheep") as Animal
	var duck := level.get_node_or_null("Animals/Duck") as Animal
	print("SMOKE: sheep=", sheep != null, " duck=", duck != null, " coop=", level.get_node_or_null("Animals/Coop") != null, " barn=", level.get_node_or_null("Animals/Barn") != null)
	# ---- 新鱼与垃圾测试 ----
	var fishing2 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	print("SMOKE: fish table=", fishing2.FISH_TABLE.size(), " junk table=", fishing2.JUNK_TABLE.size())
	# ---- 成就测试 ----
	CollectionSystem.record_fish("鲤鱼")
	CollectionSystem.record_fish("章鱼")
	CollectionSystem.record_fish("鲶鱼")
	CollectionSystem.enemies_killed["史莱姆"] = 10
	CollectionSystem.record_item("石头")
	Global.gold = 5000
	AchievementSystem.check()
	print("SMOKE: achievements fish3=", AchievementSystem.is_unlocked("fish_3"), " kill10=", AchievementSystem.is_unlocked("kill_10"), " gold5k=", AchievementSystem.is_unlocked("gold_5000"))
	# ---- 史莱姆王Boss测试 ----
	for i in 30:
		player.bag_system.add_item(load("res://Bag/items/materials/凝胶.tres").duplicate())
	var crown_recipe: Recipe = load("res://Crafting/recipes/史莱姆王冠.tres")
	crafting.panel._on_craft_pressed(crown_recipe)
	var crown: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "史莱姆王冠":
			crown = it
			break
	print("SMOKE: crafted crown=", crown != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	player.current_item = crown
	player.use_summon()
	await get_tree().process_frame
	var king := level.get_node_or_null("BossSlimeKing") as Boss
	print("SMOKE: king spawned=", king != null)
	if king:
		king.hurt.take_damage(800, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: king dead=", not is_instance_valid(king), " drops=", drops_node.get_child_count())
	print("SMOKE: boss slayer ach=", AchievementSystem.is_unlocked("boss_slayer"))
	# ---- 温室测试 ----
	var greenhouse_crop := crop_scene.instantiate() as Crop
	greenhouse_crop.crop_data = load("res://Bag/items/seeds/南瓜种子.tres").crop_data # 秋季作物
	greenhouse_crop.in_greenhouse = true
	greenhouse_crop.cell = Vector2i(145, 17)
	greenhouse_crop.global_position = (level.get_node("Ground") as TileMapLayer).map_to_local(greenhouse_crop.cell)
	level.find_child("Crops").add_child(greenhouse_crop)
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0) # 春季推进一天
	await get_tree().process_frame
	print("SMOKE: greenhouse crop withering=", greenhouse_crop.withering)
	# ---- 森林地图测试 ----
	SceneManager.change_level("Forest", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var forest := SceneManager.get_current_level() as Forest
	if forest:
		print("SMOKE: forest ground=", (forest.get_node("Ground") as TileMapLayer).get_used_cells().size(), " water=", (forest.get_node("Water") as TileMapLayer).get_used_cells().size(), " trees=", (forest.get_node("Trees") as Node2D).get_child_count(), " forage=", (forest.get_node("Forage") as Node2D).get_child_count())
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 新食谱与法杖测试 ----
	player.bag_system.add_item(load("res://Bag/items/animal/牛奶.tres").duplicate())
	var cheese_recipe: Recipe = load("res://Crafting/recipes/奶酪.tres")
	crafting.panel._on_craft_pressed(cheese_recipe)
	var has_cheese: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "奶酪":
			has_cheese = true
	print("SMOKE: crafted cheese=", has_cheese)
	# ---- 新食谱测试（南瓜汤/苹果派/烤玉米） ----
	player.bag_system.add_item(load("res://Bag/items/crops/南瓜.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/animal/牛奶.tres").duplicate())
	var pumpkin_recipe: Recipe = load("res://Crafting/recipes/南瓜汤.tres")
	crafting.panel._on_craft_pressed(pumpkin_recipe)
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/crops/苹果.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/animal/鸡蛋.tres").duplicate())
	var applepie_recipe: Recipe = load("res://Crafting/recipes/苹果派.tres")
	crafting.panel._on_craft_pressed(applepie_recipe)
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/crops/玉米.tres").duplicate())
	var roastcorn_recipe: Recipe = load("res://Crafting/recipes/烤玉米.tres")
	crafting.panel._on_craft_pressed(roastcorn_recipe)
	var found_soup: Item = null
	var found_pie: Item = null
	var found_corn: Item = null
	for it in player.bag_system.items:
		if it != null:
			match it.name:
				"南瓜汤": found_soup = it
				"苹果派": found_pie = it
				"烤玉米": found_corn = it
	print("SMOKE: soup=", found_soup != null, " hp=", found_soup.health_restore if found_soup else -1, " pie=", found_pie != null, " corn=", found_corn != null)
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	var staff_recipe: Recipe = load("res://Crafting/recipes/紫水晶法杖.tres")
	crafting.panel._on_craft_pressed(staff_recipe)
	var has_staff: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "紫水晶法杖":
			has_staff = true
	print("SMOKE: crafted staff=", has_staff)
	# ---- 宠物猫测试 ----
	var pet := get_node_or_null("/root/MainScene/Pet") as Pet
	print("SMOKE: pet=", pet != null, " follows=", pet != null and pet.get_tree() != null)
	# ---- 新敌人测试 ----
	var spider_scene: PackedScene = load("res://Combat/spider.tscn")
	var spider := spider_scene.instantiate() as Enemy
	spider.global_position = player.global_position + Vector2(60, 0)
	spider.aggro_range = 0.0
	level.add_child(spider)
	await get_tree().process_frame
	print("SMOKE: spider=", spider.enemy_name, " speed=", spider.speed)
	var jungle_scene: PackedScene = load("res://Combat/jungle_slime.tscn")
	var jungle := jungle_scene.instantiate() as Enemy
	jungle.global_position = player.global_position + Vector2(-60, 0)
	jungle.aggro_range = 0.0
	level.add_child(jungle)
	await get_tree().process_frame
	print("SMOKE: jungle slime=", jungle.enemy_name)
	# ---- 果酱/烤蘑菇 ----
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/forage/树莓.tres").duplicate())
	var jam_recipe: Recipe = load("res://Crafting/recipes/果酱.tres")
	crafting.panel._on_craft_pressed(jam_recipe)
	var has_jam: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "果酱":
			has_jam = true
	print("SMOKE: crafted jam=", has_jam)
	# ---- 传送面板 ----
	var travel_sys := get_node_or_null("/root/MainScene/TravelSystem") as TravelSystem
	var travel_panel_ins := travel_sys.panel as TravelPanel if travel_sys else null
	print("SMOKE: travel panel=", travel_panel_ins != null, " dests=", travel_panel_ins.DESTINATIONS.size() if travel_panel_ins else -1)
	# ---- 信件系统 ----
	MailSystem.pending_mail = {"text": "测试信件", "gift": "res://Bag/items/forage/蘑菇.tres", "gift_count": 2}
	var bag_before_mail: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_before_mail += 1
	MailSystem.claim()
	var got_mushroom: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "蘑菇" and it.quantity >= 2:
			got_mushroom = true
	print("SMOKE: mail gift=", got_mushroom)
	# ---- 结婚系统测试 ----
	FriendshipSystem.add_hearts("艾米丽", 10.0)
	var bouquet: Item = load("res://Bag/items/materials/花束.tres").duplicate()
	player.bag_system.add_item(bouquet)
	player.current_item = bouquet
	var emily3 := level.get_node_or_null("NPC/Emily") as NPC
	emily3._give_gift(player)
	print("SMOKE: married=", MarriageSystem.is_married(), " spouse=", MarriageSystem.spouse)
	SaveManager._save()
	SaveManager._load()
	print("SMOKE: spouse after load=", MarriageSystem.spouse)
	# ---- 新村民测试 ----
	SceneManager.change_level("Town", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var town2 := SceneManager.get_current_level() as Town
	var abigail := town2.get_node_or_null("Abigail") as NPC
	var lewis := town2.get_node_or_null("Lewis") as NPC
	print("SMOKE: abigail=", abigail != null, " lewis=", lewis != null)
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 蛋糕与雷暴测试 ----
	player.bag_system.add_item(load("res://Bag/items/animal/鸡蛋.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/animal/鸡蛋.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/animal/牛奶.tres").duplicate())
	var cake_recipe: Recipe = load("res://Crafting/recipes/蛋糕.tres")
	crafting.panel._on_craft_pressed(cake_recipe)
	var has_cake: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "蛋糕":
			has_cake = true
	print("SMOKE: crafted cake=", has_cake)
	WeatherSystem.weather = "storm"
	print("SMOKE: storm raining=", WeatherSystem.is_raining())
	# ---- 小镇海边钓鱼测试 ----
	SceneManager.change_level("Town", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var town3 := SceneManager.get_current_level() as Town
	var town_water := town3.get_node("Water") as TileMapLayer
	print("SMOKE: town ocean cells=", town_water.get_used_cells().size())
	var fishing3 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	var ocean_fish: Array = fishing3._current_fish_table()
	print("SMOKE: ocean table=", ocean_fish.size(), " (town level)")
	# 回农场
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 鱼汤测试 ----
	player.bag_system.add_item(load("res://Bag/items/food/烤鱼.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/animal/牛奶.tres").duplicate())
	var soup_recipe: Recipe = load("res://Crafting/recipes/鱼汤.tres")
	crafting.panel._on_craft_pressed(soup_recipe)
	var has_soup: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "鱼汤":
			has_soup = true
	print("SMOKE: crafted soup=", has_soup)
	# ---- 洒水器测试 ----
	player.bag_system.add_item(load("res://Bag/items/materials/铜锭.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/铜锭.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	var sprinkler_recipe: Recipe = load("res://Crafting/recipes/洒水器.tres")
	crafting.panel._on_craft_pressed(sprinkler_recipe)
	var has_sprinkler: bool = false
	for it in player.bag_system.items:
		if it != null and it.name == "洒水器":
			has_sprinkler = true
	print("SMOKE: crafted sprinkler=", has_sprinkler)
	if has_sprinkler:
		var sprinkler_scene: PackedScene = load("res://Placeables/Sprinkler/sprinkler.tscn")
		var sprinkler := sprinkler_scene.instantiate() as Sprinkler
		sprinkler.cell = Vector2i(5, 5)
		var crops_node := level.find_child("Crops") as Node2D
		crops_node.add_child(sprinkler)
		var ws2 := level.get_node("WaterSoil") as TileMapLayer
		ws2.clear()
		# 推进一天 → 洒水器自动浇水
		WeatherSystem.weather = "sunny"
		TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
		await get_tree().process_frame
		await get_tree().process_frame
		var neighbor_watered: bool = ws2.get_cell_source_id(Vector2i(5, 4)) != -1
		print("SMOKE: sprinkler watered neighbor=", neighbor_watered)
	# ---- 果树测试 ----
	var tree_seed: Item = load("res://Bag/items/seeds/苹果树苗.tres")
	var tree := crop_scene.instantiate() as Crop
	tree.crop_data = tree_seed.crop_data
	tree.cell = Vector2i(30, 30)
	tree.global_position = (level.get_node("Ground") as TileMapLayer).map_to_local(tree.cell)
	level.find_child("Crops").add_child(tree)
	WeatherSystem.weather = "rain" # 让树生长
	for i in 14:
		TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
		await get_tree().process_frame
		await get_tree().process_frame
	print("SMOKE: tree mature=", tree.is_mature(), " stage=", tree.growth_stage)
	tree._harvest()
	await get_tree().process_frame
	print("SMOKE: tree regrow alive=", is_instance_valid(tree))
	# ---- 斧头升级测试 ----
	player.bag_system.add_item(load("res://Bag/items/tools/斧头.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/铜锭.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/铜锭.tres").duplicate())
	var axe_recipe: Recipe = load("res://Crafting/recipes/铜斧.tres")
	crafting.panel._on_craft_pressed(axe_recipe)
	var has_axe: bool = false
	var axe_dmg: int = 0
	for it in player.bag_system.items:
		if it != null and it.name == "铜斧":
			has_axe = true
			axe_dmg = it.damage
	print("SMOKE: crafted copper axe=", has_axe, " dmg=", axe_dmg)
	# ---- 水壶范围浇水测试 ----
	var cc := level.get_node("CropsComponent") as CropsComponent
	var ws3 := level.get_node("WaterSoil") as TileMapLayer
	ws3.clear()
	var center_cell: Vector2i = Vector2i(40, 40)
	# 预铺3x3耕地（terrain 3 = 锄头翻土）
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			cc.tilled_soil.set_cells_terrain_connect([center_cell + Vector2i(dx, dy)], cc.terrain_set, 3, true)
	player.water_radius = 2
	var center_pos: Vector2 = (level.get_node("Ground") as TileMapLayer).map_to_local(center_cell)
	cc.on_watering(center_pos)
	var watered_count: int = 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if ws3.get_cell_source_id(center_cell + Vector2i(dx, dy)) != -1:
				watered_count += 1
	print("SMOKE: radius watering cells=", watered_count)
	# ---- 肥料测试 ----
	TimeSystem.set_time(5, 6, 0) # 拉回春天（树测试把日期推进到了夏天）
	await get_tree().process_frame
	var cc2 := level.get_node("CropsComponent") as CropsComponent
	cc2.fertilized[Vector2i(45, 45)] = true
	var fert_crop := crop_scene.instantiate() as Crop
	fert_crop.crop_data = load("res://Bag/items/seeds/萝卜种子.tres").crop_data
	fert_crop.cell = Vector2i(45, 45)
	fert_crop.global_position = (level.get_node("Ground") as TileMapLayer).map_to_local(fert_crop.cell)
	level.find_child("Crops").add_child(fert_crop)
	WeatherSystem.weather = "rain"
	TimeSystem.set_time(TimeSystem.current_day + 1, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("SMOKE: fertilized crop stage=", fert_crop.growth_stage, " (expect 2)")
	fert_crop._on_day_change(9999) # 直接调用验证信号之外逻辑
	print("SMOKE: fertilized direct call stage=", fert_crop.growth_stage)
	# ---- 血肉墙Boss测试 ----
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var doll_recipe: Recipe = load("res://Crafting/recipes/向导娃娃.tres")
	crafting.panel._on_craft_pressed(doll_recipe)
	var doll: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "向导娃娃":
			doll = it
			break
	print("SMOKE: crafted doll=", doll != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	player.current_item = doll
	player.use_summon()
	await get_tree().process_frame
	var wall := level.get_node_or_null("BossWall") as Boss
	print("SMOKE: wall spawned=", wall != null)
	if wall:
		wall.hurt.take_damage(1200, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: wall dead=", not is_instance_valid(wall), " drops=", drops_node.get_child_count())
	# ---- 沙漠地图测试 ----
	SceneManager.change_level("Desert", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var desert := SceneManager.get_current_level() as Desert
	if desert:
		print("SMOKE: desert ground=", (desert.get_node("Ground") as TileMapLayer).get_used_cells().size(), " oasis=", (desert.get_node("Oasis") as TileMapLayer).get_used_cells().size(), " decor=", (desert.get_node("Decor") as TileMapLayer).get_used_cells().size())
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	# ---- 季节色调测试 ----
	var time_color := get_node_or_null("/root/MainScene/TimeColor") as TimeColor
	TimeSystem.set_time(70, 6, 0) # 夏天（第70天）
	await get_tree().process_frame
	print("SMOKE: season tint=", time_color.season_tint)
	# ---- 宠物互动测试 ----
	var pet2 := get_node_or_null("/root/MainScene/Pet") as Pet
	if pet2:
		pet2.pet()
		pet2.pet()
		print("SMOKE: pet petted=", pet2.petted)
	# ---- 新敌人测试 ----
	var mummy_scene: PackedScene = load("res://Combat/mummy.tscn")
	var mummy := mummy_scene.instantiate() as Enemy
	mummy.global_position = player.global_position + Vector2(60, 0)
	mummy.aggro_range = 0.0
	level.add_child(mummy)
	await get_tree().process_frame
	mummy.hurt.take_damage(60, player.global_position)
	await get_tree().process_frame
	print("SMOKE: mummy=", mummy.enemy_name, " dead=", mummy.dead)
	var gbat_scene: PackedScene = load("res://Combat/giant_bat.tscn")
	var gbat := gbat_scene.instantiate() as Enemy
	gbat.global_position = player.global_position + Vector2(-60, 0)
	gbat.aggro_range = 0.0
	level.add_child(gbat)
	await get_tree().process_frame
	print("SMOKE: giant bat=", gbat.enemy_name)
	# ---- 博物馆捐赠测试 ----
	player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	var museum_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "紫水晶":
			museum_item = it
			break
	var gold_before_donate: int = Global.gold
	if museum_item:
		MuseumSystem.donate(museum_item)
		print("SMOKE: museum donated=", MuseumSystem.total_donated(), " gold_gain=", Global.gold - gold_before_donate)
	SaveManager._save()
	SaveManager._load()
	print("SMOKE: museum after load=", MuseumSystem.total_donated())
	# ---- 沙漠商人测试 ----
	SceneManager.change_level("Desert", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var desert2 := SceneManager.get_current_level() as Desert
	var merchant := desert2.get_node_or_null("Merchant") as NPC
	print("SMOKE: desert merchant=", merchant != null)
	if merchant:
		player = get_tree().get_first_node_in_group("Player")
		player.global_position = merchant.global_position + Vector2(20, 0)
		merchant._open_shop()
		print("SMOKE: merchant shop=", merchant.shop != null and merchant.shop.visible)
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	# ---- 宝箱层测试 ----
	Global.mine_floor = 5
	SceneManager.change_level("Mine", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var mine5 := SceneManager.get_current_level() as Mine
	var treasure_box: Box = null
	if mine5:
		for child in mine5.get_children():
			if child is Box:
				treasure_box = child
				break
	print("SMOKE: treasure floor box=", treasure_box != null, " loot=", treasure_box.box_system.items[0].name if treasure_box and treasure_box.box_system.items[0] else "?")
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	# ---- 沙漠鱼与任务类型测试 ----
	var fishing4 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	var desert_fish: Array = fishing4.DESERT_FISH
	print("SMOKE: desert fish table=", desert_fish.size())
	QuestSystem.quest = {"type": "mine", "target": 8, "progress": 0, "reward": 120, "name": "挖掘矿石", "done": false}
	QuestSystem.report("mine")
	QuestSystem.report("mine")
	QuestSystem.report("mine")
	print("SMOKE: mine quest progress=", QuestSystem.quest["progress"])
	QuestSystem.quest = {"type": "gift", "target": 3, "progress": 0, "reward": 150, "name": "送礼物给村民", "done": false}
	QuestSystem.report("gift")
	print("SMOKE: gift quest progress=", QuestSystem.quest["progress"])
	# ---- 海滩地图测试 ----
	SceneManager.change_level("Beach", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var beach := SceneManager.get_current_level() as Beach
	print("SMOKE: beach=", beach != null)
	if beach:
		var beach_ground: int = beach.get_node("Ground").get_used_cells().size()
		var beach_ocean: int = beach.get_node("Ocean").get_used_cells().size()
		var palm_count: int = beach.get_node("Palms").get_child_count()
		var beach_gate: Node = beach.get_node_or_null("ChangeAreas/ToFarm")
		var beach_barrier: Node = beach.get_node_or_null("OceanBarrier")
		print("SMOKE: beach ground=", beach_ground, " ocean=", beach_ocean, " palms=", palm_count, " gate=", beach_gate != null, " barrier=", beach_barrier != null)
		var fishing5 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
		print("SMOKE: beach fish table=", fishing5._current_fish_table().size())
		SceneManager.change_level("Farm", "SpawnPosition")
		await get_tree().process_frame
		await get_tree().process_frame
		level = SceneManager.get_current_level()
		player = get_tree().get_first_node_in_group("Player")
	# ---- 跨地图村民日程测试（艾米丽中午在小镇） ----
	TimeSystem.set_time(TimeSystem.current_day, 12, 0)
	SceneManager.change_level("Town", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var town_visit := SceneManager.get_current_level() as Town
	var town_emily: NPC = town_visit.get_node_or_null("EmilyTown") as NPC if town_visit else null
	print("SMOKE: town emily midday=", town_emily != null, " visitor=", town_emily.get("visitor_mode") if town_emily else false)
	TimeSystem.set_time(TimeSystem.current_day, 17, 0)
	await get_tree().create_timer(0.3).timeout
	var emily_gone: bool = town_visit == null or town_visit.get_node_or_null("EmilyTown") == null
	print("SMOKE: town emily evening gone=", emily_gone)
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 电梯测试 ----
	Global.mine_floor = 1
	SceneManager.change_level("Mine", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var mine_e := SceneManager.get_current_level() as Mine
	var elevator := mine_e.get_node_or_null("Elevator") as MineElevator
	print("SMOKE: elevator=", elevator != null)
	if elevator:
		elevator._travel_to(15)
		await get_tree().process_frame
		await get_tree().process_frame
		var mine15 := SceneManager.get_current_level() as Mine
		print("SMOKE: elevator floor=", mine15.floor_index if mine15 else -1)
		# ---- 深层矿洞测试（40层） ----
		elevator = SceneManager.get_current_level().get_node_or_null("Elevator") as MineElevator
		if elevator:
			elevator._travel_to(40)
			await get_tree().process_frame
			await get_tree().process_frame
			var mine40 := SceneManager.get_current_level() as Mine
			if mine40:
				var tint: Color = mine40.get_node("Ground").self_modulate
				var spawner_cfg: Array = mine40.get_node("EnemySpawner").enemy_scenes
				var has_giant := false
				for es in spawner_cfg:
					if es != null and es.resource_path.contains("giant_bat"):
						has_giant = true
				var ore_count: int = mine40.get_node("Ores").get_child_count()
				print("SMOKE: deep mine floor=", mine40.floor_index, " tint_r=", snappedf(tint.r, 0.01), " giant=", has_giant, " ores=", ore_count)
			# 宝箱层35（电梯直达）
			elevator = SceneManager.get_current_level().get_node_or_null("Elevator") as MineElevator
			if elevator:
				elevator._travel_to(35)
				await get_tree().process_frame
				await get_tree().process_frame
				var mine35 := SceneManager.get_current_level() as Mine
				var deep_box: Box = null
				if mine35:
					for child in mine35.get_children():
						if child is Box:
							deep_box = child
							break
				print("SMOKE: deep treasure box=", deep_box != null)
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 世纪之花Boss测试 ----
	player.bag_system.add_item(load("res://Bag/items/materials/花束.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	var bulb_recipe: Recipe = load("res://Crafting/recipes/花苞.tres")
	crafting.panel._on_craft_pressed(bulb_recipe)
	var bulb: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "花苞":
			bulb = it
			break
	print("SMOKE: crafted bulb=", bulb != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	player.current_item = bulb
	player.use_summon()
	await get_tree().process_frame
	var plantera := level.get_node_or_null("BossPlantera") as Boss
	print("SMOKE: plantera spawned=", plantera != null)
	if plantera:
		plantera.hurt.take_damage(1500, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: plantera dead=", not is_instance_valid(plantera), " drops=", drops_node.get_child_count())
	# ---- 蜂后Boss测试 ----
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/凝胶.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var hive_recipe: Recipe = load("res://Crafting/recipes/蜂巢.tres")
	crafting.panel._on_craft_pressed(hive_recipe)
	var hive_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "蜂巢":
			hive_item = it
			break
	print("SMOKE: crafted hive=", hive_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if hive_item:
		player.current_item = hive_item
		player.use_summon()
	await get_tree().process_frame
	var queen := level.get_node_or_null("BossQueenBee") as Boss
	print("SMOKE: queen spawned=", queen != null)
	if queen:
		# 加速召唤，验证蜜蜂仆从
		queen.summon_timer = 0.1
		await get_tree().create_timer(0.8).timeout
		var bee_count := 0
		for e in get_tree().get_nodes_in_group("Enemies"):
			if e != null and e.get("enemy_name") == "蜜蜂":
				bee_count += 1
		print("SMOKE: queen bees=", bee_count)
		queen.hurt.take_damage(1400, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: queen dead=", not is_instance_valid(queen), " drops=", drops_node.get_child_count())
	# ---- 双子魔眼Boss测试 ----
	for i in 6:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 4:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var twins_recipe: Recipe = load("res://Crafting/recipes/机械魔眼.tres")
	crafting.panel._on_craft_pressed(twins_recipe)
	var twins_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "机械魔眼":
			twins_item = it
			break
	print("SMOKE: crafted twins eye=", twins_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if twins_item:
		player.current_item = twins_item
		player.use_summon()
	await get_tree().process_frame
	var spaz := level.get_node_or_null("BossTwinsSpaz") as Boss
	var ret := level.get_node_or_null("BossTwinsRet") as Boss
	print("SMOKE: twins spaz=", spaz != null, " ret=", ret != null)
	if spaz and ret:
		# 激光眼发射弹幕
		ret.shoot_timer = 0.1
		await get_tree().create_timer(0.4).timeout
		var bolt_count := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				bolt_count += 1
		print("SMOKE: twins bolt=", bolt_count > 0)
		spaz.hurt.take_damage(1200, player.global_position)
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: spaz dead=", not is_instance_valid(spaz), " ret alive=", is_instance_valid(ret), " ret enraged=", ret.get("enraged") if is_instance_valid(ret) else false)
		if is_instance_valid(ret):
			ret.hurt.take_damage(1000, player.global_position)
			await get_tree().create_timer(1.2).timeout
			print("SMOKE: ret dead=", not is_instance_valid(ret), " drops=", drops_node.get_child_count())
	# ---- 骷髅王Boss测试 ----
	for i in 25:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	var skel_recipe: Recipe = load("res://Crafting/recipes/服装商巫毒娃娃.tres")
	crafting.panel._on_craft_pressed(skel_recipe)
	var skel_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "服装商巫毒娃娃":
			skel_item = it
			break
	print("SMOKE: crafted voodoo=", skel_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if skel_item:
		player.current_item = skel_item
		player.use_summon()
	await get_tree().process_frame
	var skel_boss := level.get_node_or_null("BossSkeletron") as Boss
	print("SMOKE: skeletron=", skel_boss != null)
	if skel_boss:
		var hand_count := 0
		for child in level.get_children():
			if child is SkeletronHand:
				hand_count += 1
		print("SMOKE: skeletron hands=", hand_count)
		skel_boss.hurt.take_damage(1600, player.global_position)
		await get_tree().create_timer(1.2).timeout
		var hands_gone := true
		for child in level.get_children():
			if child is SkeletronHand:
				hands_gone = false
		print("SMOKE: skeletron dead=", not is_instance_valid(skel_boss), " hands_gone=", hands_gone, " drops=", drops_node.get_child_count())
	# ---- 机械蠕虫Boss测试 ----
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var worm_recipe: Recipe = load("res://Crafting/recipes/机械蠕虫.tres")
	crafting.panel._on_craft_pressed(worm_recipe)
	var worm_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "机械蠕虫":
			worm_item = it
			break
	print("SMOKE: crafted worm=", worm_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if worm_item:
		player.current_item = worm_item
		player.use_summon()
	await get_tree().process_frame
	var worm := level.get_node_or_null("DestroyerHead") as Boss
	print("SMOKE: worm=", worm != null)
	if worm:
		var seg_count := 0
		for child in level.get_children():
			if child is DestroyerSegment:
				seg_count += 1
		print("SMOKE: worm segments=", seg_count)
		# 攻击身体 → 伤害转嫁头部
		var seg: DestroyerSegment = null
		for child in level.get_children():
			if child is DestroyerSegment:
				seg = child
				break
		if seg:
			var worm_hp_before: int = worm.hurt.current_health
			seg.hurt.take_damage(100, player.global_position)
			print("SMOKE: worm damage transfer=", worm.hurt.current_health - worm_hp_before)
		worm.hurt.take_damage(1800, player.global_position)
		await get_tree().create_timer(1.2).timeout
		var segs_gone := true
		for child in level.get_children():
			if child is DestroyerSegment:
				segs_gone = false
		print("SMOKE: worm dead=", not is_instance_valid(worm), " segs_gone=", segs_gone, " drops=", drops_node.get_child_count())
	# ---- 栅栏测试 ----
	for i in 4:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	var fence_recipe: Recipe = load("res://Crafting/recipes/木栅栏.tres")
	crafting.panel._on_craft_pressed(fence_recipe)
	var fence_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "木栅栏":
			fence_item = it
			break
	print("SMOKE: fence item=", fence_item != null, " type=", fence_item.type if fence_item else -1)
	var fence_ins: Placeable = (load("res://Placeables/fence.tscn") as PackedScene).instantiate() as Placeable
	var has_sprite: bool = fence_ins.get_node_or_null("Sprite2D") != null
	level.find_child("Crops").add_child(fence_ins)
	fence_ins.global_position = Vector2(500, 500)
	SaveManager._save()
	SaveManager._load()
	await get_tree().process_frame
	await get_tree().process_frame
	var fence_found: bool = false
	for child in level.find_child("Crops").get_children():
		if child is Placeable:
			fence_found = true
			break
	var animal_mask: int = (load("res://Animals/animal.tscn") as PackedScene).instantiate().collision_mask
	print("SMOKE: fence sprite=", has_sprite, " saved=", fence_found, " animal_mask=", animal_mask)
	# ---- 蜂房测试 ----
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 4:
		player.bag_system.add_item(load("res://Bag/items/materials/煤矿.tres").duplicate())
	var bee_recipe: Recipe = load("res://Crafting/recipes/蜂房.tres")
	crafting.panel._on_craft_pressed(bee_recipe)
	var bee_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "蜂房":
			bee_item = it
			break
	print("SMOKE: beehive item=", bee_item != null)
	var bee_ins: Placeable = (load("res://Placeables/bee_house.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(bee_ins)
	bee_ins.global_position = Vector2(540, 540)
	var day_now: int = TimeSystem.current_day
	var drops_before: int = drops_node.get_child_count()
	TimeSystem.set_time(day_now + 4, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var honey_dropped := false
	for d in drops_node.get_children():
		if d.get("item") != null and d.get("item").name == "蜂蜜":
			honey_dropped = true
	print("SMOKE: beehive honey=", honey_dropped, " drops_delta=", drops_node.get_child_count() - drops_before)
	# ---- 稻草人测试 ----
	var bag_count: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_count += 1
	print("SMOKE: bag used=", bag_count, " of ", player.bag_system.items.size())
	# 清理背包中的材料/消耗品，为后续合成腾出槽位（后续测试会重新添加）
	for i in player.bag_system.items.size():
		var bag_it: Item = player.bag_system.items[i]
		if bag_it != null and (bag_it.type == Item.ItemType.Materials or bag_it.type == Item.ItemType.Consume):
			player.bag_system.items[i] = null
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/纤维.tres").duplicate())
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	var sc_recipe: Recipe = load("res://Crafting/recipes/稻草人.tres")
	crafting.panel._on_craft_pressed(sc_recipe)
	var sc_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "稻草人":
			sc_item = it
			break
	print("SMOKE: scarecrow item=", sc_item != null, " type=", sc_item.type if sc_item else -1)
	var sc_ins: Placeable = (load("res://Placeables/scarecrow.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(sc_ins)
	sc_ins.global_position = Vector2(600, 600)
	var cc3 := level.get_node("CropsComponent") as CropsComponent
	# 造两株作物：一株在稻草人范围内(100px)，一株在范围外(300px)
	var crop_near: Crop = (load("res://Placeables/Crops/crop.tscn") as PackedScene).instantiate() as Crop
	crop_near.crop_data = load("res://Bag/items/crops/甜瓜_data.tres")
	level.find_child("Crops").add_child(crop_near)
	crop_near.global_position = Vector2(600, 620)
	var crop_far: Crop = (load("res://Placeables/Crops/crop.tscn") as PackedScene).instantiate() as Crop
	crop_far.crop_data = load("res://Bag/items/crops/甜瓜_data.tres")
	level.find_child("Crops").add_child(crop_far)
	crop_far.global_position = Vector2(900, 900)
	var protected_near: bool = cc3._is_protected(crop_near)
	var protected_far: bool = cc3._is_protected(crop_far)
	print("SMOKE: scarecrow protected_near=", protected_near, " protected_far=", protected_far)
	# ---- 铁骷髅王Boss测试 ----
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 6:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 25:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var prime_recipe: Recipe = load("res://Crafting/recipes/机械骷髅头.tres")
	crafting.panel._on_craft_pressed(prime_recipe)
	var prime_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "机械骷髅头":
			prime_item = it
			break
	print("SMOKE: crafted prime skull=", prime_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if prime_item:
		player.current_item = prime_item
		player.use_summon()
	await get_tree().process_frame
	var prime := level.get_node_or_null("BossPrime") as Boss
	print("SMOKE: prime=", prime != null)
	if prime:
		var arm_count := 0
		for child in level.get_children():
			if child is PrimeArm:
				arm_count += 1
		print("SMOKE: prime arms=", arm_count)
		# 手臂发射激光弹幕
		for child in level.get_children():
			if child is PrimeArm:
				child.shoot_timer = 0.1
		await get_tree().create_timer(0.4).timeout
		var prime_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				prime_bolt += 1
		print("SMOKE: prime bolt=", prime_bolt > 0)
		prime.hurt.take_damage(1900, player.global_position)
		await get_tree().create_timer(1.2).timeout
		var arms_gone := true
		for child in level.get_children():
			if child is PrimeArm:
				arms_gone = false
		print("SMOKE: prime dead=", not is_instance_valid(prime), " arms_gone=", arms_gone, " drops=", drops_node.get_child_count())
	# ---- 月亮领主Boss测试 ----
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/绿宝石.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/黄玉.tres").duplicate())
	var ml_recipe: Recipe = load("res://Crafting/recipes/天界符.tres")
	crafting.panel._on_craft_pressed(ml_recipe)
	var ml_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "天界符":
			ml_item = it
			break
	print("SMOKE: crafted sigil=", ml_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if ml_item:
		player.current_item = ml_item
		player.use_summon()
	await get_tree().process_frame
	var moon_lord := level.get_node_or_null("BossMoonLord") as Boss
	print("SMOKE: moon lord=", moon_lord != null)
	if moon_lord:
		moon_lord.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var ml_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				ml_bolt += 1
		print("SMOKE: moon lord volley=", ml_bolt)
		moon_lord.hurt.take_damage(3000, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: moon lord dead=", not is_instance_valid(moon_lord), " drops=", drops_node.get_child_count())
	# ---- 新作物测试（宝石甜莓/上古水果） ----
	var sweet_seed: Item = load("res://Bag/items/seeds/宝石甜莓种子.tres")
	var ancient_seed: Item = load("res://Bag/items/seeds/上古水果种子.tres")
	var sweet_data: CropData = sweet_seed.crop_data
	var ancient_data: CropData = ancient_seed.crop_data
	print("SMOKE: sweet data=", sweet_data != null, " days=", sweet_data.growth_days if sweet_data else -1, " price=", sweet_seed.price)
	print("SMOKE: ancient data=", ancient_data != null, " days=", ancient_data.growth_days if ancient_data else -1, " regrow=", ancient_data.regrow_days if ancient_data else -1, " seasons=", ancient_data.allowed_seasons if ancient_data else [])
	# 商店含新种子
	var store_panel_scene: PackedScene = load("res://Map/Store/store_panel.tscn")
	var sp_ins: Node = store_panel_scene.instantiate()
	var sp_items: Array = sp_ins.get("inventorys")
	var store_has_sweet := false
	var store_has_ancient := false
	for it in sp_items:
		if it != null and it.name == "宝石甜莓种子":
			store_has_sweet = true
		if it != null and it.name == "上古水果种子":
			store_has_ancient = true
	sp_ins.queue_free()
	print("SMOKE: store sweet=", store_has_sweet, " ancient=", store_has_ancient)
	# 种植验证：春天种上古水果不枯萎（全年可种）
	var ancient_crop: Crop = (load("res://Placeables/Crops/crop.tscn") as PackedScene).instantiate() as Crop
	ancient_crop.crop_data = ancient_data
	ancient_crop.cell = Vector2i(60, 40)
	ancient_crop.planted_day = TimeSystem.current_day
	level.find_child("Crops").add_child(ancient_crop)
	await get_tree().process_frame
	print("SMOKE: ancient crop withering=", ancient_crop.withering, " stage=", ancient_crop.growth_stage)
	# ---- 温泉测试 ----
	SceneManager.change_level("Bathhouse", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var bath := SceneManager.get_current_level() as Bathhouse
	print("SMOKE: bathhouse=", bath != null)
	if bath:
		var bath_ground: int = bath.get_node("Ground").get_used_cells().size()
		var bath_pool: int = bath.get_node("Pool").get_used_cells().size()
		print("SMOKE: bath ground=", bath_ground, " pool=", bath_pool)
		player = get_tree().get_first_node_in_group("Player")
		player.try_use_stamina(50)
		var stam_before: int = player.stamina
		player.global_position = Vector2(240, 192)
		await get_tree().create_timer(1.5).timeout
		print("SMOKE: bath regen=", player.stamina - stam_before)
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 新鱼测试 ----
	var sunfish: FishData = load("res://Fishing/fish_data/太阳鱼_data.tres")
	var bream: FishData = load("res://Fishing/fish_data/鲷鱼_data.tres")
	var squid: FishData = load("res://Fishing/fish_data/鱿鱼_data.tres")
	print("SMOKE: sunfish=", sunfish != null, " seas=", sunfish.seasons if sunfish else [], " diff=", sunfish.difficulty if sunfish else -1)
	print("SMOKE: bream seas=", bream.seasons if bream else [], " squid seas=", squid.seasons if squid else [])
	var fishing6 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	print("SMOKE: fish table=", fishing6.FISH_TABLE.size(), " ocean=", fishing6.OCEAN_FISH.size())
	# ---- 新NPC测试（向导/温泉老板） ----
	SceneManager.change_level("Town", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var town_npc := SceneManager.get_current_level() as Town
	var guide_npc := town_npc.get_node_or_null("Guide") as NPC
	print("SMOKE: guide=", guide_npc != null, " name=", guide_npc.npc_display_name if guide_npc else "?")
	if guide_npc:
		player = get_tree().get_first_node_in_group("Player")
		var g_hearts: float = FriendshipSystem.get_hearts("向导")
		player.current_item = load("res://Bag/items/forage/蘑菇.tres").duplicate()
		guide_npc._give_gift(player)
		print("SMOKE: guide hearts=", g_hearts, "->", FriendshipSystem.get_hearts("向导"))
	SceneManager.change_level("Bathhouse", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var bath_npc := SceneManager.get_current_level() as Bathhouse
	var merchant_npc := bath_npc.get_node_or_null("BathMerchant") as NPC
	print("SMOKE: bath merchant=", merchant_npc != null, " name=", merchant_npc.npc_display_name if merchant_npc else "?")
	SceneManager.change_level("Farm", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	level = SceneManager.get_current_level()
	player = get_tree().get_first_node_in_group("Player")
	# ---- 新食谱测试（烤太阳鱼/烤鱿鱼/蜜汁烤鱼） ----
	player.bag_system.add_item(load("res://Bag/items/fish/太阳鱼.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	var roastsun_recipe: Recipe = load("res://Crafting/recipes/烤太阳鱼.tres")
	crafting.panel._on_craft_pressed(roastsun_recipe)
	player.bag_system.add_item(load("res://Bag/items/fish/鱿鱼.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	var roastsquid_recipe: Recipe = load("res://Crafting/recipes/烤鱿鱼.tres")
	crafting.panel._on_craft_pressed(roastsquid_recipe)
	player.bag_system.add_item(load("res://Bag/items/food/蜂蜜.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/food/烤鱼.tres").duplicate())
	var honeyfish_recipe: Recipe = load("res://Crafting/recipes/蜜汁烤鱼.tres")
	crafting.panel._on_craft_pressed(honeyfish_recipe)
	var found_roast_sun := false
	var found_roast_squid := false
	var found_honey_fish := false
	for it in player.bag_system.items:
		if it != null:
			match it.name:
				"烤太阳鱼": found_roast_sun = true
				"烤鱿鱼": found_roast_squid = true
				"蜜汁烤鱼": found_honey_fish = true
	print("SMOKE: roast sun=", found_roast_sun, " squid=", found_roast_squid, " honey fish=", found_honey_fish)
	# ---- 成就测试（温泉常客/深海猎人） ----
	AchievementSystem.unlock("bath_regular")
	CollectionSystem.record_fish("鱿鱼")
	AchievementSystem.check()
	print("SMOKE: ach bath=", AchievementSystem.is_unlocked("bath_regular"), " deep=", AchievementSystem.is_unlocked("deep_fisher"))
	# ---- 新敌人测试（蚁狮/螃蟹） ----
	var antlion_scene: PackedScene = load("res://Combat/antlion.tscn")
	var antlion_ins: Enemy = antlion_scene.instantiate() as Enemy
	level.add_child(antlion_ins)
	antlion_ins.global_position = player.global_position + Vector2(100, 0)
	print("SMOKE: antlion=", antlion_ins.enemy_name, " hp=", antlion_ins.max_health, " vf=", antlion_ins.sprite_vframes)
	antlion_ins.hurt.take_damage(40, player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE: antlion dead=", not is_instance_valid(antlion_ins))
	var crab_scene: PackedScene = load("res://Combat/crab.tscn")
	var crab_ins: Enemy = crab_scene.instantiate() as Enemy
	level.add_child(crab_ins)
	crab_ins.global_position = player.global_position + Vector2(120, 0)
	print("SMOKE: crab=", crab_ins.enemy_name, " hp=", crab_ins.max_health, " vf=", crab_ins.sprite_vframes)
	crab_ins.hurt.take_damage(30, player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE: crab dead=", not is_instance_valid(crab_ins))
	# 沙漠刷怪池含蚁狮、海滩刷怪器存在
	var desert_cfg: Array = (load("res://Map/Desert/desert.tscn") as PackedScene).instantiate().get_node("EnemySpawner").enemy_scenes
	var desert_has_antlion := false
	for es in desert_cfg:
		if es != null and es.resource_path.contains("antlion"):
			desert_has_antlion = true
	var beach_spawner: Node = (load("res://Map/Beach/beach.tscn") as PackedScene).instantiate().get_node_or_null("EnemySpawner")
	print("SMOKE: desert antlion=", desert_has_antlion, " beach spawner=", beach_spawner != null)
	# ---- 毕业武器测试（永夜刃/圣剑） ----
	player.bag_system.add_item(load("res://Bag/items/weapon/暗影焰刀.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/weapon/鬼妖村正.tres").duplicate())
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 25:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var night_edge_recipe: Recipe = load("res://Crafting/recipes/永夜刃.tres")
	crafting.panel._on_craft_pressed(night_edge_recipe)
	player.bag_system.add_item(load("res://Bag/items/weapon/金剑.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	var excalibur_recipe: Recipe = load("res://Crafting/recipes/圣剑.tres")
	crafting.panel._on_craft_pressed(excalibur_recipe)
	var found_edge: Item = null
	var found_excalibur: Item = null
	for it in player.bag_system.items:
		if it != null:
			if it.name == "永夜刃":
				found_edge = it
			if it.name == "圣剑":
				found_excalibur = it
	print("SMOKE: night edge=", found_edge != null, " dmg=", found_edge.damage if found_edge else -1, " excalibur=", found_excalibur != null, " crit=", found_excalibur.crit if found_excalibur else -1)
	# ---- 箭矢弹药测试 ----
	var bag_used2: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_used2 += 1
	print("SMOKE: bag used2=", bag_used2, " of ", player.bag_system.items.size())
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/stone.tres").duplicate())
	var arrow_recipe: Recipe = load("res://Crafting/recipes/木箭.tres")
	crafting.panel._on_craft_pressed(arrow_recipe)
	var arrow_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "木箭":
			arrow_item = it
			break
	print("SMOKE: arrows crafted=", arrow_item != null, " qty=", arrow_item.quantity if arrow_item else -1)
	player.current_item = load("res://Bag/items/weapon/木弓.tres").duplicate()
	if arrow_item:
		var qty_before: int = arrow_item.quantity
		player.shoot_projectile()
		await get_tree().process_frame
		var qty_after: int = 0
		for it in player.bag_system.items:
			if it != null and it.name == "木箭":
				qty_after = it.quantity
		print("SMOKE: arrow consumed=", qty_before - qty_after)
	# 无箭时射击不发射
	for i in player.bag_system.items.size():
		var it2: Item = player.bag_system.items[i]
		if it2 != null and it2.name == "木箭":
			player.bag_system.items[i] = null
	var proj_before: int = 0
	for n in get_tree().root.get_children():
		if n is Projectile:
			proj_before += 1
	player.shoot_projectile()
	await get_tree().process_frame
	var proj_after: int = 0
	for n in get_tree().root.get_children():
		if n is Projectile:
			proj_after += 1
	print("SMOKE: no ammo blocks=", proj_after == proj_before)
	# ---- 丛林地图测试 ----
	SceneManager.change_level("Jungle", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var jungle2 := SceneManager.get_current_level() as Jungle
	print("SMOKE: jungle=", jungle2 != null)
	if jungle2:
		var jg: int = jungle2.get_node("Ground").get_used_cells().size()
		var jw: int = jungle2.get_node("Water").get_used_cells().size()
		var jt: int = jungle2.get_node("Trees").get_child_count()
		var jf: int = jungle2.get_node("Forage").get_child_count()
		var jspawner: Array = jungle2.get_node("EnemySpawner").enemy_scenes
		var has_jslime := false
		for es in jspawner:
			if es != null and es.resource_path.contains("jungle_slime"):
				has_jslime = true
		var fishing7 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
		print("SMOKE: jungle ground=", jg, " water=", jw, " trees=", jt, " forage=", jf, " jslime=", has_jslime, " fish=", fishing7._current_fish_table().size())
		SceneManager.change_level("Farm", "SpawnPosition")
		await get_tree().process_frame
		await get_tree().process_frame
		level = SceneManager.get_current_level()
		player = get_tree().get_first_node_in_group("Player")
	# ---- 鱼竿升级测试 ----
	player.bag_system.add_item(load("res://Bag/items/tools/鱼竿.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	var iron_rod_recipe: Recipe = load("res://Crafting/recipes/铁鱼竿.tres")
	crafting.panel._on_craft_pressed(iron_rod_recipe)
	player.bag_system.add_item(load("res://Bag/items/tools/铁鱼竿.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var gold_rod_recipe: Recipe = load("res://Crafting/recipes/金鱼竿.tres")
	crafting.panel._on_craft_pressed(gold_rod_recipe)
	var iron_rod: Item = null
	var gold_rod: Item = null
	for it in player.bag_system.items:
		if it != null:
			if it.name == "铁鱼竿":
				iron_rod = it
			if it.name == "金鱼竿":
				gold_rod = it
	print("SMOKE: iron rod=", iron_rod != null, " gold rod=", gold_rod != null, " type=", gold_rod.type if gold_rod else -1)
	# 难度修正：章鱼难度0.8 → 铁鱼竿0.68 / 金鱼竿0.56
	var fish_ui_scene: PackedScene = load("res://Fishing/fishing_ui.tscn")
	var fish_ui_ins: Control = fish_ui_scene.instantiate()
	fish_ui_ins.set("fish", load("res://Fishing/fish_data/章鱼_data.tres"))
	level.add_child(fish_ui_ins)
	player.current_item = iron_rod
	print("SMOKE: rod iron diff=", snappedf(fish_ui_ins._effective_difficulty(), 0.01))
	player.current_item = gold_rod
	print("SMOKE: rod gold diff=", snappedf(fish_ui_ins._effective_difficulty(), 0.01))
	fish_ui_ins.queue_free()
	# ---- 季节采集测试 ----
	TimeSystem.set_time(43, 6, 0) # 夏15天
	await get_tree().process_frame
	var farm2 := level as Farm
	farm2._spawn_forage()
	var forage_pool_ok := true
	for child in farm2.get_node("Forage").get_children():
		var fname: String = child.get("item").name if child.get("item") != null else ""
		if fname != "树莓" and fname != "蘑菇":
			forage_pool_ok = false
	print("SMOKE: summer forage=", forage_pool_ok, " count=", farm2.get_node("Forage").get_child_count())
	# ---- 猪鲨Boss测试 ----
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/fish/鲤鱼.tres").duplicate())
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/fish/章鱼.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var fishron_recipe: Recipe = load("res://Crafting/recipes/虾松露.tres")
	crafting.panel._on_craft_pressed(fishron_recipe)
	var fishron_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "虾松露":
			fishron_item = it
			break
	print("SMOKE: crafted truffle=", fishron_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if fishron_item:
		player.current_item = fishron_item
		player.use_summon()
	await get_tree().process_frame
	var fishron := level.get_node_or_null("BossFishron") as Boss
	print("SMOKE: fishron=", fishron != null)
	if fishron:
		fishron.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var fishron_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				fishron_bolt += 1
		print("SMOKE: fishron bolt=", fishron_bolt > 0)
		fishron.hurt.take_damage(2200, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: fishron dead=", not is_instance_valid(fishron), " drops=", drops_node.get_child_count())
	# ---- 雷暴音效测试 ----
	WeatherSystem.weather = "storm"
	WeatherSystem.thunder_timer = 0.1
	await get_tree().create_timer(0.3).timeout
	var sfx_busy: bool = false
	for sp in AudioManager.sfx_players:
		if sp != null and sp.stream != null:
			sfx_busy = true
	print("SMOKE: thunder sfx=", sfx_busy, " timer=", WeatherSystem.thunder_timer > 0.0)
	WeatherSystem.weather = "sunny"
	# ---- 酿酒测试 ----
	for i in 30:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	var keg_recipe: Recipe = load("res://Crafting/recipes/酿酒桶.tres")
	crafting.panel._on_craft_pressed(keg_recipe)
	var keg_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "酿酒桶":
			keg_item = it
			break
	print("SMOKE: keg item=", keg_item != null)
	var keg_ins: Placeable = (load("res://Placeables/keg.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(keg_ins)
	keg_ins.global_position = Vector2(640, 640)
	# 放入水果（南瓜）
	player.current_item = load("res://Bag/items/crops/南瓜.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	var inserted: bool = (keg_ins as Keg).try_insert(player)
	var brewing: bool = (keg_ins as Keg).is_brewing
	print("SMOKE: keg insert=", inserted, " brewing=", brewing)
	# 7天后产酒
	var keg_day: int = TimeSystem.current_day
	TimeSystem.set_time(keg_day + 7, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var wine_dropped := false
	for d in drops_node.get_children():
		if d.get("item") != null and d.get("item").name == "果酒":
			wine_dropped = true
	print("SMOKE: keg wine=", wine_dropped, " brewing_after=", (keg_ins as Keg).is_brewing)
	# ---- 罐头瓶测试 ----
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/stone.tres").duplicate())
	var jar_recipe: Recipe = load("res://Crafting/recipes/罐头瓶.tres")
	crafting.panel._on_craft_pressed(jar_recipe)
	var jar_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "罐头瓶":
			jar_item = it
			break
	print("SMOKE: jar item=", jar_item != null)
	var jar_ins: Placeable = (load("res://Placeables/preserves_jar.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(jar_ins)
	jar_ins.global_position = Vector2(680, 680)
	player.current_item = load("res://Bag/items/crops/玉米.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	var jar_inserted: bool = (jar_ins as PreservesJar).try_insert(player)
	var jar_day: int = TimeSystem.current_day
	TimeSystem.set_time(jar_day + 3, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var canned_dropped := false
	for d in drops_node.get_children():
		if d.get("item") != null and d.get("item").name == "罐头":
			canned_dropped = true
	print("SMOKE: jar insert=", jar_inserted, " canned=", canned_dropped)
	# ---- 双足飞龙Boss测试 ----
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/煤矿.tres").duplicate())
	var feather_recipe: Recipe = load("res://Crafting/recipes/神龙之羽.tres")
	crafting.panel._on_craft_pressed(feather_recipe)
	var feather_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "神龙之羽":
			feather_item = it
			break
	print("SMOKE: crafted feather=", feather_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if feather_item:
		player.current_item = feather_item
		player.use_summon()
	await get_tree().process_frame
	var wyvern := level.get_node_or_null("BossWyvern") as Boss
	print("SMOKE: wyvern=", wyvern != null)
	if wyvern:
		var seg_count := 0
		for child in level.get_children():
			if child is WyvernSegment:
				seg_count += 1
		print("SMOKE: wyvern segments=", seg_count)
		wyvern.hurt.take_damage(1600, player.global_position)
		await get_tree().create_timer(1.2).timeout
		var segs_gone := true
		for child in level.get_children():
			if child is WyvernSegment:
				segs_gone = false
		print("SMOKE: wyvern dead=", not is_instance_valid(wyvern), " segs_gone=", segs_gone, " drops=", drops_node.get_child_count())
	# ---- 饰品系统测试 ----
	# 清理背包材料/消耗品腾槽位（后续测试会重新添加）
	for i in player.bag_system.items.size():
		var bag_it3: Item = player.bag_system.items[i]
		if bag_it3 != null and (bag_it3.type == Item.ItemType.Materials or bag_it3.type == Item.ItemType.Consume):
			player.bag_system.items[i] = null
	var bag_used3: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_used3 += 1
	print("SMOKE: bag used3=", bag_used3, " of ", player.bag_system.items.size())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/animal/羊毛.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/煤矿.tres").duplicate())
	var boot_recipe: Recipe = load("res://Crafting/recipes/赫尔墨斯之靴.tres")
	crafting.panel._on_craft_pressed(boot_recipe)
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 2:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var band_recipe: Recipe = load("res://Crafting/recipes/再生手环.tres")
	crafting.panel._on_craft_pressed(band_recipe)
	for i in 6:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/凝胶.tres").duplicate())
	var flower_recipe: Recipe = load("res://Crafting/recipes/魔力花.tres")
	crafting.panel._on_craft_pressed(flower_recipe)
	var found_boots: Item = null
	var found_band: Item = null
	var found_flower: Item = null
	for it in player.bag_system.items:
		if it != null:
			match it.name:
				"赫尔墨斯之靴": found_boots = it
				"再生手环": found_band = it
				"魔力花": found_flower = it
	print("SMOKE: boots=", found_boots != null, " band=", found_band != null, " flower=", found_flower != null, " type=", found_boots.type if found_boots else -1)
	# 再生手环：掉血后触发一次恢复（同步验证）
	player.current_item = found_band
	player.take_damage(30)
	var hp_low: int = player.health
	player.accessory_timer = 1.9
	player._apply_accessory(0.2)
	print("SMOKE: band regen=", player.health - hp_low)
	# 魔力花：耗魔后触发一次回魔（同步验证）
	player.current_item = found_flower
	player.try_use_mana(20)
	var mana_low: int = player.mana
	player.accessory_timer = 1.9
	player._apply_accessory(0.2)
	print("SMOKE: flower mana=", player.mana - mana_low)
	# 靴子：速度倍率（同步刷新）
	player.current_item = found_boots
	player._apply_accessory(0.0)
	print("SMOKE: boots multiplier=", player.move_speed_multiplier)
	player.current_item = null
	# ---- 云朵瓶/钴蓝盾测试 ----
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/树液.tres").duplicate())
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/animal/羊毛.tres").duplicate())
	var cloud_recipe: Recipe = load("res://Crafting/recipes/云朵瓶.tres")
	crafting.panel._on_craft_pressed(cloud_recipe)
	for i in 12:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	for i in 6:
		player.bag_system.add_item(load("res://Bag/items/materials/银锭.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/stone.tres").duplicate())
	var shield_recipe: Recipe = load("res://Crafting/recipes/钴蓝盾.tres")
	crafting.panel._on_craft_pressed(shield_recipe)
	var found_cloud: Item = null
	var found_shield: Item = null
	for it in player.bag_system.items:
		if it != null:
			if it.name == "云朵瓶":
				found_cloud = it
			if it.name == "钴蓝盾":
				found_shield = it
	print("SMOKE: cloud=", found_cloud != null, " shield=", found_shield != null)
	# 云朵瓶：体力消耗20%折扣
	player.current_item = found_cloud
	player.stamina = 100
	player.try_use_stamina(20)
	print("SMOKE: cloud stamina cost=", 100 - player.stamina)
	# 钴蓝盾：击退减半
	player.current_item = found_shield
	player.velocity = Vector2.ZERO
	player.knockback_player(Vector2.RIGHT)
	print("SMOKE: shield knockback=", player.velocity.x)
	player.current_item = null
	# ---- 地牢守卫Boss测试 ----
	var bag_used4: int = 0
	for it in player.bag_system.items:
		if it != null:
			bag_used4 += 1
	print("SMOKE: bag used4=", bag_used4, " of ", player.bag_system.items.size())
	player.bag_system.add_item(load("res://Bag/items/materials/可疑眼球.tres").duplicate())
	for i in 30:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	var guardian_recipe: Recipe = load("res://Crafting/recipes/地牢咒书.tres")
	crafting.panel._on_craft_pressed(guardian_recipe)
	var guardian_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "地牢咒书":
			guardian_item = it
			break
	print("SMOKE: crafted guardian book=", guardian_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if guardian_item:
		player.current_item = guardian_item
		player.use_summon()
	await get_tree().process_frame
	var guardian := level.get_node_or_null("BossGuardian") as Boss
	print("SMOKE: guardian=", guardian != null, " hp=", guardian.max_health if guardian else -1, " dmg=", guardian.contact_damage if guardian else -1)
	if guardian:
		guardian.hurt.take_damage(9999, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: guardian dead=", not is_instance_valid(guardian), " drops=", drops_node.get_child_count())
	# ---- 魔法书武器测试 ----
	# 彻底清空背包腾槽位（后续Boss测试会重新添加所需材料）
	for i in player.bag_system.items.size():
		player.bag_system.items[i] = null
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/铁锭.tres").duplicate())
	var water_book_recipe: Recipe = load("res://Crafting/recipes/水刃书.tres")
	var cnt_wood := 0
	var cnt_sap := 0
	var cnt_iron := 0
	for it in player.bag_system.items:
		if it != null:
			if it.name == "wood":
				cnt_wood += it.quantity
			if it.name == "蓝宝石":
				cnt_sap += it.quantity
			if it.name == "铁锭":
				cnt_iron += it.quantity
	print("SMOKE: mats wood=", cnt_wood, " sapphire=", cnt_sap, " iron=", cnt_iron)
	crafting.panel._on_craft_pressed(water_book_recipe)
	player.bag_system.add_item(load("res://Bag/items/weapon/紫水晶法杖.tres").duplicate())
	for i in 25:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/蛛网.tres").duplicate())
	var demon_book_recipe: Recipe = load("res://Crafting/recipes/恶魔之书.tres")
	crafting.panel._on_craft_pressed(demon_book_recipe)
	var water_book: Item = null
	var demon_book: Item = null
	for it in player.bag_system.items:
		if it != null:
			if it.name == "水刃书":
				water_book = it
			if it.name == "恶魔之书":
				demon_book = it
	print("SMOKE: water book=", water_book != null, " dmg=", water_book.damage if water_book else -1, " mana=", water_book.mana_cost if water_book else -1)
	print("SMOKE: demon book=", demon_book != null, " dmg=", demon_book.damage if demon_book else -1)
	# 射击消耗魔力
	player.current_item = demon_book
	var mana_before: int = player.mana
	player.shoot_projectile()
	await get_tree().process_frame
	print("SMOKE: demon mana cost=", mana_before - player.mana)
	# ---- 雪山地图测试 ----
	SceneManager.change_level("Tundra", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var tundra := SceneManager.get_current_level() as Tundra
	print("SMOKE: tundra=", tundra != null)
	if tundra:
		var tg: int = tundra.get_node("Ground").get_used_cells().size()
		var tw: int = tundra.get_node("Water").get_used_cells().size()
		var td: int = tundra.get_node("Decor").get_used_cells().size()
		var tt: int = tundra.get_node("Trees").get_child_count()
		var tint: Color = tundra.get_node("CanvasModulate").color
		var tspawner: Array = tundra.get_node("EnemySpawner").enemy_scenes
		var has_zombie := false
		for es in tspawner:
			if es != null and es.resource_path.contains("zombie"):
				has_zombie = true
		print("SMOKE: tundra ground=", tg, " water=", tw, " decor=", td, " trees=", tt, " tint=", snappedf(tint.r, 0.01), " zombie=", has_zombie)
		SceneManager.change_level("Farm", "SpawnPosition")
		await get_tree().process_frame
		await get_tree().process_frame
		level = SceneManager.get_current_level()
		player = get_tree().get_first_node_in_group("Player")
	# ---- 雪原僵尸测试 ----
	var eskimo_scene: PackedScene = load("res://Combat/zombie_eskimo.tscn")
	var eskimo_ins: Enemy = eskimo_scene.instantiate() as Enemy
	level.add_child(eskimo_ins)
	eskimo_ins.global_position = player.global_position + Vector2(100, 0)
	print("SMOKE: eskimo=", eskimo_ins.enemy_name, " hp=", eskimo_ins.max_health, " vf=", eskimo_ins.sprite_vframes)
	eskimo_ins.hurt.take_damage(35, player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE: eskimo dead=", not is_instance_valid(eskimo_ins))
	# 极地猎人成就：击杀5只
	for i in 4:
		CollectionSystem.record_kill("爱斯基摩僵尸")
	AchievementSystem.check()
	print("SMOKE: polar ach=", AchievementSystem.is_unlocked("polar_hunter"))
	var tundra_cfg: Array = (load("res://Map/Tundra/tundra.tscn") as PackedScene).instantiate().get_node("EnemySpawner").enemy_scenes
	var has_eskimo := false
	for es in tundra_cfg:
		if es != null and es.resource_path.contains("eskimo"):
			has_eskimo = true
	print("SMOKE: tundra eskimo=", has_eskimo)
	# ---- 果酒品类测试 ----
	var keg2: Placeable = (load("res://Placeables/keg.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(keg2)
	keg2.global_position = Vector2(700, 700)
	player.current_item = load("res://Bag/items/crops/蓝莓.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	(keg2 as Keg).try_insert(player)
	var keg2_day: int = TimeSystem.current_day
	TimeSystem.set_time(keg2_day + 7, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var blue_wine := false
	for d in drops_node.get_children():
		if d.get("item") != null and d.get("item").name == "蓝莓酒":
			blue_wine = true
	print("SMOKE: blueberry wine=", blue_wine)
	# ---- 罐头品类测试 ----
	var jar2: Placeable = (load("res://Placeables/preserves_jar.tscn") as PackedScene).instantiate() as Placeable
	level.find_child("Crops").add_child(jar2)
	jar2.global_position = Vector2(720, 720)
	player.current_item = load("res://Bag/items/crops/南瓜.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	(jar2 as PreservesJar).try_insert(player)
	var jar2_day: int = TimeSystem.current_day
	TimeSystem.set_time(jar2_day + 3, 6, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var pumpkin_canned := false
	for d in drops_node.get_children():
		if d.get("item") != null and d.get("item").name == "南瓜罐头":
			pumpkin_canned = true
	print("SMOKE: pumpkin canned=", pumpkin_canned)
	# ---- 南瓜王Boss测试 ----
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/crops/南瓜.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var pumpking_recipe: Recipe = load("res://Crafting/recipes/万圣南瓜灯.tres")
	crafting.panel._on_craft_pressed(pumpking_recipe)
	var pumpking_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "万圣南瓜灯":
			pumpking_item = it
			break
	print("SMOKE: crafted lantern=", pumpking_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if pumpking_item:
		player.current_item = pumpking_item
		player.use_summon()
	await get_tree().process_frame
	var pumpking := level.get_node_or_null("BossPumpking") as Boss
	print("SMOKE: pumpking=", pumpking != null)
	if pumpking:
		pumpking.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var pk_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				pk_bolt += 1
		print("SMOKE: pumpking bolt=", pk_bolt > 0)
		pumpking.hurt.take_damage(2400, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: pumpking dead=", not is_instance_valid(pumpking), " drops=", drops_node.get_child_count())
	# ---- 冰雪女王Boss测试 ----
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/fish/冰鱼.tres").duplicate())
	for i in 8:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 12:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	var ice_recipe: Recipe = load("res://Crafting/recipes/冰霜核心.tres")
	crafting.panel._on_craft_pressed(ice_recipe)
	var ice_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "冰霜核心":
			ice_item = it
			break
	print("SMOKE: crafted ice core=", ice_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if ice_item:
		player.current_item = ice_item
		player.use_summon()
	await get_tree().process_frame
	var ice_queen := level.get_node_or_null("BossIceQueen") as Boss
	print("SMOKE: ice queen=", ice_queen != null)
	if ice_queen:
		ice_queen.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var iq_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				iq_bolt += 1
		print("SMOKE: ice queen bolt=", iq_bolt > 0)
		ice_queen.hurt.take_damage(2600, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: ice queen dead=", not is_instance_valid(ice_queen), " drops=", drops_node.get_child_count())
	# ---- 圣诞坦克Boss测试 ----
	for i in 12:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/煤矿.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/animal/羊毛.tres").duplicate())
	var santa_recipe: Recipe = load("res://Crafting/recipes/圣诞挂饰.tres")
	crafting.panel._on_craft_pressed(santa_recipe)
	var santa_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "圣诞挂饰":
			santa_item = it
			break
	print("SMOKE: crafted ornament=", santa_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if santa_item:
		player.current_item = santa_item
		player.use_summon()
	await get_tree().process_frame
	var santa := level.get_node_or_null("BossSantaNK") as Boss
	print("SMOKE: santa tank=", santa != null)
	if santa:
		santa.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var santa_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				santa_bolt += 1
		print("SMOKE: santa volley=", santa_bolt > 0)
		santa.hurt.take_damage(2800, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: santa dead=", not is_instance_valid(santa), " drops=", drops_node.get_child_count())
	# ---- 新成就测试（钓鱼大师/收藏大师/屠Boss猎手） ----
	CollectionSystem.record_fish("太阳鱼")
	CollectionSystem.record_fish("鲷鱼")
	CollectionSystem.record_fish("鲶鱼")
	for i in 40:
		CollectionSystem.record_item("测试物品%d" % i)
	AchievementSystem.check()
	print("SMOKE: ach fish6=", AchievementSystem.is_unlocked("fish_6"), " collect40=", AchievementSystem.is_unlocked("collect_40"), " boss5=", AchievementSystem.is_unlocked("boss_5"))
	# ---- 技能系统测试 ----
	Global.add_skill_xp("fishing", 10)
	Global.add_skill_xp("fishing", 6)
	Global.add_skill_xp("mining", 10)
	print("SMOKE: skills fishing=", Global.skills["fishing"], " mining=", Global.skills["mining"])
	print("SMOKE: fishing mult=", Global.fishing_skill_multiplier(), " mining double=", Global.mining_double_chance())
	# 钓鱼难度修正（章鱼0.8 → 1级钓鱼 ×0.98）
	player.current_item = gold_rod
	var fish_ui_ins2: Control = (load("res://Fishing/fishing_ui.tscn") as PackedScene).instantiate()
	fish_ui_ins2.set("fish", load("res://Fishing/fish_data/章鱼_data.tres"))
	level.add_child(fish_ui_ins2)
	print("SMOKE: skill rod diff=", snappedf(fish_ui_ins2._effective_difficulty(), 0.02))
	fish_ui_ins2.queue_free()
	# 存档往返
	SaveManager._save()
	SaveManager._load()
	print("SMOKE: skills after load=", Global.skills["fishing"], "/", Global.skills["mining"])
	# ---- 农业/采集技能测试 ----
	Global.add_skill_xp("farming", 10)
	Global.add_skill_xp("foraging", 10)
	print("SMOKE: skills farming=", Global.skills["farming"], " foraging=", Global.skills["foraging"])
	print("SMOKE: farm bonus=", Global.farming_bonus_chance(), " forage double=", Global.foraging_double_chance())
	# 收获作物获得农业经验（甜瓜成熟收获）
	var harvest_crop: Crop = (load("res://Placeables/Crops/crop.tscn") as PackedScene).instantiate() as Crop
	harvest_crop.crop_data = load("res://Bag/items/crops/甜瓜_data.tres")
	harvest_crop.growth_stage = 7
	level.find_child("Crops").add_child(harvest_crop)
	var farm_xp_before: int = Global.skill_xp["farming"]
	harvest_crop._on_body_droped()
	print("SMOKE: farm xp gain=", Global.skill_xp["farming"] - farm_xp_before)
	# ---- 暴击/战斗技能测试 ----
	Global.add_skill_xp("combat", 10)
	print("SMOKE: combat skill=", Global.skills["combat"], " crit bonus=", Global.combat_crit_bonus())
	# 击杀史莱姆获得战斗技能经验
	var crit_slime: Enemy = (load("res://Combat/slime.tscn") as PackedScene).instantiate() as Enemy
	level.add_child(crit_slime)
	crit_slime.global_position = player.global_position + Vector2(80, 0)
	var combat_xp_before: int = Global.skill_xp["combat"]
	crit_slime.hurt.take_damage(50, player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE: combat xp gain=", Global.skill_xp["combat"] - combat_xp_before)
	# 暴击必中测试：hit_component.crit=1.0 → 伤害翻倍
	var crit_target: Enemy = (load("res://Combat/slime.tscn") as PackedScene).instantiate() as Enemy
	level.add_child(crit_target)
	crit_target.global_position = player.global_position + Vector2(90, 0)
	player.hit_component.crit = 1.0
	player.hit_component.damage = 5
	player.hit_component.current_item_type = Item.ItemType.Weapon
	var target_hp: int = crit_target.hurt.current_health
	crit_target.hurt.on_area_entered(player.hit_component)
	print("SMOKE: crit damage=", crit_target.hurt.current_health - target_hp)
	player.hit_component.crit = 0.0
	crit_target.queue_free()
	# ---- 光之女王Boss测试 ----
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	var empress_recipe: Recipe = load("res://Crafting/recipes/光棱晶.tres")
	crafting.panel._on_craft_pressed(empress_recipe)
	var empress_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "光棱晶":
			empress_item = it
			break
	print("SMOKE: crafted prism=", empress_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if empress_item:
		player.current_item = empress_item
		player.use_summon()
	await get_tree().process_frame
	var empress := level.get_node_or_null("BossEmpress") as Boss
	print("SMOKE: empress=", empress != null)
	if empress:
		empress.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var emp_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				emp_bolt += 1
		print("SMOKE: empress bolt=", emp_bolt > 0)
		empress.hurt.take_damage(3000, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: empress dead=", not is_instance_valid(empress), " drops=", drops_node.get_child_count())
	# ---- 邪教徒Boss测试 ----
	for i in 15:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/紫水晶.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/绿宝石.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/黄玉.tres").duplicate())
	for i in 30:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var cultist_recipe: Recipe = load("res://Crafting/recipes/远古符印.tres")
	crafting.panel._on_craft_pressed(cultist_recipe)
	var cultist_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "远古符印":
			cultist_item = it
			break
	print("SMOKE: crafted sigil2=", cultist_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if cultist_item:
		player.current_item = cultist_item
		player.use_summon()
	await get_tree().process_frame
	var cultist := level.get_node_or_null("BossCultist") as Boss
	print("SMOKE: cultist=", cultist != null)
	if cultist:
		cultist.shoot_timer = 0.1
		await get_tree().create_timer(0.5).timeout
		var cult_bolt := 0
		for n in level.get_children():
			if n is Projectile and n.name == "EnemyBolt":
				cult_bolt += 1
		print("SMOKE: cultist volley=", cult_bolt > 0)
		cultist.hurt.take_damage(3200, player.global_position)
		await get_tree().create_timer(1.3).timeout
		print("SMOKE: cultist dead=", not is_instance_valid(cultist), " drops=", drops_node.get_child_count())
	# ---- 地牢地图测试 ----
	SceneManager.change_level("Dungeon", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var dungeon := SceneManager.get_current_level() as Dungeon
	print("SMOKE: dungeon=", dungeon != null)
	if dungeon:
		var dg: int = dungeon.get_node("Ground").get_used_cells().size()
		var chest: Box = null
		for child in dungeon.get_children():
			if child is Box:
				chest = child
				break
		var dspawner: Array = dungeon.get_node("EnemySpawner").enemy_scenes
		var has_skel := false
		for es in dspawner:
			if es != null and es.resource_path.contains("skeleton"):
				has_skel = true
		print("SMOKE: dungeon ground=", dg, " chest=", chest != null, " skel=", has_skel)
		SceneManager.change_level("Farm", "SpawnPosition")
		await get_tree().process_frame
		await get_tree().process_frame
		level = SceneManager.get_current_level()
		player = get_tree().get_first_node_in_group("Player")
	# ---- 宠物喂食测试 ----
	var pet_ins: Pet = (load("res://Animals/pet.tscn") as PackedScene).instantiate() as Pet
	level.add_child(pet_ins)
	pet_ins.global_position = player.global_position + Vector2(60, 0)
	# 手持鱼喂食
	player.current_item = load("res://Bag/items/fish/太阳鱼.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	var fed_ok: bool = pet_ins.feed(player)
	var fed_count: int = pet_ins.fed
	print("SMOKE: pet fed=", fed_ok, " count=", fed_count)
	# 非鱼物品不喂食（抚摸）
	player.current_item = load("res://Bag/items/food/蛋糕.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	var fed_bad: bool = pet_ins.feed(player)
	var petted_count: int = pet_ins.petted
	print("SMOKE: pet no-fish=", fed_bad == false, " petted_after=", pet_ins.petted > petted_count)
	pet_ins.queue_free()
	# ---- 出货箱测试 ----
	var bin_ins: ShippingBin = (load("res://Map/Farm/shipping_bin.tscn") as PackedScene).instantiate() as ShippingBin
	level.add_child(bin_ins)
	bin_ins.global_position = player.global_position + Vector2(60, 0)
	player.current_item = load("res://Bag/items/materials/金锭.tres").duplicate()
	player.bag_system.add_item(player.current_item)
	var gold_before_ship: int = Global.gold
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	bin_ins._unhandled_input(rc)
	var pending_count: int = Global.shipping_pending.size()
	var bin_day: int = TimeSystem.current_day
	TimeSystem.set_time(bin_day + 1, 6, 0)
	await get_tree().process_frame
	print("SMOKE: shipping pending=", pending_count, " sold_gold=", Global.gold - gold_before_ship)
	bin_ins.queue_free()
	# ---- 雪原狼/每周信件测试 ----
	var wolf_ins: Enemy = (load("res://Combat/wolf.tscn") as PackedScene).instantiate() as Enemy
	level.add_child(wolf_ins)
	wolf_ins.global_position = player.global_position + Vector2(80, 0)
	print("SMOKE: wolf=", wolf_ins.enemy_name, " hp=", wolf_ins.max_health, " vf=", wolf_ins.sprite_vframes)
	wolf_ins.hurt.take_damage(25, player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE: wolf dead=", not is_instance_valid(wolf_ins))
	var tundra_cfg2: Array = (load("res://Map/Tundra/tundra.tscn") as PackedScene).instantiate().get_node("EnemySpawner").enemy_scenes
	var has_wolf := false
	for es in tundra_cfg2:
		if es != null and es.resource_path.contains("wolf"):
			has_wolf = true
	print("SMOKE: tundra wolf=", has_wolf)
	# 每周日季节信（第7天）
	var mail_day: int = TimeSystem.current_day
	TimeSystem.set_time(7, 6, 0)
	await get_tree().process_frame
	print("SMOKE: weekly mail=", MailSystem.pending_mail.get("text", "") != "")
	# ---- 雨声测试 ----
	WeatherSystem.weather = "rain"
	await get_tree().process_frame
	print("SMOKE: rain playing=", WeatherSystem.rain_player.playing)
	WeatherSystem.weather = "sunny"
	await get_tree().process_frame
	print("SMOKE: rain stopped=", not WeatherSystem.rain_player.playing)
	# ---- 沙漠商人扩展测试 ----
	var merchant_items: Array = (load("res://NPC/desert_merchant.gd") as GDScript).new().SHOP_ITEMS
	var has_excalibur := false
	var has_topaz := false
	for it in merchant_items:
		if it != null and it.name == "圣剑":
			has_excalibur = true
		if it != null and it.name == "黄玉":
			has_topaz = true
	print("SMOKE: merchant excalibur=", has_excalibur, " topaz=", has_topaz, " total=", merchant_items.size())
	# ---- 钓鱼宝箱测试 ----
	var fishing8 := get_node_or_null("/root/MainScene/FishingSystem") as FishingSystem
	var chest_item: Item = fishing8._roll_chest_reward()
	print("SMOKE: chest reward=", chest_item != null, " name=", chest_item.name if chest_item else "?", " qty=", chest_item.quantity if chest_item else -1)
	# ---- Boss终结者/技能大师成就测试 ----
	for name in ["血肉墙", "世纪之花", "石巨人", "蜂后", "骷髅王", "机械蠕虫"]:
		CollectionSystem.record_kill(name)
	AchievementSystem.check()
	Global.skills["mining"] = 10
	AchievementSystem.check()
	print("SMOKE: ach boss10=", AchievementSystem.is_unlocked("boss_10"), " skillmaster=", AchievementSystem.is_unlocked("skill_master"))
	# ---- 采石场地图测试 ----
	SceneManager.change_level("Quarry", "SpawnPosition")
	await get_tree().process_frame
	await get_tree().process_frame
	var quarry := SceneManager.get_current_level() as Quarry
	print("SMOKE: quarry=", quarry != null)
	if quarry:
		var qg: int = quarry.get_node("Ground").get_used_cells().size()
		var qo: int = quarry.get_node("Ores").get_child_count()
		print("SMOKE: quarry ground=", qg, " ores=", qo)
		SceneManager.change_level("Farm", "SpawnPosition")
		await get_tree().process_frame
		await get_tree().process_frame
		level = SceneManager.get_current_level()
		player = get_tree().get_first_node_in_group("Player")
	# ---- 石巨人Boss测试 ----
	for i in 10:
		player.bag_system.add_item(load("res://Bag/items/materials/金锭.tres").duplicate())
	for i in 5:
		player.bag_system.add_item(load("res://Bag/items/materials/蓝宝石.tres").duplicate())
	for i in 20:
		player.bag_system.add_item(load("res://Bag/items/materials/骨头.tres").duplicate())
	var golem_recipe: Recipe = load("res://Crafting/recipes/石巨人之心.tres")
	crafting.panel._on_craft_pressed(golem_recipe)
	var golem_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "石巨人之心":
			golem_item = it
			break
	print("SMOKE: crafted golem heart=", golem_item != null)
	TimeSystem.set_time(TimeSystem.current_day, 22, 0)
	await get_tree().process_frame
	if golem_item:
		player.current_item = golem_item
		player.use_summon()
	await get_tree().process_frame
	var golem := level.get_node_or_null("BossGolem") as Boss
	print("SMOKE: golem spawned=", golem != null)
	if golem:
		print("SMOKE: golem before take_damage drops=", drops_node.get_child_count())
		golem.hurt.take_damage(2000, player.global_position)
		print("SMOKE: golem after take_damage")
		await get_tree().create_timer(1.2).timeout
		print("SMOKE: golem after timer")
		print("SMOKE: golem dead=", not is_instance_valid(golem), " drops=", drops_node.get_child_count())
	# ---- 火把（可放置光源）测试 ----
	for i in 3:
		player.bag_system.add_item(load("res://Bag/items/materials/wood.tres").duplicate())
	player.bag_system.add_item(load("res://Bag/items/materials/凝胶.tres").duplicate())
	var torch_recipe: Recipe = load("res://Crafting/recipes/火把.tres")
	crafting.panel._on_craft_pressed(torch_recipe)
	var torch_item: Item = null
	for it in player.bag_system.items:
		if it != null and it.name == "火把":
			torch_item = it
			break
	print("SMOKE: torch type=", torch_item.type if torch_item else -1, " path=", torch_item.placeable_scene_path if torch_item else "?")
	var torch_scene: PackedScene = load("res://Placeables/torch.tscn")
	var torch_ins: Placeable = torch_scene.instantiate() as Placeable
	var has_light: bool = torch_ins.get_node_or_null("PointLight2D") != null
	level.find_child("Crops").add_child(torch_ins)
	torch_ins.global_position = Vector2(400, 400)
	SaveManager._save()
	SaveManager._load()
	await get_tree().process_frame
	await get_tree().process_frame
	var torch_found: bool = false
	for child in level.find_child("Crops").get_children():
		if child is Placeable:
			torch_found = true
			break
	print("SMOKE: torch light=", has_light, " saved=", torch_found)
	# ---- 艾米丽中午/夜晚日程测试 ----
	var emily4 := level.find_child("Emily") as NPC
	print("SMOKE: emily=", emily4 != null)
	if emily4:
		var emily_x0: float = emily4.global_position.x
		TimeSystem.set_time(TimeSystem.current_day, 12, 0)
		await get_tree().create_timer(1.0).timeout
		var mid_dir: Vector2 = emily4.get("direction")
		var to_gate := (Vector2(268, 160) - emily4.global_position).normalized()
		var heading_gate: bool = mid_dir.dot(to_gate) > 0.5
		print("SMOKE: emily midday heading_gate=", heading_gate, " pos=", emily4.global_position)
		TimeSystem.set_time(TimeSystem.current_day, 20, 0)
		await get_tree().create_timer(1.0).timeout
		var night_dir: Vector2 = emily4.get("direction")
		var heading_home := (Vector2(emily_x0, emily4.global_position.y) - emily4.global_position).normalized()
		var going_home: bool = night_dir.dot(heading_home) > 0.3 or night_dir == Vector2.ZERO
		print("SMOKE: emily night going_home=", going_home, " pos=", emily4.global_position)
	print("SMOKE_OK")
