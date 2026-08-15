extends Node2D
class_name Mine
## 矿洞：多层结构，深度越深矿石越稀有，敌人越强

const GROUND_SOURCE: int = 1
const GROUND_TILE := Vector2i(1, 7)
const ORE_NODE = preload("res://Terrain/Ores/ore_node.tscn")
const ORES := {
	"copper": preload("res://Bag/items/materials/铜矿石.tres"),
	"iron": preload("res://Bag/items/materials/铁矿石.tres"),
	"silver": preload("res://Bag/items/materials/银矿石.tres"),
	"gold": preload("res://Bag/items/materials/金矿石.tres"),
}
const SLIME = preload("res://Combat/slime.tscn")
const BAT = preload("res://Combat/bat.tscn")
const SKELETON = preload("res://Combat/skeleton.tscn")
const DEMON_EYE = preload("res://Combat/demon_eye.tscn")
const LADDER = preload("res://Map/Mine/ladder.tscn")

@onready var ground: TileMapLayer = $Ground
@onready var ores_container: Node2D = $Ores
@onready var spawner: EnemySpawner = $EnemySpawner

@export var map_size: Vector2i = Vector2i(48, 36)

var floor_index: int = 1

func _ready() -> void:
	floor_index = Global.mine_floor
	Global.mine_floor = 1
	_generate_ground()
	_generate_walls()
	_spawn_ores()
	_setup_enemies()
	_setup_ladders()
	# 深度色调变暗
	var depth_tint := 1.0 - 0.05 * (floor_index - 1)
	ground.self_modulate = Color(depth_tint, depth_tint, depth_tint)

## 当前层矿石池（越深越稀有）
func _ore_pool() -> Array:
	match floor_index:
		1: return [ORES["copper"], ORES["copper"], ORES["copper"], ORES["iron"]]
		2: return [ORES["iron"], ORES["iron"], ORES["copper"], ORES["silver"]]
		3: return [ORES["silver"], ORES["iron"], ORES["gold"]]
		_: return [ORES["gold"], ORES["gold"], ORES["silver"], ORES["silver"]]

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

func _spawn_ores() -> void:
	var pool := _ore_pool()
	var count := 24 + floor_index * 4
	for i in count:
		var cell := Vector2i(randi_range(3, map_size.x - 4), randi_range(3, map_size.y - 4))
		var node := ORE_NODE.instantiate() as OreNode
		node.ore_item = pool.pick_random()
		node.position = ground.map_to_local(cell)
		ores_container.add_child(node)

## 每层敌人配置：深度越深越强
func _setup_enemies() -> void:
	match floor_index:
		1:
			spawner.enemy_scenes = [SLIME, SLIME, BAT]
		2:
			spawner.enemy_scenes = [SKELETON, SLIME, BAT]
		_:
			spawner.enemy_scenes = [SKELETON, DEMON_EYE, BAT, BAT]

## 楼梯：底部深入，顶部返回（第一层没有返回梯）
func _setup_ladders() -> void:
	var down := LADDER.instantiate() as Ladder
	down.direction = 1
	down.position = ground.map_to_local(Vector2i(map_size.x / 2, map_size.y - 2))
	add_child(down)
	if floor_index > 1:
		var up := LADDER.instantiate() as Ladder
		up.direction = -1
		up.position = ground.map_to_local(Vector2i(map_size.x / 2, 2))
		add_child(up)
