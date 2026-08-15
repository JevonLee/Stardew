extends Node2D
class_name PlaceComponent

var item_to_place:Item:
	get:
		return item_to_place
	set(val):
		_clear_preview()
		item_to_place = val
		if val.type == Item.ItemType.Placeables:
			_create_placement_preview()
var preview_ins:Placeable
var player:Player	
		
func _ready() -> void:
	await  get_tree().physics_frame
	player = get_tree().get_first_node_in_group("Player")	

func _physics_process(delta: float) -> void:
	if preview_ins != null:
		var mouse_position = get_global_mouse_position()
		var rounded_position = Vector2(int(round(mouse_position.x)),int(round(mouse_position.y)))
		#做些舍入，确保移动到真正的整像素值
		preview_ins.global_position = rounded_position

func _unhandled_input(event: InputEvent) -> void:
	if preview_ins == null : return
	if event.is_action_pressed("mouse_left"):
		_place_item()

func _clear_preview() -> void:
	if preview_ins == null:
		return
	preview_ins.queue_free()
	
func _create_placement_preview() -> void:
	if item_to_place == null:
		return
	
	var preview_scene = load(item_to_place.placeable_scene_path)
	preview_ins = preview_scene.instantiate() as Placeable #作物目前还不是Placeable
	preview_ins.set_collision_enabled(false) #
	get_tree().root.add_child(preview_ins)
	preview_ins.previewing = true
	
func _place_item() -> void:
	if preview_ins == null:
		return
	if !preview_ins.can_place:
		return
	player.bag_system.remove_num_item(player.item_index,1)
	
	preview_ins.set_collision_enabled(true)
	preview_ins.previewing = false
	var placed: Placeable = preview_ins
	preview_ins = null
	item_to_place = null
	
	# 挂到当前关卡的Crops容器下，随存档一起保存
	var level: Node2D = SceneManager.get_current_level()
	if level:
		var crops_container: Node2D = level.find_child("Crops") as Node2D
		if crops_container:
			if placed.get_parent():
				placed.get_parent().remove_child(placed)
			crops_container.add_child(placed)
