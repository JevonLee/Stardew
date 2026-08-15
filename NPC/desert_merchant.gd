extends NPC
## 沙漠商人：点击打开稀有商品商店

const SHOP = preload("res://UI/mini_shop.tscn")
const SHOP_ITEMS = [
	preload("res://Bag/items/weapon/紫水晶法杖.tres"),
	preload("res://Bag/items/weapon/金剑.tres"),
	preload("res://Bag/items/weapon/圣剑.tres"),
	preload("res://Bag/items/weapon/水刃书.tres"),
	preload("res://Bag/items/materials/金锭.tres"),
	preload("res://Bag/items/materials/银锭.tres"),
	preload("res://Bag/items/materials/蓝宝石.tres"),
	preload("res://Bag/items/materials/黄玉.tres"),
]

var shop: Control

func _ready() -> void:
	super()
	# 右键改为打开商店
	click_area.mouse_right_click.disconnect(on_mouse_right_click)
	click_area.mouse_right_click.connect(_open_shop)

func _open_shop() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null: return
	if global_position.distance_to(player.global_position) > 80.0: return
	if shop == null:
		shop = SHOP.instantiate()
		shop.inventorys = SHOP_ITEMS
		var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
		if canvas:
			canvas.add_child(shop)
		else:
			add_child(shop)
	shop.visible = true
