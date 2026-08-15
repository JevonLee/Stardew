extends Node2D
class_name CraftingSystem
## 合成系统：按C打开/关闭合成面板

const PANEL = preload("res://Crafting/crafting_panel.tscn")
const RECIPES = [
	preload("res://Crafting/recipes/火把.tres"),
	preload("res://Crafting/recipes/木剑.tres"),
	preload("res://Crafting/recipes/石剑.tres"),
	preload("res://Crafting/recipes/铜剑.tres"),
	preload("res://Crafting/recipes/铁剑.tres"),
	preload("res://Crafting/recipes/金剑.tres"),
	preload("res://Crafting/recipes/金币.tres"),
	preload("res://Crafting/recipes/可疑眼球.tres"),
	preload("res://Crafting/recipes/铜镐.tres"),
	preload("res://Crafting/recipes/铁镐.tres"),
	preload("res://Crafting/recipes/金镐.tres"),
	preload("res://Crafting/recipes/煎蛋.tres"),
	preload("res://Crafting/recipes/烤鱼.tres"),
	preload("res://Crafting/recipes/蔬菜沙拉.tres"),
	preload("res://Crafting/recipes/血腥脊椎.tres"),
]

var panel: Control

func _ready() -> void:
	panel = PANEL.instantiate()
	panel.visible = false
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(panel)
	else:
		add_child(panel)
	panel.build(RECIPES) # 必须在加入场景树之后（@onready生效）

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		panel.visible = !panel.visible
		if panel.visible:
			panel.build(RECIPES) # 刷新材料显示（数量在合成时校验）
