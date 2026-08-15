extends NPC
## 温泉老板：在温泉里经营生意，可对话送礼

@onready var sprite: Sprite2D = $Sprite2D

var anim_time: float = 0.0

func _physics_process(delta: float) -> void:
	anim_time += delta
	if sprite.vframes > 0:
		sprite.frame = int(anim_time * 8.0) % sprite.vframes
