extends Area2D
class_name HitComponent

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

@export var current_item_type: Item.ItemType = Item.ItemType.None
@export var damage:int = 1 #工具的伤害,需要在更改工具时设置对应的伤害
@export var crit:float = 0.0 ## 暴击率（由武器设置，战斗技能叠加）

func _ready() -> void:
	collision_shape_2d.disabled = true
