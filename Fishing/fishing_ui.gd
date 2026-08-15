extends Control
## 钓鱼小游戏：按住左键收线（接鱼区上移），松开下坠；鱼在区内积累进度

signal result(success: bool)

const BAR_HEIGHT: float = 260.0
const ZONE_SIZE: float = 46.0

var fish: FishData
var progress: float = 0.0
var fish_y: float = 0.0
var zone_y: float = 0.0
var time: float = 0.0
var active: bool = true
var finished: bool = false

@onready var bar: Control = $Bar
@onready var fish_icon: ColorRect = $Bar/Fish
@onready var zone: ColorRect = $Bar/Zone
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var fish_label: Label = $FishLabel

func _ready() -> void:
	fish_label.text = "鱼：%s" % (fish.fish_name if fish else "?")
	zone.position.y = BAR_HEIGHT / 2.0
	fish_icon.position.y = BAR_HEIGHT / 2.0
	zone_y = BAR_HEIGHT / 2.0
	fish_y = BAR_HEIGHT / 2.0
	set_process(true)

## 鱼竿等级修正难度（铁鱼竿-15%，金鱼竿-30%）+ 钓鱼技能等级修正
func _effective_difficulty() -> float:
	var diff := (fish.difficulty if fish else 0.5)
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player and player.current_item:
		match player.current_item.name:
			"铁鱼竿": diff *= 0.85
			"金鱼竿": diff *= 0.7
	diff *= Global.fishing_skill_multiplier()
	return diff

func _process(delta: float) -> void:
	if not active: return
	time += delta
	# 鱼的位置：双正弦叠加（难度越高动得越快）
	var speed := 1.8 + _effective_difficulty() * 3.2
	fish_y = BAR_HEIGHT / 2.0 + sin(time * speed) * (BAR_HEIGHT * 0.35) + sin(time * speed * 2.7) * (BAR_HEIGHT * 0.12)
	fish_icon.position.y = fish_y
	# 接鱼区：按住左键上升，松开下落（星露谷经典操作）
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		zone_y -= delta * 300.0
	else:
		zone_y += delta * 190.0
	zone_y = clampf(zone_y, 0.0, BAR_HEIGHT)
	zone.position.y = zone_y
	# 判定
	var diff := _effective_difficulty()
	if absf(fish_y - zone_y) < ZONE_SIZE / 2.0:
		progress += delta * (0.55 - diff * 0.25)
	else:
		progress -= delta * 0.65
	progress = clampf(progress, 0.0, 1.0)
	progress_bar.value = progress * 100.0
	if progress >= 1.0:
		_finish(true)
	elif progress <= 0.0:
		_finish(false)

func _finish(success: bool) -> void:
	if finished: return
	finished = true
	active = false
	result.emit(success)
