extends Resource
class_name Recipe
## 合成配方

@export var recipe_name:String = "配方"
@export var result:Item ## 产物
@export var result_count:int = 1
@export var ingredients:Array[Item] = [] ## 所需材料
@export var ingredient_counts:Array[int] = [] ## 对应数量
