extends Boss
## 克苏鲁之脑：第二Boss。高速漂浮 + 频繁冲刺 + 分裂减速阶段

func _ready() -> void:
	super()
	phase_timer = 1.2 # 比克苏鲁之眼更快的节奏

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
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 30.0
	else:
		var dir := (player.global_position - global_position).normalized()
		match phase:
			Phase.FLOAT:
				velocity = dir * (float_speed * 1.3)
				sprite.flip_h = dir.x < 0.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = dir
					phase_timer = 0.5
			Phase.DASH:
				velocity = dash_dir * (dash_speed * 1.2)
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.FLOAT
					phase_timer = 1.6
	# 击退衰减
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
	for i in 30:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 8:
		if item_drop:
			_drop_item(item_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("克苏鲁之脑被击败了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
