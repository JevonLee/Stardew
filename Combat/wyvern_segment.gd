extends CharacterBody2D
class_name WyvernSegment
## 双足飞龙身体段：链式跟随前一段，接触伤害；攻击身体伤害转嫁头部

var leader: Node2D
var spacing: float = 40.0
var head_ref: Node = null
var contact_damage: int = 14

@onready var hurt: HurtComponent = $HurtComponent
@onready var contact_area: Area2D = $ContactArea

var contact_cooldown: float = 0.0
var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	hurt.damage_taken.connect(_on_damage_taken)
	contact_area.body_entered.connect(_on_contact)

func _on_damage_taken(damage: int, source_position: Vector2) -> void:
	if head_ref != null and is_instance_valid(head_ref):
		head_ref.hurt.take_damage(damage, source_position)

func _on_contact(body: Node2D) -> void:
	if body is Player and contact_cooldown <= 0.0:
		contact_cooldown = 1.0
		body.take_damage(contact_damage)

func _physics_process(delta: float) -> void:
	if contact_cooldown > 0.0:
		contact_cooldown -= delta
	if leader == null: return
	var to_leader := leader.global_position - global_position
	if to_leader.length() > spacing:
		velocity = to_leader.normalized() * 360.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()
