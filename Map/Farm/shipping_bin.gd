extends Area2D
class_name ShippingBin
## 出货箱：手持物品右键放入，当晚自动按价卖出（星露谷经典经济系统）

var player: Player

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(func(b: Node2D) -> void:
		if b is Player:
			Global.show_message("出货箱：手持物品右键放入，晚上统一卖出")
		)
	TimeSystem.time_tick_day.connect(_on_new_day)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_right"):
		var p := get_tree().get_first_node_in_group("Player") as Player
		if p == null: return
		if global_position.distance_to(p.global_position) > 80.0: return
		if p.current_item == null:
			Global.show_message("手里没有物品")
			return
		var item := p.current_item.duplicate()
		item.quantity = 1
		Global.shipping_pending.append(item)
		p.bag_system.remove_num_item(p.item_index, 1)
		Global.show_message("已放入出货箱：%s（晚上卖出）" % item.name)

## 夜晚结算：所有待售物品按价卖出
func _on_new_day(_day: int) -> void:
	if Global.shipping_pending.is_empty(): return
	var total := 0
	for item in Global.shipping_pending:
		total += item.price
	Global.shipping_pending.clear()
	Global.gold += total
	Global.show_message("出货收入：%d 金币！" % total)
