extends CharacterBody2D
class_name Enemy
## 泰拉瑞亚风格敌人：史莱姆/僵尸/蝙蝠，追击玩家、接触伤害、击退、掉落

enum AI { SLIME, ZOMBIE, BAT }

@export var enemy_name:String = "史莱姆"
@export var ai:AI = AI.SLIME
@export var max_health:int = 20
@export var contact_damage:int = 8
@export var speed:float = 55.0
@export var knockback_resist:float = 0.0 ## 0=完全击退 1=免疫
@export var aggro_range:float = 260.0
@export var despawn_range:float = 1000.0
@export var coin_drop:Item ## 掉落的金币物品
@export var coin_count:int = 1
@export var item_drop:Item ## 特殊掉落（凝胶等）
@export var item_drop_chance:float = 0.8
@export var xp_reward:int = 5 ## 击杀经验
@export var sprite_texture:Texture2D ## 精灵图（垂直帧动画）
@export var sprite_vframes:int = 1
@export var sprite_scale:Vector2 = Vector2.ONE

const PICKUP = preload("res://Combat/pickup.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt: HurtComponent = $HurtComponent
@onready var contact_area: Area2D = $ContactArea

var player:Player
var knockback_velocity:Vector2 = Vector2.ZERO
var hit_flash:float = 0.0
var contact_cooldown:float = 0.0
var chasing:bool = false
var anim_time:float = 0.0
var hop_timer:float = 0.0
var dead:bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	hurt.max_health = max_health
	hurt.damage_taken.connect(_on_damage_taken)
	hurt.body_droped.connect(_on_death)
	contact_area.body_entered.connect(_on_contact)
	anim_time = randf() * 10.0
	hop_timer = randf_range(0.3, 1.0)
	# 应用外观
	if sprite_texture:
		sprite.texture = sprite_texture
	sprite.vframes = maxi(sprite_vframes, 1)
	sprite.scale = sprite_scale

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 6.0) % sprite.vframes
	# 追击判断
	var dist := 1e9
	if player:
		dist = global_position.distance_to(player.global_position)
	if dist > despawn_range:
		_despawn()
		return
	chasing = player != null and dist <= aggro_range
	# AI 移动
	match ai:
		AI.SLIME:
			_ai_slime(delta, dist)
		AI.ZOMBIE:
			_ai_zombie(delta, dist)
		AI.BAT:
			_ai_bat(delta, dist)
	# 击退衰减
	velocity = knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	# 受击闪白
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			sprite.modulate = Color.WHITE
	# 接触伤害冷却
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

func _ai_slime(delta: float, dist: float) -> void:
	if not chasing:
		velocity = Vector2.ZERO
		return
	var dir := (player.global_position - global_position).normalized()
	sprite.flip_h = dir.x < 0.0
	hop_timer -= delta
	if hop_timer <= 0.0:
		hop_timer = randf_range(0.9, 1.5)
		knockback_velocity = dir * speed * 3.2 # 跳跃
	velocity.x = knockback_velocity.x * 0.5
	velocity.y = knockback_velocity.y * 0.5

func _ai_zombie(delta: float, dist: float) -> void:
	if not chasing:
		velocity = Vector2.ZERO
		return
	var dir := (player.global_position - global_position).normalized()
	sprite.flip_h = dir.x < 0.0
	velocity.x = dir.x * speed
	velocity.y = 0.0

func _ai_bat(delta: float, dist: float) -> void:
	if not chasing:
		# 悬停巡逻：小幅晃动
		velocity = Vector2(sin(anim_time * 2.0) * 20.0, sin(anim_time * 3.0) * 20.0)
		return
	var dir := (player.global_position - global_position).normalized()
	sprite.flip_h = dir.x < 0.0
	velocity = dir * speed + Vector2(0.0, sin(anim_time * 4.0) * 25.0)

func _on_damage_taken(damage:int, source_position:Vector2) -> void:
	# 击退（泰拉瑞亚式）
	var dir := global_position - source_position
	if dir.length() < 0.01:
		dir = Vector2(randf_range(-1, 1), -1)
	dir.y = -absf(dir.y) * 0.6
	knockback_velocity += dir.normalized() * 240.0 * (1.0 - knockback_resist)
	# 闪白
	hit_flash = 0.12
	sprite.modulate = Color(3.0, 3.0, 3.0)

func _on_contact(body:Node2D) -> void:
	if dead: return
	if body is Player and contact_cooldown <= 0.0:
		contact_cooldown = 1.0
		body.take_damage(contact_damage)
		# 反方向击退玩家一小段（泰拉瑞亚手感）
		var dir := (body.global_position - global_position).normalized()
		body.knockback_player(dir)

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false # 死亡淡出期间不再可被击中
	contact_area.monitoring = false
	contact_area.monitorable = false
	# 击杀经验
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	# 掉落
	for i in coin_count:
		if coin_drop:
			_drop_item(coin_drop)
	if item_drop and randf() < item_drop_chance:
		_drop_item(item_drop)
	# 红心/魔力星
	if randf() < 0.15:
		_spawn_pickup(Pickup.Type.HEART, 1)
	if randf() < 0.08:
		_spawn_pickup(Pickup.Type.MANA, 1)
	# 死亡动画：上浮淡出
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

## 玩家太远/白天到来时淡出消失
func _despawn() -> void:
	if dead: return
	dead = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _drop_item(item:Item) -> void:
	var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
	if !drops:
		drops = get_parent()
	fall_ins.is_bezier = true
	fall_ins.position = global_position
	drops.add_child(fall_ins)
	fall_ins.generate(item)

func _spawn_pickup(type:int, amount:int) -> void:
	var pickup := PICKUP.instantiate() as Pickup
	pickup.pickup_type = type
	pickup.amount = amount
	var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
	if !drops:
		drops = get_parent()
	pickup.position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	drops.add_child(pickup)
