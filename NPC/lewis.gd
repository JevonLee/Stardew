extends NPC
## 刘易斯：鹈鹕镇镇长，在小镇巡逻

@onready var sprite: Sprite2D = $Sprite2D

var speed: int = 22
var direction: Vector2 = Vector2.ZERO
var initial_pos: Vector2
var moving_right: bool = false

func _ready() -> void:
	super()
	initial_pos = global_position

func _physics_process(_delta: float) -> void:
	if !is_dialogue:
		var target: Vector2 = initial_pos + Vector2(60, 0) if moving_right else initial_pos
		if global_position.distance_to(target) < 2.0:
			moving_right = !moving_right
		direction = (target - global_position).normalized()
	else:
		direction = Vector2.ZERO
	var pop_up = get_node(Global.root_scene["pop_up"])
	if !pop_up.find_child("DialogueUi"):
		is_dialogue = false
	velocity = direction * speed
	move_and_slide()
	sprite.frame = int(Time.get_ticks_msec() * 0.005) % 4
	sprite.flip_h = direction.x < 0.0
