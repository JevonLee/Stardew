extends Control
class_name StorePanel

const COMMODITY = preload("res://Map/Store/commodity.tscn")

@onready var v_box_container: VBoxContainer = %VBoxContainer
@onready var sell_button: Button = %SellButton

@export var inventorys:Array[Item] #商店的货物

func _ready() -> void:
	for child in v_box_container.get_children():
		child.queue_free()
	for i in inventorys.size():
		var commodity = COMMODITY.instantiate()
		v_box_container.add_child(commodity)
		commodity.set_item(inventorys[i])
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)

## 出售鼠标上拿着的物品（半价收购）
func _on_sell_pressed() -> void:
	var mouse = MouseItem.mouse_item
	if mouse == null:
		Global.show_message("没有要出售的物品")
		return
	var price:int = int(mouse.price * 0.5)
	Global.gold += price
	Global.show_message("出售了 %s，获得 %d 金币" % [mouse.name, price])
	MouseItem.mouse_item = null
	var ui_manager = get_node(Global.root_scene["ui_manager"])
	var mouse_item_ui = ui_manager.find_child("MouseItem") as MouseItem
	if mouse_item_ui:
		mouse_item_ui.set_item(null)
