extends Node
## Autoload 博物馆系统：捐赠宝石/文物，计数与奖励

signal donated_changed

const DONATABLE_TYPES:Array[int] = [
	Item.ItemType.Materials,
	Item.ItemType.Accessories,
]

var donated:Dictionary = {} ## 物品名 -> 捐赠数量

func donate(item:Item) -> bool:
	if item == null: return false
	if item.price < 50: return false # 廉价物品不收
	donated[item.name] = donated.get(item.name, 0) + 1
	var reward: int = item.price
	Global.gold += reward
	donated_changed.emit()
	Global.show_message("捐赠了 %s 给博物馆！奖励 %d 金币" % [item.name, reward])
	return true

func total_donated() -> int:
	var total := 0
	for name in donated:
		total += donated[name]
	return total
