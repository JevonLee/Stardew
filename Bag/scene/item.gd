extends Resource
class_name Item

enum ItemType{
	None,
	Tool,##工具	
	Hoe,##锄头
	Axe,##斧头
	Draft,##稿子
	Water,##水壶
	Weapon,##近战武器
	Consume,##消耗品
	Placeables,##可放置的物品
	Crops,##植物，作物等可以生长的物品
	Materials,##可合成的材料类物品 
	Accessories,##饰品
	Floors,##地板类
}
enum UseType{
	None,
	Swing, ##挥舞
	Hold, ##手持
}
enum DamageType{
	None,
	Melee,##近战
	Magic,##魔法
	Summon,##召唤
	Shoot,##远程
}

@export var name:String ## 物品的名字
@export var type:ItemType ## 物品类型
@export_multiline var description:String
@export var quantity:int = 1
@export var max_quantity:int = 999
@export var countable:bool
@export var texture:Texture
@export var price:int = 1 ##物品价格
#下面是武器类的专属属性
@export_category("武器属性")
@export var collision_size:Vector2 ## 碰撞箱宽度高度
@export var use_time:int
@export var use_animation:int ##可以调整动画节点的speed_scale值
@export var auto_use:bool
@export var damage:int
@export var crit:float ## 暴击
@export var knockback:float ##击退
@export var open_trail:bool ##是否开启贴图攻击尾迹
@export var open_texture:bool ##是否开启贴图
@export var use_type:UseType
@export var damage_type:DamageType
@export var projectile:String
#放置类物品的属性
@export_category("放置类物品属性")
@export var placeable_scene_path:String
#消耗品属性（食物/药水：右键食用恢复）
@export_category("消耗品属性")
@export var health_restore:int = 0
@export var stamina_restore:int = 0
@export var mana_restore:int = 0

func is_max_quantity() -> bool:
	return quantity>=max_quantity

func set_weapon(damage:int,crit:float,knockback:float) -> void:
	self.damage = damage
	self.crit = crit
	self.knockback = knockback
