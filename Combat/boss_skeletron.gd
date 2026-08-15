extends Boss
## 骷髅王：泰拉瑞亚经典三件套Boss——头部漂浮追击+旋转冲撞，
## 双手随头部移动夹击玩家；头部阵亡双手散架

const HAND = preload("res://Combat/skeletron_hand.tscn")

@export var gift_drop: Item ## 特殊掉落（蛛网）

var hands: Array = []

func _ready() -> void:
	super()
	_spawn_hands()

func _spawn_hands() -> void:
	var parent := get_parent()
	if parent == null: return
	for side in [-1.0, 1.0]:
		var hand := HAND.instantiate()
		parent.add_child(hand)
		hand.global_position = global_position + Vector2(side * 72.0, 26.0)
		hands.append(hand)

func _physics_process(delta: float) -> void:
	if dead: return
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 4.0) % sprite.vframes
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
		boost = 1.5 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				velocity = to_player.normalized() * 80.0 * boost + Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 40.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					phase_timer = 0.9
			Phase.DASH:
				velocity = dash_dir * dash_speed * boost
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.FLOAT
					phase_timer = dash_cooldown * (0.5 if boost > 1.0 else 1.0)
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	# 冲撞时头部旋转，平时缓缓回正
	if phase == Phase.DASH:
		sprite.rotation += delta * 10.0 * boost
	else:
		sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 4.0)
	# 双手跟随头部两侧
	for i in hands.size():
		if is_instance_valid(hands[i]):
			var side: float = -1.0 if i == 0 else 1.0
			hands[i].global_position = global_position + Vector2(side * 72.0, 26.0)
			hands[i].get_node("Sprite2D").flip_h = side > 0.0
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
	# 双手散架
	for hand in hands:
		if is_instance_valid(hand):
			hand.queue_free()
	for i in 40:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 15:
		if item_drop:
			_drop_item(item_drop)
	for i in 8:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 3:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("骷髅王被击败了！地牢的诅咒解除了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
