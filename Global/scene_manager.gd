extends Node
## Autoload

signal level_changed ##在levels之外的节点，初始化等操作如信号等，在更改场景后需要再次操作，
##比如箱子节点，之前已经连过的信号，在更改场景之后就会断，需要重连


var main_scene_path :String = "res://Main/MainScene.tscn"
var main_scene_level_root:String = "/root/MainScene"

var level_scenes:Dictionary = {
	"Farm" : "res://Map/Farm/farm.tscn",
	"MyHouse" : "res://Map/MyHouse/my_house.tscn",
	"Town" : "res://Map/Town/town.tscn",
	"Store" : "res://Map/Store/store.tscn",
	"Mine" : "res://Map/Mine/mine.tscn",
	"Forest" : "res://Map/Forest/forest.tscn",
	"Desert" : "res://Map/Desert/desert.tscn",
	"Beach" : "res://Map/Beach/beach.tscn",
	"Bathhouse" : "res://Map/Bathhouse/bathhouse.tscn",
	"Jungle" : "res://Map/Jungle/jungle.tscn",
	"Tundra" : "res://Map/Tundra/tundra.tscn",
	"Dungeon" : "res://Map/Dungeon/dungeon.tscn",
} 
var player : Player

func _ready() -> void:
	level_changed.connect(on_level_changed)
	player = get_tree().get_first_node_in_group("Player")

func on_level_changed() -> void:
	player = get_tree().get_first_node_in_group("Player")

func load_main_scene() -> void:
	if get_tree().root.has_node(main_scene_level_root): return
	
	var main_scene :Node2D= load(main_scene_path).instantiate()
	if main_scene != null:
		get_tree().root.add_child(main_scene)
		level_changed.emit()

func change_level(target_level:String,spawn_pos_name:String) -> void:
	## {Farm,MyHouse}
	var scene_path = level_scenes.get(target_level)
	if scene_path == null : return
	var target_scene = load(scene_path).instantiate()
	
	var main_scene = get_tree().root.get_node(main_scene_level_root)#通过绝对路径获取节点
	if main_scene == null : return
	
	#SaveManager._save()
	var levels = main_scene.find_child("Levels")
	#释放levels子节点，释放旧场景
	if levels != null :
		var nodes = levels.get_children()
		if nodes != null:
			for node in nodes:
				node.queue_free()
		await get_tree().process_frame
	#加载新场景
	levels.add_child(target_scene)
	#SaveManager._load()
	level_changed.emit()
	set_spawn_position(spawn_pos_name)
	
func set_spawn_position(spawn_pos_name:String) -> void:
	var spawn_poss = get_tree().get_nodes_in_group("SpawnPosition")
	#await levels.ready
	if spawn_poss == null: return
	if spawn_poss.size() == 1:
		player.global_position = spawn_poss[0].global_position
	else:
		for spawn_pos in spawn_poss:
			if spawn_pos.name == spawn_pos_name:
				player.global_position = spawn_pos.global_position
	
func get_current_level() -> Node2D: ##获得所在场景的根节点
	var main_scene = get_tree().root.get_node(main_scene_level_root)#通过绝对路径获取节点
	if main_scene == null : return null
	var levels = main_scene.find_child("Levels")
	if levels == null : return null
	var node : Node = levels.get_child(0)
	if node == null : return null
	return node
