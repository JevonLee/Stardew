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

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(_day:int) -> void:
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
