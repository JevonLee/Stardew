extends Node
## Autoload 成就系统：达成条件自动解锁并发奖

signal achievement_unlocked(id:String)

const ACHIEVEMENTS := [
	{"id": "first_fish", "name": "初钓", "desc": "钓到第一条鱼", "reward": 100},
	{"id": "fish_3", "name": "钓鱼入门", "desc": "钓到3种不同的鱼", "reward": 300},
	{"id": "kill_10", "name": "猎手", "desc": "累计击杀10只怪物", "reward": 300},
	{"id": "boss_slayer", "name": "屠Boss者", "desc": "击败任意Boss", "reward": 1000},
	{"id": "level_5", "name": "老练冒险者", "desc": "达到5级", "reward": 500},
	{"id": "collect_20", "name": "收藏家", "desc": "收集20种不同物品", "reward": 500},
	{"id": "gold_5000", "name": "小富翁", "desc": "拥有5000金币", "reward": 1000},
	{"id": "bath_regular", "name": "温泉常客", "desc": "第一次泡温泉", "reward": 100},
	{"id": "deep_fisher", "name": "深海猎人", "desc": "钓到冬季限定的鱿鱼", "reward": 300},
]

var unlocked:Dictionary = {}

func _ready() -> void:
	CollectionSystem.collection_changed.connect(check)
	Global.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(_gold:int) -> void:
	check()

func is_unlocked(id:String) -> bool:
	return unlocked.has(id)

func check() -> void:
	var conditions := {
		"first_fish": CollectionSystem.fish_caught.size() >= 1,
		"fish_3": CollectionSystem.fish_caught.size() >= 3,
		"kill_10": _total_kills() >= 10,
		"boss_slayer": _boss_killed(),
		"collect_20": CollectionSystem.items_collected.size() >= 20,
		"gold_5000": Global.gold >= 5000,
		"deep_fisher": CollectionSystem.fish_caught.has("鱿鱼"),
	}
	for id in conditions:
		if conditions[id]:
			_unlock(id)

## 由其他系统直接解锁（如泡温泉）
func unlock(id:String) -> void:
	_unlock(id)

## 由玩家升级时调用
func check_level(level:int) -> void:
	if level >= 5:
		_unlock("level_5")

func _unlock(id:String) -> void:
	if unlocked.has(id): return
	unlocked[id] = true
	achievement_unlocked.emit(id)
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			Global.show_message("成就解锁：%s！+%d金币" % [a["name"], a["reward"]])
			if a["reward"] > 0:
				Global.gold += a["reward"]
			break

func _total_kills() -> int:
	var total := 0
	for name in CollectionSystem.enemies_killed:
		total += CollectionSystem.enemies_killed[name]
	return total

func _boss_killed() -> bool:
	return CollectionSystem.enemies_killed.get("克苏鲁之眼", 0) > 0 \
		or CollectionSystem.enemies_killed.get("克苏鲁之脑", 0) > 0 \
		or CollectionSystem.enemies_killed.get("史莱姆王", 0) > 0
