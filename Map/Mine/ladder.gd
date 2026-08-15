extends Area2D
class_name Ladder
## 矿洞楼梯：按F上/下楼层

@export var direction: int = 1 ## 1=深入 -1=返回上层

var player_near: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_near = true
		Global.show_message("按 F 上下楼梯" if direction > 0 else "按 F 返回上层")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_near = false

func _unhandled_input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("interact"):
		var mine := get_parent() as Mine
		if mine:
			Global.mine_floor = clampi(mine.floor_index + direction, 1, 99)
			SceneManager.change_level("Mine", "SpawnPosition")
