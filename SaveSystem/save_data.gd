extends Resource
class_name SaveData

@export var components:Array = [] #每个元素是对应SaveComponent保存的 Array[PackedScene]
@export var player_inventory:InventorySystem
@export var box_inventory:InventorySystem #箱子应该有一个唯一标识
@export var gold:int = 500
@export var player_stats:Dictionary = {} # health/stamina/mana
@export var day:int = 1
@export var weather:String = "sunny"
@export var friendships:Dictionary = {} # npc好感度
@export var quest:Dictionary = {} # 当前任务
@export var quest_day:int = -1
@export var collection:Dictionary = {} # 图鉴数据
@export var achievements:Dictionary = {} # 已解锁成就
@export var spouse:String = "" # 配偶
@export var museum:Dictionary = {} # 博物馆捐赠
@export var skills:Dictionary = {} # 技能等级
@export var skill_xp:Dictionary = {} # 技能经验
@export var shipping_pending:Array = [] # 出货箱待售物品
#还有tilemap类存档
