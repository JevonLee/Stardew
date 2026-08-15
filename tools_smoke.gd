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
	print("SMOKE: travel panel=", travel_sys != null and travel_sys.panel != null)
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
	print("SMOKE_OK")
