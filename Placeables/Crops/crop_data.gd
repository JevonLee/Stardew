extends Resource
class_name CropData
## 作物数据（数据驱动）：生长天数/季节/产物/重长等

@export var crop_name:String = "作物"
@export var texture:Texture2D ## 生长序列图（hframes 帧 = 各生长阶段）
@export var hframes:int = 7
@export var growth_days:int = 7 ## 从种下到成熟需要的浇水天数
@export var regrow_days:int = 0 ## 收获后可再生长天数，0=一次性作物
@export var drops_count:int = 1 ## 每次收获的产物数量
@export var allowed_seasons:Array[int] = [0] ## 可种植季节（0春 1夏 2秋 3冬）
@export var harvest_item:Item ## 收获产物
