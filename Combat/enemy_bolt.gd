extends Projectile
## 敌人弹幕：直线飞行，命中玩家造成伤害，只被墙壁（层6）阻挡

@export var speed: float = 260.0
@export var damage: int = 12
@export var life: float = 2.5

var direction: Vector2 = Vector2.RIGHT

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	rotation = direction.angle()
	linear_velocity = direction * speed
	detect_area.body_entered.connect(_on_body_entered)

func setup(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	if is_inside_tree():
		rotation = direction.angle()
		linear_velocity = direction * speed

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(damage)
		queue_free()
		return
	# 只被墙壁（层6）阻挡，其余穿透
	if body is CollisionObject2D and (body.collision_layer & 64) == 0:
		return
	queue_free()
