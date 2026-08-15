extends Node2D
class_name Farm

const FORAGE_NODE = preload("res://Placeables/Forage/forage_node.tscn")
const FORAGE_ITEMS = [ ## Array[Item]
	preload("res://Bag/items/forage/树莓.tres"),
	preload("res://Bag/items/forage/蘑菇.tres"),
	preload("res://Bag/items/forage/野葱.tres"),
]

const WATER_SOURCE_ID: int = 1
const WATER_TILES: Array[Vector2i] = [Vector2i(8,13), Vector2i(9,13), Vector2i(10,13), Vector2i(11,13)]
const POND_RECT: Rect2i = Rect2i(8, 38, 8, 6) ## 池塘区域（格）

const FESTIVAL_GIFTS := {
	"蛋节": "res://Bag/items/food/煎蛋.tres",
	"月光水母节": "res://Bag/items/food/烤鱼.tres",
	"冰雪节": "res://Bag/items/food/蔬菜沙拉.tres",
}

@export var bg_music1:AudioStream

@onready var water_layer: TileMapLayer = $Water
@onready var forage_container: Node2D = $Forage

func _ready() -> void:
	AudioManager.play_music(bg_music1)
	_paint_pond()
	_spawn_forage()
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(_day:int) -> void:
	_spawn_forage()
	_check_festival()

## 节日：春13蛋节 / 春28月光水母节 / 秋25冰雪节（额外采集物+礼物）
func _check_festival() -> void:
	var season := TimeSystem.get_season()
	var day := TimeSystem.get_day_of_season()
	var festival := ""
	if season == TimeSystem.Season.SPRING and day == 13:
		festival = "蛋节"
	elif season == TimeSystem.Season.SPRING and day == 28:
		festival = "月光水母节"
	elif season == TimeSystem.Season.FALL and day == 25:
		festival = "冰雪节"
	if festival == "": return
	Global.show_message("今天是%s！节日快乐！" % festival)
	# 额外采集物
	for i in 3:
		var node := FORAGE_NODE.instantiate() as ForageNode
		node.item = FORAGE_ITEMS.pick_random()
		node.global_position = Vector2(randf_range(120.0, 2650.0), randf_range(180.0, 1450.0))
		forage_container.add_child(node)
	# 节日礼物
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player:
		var gift_path: String = FESTIVAL_GIFTS[festival]
		var gift: Item = load(gift_path).duplicate()
		player.bag_system.add_item(gift)
		Global.show_message("节日礼物：%s" % gift.name)

## 绘制池塘（水瓦片交替）+ 阻挡玩家走入
func _paint_pond() -> void:
	var i := 0
	for y in range(POND_RECT.position.y, POND_RECT.end.y):
		for x in range(POND_RECT.position.x, POND_RECT.end.x):
			water_layer.set_cell(Vector2i(x, y), WATER_SOURCE_ID, WATER_TILES[i % WATER_TILES.size()])
			i += 1
	# 隐形阻挡（层2 Objects，玩家掩码包含）
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

## 每天清晨刷新野外采集物
func _spawn_forage() -> void:
	for child in forage_container.get_children():
		child.queue_free()
	var count := randi_range(4, 7)
	for i in count:
		var node := FORAGE_NODE.instantiate() as ForageNode
		node.item = FORAGE_ITEMS.pick_random()
		node.global_position = Vector2(randf_range(120.0, 2650.0), randf_range(180.0, 1450.0))
		forage_container.add_child(node)
