extends Control
class_name MiniShop
## 迷你商店：商品行（复用商店商品行）+ 出售 + 关闭

const COMMODITY = preload("res://Map/Store/commodity.tscn")

@onready var v_box: VBoxContainer = $Panel/VBoxContainer
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton

@export var inventorys:Array = [] ## Array[Item]

func _ready() -> void:
	for i in inventorys.size():
		var commodity = COMMODITY.instantiate()
		v_box.add_child(commodity)
		commodity.set_item(inventorys[i])
	sell_button.pressed.connect(_on_sell_pressed)
	close_button.pressed.connect(func(): visible = false)

func _on_sell_pressed() -> void:
	var mouse = MouseItem.mouse_item
	if mouse == null:
		Global.show_message("没有要出售的物品")
		return
	var price: int = int(mouse.price * 0.5)
	Global.gold += price
	Global.show_message("出售了 %s，获得 %d 金币" % [mouse.name, price])
	MouseItem.mouse_item = null
	var ui_manager = get_node(Global.root_scene["ui_manager"])
	var mouse_item_ui = ui_manager.find_child("MouseItem") as MouseItem
	if mouse_item_ui:
		mouse_item_ui.set_item(null)
