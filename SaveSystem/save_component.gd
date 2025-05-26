extends Node
class_name SaveComponent
## 作为需要存档的节点的子节点，对属性的获取和赋值都是通过这个组件

func _ready() -> void:
	await get_parent().ready
	add_to_group("SaveComponents")
	

func get_save_data() -> Array[PackedScene]:
	var save_data = SaveData.new()
	var parent = get_parent()
	for child in parent.get_children():
		var pack_scene = PackedScene.new()
		pack_scene.pack(child)
		if child.name != "SaveComponent":
			save_data.nodes.append(pack_scene)
	return save_data.nodes
	
func set_save_data(nodes:Array[PackedScene]) -> void:
	var parent = get_parent()
	#for child in parent.get_children():
		#child.queue_free()
	for child in nodes:
		var pack_node = child.instantiate()
		parent.add_child(pack_node)
