extends Node2D
class_name Crop
## 通用作物：数据驱动生长（浇水/雨水/季节/收获/重长）

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var hurt_component: HurtComponent = $HurtComponent

@export var crop_data:CropData
@export var cell:Vector2i = Vector2i.ZERO ## 所在格子（存档）
@export var planted_day:int = -1 ## 种植时的天数（存档）
@export var growth_stage:int = 0 ## 当前生长阶段（存档）

var water_soil:TileMapLayer
var farm:Node2D
var withering:bool = false

func _ready() -> void:
	farm = get_parent().get_parent() as Node2D # Crops容器 -> 农场
	if farm:
		water_soil = farm.get_node_or_null("WaterSoil") as TileMapLayer
	TimeSystem.time_tick_day.connect(_on_day_change)
	hurt_component.body_droped.connect(_on_body_droped)
	area_2d.body_entered.connect(_on_body_entered)
	apply_data()

func is_mature() -> bool:
	return crop_data != null and growth_stage >= crop_data.growth_days

func apply_data() -> void:
	if crop_data == null: return
	sprite_2d.texture = crop_data.texture
	sprite_2d.hframes = maxi(crop_data.hframes, 1)
	update_sprite()

func update_sprite() -> void:
	if crop_data == null: return
	sprite_2d.frame = clampi(growth_stage, 0, crop_data.hframes - 1)

## 每天清晨结算：季节约束 → 浇水/雨水 → 生长
func _on_day_change(day:int) -> void:
	if crop_data == null: return
	# 季节约束：不在允许季节 → 枯萎
	var season:int = TimeSystem.get_season()
	if not crop_data.allowed_seasons.has(season):
		if not withering:
			withering = true
			modulate = Color(0.45, 0.4, 0.25)
			sprite_2d.self_modulate = Color(0.6, 0.5, 0.3)
		return
	if withering: return
	# 浇水/雨水检查：没水不长
	if not _is_watered():
		return
	growth_stage = mini(growth_stage + 1, crop_data.hframes - 1)
	update_sprite()

## 浇水检查：格子所在 WaterSoil 有水 或 当天下雨/雪
func _is_watered() -> bool:
	if WeatherSystem.is_raining() or WeatherSystem.is_snowing():
		return true
	if water_soil == null: return false
	return water_soil.get_cell_source_id(cell) != -1

## 被武器打中（HurtComponent）：成熟才收获
func _on_body_droped() -> void:
	if crop_data == null: return
	if not is_mature():
		Global.show_message("%s 还没成熟！" % crop_data.crop_name)
		return
	_harvest()

func _harvest() -> void:
	if crop_data == null or crop_data.harvest_item == null: return
	for i in crop_data.drops_count:
		_drop_item(crop_data.harvest_item)
	QuestSystem.report("harvest")
	if crop_data.regrow_days > 0:
		growth_stage = maxi(crop_data.growth_days - crop_data.regrow_days, 0)
		update_sprite()
	else:
		queue_free()

func _drop_item(item:Item) -> void:
	var fall_ins = Global.FALL_OBJECT_COMPONENT.instantiate()
	var drops = get_node_or_null(Global.root_scene["drops"]) as Node2D
	if !drops:
		drops = get_parent()
	fall_ins.is_bezier = true
	fall_ins.position = global_position
	drops.add_child(fall_ins)
	fall_ins.generate(item)

## 成熟后玩家靠近时轻微摇摆
func _on_body_entered(body:Node2D) -> void:
	if body is Player and is_mature() and sprite_2d.material:
		var direction := global_position.direction_to(body.global_position)
		var skew := -direction.x * 5
		var tween := create_tween()
		tween.tween_property(sprite_2d.material, "shader_parameter/skew", skew, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_2d.material, "shader_parameter/skew", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
