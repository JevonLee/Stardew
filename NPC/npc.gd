extends CharacterBody2D
class_name NPC
## 村民基类：对话 + 好感度 + 送礼
## 右键：手持可赠送物品时送礼，否则对话

const DIALOGUE_UI = preload("res://NPC/dialogue/dialogue_ui.tscn")

@export var click_area:ClickAreaComponent
@export var dialogue:Dialogue
@export var npc_display_name:String = "村民"

var is_dialogue:bool = false

func _ready() -> void:
	if click_area:
		click_area.mouse_right_click.connect(on_mouse_right_click)

func on_mouse_right_click() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null: return
	if global_position.distance_to(player.global_position) > 70.0: return
	# 送礼优先：手里有可赠送物品
	if player.current_item != null and _is_giftable(player.current_item):
		_give_gift(player)
		return
	_talk(player)

func _is_giftable(item:Item) -> bool:
	return item.type == Item.ItemType.Consume \
		or item.type == Item.ItemType.Materials \
		or item.type == Item.ItemType.Crops \
		or item.type == Item.ItemType.Accessories \
		or item.type == Item.ItemType.Floors

func _give_gift(player:Player) -> void:
	var item := player.current_item
	if item == null: return
	if not FriendshipSystem.can_gift(npc_display_name):
		Global.show_message("%s今天已经收过礼物了" % npc_display_name)
		return
	player.bag_system.remove_num_item(player.item_index, 1)
	var gain := clampi(int(item.price / 20.0) + 3, 1, 12)
	FriendshipSystem.add_hearts(npc_display_name, gain)
	Global.show_message("送给%s %s，好感度+%d！" % [npc_display_name, item.name, gain])

func _talk(player:Player) -> void:
	is_dialogue = true
	var ui = DIALOGUE_UI.instantiate()
	ui.dialogue = dialogue
	ui.npc_name_override = npc_display_name
	ui.hearts = FriendshipSystem.get_hearts(npc_display_name)
	var pop_up = get_node(Global.root_scene["pop_up"])
	pop_up.add_child(ui)
