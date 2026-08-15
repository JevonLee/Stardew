extends Node
## Autoload 图鉴系统：记录钓到的鱼 / 击杀的敌人 / 收集的物品

signal collection_changed

var fish_caught:Array[String] = []
var enemies_killed:Dictionary = {} ## 名称 -> 击杀数
var items_collected:Dictionary = {} ## 名称 -> 收集数

func record_fish(fish_name:String) -> void:
	if fish_name == "": return
	if not fish_caught.has(fish_name):
		fish_caught.append(fish_name)
	collection_changed.emit()

func record_kill(enemy_name:String) -> void:
	if enemy_name == "": return
	enemies_killed[enemy_name] = enemies_killed.get(enemy_name, 0) + 1
	collection_changed.emit()

func record_item(item_name:String) -> void:
	if item_name == "": return
	items_collected[item_name] = items_collected.get(item_name, 0) + 1
	collection_changed.emit()
