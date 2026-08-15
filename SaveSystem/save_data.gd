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
#还有tilemap类存档
