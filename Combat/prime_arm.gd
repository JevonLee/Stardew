extends Area2D
class_name PrimeArm
## 铁骷髅王激光臂：由头部控制位置，接触伤害+周期发射激光弹幕

const BOLT = preload("res://Combat/enemy_bolt.tscn")

var player: Player
var contact_cooldown: float = 0.0
var shoot_timer: float = 2.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if contact_cooldown > 0.0:
		contact_cooldown -= delta
	if player == null: return
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = randf_range(1.6, 2.8)
		_shoot()

func _shoot() -> void:
	var bolt := BOLT.instantiate() as Projectile
	var dir := (player.global_position - global_position).normalized()
	bolt.setup(dir, 16)
	var parent := get_parent()
	if parent:
		parent.add_child(bolt)
		bolt.global_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if body is Player and contact_cooldown <= 0.0:
		contact_cooldown = 1.0
		body.take_damage(18)
		var dir := (body.global_position - global_position).normalized()
		if dir.length() > 0.01:
			body.knockback_player(dir)
