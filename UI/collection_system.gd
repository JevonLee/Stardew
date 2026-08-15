extends Node2D
class_name CollectionSystemUI
## 图鉴系统入口：按G开关图鉴面板

const PANEL = preload("res://UI/collection_panel.tscn")

var panel: Control

func _ready() -> void:
	panel = PANEL.instantiate()
	panel.visible = false
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(panel)
	else:
		add_child(panel)
	panel.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("collection"):
		panel.visible = !panel.visible
		if panel.visible:
			panel.refresh()
