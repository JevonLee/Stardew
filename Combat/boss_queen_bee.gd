extends Boss
## 蜂后：飞行Boss——环绕玩家浮动+周期性冲锋，半血狂暴并召唤蜜蜂仆从

const BEE = preload("res://Combat/bee.tscn")

@export var gift_drop: Item ## 特殊掉落（花束）

var summon_timer: float = 5.0
var enraged: bool = false
const MAX_MINIONS: int = 4

func _ready() -> void:
	super()
	summon_timer = 3.0

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
		# 半血狂暴：加速+更频繁冲锋与召唤
		enraged = hurt.current_health < max_health * 0.5 and max_health > 0
		var boost: float = 1.6 if enraged else 1.0
		var to_player := (player.global_position - global_position)
		sprite.flip_h = to_player.x < 0.0
		match phase:
			Phase.FLOAT:
				# 环绕玩家浮动
				var orbit := Vector2(cos(anim_time * 1.5), sin(anim_time * 1.5)) * 140.0
				velocity = to_player.normalized() * 80.0 * boost + orbit * 0.4
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
					phase_timer = dash_cooldown * (0.55 if enraged else 1.0)
		# 召唤蜜蜂仆从
		summon_timer -= delta
		if summon_timer <= 0.0 and _count_bees() < MAX_MINIONS:
			summon_timer = 5.0 if not enraged else 3.0
			_summon_bee()
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			sprite.modulate = Color.WHITE
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

func _count_bees() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e != null and e.get("enemy_name") == "蜜蜂":
			n += 1
	return n

func _summon_bee() -> void:
	var bee := BEE.instantiate() as Enemy
	bee.add_to_group("Enemies")
	var parent := get_parent()
	if parent:
		parent.add_child(bee)
		bee.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
	bee.aggro_range = 9999.0

func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	CollectionSystem.record_kill(enemy_name)
	for i in 40:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 8:
		if item_drop:
			_drop_item(item_drop)
	for i in 5:
		if gift_drop:
			_drop_item(gift_drop)
	for i in 4:
		_spawn_pickup(Pickup.Type.HEART, 1)
	for i in 3:
		_spawn_pickup(Pickup.Type.MANA, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("蜂后被击败了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
