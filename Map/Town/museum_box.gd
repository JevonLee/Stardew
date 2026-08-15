extends Area2D
class_name MuseumBox
## 博物馆捐赠箱：右键手持宝石/材料捐赠

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

var player_near: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_near = true
		Global.show_message("博物馆捐赠箱：右键捐赠贵重物品")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_near = false

func _unhandled_input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("mouse_right"):
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player == null or player.current_item == null: return
		if MuseumSystem.donate(player.current_item):
			player.bag_system.remove_num_item(player.item_index, 1)
