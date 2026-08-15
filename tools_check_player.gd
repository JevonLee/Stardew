extends SceneTree

func _init() -> void:
	var packed = load("res://Player/player.tscn")
	print("PLAYER_LOADED=", packed)
	if packed != null:
		var inst = packed.instantiate()
		print("PLAYER_INST=", inst)
		inst.free()
	quit()
