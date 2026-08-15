extends Node2D
class_name Desert
## 沙漠：程序生成——沙地 + 绿洲（可钓鱼）+ 仙人掌 + 怪物

const DESERT_TEX = preload("res://Art/StardewValley/maps/DesertTiles.zh-CN.png")
const SAND_TILES: Array[Vector2i] = [
	Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
	Vector2i(1,2), Vector2i(0,3), Vector2i(2,3), Vector2i(0,4), Vector2i(2,4),
	Vector2i(0,5), Vector2i(1,5), Vector2i(2,5),
]
const WATER_TILES: Array[Vector2i] = [
	Vector2i(12,6), Vector2i(14,6), Vector2i(15,6), Vector2i(12,7),
	Vector2i(13,7), Vector2i(14,7), Vector2i(15,7), Vector2i(12,8),
]
const DECOR_TILES: Array[Vector2i] = [
	Vector2i(3,3), Vector2i(1,6), Vector2i(2,6), Vector2i(3,6), Vector2i(1,7),
	Vector2i(2,7), Vector2i(3,7), Vector2i(1,8), Vector2i(2,8), Vector2i(3,8),
	Vector2i(4,8), Vector2i(4,9), Vector2i(4,10), Vector2i(2,11), Vector2i(3,11),
	Vector2i(4,11), Vector2i(5,11),
]
const OASIS_RECT: Rect2i = Rect2i(52, 36, 6, 4)

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var oasis: TileMapLayer = $Oasis

@export var map_size: Vector2i = Vector2i(70, 50)

func _ready() -> void:
	var ts := _build_tileset()
	ground.tile_set = ts
	decor.tile_set = ts
	oasis.tile_set = ts
	_generate_ground()
	_generate_walls()
	_paint_oasis()
	_decorate()

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = DESERT_TEX
	atlas.texture_region_size = Vector2i(16, 16)
	var all: Array[Vector2i] = []
	all.append_array(SAND_TILES)
	all.append_array(WATER_TILES)
	all.append_array(DECOR_TILES)
	for c in all:
		atlas.create_tile(c)
	ts.add_source(atlas, 0)
	return ts

func _generate_ground() -> void:
	for y in map_size.y:
		for x in map_size.x:
			ground.set_cell(Vector2i(x, y), 0, SAND_TILES.pick_random())

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

## 绿洲（可钓鱼）
func _paint_oasis() -> void:
	var i := 0
	for y in range(OASIS_RECT.position.y, OASIS_RECT.end.y):
		for x in range(OASIS_RECT.position.x, OASIS_RECT.end.x):
			oasis.set_cell(Vector2i(x, y), 0, WATER_TILES[i % WATER_TILES.size()])
			i += 1
	var barrier := StaticBody2D.new()
	barrier.name = "OasisBarrier"
	barrier.collision_layer = 2
	barrier.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(OASIS_RECT.size.x * 16.0, 16.0)
	shape.shape = rect
	shape.position = Vector2(OASIS_RECT.position.x * 16.0 + rect.size.x / 2.0, OASIS_RECT.position.y * 16.0)
	barrier.add_child(shape)
	add_child(barrier)

## 仙人掌等装饰
func _decorate() -> void:
	for i in 26:
		var cell := Vector2i(randi_range(2, map_size.x - 3), randi_range(2, map_size.y - 3))
		if OASIS_RECT.has_point(cell):
			continue
		decor.set_cell(cell, 0, DECOR_TILES.pick_random())
