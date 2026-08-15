extends Node
## Autoload，用于存储常量与全局状态（金币等）

const TOOL_TIP = preload("res://UI/tool_tip.tscn")
const FALL_OBJECT_COMPONENT = preload("res://FallObjects/fall_object_component.tscn")

var root_scene:Dictionary = { ##"main_scene""main_canvas_layer""pop_up""levels""drops""ui_manager"
	"main_scene": "/root/MainScene",
	"main_canvas_layer":"/root/MainScene/MainCanvasLayer",
	"pop_up":"/root/MainScene/MainCanvasLayer/PopUp",
	"levels":"/root/MainScene/Levels",
	"drops":"/root/MainScene/Drops",
	"ui_manager":"/root/MainScene/MainCanvasLayer/UIManager",
}

signal gold_changed(gold:int)

var gold:int = 500: ## 玩家金币
	set(val):
		gold = maxi(val, 0)
		gold_changed.emit(gold)

var mine_floor:int = 1 ## 进入矿洞的层数（由楼梯设置，矿洞读取后重置）

## 技能系统：钓鱼/采矿技能等级（10级上限，每级效果增强）
var skills:Dictionary = {"fishing": 0, "mining": 0}
var skill_xp:Dictionary = {"fishing": 0, "mining": 0}
const SKILL_NAMES := {"fishing": "钓鱼", "mining": "采矿"}

## 获得技能经验（每10点升1级，上限10级）
func add_skill_xp(skill: String, amount: int) -> void:
	skill_xp[skill] = skill_xp.get(skill, 0) + amount
	while skill_xp[skill] >= 10:
		skill_xp[skill] -= 10
		skills[skill] = mini(skills.get(skill, 0) + 1, 10)
		show_message("%s技能升级！当前%d级" % [SKILL_NAMES.get(skill, skill), skills[skill]])

## 钓鱼技能：每级使钓鱼难度再降低2%（10级共-20%）
func fishing_skill_multiplier() -> float:
	return 1.0 - 0.02 * skills.get("fishing", 0)

## 采矿技能：每级5%概率双倍矿石（10级共50%）
func mining_double_chance() -> float:
	return 0.05 * skills.get("mining", 0)

## 在 PopUp 上显示一条短暂提示文字
func show_message(text:String) -> void:
	var pop_up = get_node_or_null(root_scene["pop_up"])
	if pop_up == null: return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(430, 400)
	label.z_index = 100
	pop_up.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", 330.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tween.tween_callback(label.queue_free)
