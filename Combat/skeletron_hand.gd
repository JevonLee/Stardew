extends Area2D
class_name SkeletronHand
## 骷髅王之手：由头部控制位置，接触玩家造成伤害（无血量，头部阵亡即散架）

var player: Player
var contact_cooldown: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if contact_cooldown > 0.0:
		contact_cooldown -= delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player and contact_cooldown <= 0.0:
		contact_cooldown = 1.0
		body.take_damage(20)
		var dir := (body.global_position - global_position).normalized()
		if dir.length() > 0.01:
			body.knockback_player(dir)
