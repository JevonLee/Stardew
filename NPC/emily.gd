extends NPC

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var speed:int = 30 
var direction:Vector2
var initial_pos 

func _ready() -> void:
	super()
	initial_pos = global_position
	is_dialogue = false

func _physics_process(delta: float) -> void:
	if !is_dialogue:
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
		animated_sprite_2d.play("dance1")
		#if global_position.distance_to(initial_pos) > 10:
			#direction = global_position.direction_to(initial_pos)
	
	var pop_up = get_node(Global.root_scene["pop_up"])
	var dialogue_ui = pop_up.find_child("DialogueUi")
	if !dialogue_ui:
		is_dialogue = false
	
	velocity = speed * direction
	move_and_slide()
	update_anim()
	
func update_anim():
	if direction == Vector2.LEFT:
		animated_sprite_2d.flip_h = true
	else:
		animated_sprite_2d.flip_h = false
	if direction == Vector2.ZERO:
		animated_sprite_2d.play("idle")
	if direction == Vector2.DOWN:
		animated_sprite_2d.play("move_down")
	if direction == Vector2.UP:
		animated_sprite_2d.play("move_up")
	if direction == Vector2.LEFT:
		animated_sprite_2d.play("move_right")
	if direction == Vector2.RIGHT:
		animated_sprite_2d.play("move_right")
