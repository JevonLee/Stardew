extends Boss
## 激光眼（Retinazer）：双子魔眼之远程形态——保持距离发射激光弹幕，
## 伙伴炽焰眼阵亡后狂暴（射速翻倍、伤害提升）

const BOLT = preload("res://Combat/enemy_bolt.tscn")

var shoot_timer: float = 2.5
var enraged: bool = false

func _ready() -> void:
	super()
	shoot_timer = 1.5

func enrage() -> void:
	enraged = true

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
		var boost: float = 1.5 if enraged else 1.0
		var to_player := (player.global_position - global_position)
		var p_dist := to_player.length()
		var dir := to_player.normalized()
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 保持距离：太近远离、太远靠近、适中环绕
				if p_dist < 220.0:
					velocity = -dir * 110.0 * boost
				elif p_dist > 340.0:
					velocity = dir * 90.0 * boost
				else:
					velocity = dir.rotated(PI / 2.0) * 60.0
				# 周期发射激光弹幕
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					shoot_timer = 2.0 if not enraged else 1.0
					_shoot()
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = dir
					phase_timer = 0.5
			Phase.DASH:
				velocity = dash_dir * dash_speed * 0.7
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

func _shoot() -> void:
	if player == null: return
	var bolt := BOLT.instantiate() as Projectile
	var dir := (player.global_position - global_position).normalized()
	bolt.setup(dir, 14 if not enraged else 18)
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
	Global.show_message("激光眼被击败了！双子魔眼覆灭！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
