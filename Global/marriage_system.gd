extends Node
## Autoload 婚姻系统：好感满10心后送花束求婚，配偶每日送礼物

signal marriage_changed(spouse:String)

const SPOUSE_GIFTS = [
	"res://Bag/items/food/煎蛋.tres",
	"res://Bag/items/food/果酱.tres",
	"res://Bag/items/forage/树莓.tres",
	"res://Bag/items/fish/鲤鱼.tres",
	"res://Bag/items/food/烤蘑菇.tres",
]

var spouse:String = ""

func is_married() -> bool:
	return spouse != ""

func marry(name:String) -> void:
	spouse = name
	marriage_changed.emit(spouse)
	Global.show_message("你和%s结婚了！新婚快乐！" % spouse)

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)

## 配偶每日礼物
func _on_new_day(_day:int) -> void:
	if not is_married(): return
	if randf() < 0.5:
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player:
			var gift: Item = load(SPOUSE_GIFTS.pick_random()).duplicate()
			player.bag_system.add_item(gift)
			Global.show_message("%s送给你一份礼物：%s" % [spouse, gift.name])
