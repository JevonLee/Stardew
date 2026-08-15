extends Placeable
class_name PreservesJar
## 罐头瓶：手持蔬菜/水果右键放入，3天后制成罐头（随存档保存）

const CANNED = preload("res://Bag/items/food/罐头.tres")
## 按放入的食材产出对应罐头（未知食材产通用罐头）
const JAR_MAP := {
	"南瓜": preload("res://Bag/items/food/南瓜罐头.tres"),
	"蓝莓": preload("res://Bag/items/food/蓝莓罐头.tres"),
	"玉米": preload("res://Bag/items/food/玉米罐头.tres"),
	"番茄": preload("res://Bag/items/food/番茄罐头.tres"),
}

var stored_name: String = ""
var placed_day: int = 0
var finish_day: int = 0
var is_processing: bool = false

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

func try_insert(player: Player) -> bool:
	if player == null: return false
	if is_processing:
		Global.show_message("罐头瓶正在加工中……")
		return false
	if player.current_item != null and (player.current_item.type == Item.ItemType.Crops or player.current_item.type == Item.ItemType.Consume):
		stored_name = player.current_item.name
		player.bag_system.remove_num_item(player.item_index, 1)
		placed_day = TimeSystem.current_day
		finish_day = placed_day + 3
		is_processing = true
		Global.show_message("已放入%s，3天后制成罐头" % stored_name)
		return true
	Global.show_message("手持蔬菜或水果右键罐头瓶")
	return false

func _on_new_day(day: int) -> void:
	if is_processing and day >= finish_day:
		is_processing = false
		_spawn_canned()

func _spawn_canned() -> void:
	var fall := Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops := get_node_or_null(Global.root_scene["drops"]) as Node2D
	if drops == null:
		drops = get_parent()
	fall.position = global_position + Vector2(0, -24)
	drops.add_child(fall)
	var canned: Item = JAR_MAP.get(stored_name, CANNED)
	fall.generate(canned)
	Global.show_message("%s做好了！" % canned.name)
