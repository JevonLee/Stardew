extends Node2D
class_name Bobber
## 浮漂：抛物线飞向落点 → 漂浮 → 咬钩（变红并发信号）

signal bite(bobber: Bobber)

const BOB_AMOUNT: float = 4.0

var target: Vector2 = Vector2.ZERO
var flying: bool = true
var waiting_bite: bool = false
var hooked: bool = false
var bite_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var start := global_position
	var mid := (start + target) / 2.0 + Vector2(0.0, -70.0)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void: global_position = _quad(start, mid, target, t),
		0.0, 1.0, 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land)

func _quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p2, t)

func _land() -> void:
	flying = false
	waiting_bite = true
	bite_timer = randf_range(1.8, 3.6)

func _process(delta: float) -> void:
	if flying: return
	if hooked:
		sprite.position.y = sin(Time.get_ticks_msec() * 0.02) * 3.0
		return
	if waiting_bite:
		sprite.position.y = sin(Time.get_ticks_msec() * 0.006) * BOB_AMOUNT
		bite_timer -= delta
		if bite_timer <= 0.0:
			_hook()

func _hook() -> void:
	waiting_bite = false
	hooked = true
	sprite.modulate = Color(1.0, 0.25, 0.25)
	bite.emit(self)

## 鱼跑掉后浮漂复位，继续等待
func reset_after_escape() -> void:
	hooked = false
	waiting_bite = true
	bite_timer = randf_range(1.5, 3.0)
	sprite.modulate = Color.WHITE
	sprite.position.y = 0.0
