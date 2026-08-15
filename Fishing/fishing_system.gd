extends Node2D
class_name FishingSystem
## 钓鱼系统：选中鱼竿后左键抛竿；咬钩后弹出小游戏

const BOBBER = preload("res://Fishing/bobber.tscn")
const FISH_UI = preload("res://Fishing/fishing_ui.tscn")
const FISH_TABLE = [ ## Array[FishData]
	preload("res://Fishing/fish_data/沙丁鱼_data.tres"),
	preload("res://Fishing/fish_data/鲤鱼_data.tres"),
	preload("res://Fishing/fish_data/大嘴鲈鱼_data.tres"),
	preload("res://Fishing/fish_data/鲶鱼_data.tres"),
	preload("res://Fishing/fish_data/河豚_data.tres"),
	preload("res://Fishing/fish_data/章鱼_data.tres"),
	preload("res://Fishing/fish_data/冰鱼_data.tres"),
]
const JUNK_TABLE = [ ## 垃圾（低难度占位鱼）
	preload("res://Fishing/fish_data/垃圾_data.tres"),
	preload("res://Fishing/fish_data/垃圾2_data.tres"),
]
const JUNK_CHANCE: float = 0.15

var player: Player
var bobber: Bobber
var fishing_ui: Control
var casting: bool = false

func _ready() -> void:
	SceneManager.level_changed.connect(_find_player)
	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player")

func _unhandled_input(event: InputEvent) -> void:
	if player == null: return
	if player.current_item == null: return
	if player.current_item.type != Item.ItemType.Fishing: return
	if bobber != null or fishing_ui != null or casting: return
	if event.is_action_pressed("mouse_left"):
		_cast()

func _cast(dir_override: Vector2 = Vector2.ZERO) -> void:
	var water := get_tree().get_first_node_in_group("Water") as TileMapLayer
	if water == null:
		Global.show_message("这里没有水！")
		return
	var dir := dir_override
	if dir == Vector2.ZERO:
		dir = player.global_position.direction_to(player.get_global_mouse_position())
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var target := player.global_position + dir * 120.0
	if water.get_cell_source_id(water.local_to_map(target)) == -1:
		Global.show_message("鱼钩要落在水里！")
		return
	casting = true
	bobber = BOBBER.instantiate() as Bobber
	bobber.target = target
	bobber.global_position = player.global_position
	bobber.bite.connect(_on_bite)
	get_parent().add_child(bobber)
	await get_tree().create_timer(0.6).timeout
	casting = false

func _on_bite(_b: Bobber) -> void:
	var fish := _pick_fish()
	if fish == null: return
	fishing_ui = FISH_UI.instantiate()
	fishing_ui.fish = fish
	fishing_ui.result.connect(_on_fishing_result)
	var canvas := get_node_or_null(Global.root_scene["main_canvas_layer"])
	if canvas:
		canvas.add_child(fishing_ui)
	else:
		add_child(fishing_ui)

func _on_fishing_result(success: bool) -> void:
	if success and fishing_ui and fishing_ui.fish:
		var is_junk: bool = fishing_ui.fish.item != null and fishing_ui.fish.item.price <= 5
		player.bag_system.add_item(fishing_ui.fish.item.duplicate())
		if not is_junk:
			QuestSystem.report("fish")
			CollectionSystem.record_fish(fishing_ui.fish.fish_name)
		Global.show_message("钓到了 %s！" % fishing_ui.fish.fish_name if not is_junk else "钓到了垃圾…")
	else:
		Global.show_message("鱼跑掉了……")
	if fishing_ui:
		fishing_ui.queue_free()
	fishing_ui = null
	if bobber:
		if success:
			bobber.queue_free()
			bobber = null
		else:
			bobber.reset_after_escape()

## 按季节与权重随机选鱼（15%概率钓到垃圾）
func _pick_fish() -> FishData:
	if randf() < JUNK_CHANCE:
		return JUNK_TABLE.pick_random()
	var season := TimeSystem.get_season()
	var candidates: Array[FishData] = []
	for fish in FISH_TABLE:
		if fish.seasons.has(season):
			candidates.append(fish)
	if candidates.is_empty():
		candidates = FISH_TABLE.duplicate()
	return candidates.pick_random()
