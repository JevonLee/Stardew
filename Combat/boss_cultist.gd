extends Boss
## 邪教徒：月球事件前Boss——漂浮追击+5发扇形远古弹+周期瞬移，半血狂暴

const BOLT = preload("res://Combat/enemy_bolt.tscn")

@export var gift_drop: Item ## 特殊掉落（骨头）

var shoot_timer: float = 2.8
var teleport_timer: float = 6.0

func _ready() -> void:
	super()
	shoot_timer = 1.8
	teleport_timer = 4.0

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
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 35.0
	else:
		var boost: float = 1.6 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 漂浮逼近
				velocity = to_player.normalized() * 80.0 * boost + Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 40.0
				# 周期扇形远古弹（5发）
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					shoot_timer = 2.8 if not boost > 1.0 else 1.8
					_shoot_volley()
				# 周期瞬移（闪现到玩家附近）
				teleport_timer -= delta
				if teleport_timer <= 0.0:
					teleport_timer = 6.0 if not boost > 1.0 else 4.0
					_teleport()
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

func _shoot_volley() -> void:
	if player == null: return
	var base := (player.global_position - global_position).normalized()
	for i in 5:
		var dir := base.rotated(deg_to_rad((i - 2) * 12.0))
		var bolt := BOLT.instantiate() as Projectile
		bolt.setup(dir, 16)
		var sprite_node := bolt.get_node_or_null("Sprite2D") as Sprite2D
		if sprite_node:
			sprite_node.modulate = Color(0.7, 0.5, 1.0, 1.0) # 紫黑远古弹
		var parent := get_parent()
		if parent:
			parent.add_child(bolt)
			bolt.global_position = global_position

func _teleport() -> void:
	if player == null: return
	# 闪现到玩家附近的随机位置
	var offset := Vector2(randf_range(-160, 160), randf_range(-120, 120))
	global_position = player.global_position + offset
	sprite.modulate = Color(5.0, 5.0, 5.0)
	hit_flash = 0.3
	Global.show_message("邪教徒闪现在你身边！")

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	for i in 90:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 15:
		if item_drop:
			_drop_item(item_drop)
	for i in 20:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 5:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 5:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("邪教徒被击败了！月亮的仪式被阻止了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
