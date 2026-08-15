extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var body_hurt_box: HurtComponent = $HurtComponent

@export var fall_objects:Array[Item] 

const FIBER = preload("res://Bag/items/materials/纤维.tres")

var player:Player = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_hurt_box.body_droped.connect(on_body_droped)
	player = get_tree().get_first_node_in_group("Player")
	# 掉落物兜底：未配置时默认掉纤维（修复无掉落bug）
	if fall_objects.is_empty() or fall_objects[0] == null:
		fall_objects = [FIBER]
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var direction:=global_position.direction_to(body.global_position)
		var skew := -direction.x * 5 #判断玩家方向并乘上震动强度
		var tween = create_tween()
		tween.tween_property(sprite_2d.material,"shader_parameter/skew",skew,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_2d.material,"shader_parameter/skew",0.0,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func on_body_droped() ->void: #树身体被砍
	call_deferred("add_fall_objects",1,fall_objects[0])
	queue_free()
	
func add_fall_objects(num:int,item:Item) -> void: #bug原因：吸附的优先级高于动画
	for i in range(num):
		var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
		var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
		if !drops:
			drops = get_parent()
		fall_ins.is_bezier = true
		fall_ins.position = global_position
		drops.add_child(fall_ins)
		fall_ins.generate(item)
		
