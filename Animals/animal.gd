extends CharacterBody2D
class_name Animal
## 农场动物：随机游走，右键抚摸时产出（鸡蛋/牛奶等）

@export var animal_name:String = "动物"
@export var product:Item ## 产出物
@export var sprite_texture:Texture2D ## 精灵图（4方向行走帧）
@export var sprite_scale:Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: ClickAreaComponent = $ClickAreaComponent

var wander_dir:Vector2 = Vector2.ZERO
var wander_timer:float = 0.0
var anim_time:float = 0.0
var produced_today:bool = true

func _ready() -> void:
	TimeSystem.time_tick_day.connect(_on_new_day)
	if sprite_texture:
		sprite.texture = sprite_texture
	sprite.scale = sprite_scale
	click_area.mouse_right_click.connect(pet)

func _physics_process(delta: float) -> void:
	anim_time += delta
	sprite.frame = int(anim_time * 6.0) % 4
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		if randf() < 0.7:
			wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		else:
			wander_dir = Vector2.ZERO
	velocity = wander_dir * 25.0
	sprite.flip_h = wander_dir.x < 0.0
	move_and_slide()

func _on_new_day(_day:int) -> void:
	produced_today = false

## 右键抚摸：产出一个产品（每天一次）
func pet() -> void:
	if product == null: return
	if produced_today:
		Global.show_message("%s今天已经产过了" % animal_name)
		return
	produced_today = true
	var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
	if !drops:
		drops = get_parent()
	fall_ins.is_bezier = true
	fall_ins.position = global_position + Vector2(8, 0)
	drops.add_child(fall_ins)
	fall_ins.generate(product)
	Global.show_message("%s产出了 %s！" % [animal_name, product.name])
