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
