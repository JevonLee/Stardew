extends Node2D
class_name EnemySpawner
## 敌人刷怪器：夜晚在玩家周围生成敌人，白天驱散

@export var enabled:bool = true
@export var night_only:bool = true
@export var spawn_interval:float = 6.0
@export var max_enemies:int = 8
@export var spawn_radius:float = 520.0
@export var min_spawn_distance:float = 180.0
@export var enemy_scenes:Array[PackedScene] = []

var timer:float = 0.0

func _process(delta: float) -> void:
	if not enabled: return
	var is_night := TimeSystem.current_hour >= 19 or TimeSystem.current_hour < 6
	if night_only and not is_night:
		# 白天：驱散剩余敌人
		for enemy in get_tree().get_nodes_in_group("Enemies"):
			if enemy is Enemy:
				enemy._despawn()
		return
	timer -= delta
	if timer > 0.0: return
	timer = spawn_interval
	var existing := get_tree().get_nodes_in_group("Enemies")
	if existing.size() >= max_enemies: return
	_spawn()

func _spawn() -> void:
	if enemy_scenes.is_empty(): return
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player == null: return
	var scene: PackedScene = enemy_scenes.pick_random()
	var enemy := scene.instantiate() as Enemy
	var angle := randf() * TAU
	var dist := randf_range(min_spawn_distance, spawn_radius)
	enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	enemy.add_to_group("Enemies")
	add_child(enemy)
