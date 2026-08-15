extends CharacterBody2D
class_name Player
## 只用于选择Item和此Item对应的动画和状态，其他的功能通过额外组件来实现

@onready var hit_component: HitComponent = $HitComponent
@onready var weapon: Sprite2D = $Weapon/Weapon
@onready var jian_qi: JianQi = $Weapon/JianQi
@onready var effects: AnimatedSprite2D = $Effects
@onready var place_component: PlaceComponent = $PlaceComponent
@onready var state_machine: StateMachine = $StateMachine

@export var bag_system:InventorySystem
@export var current_item_type: Item.ItemType:
	set(val):
		if current_item != null:
			current_item_type = current_item.type
		else:
			current_item_type = Item.ItemType.None
@export var current_item:Item :
	set(val):
		handle_selected_item(val)
		current_item = val
@export var swing_sfx:AudioStream
		
signal watering
signal get_item ##拾取物品发送的信号
signal stats_changed(health:int, max_health:int, stamina:int, max_stamina:int, mana:int, max_mana:int)

## ---------- 生命 / 体力 / 魔力 ----------
@export var max_health:int = 100
@export var max_stamina:int = 270
@export var max_mana:int = 100
var health:int = 100
var stamina:int = 270
var mana:int = 100

const TOOL_STAMINA_COST:int = 4 ## 锄头/斧头/稿子/水壶的体力消耗
const SWING_STAMINA_COST:int = 5 ## 挥剑的体力消耗

## 受击无敌时间（泰拉瑞亚式）
const INVINCIBLE_TIME:float = 0.6
var invincible_time:float = 0.0

var items = null
var item_index:int = 0: ##current_item对应的下标
	set(val):
		item_index = val
		if items[item_index] == null:
			current_item = null
static var direction:Vector2 = Vector2.ZERO#在其他地方调用direction会使用同一个内存空间的direction变量
var player_direction:Vector2 #这个变量用于记住移动之后留下来的方向，上面这个是移动操作的变量
#static var tool_direction:Vector2 #使用工具的方向，根据鼠标来判断
var can_move:bool

var ground:TileMapLayer
var mouse_position:Vector2 #鼠标位置
var cell_position:Vector2i #tile单元格坐标
var cell_source_id:int #用于判断单元格下方是否有tile，-1则是没有
var local_cell_position:Vector2 #单元格中心位置
var distance:float


func _ready() -> void:
	bag_system.items.resize(bag_system.items_size)
	items = bag_system.items
	weapon.hide()
	weapon.offset = Vector2(12,-12)
	weapon.flip_h = false
	weapon.position = Vector2(0,-12)
	jian_qi.hide()
	can_move = true
	effects.hide()
	player_direction=Vector2.DOWN ##感谢bidegushi的bug修复
	player_direction=Vector2.DOWN
	#只有部分代码需要在场景转换时重新赋值
	initial()
	SceneManager.level_changed.connect(initial)
	health = max_health
	stamina = max_stamina
	mana = max_mana
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)

func initial() -> void:
	ground = get_tree().get_first_node_in_group("TileMap")
	
## 读档后同步背包引用
func sync_inventory() -> void:
	items = bag_system.items
	if item_index >= items.size():
		item_index = 0
	current_item = items[item_index]

## 消耗体力，不足时返回false并提示
func try_use_stamina(cost:int) -> bool:
	if stamina < cost:
		Global.show_message("体力不足！")
		return false
	stamina -= cost
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)
	return true

## 消耗魔力（泰拉瑞亚式魔法武器用）
func try_use_mana(cost:int) -> bool:
	if mana < cost:
		Global.show_message("魔力不足！")
		return false
	mana -= cost
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)
	return true

## 恢复（吃食物等）
func heal(h:int, s:int, m:int) -> void:
	health = clampi(health + h, 0, max_health)
	stamina = clampi(stamina + s, 0, max_stamina)
	mana = clampi(mana + m, 0, max_mana)
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)

## 右键食用当前选中的消耗品
func eat_current_item() -> bool:
	if current_item == null or current_item.type != Item.ItemType.Consume:
		return false
	var h:int = current_item.health_restore
	var s:int = current_item.stamina_restore
	var m:int = current_item.mana_restore
	if h <= 0 and s <= 0 and m <= 0:
		return false
	heal(h, s, m)
	bag_system.remove_num_item(item_index, 1)
	Global.show_message("吃了 %s" % current_item.name)
	return true

## 受伤（敌人攻击、掉落伤害等），带无敌帧
func take_damage(amount:int) -> void:
	if health <= 0 or invincible_time > 0.0: return
	health = maxi(health - amount, 0)
	invincible_time = INVINCIBLE_TIME
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)
	# 受击闪红
	modulate = Color(3.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	if health <= 0:
		die()

## 被敌人击退一小段（泰拉瑞亚手感）
func knockback_player(dir:Vector2) -> void:
	velocity = dir * 160.0

## 远程/魔法武器射击
func shoot_projectile() -> void:
	if current_item == null or current_item.projectile == "": return
	if current_item.mana_cost > 0 and not try_use_mana(current_item.mana_cost):
		return
	var proj_scene = load(current_item.projectile)
	var proj = proj_scene.instantiate()
	var dir := global_position.direction_to(get_global_mouse_position())
	get_tree().root.add_child(proj)
	proj.global_position = global_position + dir * 18.0
	if proj.has_method("setup"):
		proj.setup(dir, current_item.damage)

## 晕倒：回家、恢复部分体力、损失10%金币
func die() -> void:
	can_move = false
	health = max_health
	stamina = int(max_stamina * 0.5)
	mana = max_mana
	stats_changed.emit(health, max_health, stamina, max_stamina, mana, max_mana)
	var lost:int = int(Global.gold * 0.1)
	Global.gold -= lost
	Global.show_message("你晕倒了……损失了 %d 金币" % lost)
	SceneManager.change_level("MyHouse", "SpawnPosition")
	can_move = true

func _process(delta: float) -> void:
	if !effects.is_playing():
		effects.hide()
	
func _physics_process(_delta: float) -> void:
	if can_move:
		direction = Input.get_vector("move_left","move_right","move_up","move_down")
	if invincible_time > 0.0:
		invincible_time -= _delta
	#tool_direction = global_position.direction_to(get_global_mouse_position())

func handle_selected_item(item:Item) -> void:
	if item == null : return
	current_item_type = item.type
	#设置碰撞箱大小
	if item.collision_size != Vector2.ZERO:
		var coll = hit_component.get_child(0) as CollisionShape2D
		coll.shape.extents = item.collision_size
	elif item.collision_size == Vector2.ZERO:
		var coll = hit_component.get_child(0) as CollisionShape2D
		coll.shape.extents = Vector2(8,8)
	#设置伤害（工具保持至少1点）
	hit_component.damage = maxi(item.damage, 1)
	#选中物品时做出的相应效果
	match item.type:
		Item.ItemType.Weapon:
			weapon.texture = item.texture
		Item.ItemType.Placeables:
			place_component.item_to_place = item
		Item.ItemType.Consume:
			pass
		Item.ItemType.Water:
			show_water_effects()
	 

func show_water_effects() -> void:
	get_cell_under_mouse()
	if Input.is_action_just_pressed("mouse_left") and !effects.visible and distance<=40:
		effects.global_position = local_cell_position
		watering.emit(local_cell_position)
		effects.show()
		effects.play("water")
	
func get_cell_under_mouse() -> void:
	if ground == null : return
	mouse_position = ground.get_local_mouse_position() #返回该 CanvasItem 中鼠标的位置
	cell_position = ground.local_to_map(mouse_position) #返回包含给定 mouse_position 的单元格地图坐标
	cell_source_id = ground.get_cell_source_id(cell_position) #返回位于坐标的单元格的图块源 ID。如果单元格不存在则返回 -1。
	local_cell_position = ground.map_to_local(cell_position) #返回位于坐标 coords 的单元格的图块源 ID。如果单元格不存在则返回 -1。
	distance = self.global_position.distance_to(local_cell_position) #玩家到单元格中心的距离
func _unhandled_input(event: InputEvent) -> void: #这个函数可以忽略UI的事件操作
	#右键食用消耗品
	if event.is_action_pressed("mouse_right"):
		eat_current_item()
		return
	if current_item == null : return
	if event.is_action_pressed("mouse_left"):
		match self.current_item_type:
			Item.ItemType.Axe:
				if try_use_stamina(TOOL_STAMINA_COST):
					state_machine.transition_state("Axe")
			Item.ItemType.Draft:
				if try_use_stamina(TOOL_STAMINA_COST):
					state_machine.transition_state("Draft")
			Item.ItemType.Hoe:
				if try_use_stamina(TOOL_STAMINA_COST):
					state_machine.transition_state("Hoe")
			Item.ItemType.Water:
				if try_use_stamina(TOOL_STAMINA_COST):
					state_machine.transition_state("Water")
			Item.ItemType.Weapon:
				# 远程/魔法武器：左键发射投射物（泰拉瑞亚式），近战武器挥砍
				if current_item.projectile != "":
					shoot_projectile()
					return
				if try_use_stamina(SWING_STAMINA_COST):
					state_machine.transition_state("Swing")
					AudioManager.play_sfx(swing_sfx)
					if current_item.name == "喵刀":
						var rain_bow_cat = load("res://Bag/projectiles/rainbow_cat.tscn").instantiate() as Node2D
						get_tree().root.add_child(rain_bow_cat)
						rain_bow_cat.global_position = global_position
					if current_item.name == "暗影焰刀":
						var rain_bow_cat = load("res://Bag/projectiles/暗影焰刀.tscn").instantiate() as Node2D
						get_tree().root.add_child(rain_bow_cat)
						rain_bow_cat.global_position = global_position
			Item.ItemType.None:
				print("没有物品")
			_:
				print("没有对应类型")
