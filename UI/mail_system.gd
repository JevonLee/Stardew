extends Node2D
class_name MailSystemUI
## 信件系统入口：收到信时弹出面板

const PANEL = preload("res://UI/mail_panel.tscn")

var panel: Control

func _ready() -> void:
	panel = PANEL.instantiate()
	panel.visible = false
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(panel)
	else:
		add_child(panel)
	MailSystem.mail_received.connect(_on_mail)

func _on_mail(mail: Dictionary) -> void:
	panel.show_mail(mail)
