extends NPC

const GATE_POS := Vector2(268, 160) ## 农场北门（去往小镇的方向）

@export var visitor_mode: bool = false ## 访客模式：在小镇内闲逛（跨地图日程），而非走向北门

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var speed:int = 30 
var direction:Vector2
var initial_pos:Vector2

func _ready() -> void:
	super()
	initial_pos = global_position
	is_dialogue = false

func _physics_process(delta: float) -> void:
	# 日程：夜间在农场跳舞；中午（10-16点）去镇里赶集；其余时间在家附近巡逻
	var is_night: bool = TimeSystem.current_hour >= 19 or TimeSystem.current_hour < 6
	var is_midday: bool = TimeSystem.current_hour >= 10 and TimeSystem.current_hour < 16
	var pop_up = get_node(Global.root_scene["pop_up"])
	if !pop_up.find_child("DialogueUi"):
		is_dialogue = false
	if is_dialogue:
		direction = Vector2.ZERO
		animated_sprite_2d.play("dance1")
	elif is_night:
		# 夜晚：先回家，到家后跳舞
		if global_position.distance_to(initial_pos) > 8.0:
			direction = global_position.direction_to(initial_pos)
		else:
			direction = Vector2.ZERO
			animated_sprite_2d.play("dance1")
	elif is_midday:
		if visitor_mode:
			# 在小镇内闲逛
			_patrol()
		else:
			# 走向北门等待，模拟去镇里
			if global_position.distance_to(GATE_POS) > 8.0:
				direction = global_position.direction_to(GATE_POS)
			else:
				direction = Vector2.ZERO
				animated_sprite_2d.play("idle")
	else:
		_patrol()
	
	velocity = speed * direction
	move_and_slide()
	update_anim()
	
func _patrol() -> void:
	if global_position.distance_to(initial_pos) < 2.0:
		direction = Vector2.RIGHT
	elif global_position.distance_to(initial_pos + Vector2(50,0)) <2.0:
		direction = Vector2.DOWN
	elif global_position.distance_to(initial_pos + Vector2(50,50)) <2.0:
		direction = Vector2.LEFT
	elif global_position.distance_to(initial_pos + Vector2(0,50)) <2.0:
		direction = Vector2.UP
	else:
		direction = Vector2.ZERO
		animated_sprite_2d.play("idle")
	
func update_anim():
	if direction == Vector2.ZERO:
		animated_sprite_2d.play("idle")
		return
	var horizontal: bool = absf(direction.x) >= absf(direction.y)
	if horizontal:
		animated_sprite_2d.flip_h = direction.x < 0.0
		animated_sprite_2d.play("move_right")
	elif direction.y > 0.0:
		animated_sprite_2d.flip_h = false
		animated_sprite_2d.play("move_down")
	else:
		animated_sprite_2d.flip_h = false
		animated_sprite_2d.play("move_up")
