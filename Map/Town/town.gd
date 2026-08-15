extends Node2D
class_name Town

const WATER_SOURCE_ID: int = 4 ## spring_town.zh-CN.png
const OCEAN_TILES: Array[Vector2i] = [Vector2i(12,36), Vector2i(13,36), Vector2i(12,37), Vector2i(13,37)]
const OCEAN_RECT: Rect2i = Rect2i(12, 36, 8, 6) ## 海边海洋区域（格）

const EMILY_SCENE = preload("res://NPC/emily.tscn")
const EMILY_VISIT_POS := Vector2(520, 430) ## 艾米丽中午在小镇闲逛的位置（皮埃尔商店旁）

@onready var lights: Node2D = $Light
@onready var water_layer: TileMapLayer = $Water

var town_emily: NPC = null ## 跨地图日程：中午在小镇出现的艾米丽

@export var bg_music1:AudioStream
@export var bg_music2:AudioStream #夜晚

func _ready() -> void:
	lights.hide()
	TimeSystem.time_tick.connect(func(day,hour,minute,week):
		if hour >= 18 and hour<=24:
			lights.show()
			AudioManager.play_music(bg_music2)
		)
	TimeSystem.time_tick.connect(_on_time_tick)
	AudioManager.play_music(bg_music1)
	_paint_ocean()
	_update_emily_visit()

func _on_time_tick(_day:int, _hour:int, _minute:int, _week) -> void:
	_update_emily_visit()

## 跨地图村民日程：中午（10-16点）艾米丽在小镇闲逛，其余时间回到农场
func _update_emily_visit() -> void:
	var visiting: bool = TimeSystem.current_hour >= 10 and TimeSystem.current_hour < 16
	if visiting and town_emily == null:
		var emily = EMILY_SCENE.instantiate()
		emily.visitor_mode = true
		emily.name = "EmilyTown"
		emily.position = EMILY_VISIT_POS
		add_child(emily)
		town_emily = emily as NPC
	elif not visiting and town_emily != null:
		town_emily.queue_free()
		town_emily = null

## 海边海洋（可钓鱼）
func _paint_ocean() -> void:
	var i := 0
	for y in range(OCEAN_RECT.position.y, OCEAN_RECT.end.y):
		for x in range(OCEAN_RECT.position.x, OCEAN_RECT.end.x):
			water_layer.set_cell(Vector2i(x, y), WATER_SOURCE_ID, OCEAN_TILES[i % OCEAN_TILES.size()])
			i += 1
	# 北岸阻挡（防止走入海中）
	var barrier := StaticBody2D.new()
	barrier.name = "OceanBarrier"
	barrier.collision_layer = 2
	barrier.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(OCEAN_RECT.size.x * 16.0, 16.0)
	shape.shape = rect
	shape.position = Vector2(OCEAN_RECT.position.x * 16.0 + rect.size.x / 2.0, OCEAN_RECT.position.y * 16.0)
	barrier.add_child(shape)
	add_child(barrier)
