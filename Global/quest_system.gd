extends Node
## Autoload 任务系统：每天清晨随机一个日常任务，完成自动发奖

signal quest_updated(quest:Dictionary)

const QUEST_TYPES:Array[String] = ["forage", "kill", "fish", "harvest"]
const QUEST_TARGETS := {"forage": 5, "kill": 5, "fish": 2, "harvest": 3}
const QUEST_NAMES := {"forage": "采集野外物品", "kill": "击败敌人", "fish": "钓到鱼", "harvest": "收获作物"}
const QUEST_REWARDS := {"forage": 100, "kill": 150, "fish": 120, "harvest": 120}

var quest:Dictionary = {} ## {type,target,progress,reward,name,done}
var day_rolled:int = -1

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(day:int) -> void:
	if day != day_rolled:
		roll_quest()

func roll_quest() -> void:
	day_rolled = TimeSystem.current_day
	var qtype: String = QUEST_TYPES.pick_random()
	quest = {
		"type": qtype,
		"target": QUEST_TARGETS[qtype],
		"progress": 0,
		"reward": QUEST_REWARDS[qtype],
		"name": QUEST_NAMES[qtype],
		"done": false,
	}
	quest_updated.emit(quest)
	Global.show_message("今日任务：%s %d/%d（奖励 %d 金）" % [quest.name, 0, quest.target, quest.reward])

## 上报进度（kill/forage/fish/harvest）
func report(qtype:String) -> void:
	if quest.is_empty() or quest.get("done", false): return
	if quest["type"] != qtype: return
	quest["progress"] += 1
	quest_updated.emit(quest)
	if quest["progress"] >= quest["target"]:
		quest["done"] = true
		Global.gold += quest["reward"]
		Global.show_message("任务完成！获得 %d 金币" % quest["reward"])
