extends Boss
## 世纪之花：巨大的花苞Boss，缓慢追击并周期召唤花孢子仆从

const SPORE = preload("res://Combat/jungle_slime.tscn")

var spawn_timer: float = 6.0
const MAX_MINIONS: int = 5

func _ready() -> void:
	super()
	spawn_timer = 4.0

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
		velocity = Vector2(sin(anim_time), cos(anim_time)) * 30.0
	else:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * 70.0
		sprite.flip_h = dir.x < 0.0
		# 周期召唤花孢子
		spawn_timer -= delta
		if spawn_timer <= 0.0 and get_tree().get_nodes_in_group("Enemies").size() < 8:
			spawn_timer = 6.0
			_spawn_spore()
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

func _spawn_spore() -> void:
	var spore := SPORE.instantiate() as Enemy
	spore.add_to_group("Enemies")
	var parent := get_parent()
	if parent:
		parent.add_child(spore)
		spore.global_position = global_position + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	spore.aggro_range = 9999.0

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	for i in 50:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 15:
		if item_drop:
			_drop_item(item_drop)
	for i in 6:
		_spawn_pickup(Pickup.Type.HEART, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("世纪之花被击败了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
