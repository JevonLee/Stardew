extends Boss
## 月亮领主：最终Boss——漂浮追击+眼棱激光弹幕（3发扇形）+冲撞，半血狂暴

const BOLT = preload("res://Combat/enemy_bolt.tscn")

@export var gift_drop: Item ## 特殊掉落（蓝宝石）

var shoot_timer: float = 3.0

func _ready() -> void:
	super()
	shoot_timer = 2.5

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
	if not chasing:
		velocity = Vector2(sin(anim_time * 2.0), cos(anim_time * 2.0)) * 30.0
	else:
		var boost: float = 1.6 if (max_health > 0 and hurt.current_health < max_health * 0.5) else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 环绕逼近
				velocity = to_player.normalized() * 75.0 * boost + Vector2(sin(anim_time * 1.2), cos(anim_time * 1.2)) * 60.0
				# 周期发射眼棱激光（3发扇形）
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					shoot_timer = 3.0 if not boost > 1.0 else 1.8
					_shoot_volley()
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

## 眼棱激光：向玩家发射3发扇形弹幕
func _shoot_volley() -> void:
	if player == null: return
	var base := (player.global_position - global_position).normalized()
	for i in 3:
		var dir := base.rotated(deg_to_rad((i - 1) * 14.0))
		var bolt := BOLT.instantiate() as Projectile
		bolt.setup(dir, 18)
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
	for i in 100:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 5:
		if item_drop:
			_drop_item(item_drop)
	for i in 5:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 6:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 5:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("月亮领主被击败了！泰拉瑞亚的威胁终结了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
