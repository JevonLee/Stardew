extends State

@export var player:Player
@export var anim:AnimationPlayer
@export var speed:int = 100

var direction:Vector2

func _enter():
	print("Move")
	pass# 进入这个状态时要做什么（比如播放动画）
	
func _exit():
	anim.stop()
	pass# 离开这个状态时要做什么
	
func _physics_update(delta):
	direction = player.direction
	_update_animation()
	
	if direction != Vector2.ZERO:#记录Move->Idle的方向
		player.player_direction = direction

	if player.direction == Vector2.ZERO:
		transition_to.emit("Idle")
		
	player.velocity = player.direction * speed * player.move_speed_multiplier 
	player.move_and_slide()	

func _update_animation():
	#停下来的时候direction为0,所以Idle下面条件永远不会执行
	#为了避免这种情况，Move状态需要一个单独的direction
	if direction == Vector2.UP:
		anim.play("move_up")
	elif direction == Vector2.DOWN:
		anim.play("move_down")
	elif direction == Vector2.LEFT:
		anim.play("move_left")
	elif direction == Vector2.RIGHT:
		anim.play("move_right")
	#anim["parameters/Move/blend_position"] = player.player_direction
