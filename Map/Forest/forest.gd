extends Node2D
class_name Forest
## 森林：程序生成——草地+池塘（可钓鱼）+交互树+采集物+怪物

const GROUND_SOURCE: int = 1
const GROUND_TILE := Vector2i(1, 7)
const WATER_TILES: Array[Vector2i] = [Vector2i(8,13), Vector2i(9,13), Vector2i(10,13), Vector2i(11,13)]
const POND_RECT: Rect2i = Rect2i(62, 42, 8, 6)
const TREE = preload("res://Terrain/Trees/trees.tscn")
const FORAGE_NODE = preload("res://Placeables/Forage/forage_node.tscn")
const FORAGE_ITEMS = [
	preload("res://Bag/items/forage/树莓.tres"),
	preload("res://Bag/items/forage/蘑菇.tres"),
	preload("res://Bag/items/forage/野葱.tres"),
]

@onready var ground: TileMapLayer = $Ground
@onready var water_layer: TileMapLayer = $Water
@onready var trees_container: Node2D = $Trees
@onready var forage_container: Node2D = $Forage

@export var map_size: Vector2i = Vector2i(80, 60)

func _ready() -> void:
	_generate_ground()
	_generate_walls()
	_paint_pond()
	_spawn_trees()
	_spawn_forage()

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

## 森林池塘（可钓鱼）
func _paint_pond() -> void:
	var i := 0
	for y in range(POND_RECT.position.y, POND_RECT.end.y):
		for x in range(POND_RECT.position.x, POND_RECT.end.x):
			water_layer.set_cell(Vector2i(x, y), GROUND_SOURCE, WATER_TILES[i % WATER_TILES.size()])
			i += 1
	var barrier := StaticBody2D.new()
	barrier.name = "PondBarrier"
	barrier.collision_layer = 2
	barrier.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(POND_RECT.size.x * 16.0, POND_RECT.size.y * 16.0)
	shape.shape = rect
	shape.position = Vector2(POND_RECT.position.x * 16.0 + rect.size.x / 2.0, POND_RECT.position.y * 16.0 + rect.size.y / 2.0)
	barrier.add_child(shape)
	add_child(barrier)

func _spawn_trees() -> void:
	var count := 14
	for i in count:
		var cell := Vector2i(randi_range(2, map_size.x - 3), randi_range(2, map_size.y - 3))
		if POND_RECT.has_point(cell):
			continue
		var tree := TREE.instantiate()
		tree.position = ground.map_to_local(cell)
		trees_container.add_child(tree)

func _spawn_forage() -> void:
	for i in 5:
		var node := FORAGE_NODE.instantiate() as ForageNode
		node.item = FORAGE_ITEMS.pick_random()
		node.global_position = Vector2(randf_range(60.0, map_size.x * 16.0 - 60.0), randf_range(60.0, map_size.y * 16.0 - 60.0))
		forage_container.add_child(node)
