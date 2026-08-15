extends Control
class_name CraftingPanel
## 合成面板：列出配方，点击合成

signal closed

const RECIPES: Array[Recipe] = []

@onready var v_box: VBoxContainer = $Panel/MarginContainer/VBoxContainer

var recipe_rows: Array = []

func _ready() -> void:
	pass

func build(recipes: Array) -> void:
	for child in v_box.get_children():
		child.queue_free()
	recipe_rows.clear()
	for recipe in recipes:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if recipe.result:
			icon.texture = recipe.result.texture
		row.add_child(icon)
		var info := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = recipe.recipe_name
		info.add_child(name_label)
		var ing_label := Label.new()
		ing_label.text = _ingredients_text(recipe)
		ing_label.add_theme_font_size_override("font_size", 12)
		info.add_child(ing_label)
		row.add_child(info)
		var craft_btn := Button.new()
		craft_btn.text = "合成"
		craft_btn.pressed.connect(_on_craft_pressed.bind(recipe))
		row.add_child(craft_btn)
		v_box.add_child(row)
		recipe_rows.append(row)

func _ingredients_text(recipe: Recipe) -> String:
	var parts: Array[String] = []
	for i in recipe.ingredients.size():
		var item: Item = recipe.ingredients[i]
		var count: int = recipe.ingredient_counts[i] if i < recipe.ingredient_counts.size() else 1
		parts.append("%s x%d" % [item.name if item else "?", count])
	return "  ".join(parts)

func _on_craft_pressed(recipe: Recipe) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player == null: return
	# 检查材料
	for i in recipe.ingredients.size():
		var item: Item = recipe.ingredients[i]
		if item == null: continue
		var count: int = recipe.ingredient_counts[i] if i < recipe.ingredient_counts.size() else 1
		if not _has_count(player.bag_system.items, item.name, count):
			Global.show_message("材料不足：%s" % item.name)
			return
	# 扣材料
	for i in recipe.ingredients.size():
		var item: Item = recipe.ingredients[i]
		if item == null: continue
		var count: int = recipe.ingredient_counts[i] if i < recipe.ingredient_counts.size() else 1
		_remove_count(player.bag_system.items, item.name, count)
	# 给产物
	var result := recipe.result.duplicate()
	result.quantity = recipe.result_count
	player.bag_system.add_item(result)
	Global.show_message("合成了 %s x%d" % [recipe.recipe_name, recipe.result_count])

func _has_count(items: Array, item_name: String, count: int) -> bool:
	var total := 0
	for item in items:
		if item != null and item.name == item_name:
			total += item.quantity
	return total >= count

func _remove_count(items: Array, item_name: String, count: int) -> void:
	var remaining := count
	for i in items.size():
		if remaining <= 0: break
		var item: Item = items[i]
		if item != null and item.name == item_name:
			var take: int = mini(item.quantity, remaining)
			item.quantity -= take
			remaining -= take
			if item.quantity <= 0:
				items[i] = null
