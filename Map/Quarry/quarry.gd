extends Node2D
class_name Quarry
## 采石场：矿石富集区——大量矿石节点与石头（敲矿练采矿技能）

const GROUND_SOURCE: int = 1
const GROUND_TILE := Vector2i(1, 7)
const ORE_NODE = preload("res://Terrain/Ores/ore_node.tscn")
const ROCK = preload("res://Terrain/Rocks/rock.tscn")
const ORES := [
	preload("res://Bag/items/materials/铜矿石.tres"),
	preload("res://Bag/items/materials/铁矿石.tres"),
	preload("res://Bag/items/materials/银矿石.tres"),
	preload("res://Bag/items/materials/金矿石.tres"),
]
const GEMS := [
	preload("res://Bag/items/materials/紫水晶.tres"),
	preload("res://Bag/items/materials/蓝宝石.tres"),
	preload("res://Bag/items/materials/黄玉.tres"),
]

@onready var ground: TileMapLayer = $Ground
@onready var ores_container: Node2D = $Ores

@export var map_size: Vector2i = Vector2i(40, 30)

func _ready() -> void:
	_generate_ground()
	_generate_walls()
	_spawn_ores()

func _generate_ground() -> void:
	for y in map_size.y:
		for x in map_size.x:
			ground.set_cell(Vector2i(x, y), GROUND_SOURCE, GROUND_TILE)

func _generate_walls() -> void:
	var wall := StaticBody2D.new()
	wall.name = "Walls"
	wall.collision_layer = 2
	wall.collision_mask = 1
	add_child(wall)
	var wall_defs := [
		{ "pos": Vector2(map_size.x * 8.0, 0.0), "size": Vector2(map_size.x * 16.0 + 32.0, 32.0) },
		{ "pos": Vector2(0.0, map_size.y * 8.0), "size": Vector2(32.0, map_size.y * 16.0 + 32.0) },
		{ "pos": Vector2(map_size.x * 8.0, map_size.y * 16.0), "size": Vector2(map_size.x * 16.0 + 32.0, 32.0) },
		{ "pos": Vector2(map_size.x * 16.0, map_size.y * 8.0), "size": Vector2(32.0, map_size.y * 16.0 + 32.0) },
	]
	for w in wall_defs:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w["size"]
		shape.shape = rect
		shape.position = w["pos"]
		wall.add_child(shape)

## 24个矿石节点（铜/铁/银/金）+ 8块可敲石头 + 宝石掉落
func _spawn_ores() -> void:
	for i in 24:
		var cell := Vector2i(randi_range(2, map_size.x - 3), randi_range(2, map_size.y - 3))
		var node := ORE_NODE.instantiate() as OreNode
		node.ore_item = ORES.pick_random()
		if randf() < 0.35:
			node.gem_item = GEMS.pick_random()
			node.gem_chance = 0.2
		node.position = ground.map_to_local(cell)
		ores_container.add_child(node)
	for i in 8:
		var cell := Vector2i(randi_range(2, map_size.x - 3), randi_range(2, map_size.y - 3))
		var rock := ROCK.instantiate()
		rock.position = ground.map_to_local(cell)
		ores_container.add_child(rock)
