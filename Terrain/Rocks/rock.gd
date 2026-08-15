extends StaticBody2D
class_name Rock

const COAL = preload("res://Bag/items/materials/煤矿.tres")

@onready var body: Sprite2D = $body
@onready var body_hurt_box: HurtComponent = $body/HurtComponent

@export var fall_objects:Array[Item] 
@export var sfx1:AudioStream
@export var coal_chance:float = 0.15 ## 额外掉落煤矿的概率

var player:Player = null

func _ready() -> void:
	body_hurt_box.body_droped.connect(on_body_droped)
	body_hurt_box.hit_entered.connect(func():AudioManager.play_sfx(sfx1))
	player = get_tree().get_first_node_in_group("Player")

func on_body_droped() ->void: #树身体被砍
	call_deferred("add_fall_objects",1,fall_objects[0])
	if randf() < coal_chance:
		call_deferred("add_fall_objects",1,COAL)
	queue_free()
	
func add_fall_objects(num:int,item:Item) -> void: #bug原因：吸附的优先级高于动画
	for i in range(num):
		var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
		var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
		if !drops:
			drops = get_parent()
		fall_ins.position = global_position	
		fall_ins.is_bezier = true
		drops.add_child(fall_ins)
		fall_ins.generate(item)
