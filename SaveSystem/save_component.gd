extends Node
class_name SaveComponent
## 作为需要存档的节点的子节点，对属性的获取和赋值都是通过这个组件

func _ready() -> void:
	await get_parent().ready
	add_to_group("SaveComponents")
	

func get_save_data() -> Array[PackedScene]:
	var result:Array[PackedScene] = []
	var parent = get_parent()
	for child in parent.get_children():
		var pack_scene = PackedScene.new()
		pack_scene.pack(child)
		if child.name != "SaveComponent":
			result.append(pack_scene)
	return result
	
func set_save_data(nodes:Array[PackedScene]) -> void:
	var parent = get_parent()
	#先清理旧子节点，避免重复加载
	for child in parent.get_children():
		if child.name != "SaveComponent":
			child.queue_free()
	for child in nodes:
		var pack_node = child.instantiate()
		parent.add_child(pack_node)
