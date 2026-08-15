extends Node2D
class_name Beach
## 海滩：程序生成——沙滩 + 大海（可钓鱼）+ 椰子树
## 瓦片来源：spring_outdoorsTileSheet2（沙滩/浪花/草丛）+ spring_town（海洋）

const SHEET2_TEX = preload("res://Art/maps/spring_outdoorsTileSheet2.png")
const TOWN_TEX = preload("res://Art/maps/spring_town.zh-CN.png")
## 沙滩瓦片（sheet2 沙丘区）
const SAND_TILES: Array[Vector2i] = [
	Vector2i(2,23), Vector2i(5,23), Vector2i(6,23), Vector2i(7,23), Vector2i(11,23),
	Vector2i(0,24), Vector2i(1,24), Vector2i(2,24), Vector2i(3,24), Vector2i(4,24),
	Vector2i(1,25), Vector2i(9,25), Vector2i(1,26), Vector2i(2,26),
	Vector2i(0,28), Vector2i(2,28), Vector2i(0,31), Vector2i(1,31), Vector2i(2,31), Vector2i(3,31),
]
## 沙地草丛装饰
const GRASS_TILES: Array[Vector2i] = [
	Vector2i(4,23), Vector2i(8,23), Vector2i(10,23), Vector2i(9,24), Vector2i(10,24), Vector2i(11,24),
	Vector2i(1,27), Vector2i(4,27), Vector2i(6,27), Vector2i(5,28),
]
## 浪花/浅水
const FOAM_TILES: Array[Vector2i] = [Vector2i(7,34), Vector2i(10,34), Vector2i(7,36)]
## 海洋（spring_town 纯蓝水）
const OCEAN_TILES: Array[Vector2i] = [
	Vector2i(12,36), Vector2i(13,36), Vector2i(12,38), Vector2i(12,39),
	Vector2i(13,37), Vector2i(13,34), Vector2i(14,34), Vector2i(16,34), Vector2i(17,34),
]
const OCEAN_RECT: Rect2i = Rect2i(46, 12, 24, 34) ## 大海区域（格）
const PALM_REGION := Rect2(128.0, 528.0, 48.0, 208.0) ## 椰子树（sheet2 3x13 格）

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var ocean: TileMapLayer = $Ocean
@onready var palms: Node2D = $Palms

@export var map_size: Vector2i = Vector2i(72, 48)

func _ready() -> void:
	var ts := _build_tileset()
	ground.tile_set = ts
	decor.tile_set = ts
	ocean.tile_set = ts
	_generate_ground()
	_generate_walls()
	_paint_ocean()
	_decorate()
	_spawn_palms()

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = SHEET2_TEX
	atlas.texture_region_size = Vector2i(16, 16)
	var all: Array[Vector2i] = []
	all.append_array(SAND_TILES)
	all.append_array(GRASS_TILES)
	all.append_array(FOAM_TILES)
	for c in all:
		atlas.create_tile(c)
	ts.add_source(atlas, 0)
	var atlas2 := TileSetAtlasSource.new()
	atlas2.texture = TOWN_TEX
	atlas2.texture_region_size = Vector2i(16, 16)
	for c in OCEAN_TILES:
		atlas2.create_tile(c)
	ts.add_source(atlas2, 1)
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

## 大海（可钓鱼）：左/上边缘浪花，其余深蓝水；北岸与西岸阻挡
func _paint_ocean() -> void:
	var i := 0
	for y in range(OCEAN_RECT.position.y, OCEAN_RECT.end.y):
		for x in range(OCEAN_RECT.position.x, OCEAN_RECT.end.x):
			if x == OCEAN_RECT.position.x or y == OCEAN_RECT.position.y:
				ocean.set_cell(Vector2i(x, y), 0, FOAM_TILES.pick_random())
			else:
				ocean.set_cell(Vector2i(x, y), 1, OCEAN_TILES[i % OCEAN_TILES.size()])
			i += 1
	# 北岸阻挡（站在沙滩上朝海抛竿）
	var barrier := StaticBody2D.new()
	barrier.name = "OceanBarrier"
	barrier.collision_layer = 2
	barrier.collision_mask = 1
	var s1 := CollisionShape2D.new()
	var r1 := RectangleShape2D.new()
	r1.size = Vector2(OCEAN_RECT.size.x * 16.0, 16.0)
	s1.shape = r1
	s1.position = Vector2(OCEAN_RECT.position.x * 16.0 + r1.size.x / 2.0, OCEAN_RECT.position.y * 16.0)
	barrier.add_child(s1)
	# 西岸阻挡
	var s2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(16.0, OCEAN_RECT.size.y * 16.0 - 16.0)
	s2.shape = r2
	s2.position = Vector2(OCEAN_RECT.position.x * 16.0, OCEAN_RECT.position.y * 16.0 + 8.0 + r2.size.y / 2.0)
	barrier.add_child(s2)
	add_child(barrier)

## 沙地草丛
func _decorate() -> void:
	for i in 60:
		var cell := Vector2i(randi_range(1, map_size.x - 4), randi_range(1, map_size.y - 3))
		if OCEAN_RECT.grow(1).has_point(cell):
			continue
		decor.set_cell(cell, 0, GRASS_TILES.pick_random())

## 椰子树（Sprite2D裁剪 + 树干碰撞）
func _spawn_palms() -> void:
	for pos in [Vector2(260, 250), Vector2(540, 440), Vector2(180, 640), Vector2(660, 300)]:
		var palm := Node2D.new()
		palm.y_sort_enabled = true
		var spr := Sprite2D.new()
		spr.texture = SHEET2_TEX
		spr.region_enabled = true
		spr.region_rect = PALM_REGION
		spr.position = Vector2(0, -208)
		palm.add_child(spr)
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, 10)
		shape.shape = rect
		shape.position = Vector2(24, 0)
		body.add_child(shape)
		palm.add_child(body)
		palm.position = pos
		palms.add_child(palm)
