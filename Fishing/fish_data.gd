extends Resource
class_name FishData
## 鱼类数据

@export var fish_name:String = "鱼"
@export var item:Item ## 钓上来的物品
@export var difficulty:float = 0.5 ## 0容易 1困难（影响鱼的游动速度与进度增减）
@export var seasons:Array[int] = [0, 1, 2, 3] ## 出现的季节
