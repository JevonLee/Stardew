extends Node
## Autoload 好感度系统：村民好感（0-10心）与每日送礼限制

signal friendship_changed(npc_name:String, hearts:float)

var friendships:Dictionary = {} ## name -> {"hearts": float, "gifted_today": bool}

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)

func _on_new_day(_day:int) -> void:
	# 每日重置送礼状态
	for key in friendships:
		friendships[key]["gifted_today"] = false

func _ensure(npc_name:String) -> Dictionary:
	if not friendships.has(npc_name):
		friendships[npc_name] = {"hearts": 0.0, "gifted_today": false}
	return friendships[npc_name]

func get_hearts(npc_name:String) -> float:
	return _ensure(npc_name)["hearts"]

func can_gift(npc_name:String) -> bool:
	return not _ensure(npc_name)["gifted_today"]

func add_hearts(npc_name:String, amount:float) -> void:
	var data := _ensure(npc_name)
	data["hearts"] = clampf(data["hearts"] + amount, 0.0, 10.0)
	data["gifted_today"] = true
	friendship_changed.emit(npc_name, data["hearts"])
