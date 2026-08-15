extends Node2D
class_name Mine
## 矿洞：运行时生成地面/围墙/矿石节点

const GROUND_SOURCE: int = 1
const GROUND_TILE := Vector2i(1, 7)
const ORE_NODE = preload("res://Terrain/Ores/ore_node.tscn")
const ORES: Array[Item] = [
	preload("res://Bag/items/materials/铜矿石.tres"),
	preload("res://Bag/items/materials/铁矿石.tres"),
	preload("res://Bag/items/materials/银矿石.tres"),
	preload("res://Bag/items/materials/金矿石.tres"),
]

@onready var ground: TileMapLayer = $Ground
@onready var ores_container: Node2D = $Ores

@export var map_size: Vector2i = Vector2i(48, 36)
@export var ore_count: int = 26

func _ready() -> void:
	_generate_ground()
	_generate_walls()
	_spawn_ores()

func _generate_ground() -> void:
	for y in map_size.y:
		for x in map_size.x:
			ground.set_cell(Vector2i(x, y), GROUND_SOURCE, GROUND_TILE)

func _generate_walls() -> void:
	# 四周围墙（层2 Objects，玩家掩码包含）
	var walls := [
		{ "pos": Vector2(map_size.x * 8.0, map_size.y * 8.0), "size": Vector2(map_size.x * 16.0 + 32.0, 32.0) }, # 北
		{ "pos": Vector2(map_size.x * 8.0, map_size.y * 8.0), "size": Vector2(32.0, map_size.y * 16.0 + 32.0) }, # 西
	]
	var wall := StaticBody2D.new()
	wall.name = "Walls"
	wall.collision_layer = 2
	wall.collision_mask = 1
	add_child(wall)
	for w in walls:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w["size"]
		shape.shape = rect
		shape.position = w["pos"]
		wall.add_child(shape)
	# 南北墙也加
	var south := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(map_size.x * 16.0 + 32.0, 32.0)
	south.shape = srect
	south.position = Vector2(map_size.x * 8.0, map_size.y * 16.0)
	wall.add_child(south)
	var east := CollisionShape2D.new()
	var erect := RectangleShape2D.new()
	erect.size = Vector2(32.0, map_size.y * 16.0 + 32.0)
	east.shape = erect
	east.position = Vector2(map_size.x * 16.0, map_size.y * 8.0)
	wall.add_child(east)

func _spawn_ores() -> void:
	for i in ore_count:
		var cell := Vector2i(randi_range(3, map_size.x - 4), randi_range(3, map_size.y - 4))
		var node := ORE_NODE.instantiate() as OreNode
		node.ore_item = ORES.pick_random()
		node.position = ground.map_to_local(cell)
		ores_container.add_child(node)
