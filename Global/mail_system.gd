extends Node
## Autoload 信件系统：每天清晨可能收到信件（含礼物）

signal mail_received(mail:Dictionary)

const MAILS := [
	{"text": "亲爱的农场主：听说森林里出现了奇怪的生物，去探索时小心点！—— 皮埃尔", "gift": "", "gift_count": 0},
	{"text": "谢谢你让鹈鹕镇热闹起来！送你一点小礼物。—— 艾米丽", "gift": "res://Bag/items/forage/树莓.tres", "gift_count": 3},
	{"text": "矿洞深处藏着宝石，祝你好运。—— 镇上老矿工", "gift": "res://Bag/items/materials/煤矿.tres", "gift_count": 5},
	{"text": "钓鱼的时候记得看好浮漂。—— 威利", "gift": "res://Bag/items/fish/沙丁鱼.tres", "gift_count": 2},
	{"text": "今天天气不错，适合种地。—— 小镇广播", "gift": "", "gift_count": 0},
	{"text": "我在森林里捡到了这个，送给你。—— 一位陌生朋友", "gift": "res://Bag/items/materials/紫水晶.tres", "gift_count": 1},
]

var pending_mail:Dictionary = {}

## 每周日清晨的季节提示信
const SEASON_TIPS := {
	0: {"text": "春天到了！萝卜甜瓜正当时，13日是蛋节，别忘了参加。—— 小镇广播", "gift": "", "gift_count": 0},
	1: {"text": "盛夏！蓝莓番茄大丰收，小心雷暴天气，矿洞里凉快。—— 小镇广播", "gift": "", "gift_count": 0},
	2: {"text": "秋天！南瓜蔓越莓成熟了，16日星露谷博览会见！—— 小镇广播", "gift": "", "gift_count": 0},
	3: {"text": "寒冬！去雪山冰湖钓鱼吧，冰鱼只有冬天才有。—— 小镇广播", "gift": "", "gift_count": 0},
}

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(day:int) -> void:
	# 每周日（第7天）季节提示信
	if day % 7 == 0:
		pending_mail = SEASON_TIPS[TimeSystem.get_season()]
		mail_received.emit(pending_mail)
		return
	if randf() < 0.3:
		pending_mail = MAILS.pick_random()
		mail_received.emit(pending_mail)

## 领取信件（礼物进背包）
func claim() -> void:
	if pending_mail.is_empty(): return
	var gift_path: String = pending_mail.get("gift", "")
	if gift_path != "":
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player:
			var gift: Item = load(gift_path).duplicate()
			gift.quantity = pending_mail.get("gift_count", 1)
			player.bag_system.add_item(gift)
	pending_mail = {}
