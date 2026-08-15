extends Control

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var portaits: TextureRect = $Portaits
@onready var npc_name: Label = $NpcName
@onready var hearts_label: Label = $Hearts

var dialogue_index = 0
var dialogue:Dialogue
var typing_tween:Tween
var npc_name_override:String = ""
var hearts:float = 0.0

func _ready() -> void:
	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self,"global_position",Vector2(640,720),0.5)
	await tween.finished
	dialogue_next()

func dialogue_next() -> void:
	if dialogue == null : return
	if dialogue_index >= dialogue.texts.size() : 
		var tween = get_tree().create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self,"global_position",Vector2(640,1120),0.3)
		await tween.finished
		queue_free()
		return
	
	var content = dialogue.texts[dialogue_index]
	
	if typing_tween and typing_tween.is_running():
		typing_tween.kill()
		rich_text_label.text = content
		dialogue_index+=1
		
	npc_name.text = dialogue.npc_name if npc_name_override == "" else npc_name_override
	portaits.texture = dialogue.protaits
	hearts_label.text = _hearts_text()
	rich_text_label.text = ""
	
	typing_tween = get_tree().create_tween()

	for char in content:
		typing_tween.tween_callback(func():rich_text_label.text+=char).set_delay(0.05)
	typing_tween.tween_callback(func():dialogue_index+=1)

func _hearts_text() -> String:
	var full: int = int(hearts)
	var half: bool = hearts - full >= 0.5
	var text := ""
	for i in 10:
		if i < full:
			text += "♥"
		elif i == full and half:
			text += "❤"
		else:
			text += "♡"
	return text

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		dialogue_next()
