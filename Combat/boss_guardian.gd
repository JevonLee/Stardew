extends Boss
## 地牢守卫：泰拉瑞亚隐藏Boss——超高速冲撞，接触一击必杀，近乎不可战胜

@export var gift_drop: Item ## 特殊掉落（紫水晶）

func _ready() -> void:
	super()
	phase_timer = 2.0

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 12.0) % sprite.vframes
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
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 高速直追
				velocity = to_player.normalized() * 300.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					phase_timer = 0.8
			Phase.DASH:
				# 超高速冲撞（一秒横跨大半屏）
				velocity = dash_dir * dash_speed
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.FLOAT
					phase_timer = dash_cooldown
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			sprite.modulate = Color.WHITE
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	for i in 100:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 10:
		if item_drop:
			_drop_item(item_drop)
	for i in 10:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 5:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 5:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("地牢守卫被击败了！这不可能……传说被打破了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
