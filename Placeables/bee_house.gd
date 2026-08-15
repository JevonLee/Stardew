extends Placeable
class_name BeeHouse
## 蜂房：每4天产出一罐蜂蜜（附近3格内有作物则加速为2天），放置后随存档保存

const HONEY = preload("res://Bag/items/food/蜂蜜.tres")

var placed_day: int = 0 ## 上次产蜜日（绝对天数）

func _ready() -> void:
	super()
	if placed_day <= 0:
		placed_day = TimeSystem.current_day
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(day: int) -> void:
	var interval: int = 2 if _has_flower_nearby() else 4
	if day >= placed_day + interval:
		placed_day = day
		_spawn_honey()

## 附近3格（96px）内有作物视为有花，加速产蜜
func _has_flower_nearby() -> bool:
	var container := get_parent()
	if container == null: return false
	for child in container.get_children():
		if child is Crop and is_instance_valid(child):
			if global_position.distance_to(child.global_position) <= 96.0:
				return true
	return false

func _spawn_honey() -> void:
	var fall := Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops := get_node_or_null(Global.root_scene["drops"]) as Node2D
	if drops == null:
		drops = get_parent()
	fall.position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	drops.add_child(fall)
	fall.generate(HONEY)
	Global.show_message("蜂房产出了一罐蜂蜜！")
