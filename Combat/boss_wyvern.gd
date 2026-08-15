extends Boss
## 双足飞龙：天空巨蛇——飞行头部蛇形追击+冲刺，身体链式跟随，
## 攻击身体伤害转嫁头部，头部阵亡全身散架

const SEGMENT = preload("res://Combat/wyvern_segment.tscn")

var segments: Array = []

func _ready() -> void:
	super()
	_spawn_segments()

func _spawn_segments() -> void:
	var parent := get_parent()
	if parent == null: return
	var prev: Node2D = self
	for i in 6: # 5节身体 + 1节尾巴
		var seg := SEGMENT.instantiate() as WyvernSegment
		parent.add_child(seg)
		seg.global_position = global_position + Vector2(0, (i + 1) * 40.0)
		seg.leader = prev
		seg.head_ref = self
		seg.contact_damage = 16 if i < 5 else 12
		seg.name = "WyvernSeg%d" % i
		if i == 5:
			(seg.get_node("Sprite2D") as Sprite2D).texture = load("res://Art/Terraria/images/NPC_89.png")
		segments.append(seg)
		prev = seg

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
	if not chasing:
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 30.0
	else:
		var boost: float = 1.5 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 天空蛇形游走
				velocity = to_player.normalized() * 100.0 * boost + Vector2(sin(anim_time * 3.0), cos(anim_time * 2.0)) * 55.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = to_player.normalized()
					phase_timer = 0.6
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
	for seg in segments:
		if is_instance_valid(seg):
			seg.queue_free()
	for i in 40:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 10:
		if item_drop:
			_drop_item(item_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 3:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("双足飞龙被击败了！天空恢复了宁静！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
