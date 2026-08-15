extends Area2D
class_name Pickup
## 泰拉瑞亚式拾取物：红心/魔力星（磁吸、弹跳）

enum Type { HEART, MANA }

const HEART_TEX := preload("res://Art/Terraria/images/Heart.png")
const MANA_TEX := preload("res://Art/Terraria/images/Mana.png")

@export var pickup_type:Type = Type.HEART
@export var amount:int = 1

@onready var sprite: Sprite2D = $Sprite2D

var player:Player
var life:float = 30.0
var bobbing:float = 0.0
var magnetized:bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	match pickup_type:
		Type.HEART:
			sprite.texture = HEART_TEX
		Type.MANA:
			sprite.texture = MANA_TEX
	body_entered.connect(_on_body_entered)
	bobbing = randf() * TAU

func _process(delta: float) -> void:
	life -= delta
	bobbing += delta * 4.0
	sprite.position.y = sin(bobbing) * 3.0
	if life <= 0.0:
		queue_free()
		return
	if player == null:
		return
	# 磁吸
	if not magnetized and global_position.distance_to(player.global_position) < 100.0:
		magnetized = true
	if magnetized:
		global_position = global_position.move_toward(player.global_position, 320.0 * delta)

func _on_body_entered(body:Node2D) -> void:
	if body is Player:
		match pickup_type:
			Type.HEART:
				player.heal(20, 0, 0)
				Global.show_message("+20 生命")
			Type.MANA:
				player.heal(0, 0, 25)
				Global.show_message("+25 魔力")
		queue_free()
