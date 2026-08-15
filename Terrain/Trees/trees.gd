extends StaticBody2D
class_name Trees

const SAP = preload("res://Bag/items/materials/树液.tres")
const WOOD = preload("res://Bag/items/materials/wood.tres")

@onready var root_hurt_box: Area2D = $TreeRoot/HurtComponent
@onready var body_hurt_box: Area2D = $TreeBody/HurtComponent
@onready var body_enterd: Area2D = $TreeBody/BodyEnterd
@onready var tree_root: Sprite2D = $TreeRoot
@onready var tree_body: Sprite2D = $TreeBody
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles_2d: GPUParticles2D = $TreeBody/GPUParticles2D

@export var fall_objects:Array[Item] #掉落物这里用字典比较好
@export var sfx_1:AudioStream

var player:Player = null

func _ready() -> void:
	body_enterd.body_entered.connect(on_body_enterd)
	body_enterd.body_exited.connect(on_body_exited)
	#树被砍倒的两个信号连接
	body_hurt_box.body_droped.connect(on_body_droped)
	root_hurt_box.root_droped.connect(on_root_droped)
	#树被砍的信号
	body_hurt_box.hit_entered.connect(on_hit_entered.bind(tree_body))
	body_hurt_box.hit_exited.connect(on_hit_exited.bind(tree_body))
	root_hurt_box.hit_entered.connect(on_hit_entered.bind(tree_root))
	root_hurt_box.hit_exited.connect(on_hit_exited.bind(tree_root))
	#下面是初始状态赋值
	root_hurt_box.get_child(0).disabled = true
	player = get_tree().get_first_node_in_group("Player")
	# 掉落物兜底：未配置时默认掉木头（修复代码生成树无掉落bug）
	if fall_objects.is_empty() or fall_objects[0] == null:
		fall_objects = [WOOD]
	
func on_body_enterd(body:Node2D) -> void:
	if body is Player:
		var tween = body.create_tween()
		tween.tween_property(tree_body.material,"shader_parameter/alpha",0.3,0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.set_parallel()
		tween.tween_property(tree_root.material,"shader_parameter/alpha",0.3,0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		
func on_body_exited(body:Node2D) -> void:
	if body is Player:
		var tween = body.create_tween()
		tween.tween_property(tree_body.material,"shader_parameter/alpha",1.0,0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		tween.set_parallel()
		tween.tween_property(tree_root.material,"shader_parameter/alpha",1.0,0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

func on_hit_entered(body:Sprite2D) -> void:
	body.material.set_shader_parameter("shake_intensity",2.5)
	if gpu_particles_2d:
		gpu_particles_2d.emitting = true
	AudioManager.play_sfx(sfx_1)
	
func on_hit_exited(body:Sprite2D) -> void:
	body.material.set_shader_parameter("shake_intensity",0.0)
	if gpu_particles_2d:
		gpu_particles_2d.emitting = false

func on_body_droped() ->void: #树身体被砍
	root_hurt_box.get_child(0).set_deferred("disabled",false) #因为引擎的一些原因，这里更改物理属性需要延迟
	#被砍到动画，生成掉落物
	var direction = global_position.x - player.global_position.x
	if direction >= 0: #说明人在树的左边
		animation_player.play("tree_drop_right")
	else:
		animation_player.play("tree_drop_left")
	await get_tree().create_timer(1.0).timeout #这个时间是树倒下的动画时间
	add_fall_objects(14,tree_body,fall_objects[0])
	if randf() < 0.25: #额外掉落树液
		add_fall_objects(1,tree_body,SAP)
	gpu_particles_2d = null
	tree_body.queue_free()
	
func on_root_droped() ->void: #树根被砍
	call_deferred("add_fall_objects",7,tree_root,fall_objects[0]) #树根的物理状态改变过，所以要延迟调用
	queue_free()

	
func add_fall_objects(num:int,body:Node2D,item:Item) -> void: #bug原因：吸附的优先级高于动画
	var tween = create_tween().set_parallel()
	for i in range(num):
		var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
		fall_ins.position = body.global_position
		var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
		if !drops:
			drops = get_parent()
		fall_ins.is_bezier = false
		drops.add_child(fall_ins)
		fall_ins.generate(item)
		tween.tween_property(fall_ins,"global_position",Vector2( #在直径为100的圆内随机生成
			randf_range(-25,25),
			randf_range(-25,25)
		),0.2).as_relative()#相对树身体的坐标
		
		
