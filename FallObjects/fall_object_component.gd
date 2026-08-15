extends Node2D
class_name FallObjectComponent

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D

@export var item:Item
@export var speed:float = 1.5
@export var deviation_distance:float = 50 #偏航距离（p0到p1距离）
@export var deviation_angle:float = 90 #偏航角度

var is_bezier:bool = true #是否启用贝塞尔曲线
var player:Player
var body_in_area:bool = false
var p0:Vector2 #起点
var p1:Vector2 #控制点
var p2:Vector2 #目的地
var t:float = 0.0 #曲线进展（0代表初始位置）


func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	area_2d.body_entered.connect(on_body_entered)
	set_physics_process(false)
	collision_shape_2d.disabled = true
	if is_bezier:
		set_destination()
	await get_tree().create_timer(.5).timeout
	collision_shape_2d.set_deferred("disabled",false)


func _physics_process(delta: float) -> void:
	if t<1.0:
		t += delta * speed
	position = position.bezier_interpolate(p0,p1,p2,t) #贝塞尔曲线函数，也可以用下面自定义的
	
func _process(delta: float) -> void:
	if body_in_area:
		var tween = create_tween()
		tween.tween_property(self,"global_position",player.global_position,0.5)
		if player.global_position.distance_to(global_position) <= 15.0:
			tween.tween_property(self,"global_position",player.global_position,0.5)
			queue_free()
			player.bag_system.add_item(item)
			CollectionSystem.record_item(item.name)
			player.get_item.emit(item)
	
func on_body_entered(body:Node2D) -> void: #移向玩家
	if body is Player:
		body_in_area = true

func generate(item: Item):
	self.item = item.duplicate()
	sprite_2d.texture = item.texture

func set_destination() -> void: #赋值目的点和控制点
	var direction = global_position.direction_to(player.global_position)
	if direction.x >= 0: #生成物在玩家左边
		p2 = global_position + Vector2(20,0)
		deviation_angle = -deviation_angle
	else:
		p2 = global_position + Vector2(-20,0)
	p0 = global_position
	var tilted_unit_vector = (p2-p0).normalized().rotated(deg_to_rad(deviation_angle))
	p1 = p0 + deviation_distance * tilted_unit_vector
	call_deferred("set_physics_process",true)
	
func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float):
	#官方文档的二次贝塞尔曲线函数
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)
