extends Projectile
## 箭矢：直线飞行，命中敌人（Weapon类HurtComponent）造成伤害

@export var speed:float = 420.0
@export var damage:int = 8
@export var life:float = 2.0

var direction:Vector2 = Vector2.RIGHT

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	rotation = direction.angle()
	linear_velocity = direction * speed
	detect_area.area_entered.connect(_on_area_entered)
	detect_area.body_entered.connect(_on_body_entered)

func setup(dir:Vector2, dmg:int) -> void:
	direction = dir.normalized()
	damage = dmg
	if is_inside_tree():
		rotation = direction.angle()
		linear_velocity = direction * speed

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_area_entered(area:Area2D) -> void:
	# 只对敌人的受击区域（Weapon类HurtComponent）造成伤害并消失，忽略其他区域
	if area is HurtComponent and area.tool == Item.ItemType.Weapon:
		area.take_damage(damage, global_position)
		queue_free()

func _on_body_entered(body:Node2D) -> void:
	# 只有墙壁（层6）阻挡箭矢；敌人由HurtComponent结算，其他物体穿透
	if body is Enemy or body is Player:
		return
	if body is CollisionObject2D and (body.collision_layer & 64) == 0:
		return
	queue_free()
