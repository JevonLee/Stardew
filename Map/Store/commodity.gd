extends PanelContainer
class_name Commodity
##商品

@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var texture: TextureRect = %Texture
@onready var c_name: Label = %CName
@onready var control: Control = %Control
@onready var price: Label = %Price
@onready var coin: TextureRect = %Coin

var item:Item

func _ready() -> void:
	h_box_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in h_box_container.get_children():
		i = i as Control
		i.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_item(item:Item) ->void:
	self.item = item
	if item != null:
		texture.texture = item.texture
		c_name.text = item.name
		price.text = str(item.price)

func _gui_input(event: InputEvent) -> void:
	var ui_manager = get_node(Global.root_scene["ui_manager"])
	var mouse_item = ui_manager.find_child("MouseItem") as MouseItem
	if event.is_action_pressed("mouse_left"):
		if Global.gold < item.price:
			price.modulate = Color(1, 0.3, 0.3)
			price.text = "金币不足"
			await get_tree().create_timer(0.6).timeout
			price.modulate = Color.WHITE
			price.text = str(item.price)
			return
		Global.gold -= item.price
		if MouseItem.mouse_item == null:
			MouseItem.mouse_item = item.duplicate()
			mouse_item.set_item(MouseItem.mouse_item)
		elif MouseItem.mouse_item != null:
			MouseItem.mouse_item.quantity += 1
			mouse_item.set_item(MouseItem.mouse_item)
			#和player之前item的接触就会有问题,
