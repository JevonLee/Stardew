extends CharacterBody2D
class_name Pet
## 宠物猫：跟随玩家，走太远会小跑跟上，近了会坐下休息

@export var follow_distance: float = 80.0
@export var speed: float = 120.0
@export var sprite_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var player: Player
var idle_timer: float = 2.0
var sitting: bool = false
var petted: int = 0 ## 被撸次数

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	SceneManager.level_changed.connect(_find_player)
	if sprite_texture:
		sprite.texture = sprite_texture

## 右键撸宠物
func pet() -> void:
	petted += 1
	Global.show_message("撸%s！心情+1（已撸 %d 次）" % [name, petted])
	# 开心反应：原地转圈
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_right"):
		if global_position.distance_to(get_global_mouse_position()) < 50.0:
			pet()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
		if player == null: return
	var dist := global_position.distance_to(player.global_position)
	if dist > follow_distance:
		sitting = false
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * speed
		sprite.flip_h = dir.x < 0.0
		sprite.frame = int(Time.get_ticks_msec() * 0.008) % 4
	else:
		velocity = Vector2.ZERO
		idle_timer -= _delta
		if idle_timer <= 0.0:
			idle_timer = randf_range(2.0, 5.0)
			sitting = !sitting
		sprite.frame = 0
	move_and_slide()
