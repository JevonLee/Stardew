extends Control
class_name CollectionPanel
## 图鉴面板：鱼类图鉴 + 敌人图鉴 + 物品收集统计

const ALL_FISH = [
	preload("res://Fishing/fish_data/沙丁鱼_data.tres"),
	preload("res://Fishing/fish_data/鲤鱼_data.tres"),
	preload("res://Fishing/fish_data/大嘴鲈鱼_data.tres"),
]

@onready var fish_list: VBoxContainer = $Panel/FishScroll/FishList
@onready var enemy_list: VBoxContainer = $Panel/EnemyScroll/EnemyList
@onready var item_count_label: Label = $Panel/ItemCount

func _ready() -> void:
	CollectionSystem.collection_changed.connect(refresh)

func refresh() -> void:
	for c in fish_list.get_children():
		c.queue_free()
	for c in enemy_list.get_children():
		c.queue_free()
	# 鱼类图鉴
	for fish in ALL_FISH:
		var label := Label.new()
		var caught: bool = CollectionSystem.fish_caught.has(fish.fish_name)
		label.text = ("✓ " if caught else "✗ ") + fish.fish_name
		label.modulate = Color.WHITE if caught else Color(0.45, 0.45, 0.45)
		fish_list.add_child(label)
	# 敌人图鉴
	for name in CollectionSystem.enemies_killed:
		var label := Label.new()
		label.text = "%s × %d" % [name, CollectionSystem.enemies_killed[name]]
		enemy_list.add_child(label)
	# 物品统计
	item_count_label.text = "已收集 %d 种物品" % CollectionSystem.items_collected.size()
