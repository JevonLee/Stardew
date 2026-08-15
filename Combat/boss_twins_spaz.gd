extends Boss
## 炽焰眼（Spazmatism）：双子魔眼之近战冲锋形态——快速冲刺，半血狂暴；
## 登场时召唤伙伴激光眼，自身阵亡后伙伴狂暴

const RET = preload("res://Combat/boss_twins_ret.tscn")

var partner: Boss = null

func _ready() -> void:
	super()
	# 召唤伙伴激光眼
	if get_tree().get_nodes_in_group("Boss").size() < 2:
		partner = RET.instantiate() as Boss
		partner.add_to_group("Boss")
		var level: Node2D = SceneManager.get_current_level()
		if level:
			level.add_child(partner)
			partner.global_position = global_position + Vector2(-160, 0)
		partner.aggro_range = 9999.0

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 8.0) % sprite.vframes
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
		var boost: float = 1.5 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 逼近玩家并小幅晃动
				velocity = to_player.normalized() * 90.0 * boost + Vector2(sin(anim_time * 3.0), cos(anim_time * 3.0)) * 60.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					phase_timer = 0.5
			Phase.DASH:
				velocity = dash_dir * dash_speed * boost
				phase_timer -= delta
				if phase_timer <= 0.0:
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

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	# 伙伴狂暴
	if partner != null and is_instance_valid(partner):
		partner.call("enrage")
	for i in 30:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 4:
		if item_drop:
			_drop_item(item_drop)
	for i in 3:
		_spawn_pickup(Pickup.Type.HEART, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("炽焰眼被击败了！激光眼陷入狂暴！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
