extends Area2D

@export_enum("Farm","MyHouse","Town","Store","Mine","Forest","Desert","Beach","Bathhouse","Jungle","Tundra","Dungeon","Quarry") var target_scene:String = "Farm"
## 如果有多个生成点，则生成节点名、枚举类型名、目标场景根节点名相同

func _ready() -> void:
	body_entered.connect(on_body_entered)
	
func on_body_entered(body:Node2D) -> void:
	if body is Player:
		var current_scene = SceneManager.get_current_level()
		var pos_name = current_scene.name
		SceneManager.change_level(target_scene,pos_name)
