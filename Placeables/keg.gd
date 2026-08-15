extends Placeable
class_name Keg
## 酿酒桶：手持水果右键放入，7天后酿成一瓶果酒（随存档保存）

const WINE = preload("res://Bag/items/food/果酒.tres")
## 按放入的水果产出对应果酒（未知水果产通用果酒）
const WINE_MAP := {
	"蓝莓": preload("res://Bag/items/food/蓝莓酒.tres"),
	"苹果": preload("res://Bag/items/food/苹果酒.tres"),
	"南瓜": preload("res://Bag/items/food/南瓜酒.tres"),
	"蔓越莓": preload("res://Bag/items/food/蔓越莓酒.tres"),
}

var stored_name: String = "" ## 放入的水果名（提示用）
var placed_day: int = 0
var finish_day: int = 0 ## 酿成日（绝对天数）
var is_brewing: bool = false

func _ready() -> void:
	super()
	if placed_day <= 0:
		placed_day = TimeSystem.current_day
	TimeSystem.time_tick_day.connect(_on_new_day)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_right"):
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player == null: return
		if global_position.distance_to(player.global_position) > 90.0: return
		try_insert(player)

## 放入手持水果（返回是否成功）
func try_insert(player: Player) -> bool:
	if player == null: return false
	if is_brewing:
		Global.show_message("酒桶正在酿造中……")
		return false
	if player.current_item != null and (player.current_item.type == Item.ItemType.Crops or player.current_item.type == Item.ItemType.Consume):
		stored_name = player.current_item.name
		player.bag_system.remove_num_item(player.item_index, 1)
		placed_day = TimeSystem.current_day
		finish_day = placed_day + 7
		is_brewing = true
		Global.show_message("已放入%s，7天后酿成果酒" % stored_name)
		return true
	Global.show_message("手持水果右键酒桶开始酿酒")
	return false

func _on_new_day(day: int) -> void:
	if is_brewing and day >= finish_day:
		is_brewing = false
		_spawn_wine()

func _spawn_wine() -> void:
	var fall := Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops := get_node_or_null(Global.root_scene["drops"]) as Node2D
	if drops == null:
		drops = get_parent()
	fall.position = global_position + Vector2(0, -24)
	drops.add_child(fall)
	var wine: Item = WINE_MAP.get(stored_name, WINE)
	fall.generate(wine)
	Global.show_message("%s酿好了！" % wine.name)
