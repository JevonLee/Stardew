extends Node2D
class_name TravelSystem
## 传送系统：按M开关传送面板

const PANEL = preload("res://UI/travel_panel.tscn")

var panel: Control

func _ready() -> void:
	panel = PANEL.instantiate()
	panel.visible = false
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(panel)
	else:
		add_child(panel)
	panel.build() # 必须在加入场景树之后（@onready生效）

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("travel"):
		panel.visible = !panel.visible
