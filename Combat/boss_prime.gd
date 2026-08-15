extends Boss
## 铁骷髅王：机械化的骷髅王——头部旋转冲撞+半血狂暴，
## 两条激光臂随头部移动并周期发射激光弹幕；头部阵亡双臂散架

const ARM = preload("res://Combat/prime_arm.tscn")

@export var gift_drop: Item ## 特殊掉落（金锭）

var arms: Array = []

func _ready() -> void:
	super()
	_spawn_arms()

func _spawn_arms() -> void:
	var parent := get_parent()
	if parent == null: return
	for side in [-1.0, 1.0]:
		var arm := ARM.instantiate()
		parent.add_child(arm)
		arm.global_position = global_position + Vector2(side * 70.0, 24.0)
		arms.append(arm)

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 6.0) % sprite.vframes
	var dist := 1e9
	if player:
		dist = global_position.distance_to(player.global_position)
	if dist > despawn_range * 3.0:
		_despawn()
		return
	chasing = player != null and dist <= aggro_range * 4.0
	var boost: float = 1.0
	if not chasing:
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 30.0
	else:
		boost = 1.6 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				velocity = to_player.normalized() * 85.0 * boost + Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 40.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					phase_timer = 0.8
			Phase.DASH:
				velocity = dash_dir * dash_speed * boost
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.FLOAT
					phase_timer = dash_cooldown * (0.5 if boost > 1.0 else 1.0)
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	if phase == Phase.DASH:
		sprite.rotation += delta * 11.0 * boost
	else:
		sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 4.0)
	# 双臂跟随头部两侧
	for i in arms.size():
		if is_instance_valid(arms[i]):
			var side: float = -1.0 if i == 0 else 1.0
			arms[i].global_position = global_position + Vector2(side * 70.0, 24.0)
			arms[i].get_node("Sprite2D").flip_h = side > 0.0
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
	# 双臂散架
	for arm in arms:
		if is_instance_valid(arm):
			arm.queue_free()
	for i in 50:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 12:
		if item_drop:
			_drop_item(item_drop)
	for i in 6:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 3:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("铁骷髅王被击败了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
