extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var hurt_component: HurtComponent = $HurtComponent
@onready var area_2d: Area2D = $Area2D

@export var fall_objects:Array[Item]

var player:Player = null
var can_hurt:bool

func _ready() -> void:
	area_2d.body_entered.connect(_on_body_entered)
	hurt_component.body_droped.connect(on_body_droped)
	player = get_tree().get_first_node_in_group("Player")
	TimeSystem.time_tick_day.connect(on_time_tick_day)
	can_hurt = false
	sprite_2d.frame = 0
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player and sprite_2d.frame >=4:
		var direction:=global_position.direction_to(body.global_position)
		var skew := -direction.x * 5 #判断玩家方向并乘上震动强度
		var tween = create_tween()
		tween.tween_property(sprite_2d.material,"shader_parameter/skew",skew,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_2d.material,"shader_parameter/skew",0.0,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func on_body_droped() ->void: 
	call_deferred("add_fall_objects",1,fall_objects[0])
	if sprite_2d.frame == 6:
		queue_free()
	
func add_fall_objects(num:int,item:Item) -> void: #bug原因：吸附的优先级高于动画
	if sprite_2d.frame == 6:
		for i in range(num):
			var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
			var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
			if !drops:
				drops = get_parent()
			fall_ins.is_bezier = true
			fall_ins.position = global_position
			drops.add_child(fall_ins)
			fall_ins.generate(item)

func on_time_tick_day(day:int)->void:
	var a_day = day+7 #从种下当天往后算7天
	if day<=7:#应该从种下那天开始计算,浇水后第二天生长 3-10
		sprite_2d.frame = (day-1)%sprite_2d.hframes
