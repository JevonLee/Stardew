extends Crop
class_name Sprinkler
## 洒水器：种植在耕地上（作为作物放置），每天清晨自动浇灌四周的格子

const SPRINKLER_ITEM = preload("res://Bag/items/placeables/洒水器.tres")

var watered_cells: Array[Vector2i] = []

func _ready() -> void:
	# 不调用super（不走作物生长逻辑），自行解析农场引用
	farm = get_parent().get_parent() as Node2D
	if farm:
		water_soil = farm.get_node_or_null("WaterSoil") as TileMapLayer
	TimeSystem.time_tick_day.connect(_on_day_change)
	hurt_component.tool = Item.ItemType.Draft
	hurt_component.max_health = 1
	hurt_component.body_droped.connect(_on_broken)
	area_2d.body_entered.connect(_on_body_entered)

func _on_day_change(_day:int) -> void:
	# 延后浇水：在土壤变干之后执行，保证当天土壤保持湿润
	call_deferred("_water_neighbors")

func _water_neighbors() -> void:
	if water_soil == null: return
	watered_cells.clear()
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for offset in offsets:
		var c: Vector2i = cell + offset
		water_soil.set_cells_terrain_connect([c], 0, 4, true)
		watered_cells.append(c)

## 被镐子敲掉：归还一个洒水器
func _on_broken() -> void:
	_drop_item(SPRINKLER_ITEM)
	queue_free()

func _on_body_entered(_body: Node2D) -> void:
	pass # 无需摇摆特效
