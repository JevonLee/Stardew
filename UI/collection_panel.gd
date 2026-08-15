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
@onready var ach_list: VBoxContainer = $Panel/AchScroll/AchList
@onready var museum_label: Label = $Panel/MuseumLabel
@onready var museum_list: Label = $Panel/MuseumList

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
	# 成就
	for c in ach_list.get_children():
		c.queue_free()
	for a in AchievementSystem.ACHIEVEMENTS:
		var label := Label.new()
		var got: bool = AchievementSystem.is_unlocked(a["id"])
		label.text = ("✓ " if got else "✗ ") + a["name"] + "：" + a["desc"]
		label.modulate = Color.WHITE if got else Color(0.45, 0.45, 0.45)
		ach_list.add_child(label)
	# 博物馆
	museum_label.text = "博物馆捐赠：%d 件" % MuseumSystem.total_donated()
	var museum_text: String = ""
	for name in MuseumSystem.donated:
		museum_text += "%s × %d\n" % [name, MuseumSystem.donated[name]]
	museum_list.text = museum_text if museum_text != "" else "（还没有捐赠）"
