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
const ELEVATOR = preload("res://Map/Mine/elevator.tscn")
const GEMS = [
	preload("res://Bag/items/materials/紫水晶.tres"),
	preload("res://Bag/items/materials/绿宝石.tres"),
	preload("res://Bag/items/materials/蓝宝石.tres"),
]

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
	# 每5层为宝箱层：中央一个装满战利品的宝箱
	if floor_index % 5 == 0:
		_spawn_treasure_floor()
		return
	var pool := _ore_pool()
	var count := 24 + floor_index * 4
	for i in count:
		var cell := Vector2i(randi_range(3, map_size.x - 4), randi_range(3, map_size.y - 4))
		var node := ORE_NODE.instantiate() as OreNode
		node.ore_item = pool.pick_random()
		# 深层矿洞附带宝石
		if floor_index >= 3:
			node.gem_item = GEMS.pick_random()
			node.gem_chance = 0.15
		node.position = ground.map_to_local(cell)
		ores_container.add_child(node)

## 宝箱层：中央一个宝箱（金锭/宝石/金币）
func _spawn_treasure_floor() -> void:
	var box_scene: PackedScene = load("res://Bag/scene/box.tscn")
	var box := box_scene.instantiate() as Box
	var chest_inv := InventorySystem.new()
	chest_inv.items_size = 9
	chest_inv.items.resize(9)
	var loot: Array = []
	loot.append(load("res://Bag/items/materials/金锭.tres").duplicate())
	loot.append(load("res://Bag/items/materials/金锭.tres").duplicate())
	loot.append(GEMS.pick_random().duplicate())
	for i in 3:
		loot.append(load("res://Bag/items/materials/金币.tres").duplicate())
	for i in mini(loot.size(), chest_inv.items_size):
		chest_inv.items[i] = loot[i]
	box.box_system = chest_inv
	box.position = ground.map_to_local(Vector2i(map_size.x / 2, map_size.y / 2))
	add_child(box)
	Global.show_message("发现宝箱层！")

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
	# 电梯（每层都有，可直达5/10/15/20/25/30层）
	var elevator := ELEVATOR.instantiate()
	elevator.position = ground.map_to_local(Vector2i(map_size.x / 2 + 3, 2))
	add_child(elevator)
	if floor_index > 1:
		var up := LADDER.instantiate() as Ladder
		up.direction = -1
		up.position = ground.map_to_local(Vector2i(map_size.x / 2, 2))
		add_child(up)
