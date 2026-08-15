extends Node2D
class_name Dungeon
## 地牢：泰拉瑞亚地牢主题——木地板+宝箱+骷髅军团（室内地图）

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(2,2), Vector2i(3,2),
	Vector2i(2,3), Vector2i(3,3), Vector2i(1,5), Vector2i(2,5), Vector2i(3,5),
	Vector2i(1,6), Vector2i(2,6), Vector2i(3,6),
]
const WALL_TILES: Array[Vector2i] = [Vector2i(0,2), Vector2i(0,3), Vector2i(4,5)]
const CHEST_LOOT = [ ## 地牢宝箱
	preload("res://Bag/items/materials/金锭.tres"),
	preload("res://Bag/items/materials/蓝宝石.tres"),
	preload("res://Bag/items/materials/黄玉.tres"),
	preload("res://Bag/items/food/果酒.tres"),
]

@onready var ground: TileMapLayer = $Ground

@export var map_size: Vector2i = Vector2i(40, 30)

func _ready() -> void:
	var ts := _build_tileset()
	ground.tile_set = ts
	_generate()
	_spawn_chest()

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://Art/maps/townInterior.zh-CN.png")
	atlas.texture_region_size = Vector2i(16, 16)
	for c in FLOOR_TILES:
		atlas.create_tile(c)
	for c in WALL_TILES:
		atlas.create_tile(c)
	ts.add_source(atlas, 0)
	return ts

func _generate() -> void:
	for y in map_size.y:
		for x in map_size.x:
			if x == 0 or y == 0 or x == map_size.x - 1 or y == map_size.y - 1:
				ground.set_cell(Vector2i(x, y), 0, WALL_TILES.pick_random())
			else:
				ground.set_cell(Vector2i(x, y), 0, FLOOR_TILES.pick_random())
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

## 中央地牢宝箱（金锭/宝石/果酒）
func _spawn_chest() -> void:
	var box_scene: PackedScene = load("res://Bag/scene/box.tscn")
	var box := box_scene.instantiate() as Box
	var chest_inv := InventorySystem.new()
	chest_inv.items_size = 9
	chest_inv.items.resize(9)
	for i in mini(CHEST_LOOT.size(), chest_inv.items_size):
		chest_inv.items[i] = CHEST_LOOT[i].duplicate()
	box.box_system = chest_inv
	box.position = Vector2(map_size.x * 8.0, map_size.y * 8.0)
	add_child(box)
