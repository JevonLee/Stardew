extends Area2D
class_name HurtComponent


@export var tool:Item.ItemType = Item.ItemType.None #砍树所用工具
@export var max_health:int = 10 #当前物体能承受的伤害,10,5

var current_health:int = 0

signal hit_entered #工具进入hurt区域
signal hit_exited #工具退出hurt区域
#上面这两个信号主要用于处理非血量之外的特效之类的
signal body_droped #树被砍倒
signal root_droped #根被砍倒
signal damage_taken(damage:int, source_position:Vector2) #受到伤害（用于击退/闪白等）

func _ready() -> void:
	current_health = 0
	area_entered.connect(on_area_entered)
	area_exited.connect(on_area_exited)
	
func on_area_entered(area:Area2D) ->void:
	var hit = area as HitComponent
	if hit == null: return # 非工具命中区域（如箭矢检测区）忽略
	if hit.current_item_type == tool:
		var dmg: int = hit.damage
		# 暴击：武器暴击率 + 战斗技能加成（伤害翻倍）
		if randf() < hit.crit + Global.combat_crit_bonus():
			dmg *= 2
		current_health += dmg
		hit_entered.emit()
		damage_taken.emit(dmg, hit.global_position)
		if current_health >= max_health:
			body_droped.emit()
			root_droped.emit()
			current_health = 0 #防止重复触发

## 直接造成伤害（投射物等），source_position用于击退方向
func take_damage(amount:int, source_position:Vector2 = Vector2.ZERO) -> void:
	if current_health >= max_health: return
	current_health += amount
	damage_taken.emit(amount, source_position)
	if current_health >= max_health:
		body_droped.emit()
		root_droped.emit()
		current_health = 0

func on_area_exited(area:Area2D) -> void:
	var hit = area as HitComponent
	if hit == null: return
	if hit.current_item_type == tool:
		hit_exited.emit()
