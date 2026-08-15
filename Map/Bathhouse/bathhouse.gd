extends Node2D
class_name Bathhouse
## 温泉：泡澡恢复体力与生命（星露谷经典休闲地点）

const TEX = preload("res://Art/maps/bathhouse_tiles.zh-CN.png")
## 蓝色墙壁
const WALL_TILES: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(6,0), Vector2i(0,1), Vector2i(14,1)]
## 蓝灰地砖
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(10,5), Vector2i(11,5), Vector2i(14,5), Vector2i(10,6), Vector2i(11,6),
	Vector2i(12,6), Vector2i(13,6), Vector2i(10,7), Vector2i(11,7), Vector2i(12,7),
	Vector2i(13,7), Vector2i(5,6), Vector2i(5,7),
]
## 温泉水（浅蓝白）
const WATER_TILES: Array[Vector2i] = [
	Vector2i(2,5), Vector2i(3,5), Vector2i(2,6), Vector2i(3,6),
	Vector2i(4,5), Vector2i(5,5), Vector2i(4,4), Vector2i(2,4), Vector2i(6,6),
]
## 池边深蓝
const EDGE_TILES: Array[Vector2i] = [Vector2i(0,1), Vector2i(1,1), Vector2i(4,1), Vector2i(5,1), Vector2i(1,2), Vector2i(6,1)]
## 木柜装饰
const WOOD_TILES: Array[Vector2i] = [
	Vector2i(10,8), Vector2i(11,8), Vector2i(12,8),
	Vector2i(10,9), Vector2i(11,9), Vector2i(12,9),
	Vector2i(10,10), Vector2i(11,10), Vector2i(12,10),
]
const POOL_RECT: Rect2i = Rect2i(8, 7, 14, 10) ## 水池区域（格）

@onready var ground: TileMapLayer = $Ground
@onready var pool: TileMapLayer = $Pool
@onready var pool_area: Area2D = $PoolArea

var regen_timer: float = 0.0
var in_pool: bool = false

@export var map_size: Vector2i = Vector2i(30, 24)

func _ready() -> void:
	var ts := _build_tileset()
	ground.tile_set = ts
	pool.tile_set = ts
	_generate()
	pool_area.body_entered.connect(_on_pool_entered)
	pool_area.body_exited.connect(_on_pool_exited)

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TEX
	atlas.texture_region_size = Vector2i(16, 16)
	var all: Array[Vector2i] = []
	all.append_array(WALL_TILES)
	all.append_array(FLOOR_TILES)
	all.append_array(WATER_TILES)
	all.append_array(EDGE_TILES)
	all.append_array(WOOD_TILES)
	for c in all:
		if not atlas.has_tile(c):
			atlas.create_tile(c)
	ts.add_source(atlas, 0)
	return ts

func _generate() -> void:
	# 墙圈
	for y in map_size.y:
		for x in map_size.x:
			if x == 0 or y == 0 or x == map_size.x - 1 or y == map_size.y - 1:
				ground.set_cell(Vector2i(x, y), 0, WALL_TILES.pick_random())
			else:
				ground.set_cell(Vector2i(x, y), 0, FLOOR_TILES.pick_random())
	# 池边（水池外围一圈深蓝边）
	for y in range(POOL_RECT.position.y - 1, POOL_RECT.end.y + 1):
		for x in range(POOL_RECT.position.x - 1, POOL_RECT.end.x + 1):
			if POOL_RECT.has_point(Vector2i(x, y)):
				continue
			if x >= POOL_RECT.position.x - 1 and x <= POOL_RECT.end.x and y >= POOL_RECT.position.y - 1 and y <= POOL_RECT.end.y:
				ground.set_cell(Vector2i(x, y), 0, EDGE_TILES.pick_random())
	# 水池
	var i := 0
	for y in range(POOL_RECT.position.y, POOL_RECT.end.y):
		for x in range(POOL_RECT.position.x, POOL_RECT.end.x):
			pool.set_cell(Vector2i(x, y), 0, WATER_TILES[i % WATER_TILES.size()])
			i += 1
	# 木柜（左下角）
	for c in WOOD_TILES:
		var pos := Vector2i(c.x + 2, c.y + 12)
		if pos.x < map_size.x and pos.y < map_size.y:
			ground.set_cell(pos, 0, WOOD_TILES[0])

func _on_pool_entered(body: Node2D) -> void:
	if body is Player:
		in_pool = true
		Global.show_message("温泉好舒服！体力正在恢复……")

func _on_pool_exited(body: Node2D) -> void:
	if body is Player:
		in_pool = false

func _process(delta: float) -> void:
	if not in_pool: return
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player == null: return
	regen_timer += delta
	if regen_timer >= 0.5:
		regen_timer = 0.0
		player.heal(2, 10, 0) ## 每0.5秒 +2生命 +10体力
