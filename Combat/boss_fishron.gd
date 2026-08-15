extends Boss
## 猪鲨（猪龙鱼公）：海洋Boss——高速环绕+三连冲撞，半血狂暴并发射水弹

const BOLT = preload("res://Combat/enemy_bolt.tscn")

@export var gift_drop: Item ## 特殊掉落（章鱼）

var shoot_timer: float = 3.0
var dash_count: int = 0

func _ready() -> void:
	super()
	shoot_timer = 2.0

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 10.0) % sprite.vframes
	var dist := 1e9
	if player:
		dist = global_position.distance_to(player.global_position)
	if dist > despawn_range * 3.0:
		_despawn()
		return
	chasing = player != null and dist <= aggro_range * 4.0
	if not chasing:
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 40.0
	else:
		var boost: float = 1.6 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 高速环绕
				velocity = to_player.normalized() * 100.0 * boost + Vector2(cos(anim_time * 2.2), sin(anim_time * 2.2)) * 90.0
				# 周期发射水弹
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					shoot_timer = 2.5 if not boost > 1.0 else 1.6
					_shoot()
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					dash_count = 0
					phase_timer = 0.45
			Phase.DASH:
				velocity = dash_dir * dash_speed * boost
				phase_timer -= delta
				if phase_timer <= 0.0:
					# 三连冲撞后回到环绕
					dash_count += 1
					if dash_count < 3:
						phase_timer = 0.3
						dash_dir = (player.global_position - global_position).normalized()
					else:
						phase = Phase.FLOAT
						phase_timer = dash_cooldown * (0.5 if boost > 1.0 else 1.0)
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			sprite.modulate = Color.WHITE
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

func _shoot() -> void:
	if player == null: return
	var bolt := BOLT.instantiate() as Projectile
	var dir := (player.global_position - global_position).normalized()
	bolt.setup(dir, 15)
	var sprite_node := bolt.get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node:
		sprite_node.modulate = Color(0.4, 0.7, 1.0, 1.0) # 水蓝色弹幕
	var parent := get_parent()
	if parent:
		parent.add_child(bolt)
		bolt.global_position = global_position

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	for i in 60:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 8:
		if item_drop:
			_drop_item(item_drop)
	for i in 5:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 4:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("猪鲨被击败了！海洋的霸主倒下了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
