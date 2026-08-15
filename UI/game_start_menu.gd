extends CanvasLayer

@onready var title: TextureRect = %Title
@onready var buttons: MarginContainer = %Buttons
@onready var create: TextureButton = %Create
@onready var load: TextureButton = %Load
@onready var coop: TextureButton = %Coop
@onready var exit: TextureButton = %Exit

@export var bg_music1:AudioStream

func _ready() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(title,"global_position",Vector2(342,90),0.5)
	tween.set_parallel()
	tween.tween_property(buttons,"global_position",Vector2(408,440),0.5)
	create.pressed.connect(_on_create_pressed)
	load.pressed.connect(_on_load_pressed)
	coop.pressed.connect(_on_coop_pressed)
	exit.pressed.connect(_on_exit_pressed)
	AudioManager.play_music(bg_music1)

func _on_create_pressed() -> void:
	# 新游戏：清除旧存档并重置全局状态
	DirAccess.remove_absolute("user://abc.tres")
	Global.gold = 500
	TimeSystem.set_time(1, 6, 0)
	SceneManager.load_main_scene()
	queue_free()


func _on_load_pressed() -> void:
	SceneManager.load_main_scene()
	await get_tree().process_frame
	SaveManager._load()
	queue_free()

func _on_coop_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().quit()
