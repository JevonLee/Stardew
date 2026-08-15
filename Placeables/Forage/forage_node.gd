extends Area2D
class_name ForageNode
## 野外采集物：走过即可拾取，次日清晨重新刷新

@onready var sprite: Sprite2D = $Sprite2D

@export var item: Item

var player: Player
var bobbing: float = 0.0
var picked: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(_on_body_entered)
	bobbing = randf() * TAU
	if item:
		sprite.texture = item.texture

func _process(delta: float) -> void:
	bobbing += delta * 3.0
	sprite.position.y = sin(bobbing) * 2.0
	if player == null: return
	# 玩家靠近时轻微磁吸，简化拾取手感
	if global_position.distance_to(player.global_position) < 40.0 and not picked:
		_pick()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not picked:
		_pick()

func _pick() -> void:
	picked = true
	player.bag_system.add_item(item)
	player.get_item.emit(item)
	QuestSystem.report("forage")
	CollectionSystem.record_item(item.name)
	Global.show_message("拾取了 %s" % item.name)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
