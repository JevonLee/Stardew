extends StaticBody2D
class_name OreNode
## 矿洞中的矿石节点：用稿子敲击，掉落矿石

const COAL = preload("res://Bag/items/materials/煤矿.tres")
const STONE = preload("res://Bag/items/materials/stone.tres")

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt: HurtComponent = $HurtComponent

@export var ore_item: Item ## 掉落的矿石
@export var stone_chance: float = 0.5
@export var coal_chance: float = 0.15
@export var gem_item: Item ## 稀有宝石掉落（深层矿洞）
@export var gem_chance: float = 0.0

func _ready() -> void:
	hurt.tool = Item.ItemType.Draft
	hurt.max_health = 3
	if ore_item:
		sprite.texture = ore_item.texture
	hurt.body_droped.connect(_on_broken)
	hurt.damage_taken.connect(_on_hit)

func _on_hit(_damage: int, _source: Vector2) -> void:
	# 受击闪白
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _on_broken() -> void:
	_drop(ore_item)
	QuestSystem.report("mine")
	if randf() < stone_chance:
		_drop(STONE)
	if randf() < coal_chance:
		_drop(COAL)
	if gem_item and randf() < gem_chance:
		_drop(gem_item)
	# 碎裂动画：缩小淡出
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _drop(item: Item) -> void:
	var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
	if !drops:
		drops = get_parent()
	fall_ins.is_bezier = true
	fall_ins.position = global_position
	drops.add_child(fall_ins)
	fall_ins.generate(item)
