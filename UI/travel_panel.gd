extends Control
class_name TravelPanel
## 传送面板：M键打开，快速前往已探索区域

@onready var v_box: VBoxContainer = $Panel/ScrollContainer/VBoxContainer

const DESTINATIONS := [
	{"name": "农场", "level": "Farm", "spawn": "SpawnPosition"},
	{"name": "小镇", "level": "Town", "spawn": "SpawnPosition"},
	{"name": "矿洞", "level": "Mine", "spawn": "SpawnPosition"},
	{"name": "森林", "level": "Forest", "spawn": "SpawnPosition"},
	{"name": "沙漠", "level": "Desert", "spawn": "SpawnPosition"},
	{"name": "海滩", "level": "Beach", "spawn": "SpawnPosition"},
	{"name": "温泉", "level": "Bathhouse", "spawn": "SpawnPosition"},
	{"name": "丛林", "level": "Jungle", "spawn": "SpawnPosition"},
	{"name": "雪山", "level": "Tundra", "spawn": "SpawnPosition"},
	{"name": "地牢", "level": "Dungeon", "spawn": "SpawnPosition"},
	{"name": "采石场", "level": "Quarry", "spawn": "SpawnPosition"},
	{"name": "腐化之地", "level": "Corruption", "spawn": "SpawnPosition"},
]

func build() -> void:
	for c in v_box.get_children():
		c.queue_free()
	for dest in DESTINATIONS:
		var btn := Button.new()
		btn.text = "前往" + dest["name"]
		btn.pressed.connect(_travel.bind(dest))
		v_box.add_child(btn)

func _travel(dest: Dictionary) -> void:
	visible = false
	SceneManager.change_level(dest["level"], dest["spawn"])
