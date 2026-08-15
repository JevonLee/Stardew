extends Area2D
class_name MineElevator
## 矿洞电梯：按F打开楼层选择，直达目标层（5/10/15/20/25/30/35/40/45/50）

var player_near: bool = false
var panel: Control

const FLOORS: Array[int] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_near = true
		Global.show_message("按 F 使用电梯")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_near = false
		_close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("interact"):
		_toggle_panel()

func _toggle_panel() -> void:
	if panel == null:
		_build_panel()
	panel.visible = !panel.visible

func _build_panel() -> void:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(440, 140)
	box.size = Vector2(400, 480)
	panel.add_child(box)
	var title := Label.new()
	title.text = "矿洞电梯（选择层数）"
	title.position = Vector2(20, 12)
	box.add_child(title)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 50)
	box.add_child(vbox)
	for floor in FLOORS:
		var btn := Button.new()
		btn.text = "第 %d 层" % floor
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_travel_to.bind(floor))
		vbox.add_child(btn)
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(panel)
	else:
		add_child(panel)
	panel.visible = false

func _travel_to(floor: int) -> void:
	_close_panel()
	Global.mine_floor = floor
	SceneManager.change_level("Mine", "SpawnPosition")

func _close_panel() -> void:
	if panel != null:
		panel.visible = false
