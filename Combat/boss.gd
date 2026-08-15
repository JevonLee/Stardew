extends Enemy
class_name Boss
## 泰拉瑞亚风格Boss：克苏鲁之眼。漂浮追击 + 周期性冲刺，高血量高伤害

enum Phase { FLOAT, DASH }

@export var dash_cooldown: float = 2.5
@export var dash_speed: float = 420.0
@export var float_speed: float = 90.0

var phase: Phase = Phase.FLOAT
var phase_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super()
	phase_timer = dash_cooldown

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
		var dir := (player.global_position - global_position).normalized()
		match phase:
			Phase.FLOAT:
				velocity = dir * float_speed
				sprite.flip_h = dir.x < 0.0
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.DASH
					dash_dir = dir
					phase_timer = 0.7
			Phase.DASH:
				velocity = dash_dir * dash_speed
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = Phase.FLOAT
					phase_timer = dash_cooldown
	# 击退衰减
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	move_and_slide()
	# 受击闪白
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			sprite.modulate = Color.WHITE
	# 接触伤害冷却
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

## Boss专属掉落与结算
func _on_death() -> void:
	if dead: return
	dead = true
	hurt.monitoring = false
	hurt.monitorable = false
	contact_area.monitoring = false
	contact_area.monitorable = false
	# 掉落：金币 x20 + 特殊掉落 x5 + 红心 x3
	for i in 20:
		if coin_drop:
			_drop_item(coin_drop)
	for i in 5:
		if item_drop:
			_drop_item(item_drop)
	for i in 3:
		_spawn_pickup(Pickup.Type.HEART, 1)
	if player and xp_reward > 0:
		player.gain_xp(xp_reward)
	Global.show_message("克苏鲁之眼被击败了！")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
