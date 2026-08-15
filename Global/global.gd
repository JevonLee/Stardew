extends Node
## Autoload，用于存储常量与全局状态（金币等）

const TOOL_TIP = preload("res://UI/tool_tip.tscn")
const FALL_OBJECT_COMPONENT = preload("res://FallObjects/fall_object_component.tscn")

var root_scene:Dictionary = { ##"main_scene""main_canvas_layer""pop_up""levels""drops""ui_manager"
	"main_scene": "/root/MainScene",
	"main_canvas_layer":"/root/MainScene/MainCanvasLayer",
	"pop_up":"/root/MainScene/MainCanvasLayer/PopUp",
	"levels":"/root/MainScene/Levels",
	"drops":"/root/MainScene/Drops",
	"ui_manager":"/root/MainScene/MainCanvasLayer/UIManager",
}

signal gold_changed(gold:int)

var gold:int = 500: ## 玩家金币
	set(val):
		gold = maxi(val, 0)
		gold_changed.emit(gold)

var mine_floor:int = 1 ## 进入矿洞的层数（由楼梯设置，矿洞读取后重置）

## 技能系统：钓鱼/采矿/农业/采集/战斗技能等级（10级上限，每级效果增强）
var skills:Dictionary = {"fishing": 0, "mining": 0, "farming": 0, "foraging": 0, "combat": 0}
var skill_xp:Dictionary = {"fishing": 0, "mining": 0, "farming": 0, "foraging": 0, "combat": 0}
const SKILL_NAMES := {"fishing": "钓鱼", "mining": "采矿", "farming": "农业", "foraging": "采集", "combat": "战斗"}

## 获得技能经验（每10点升1级，上限10级）
func add_skill_xp(skill: String, amount: int) -> void:
	skill_xp[skill] = skill_xp.get(skill, 0) + amount
	while skill_xp[skill] >= 10:
		skill_xp[skill] -= 10
		skills[skill] = mini(skills.get(skill, 0) + 1, 10)
		show_message("%s技能升级！当前%d级" % [SKILL_NAMES.get(skill, skill), skills[skill]])

## 钓鱼技能：每级使钓鱼难度再降低2%（10级共-20%）
func fishing_skill_multiplier() -> float:
	return 1.0 - 0.02 * skills.get("fishing", 0)

## 采矿技能：每级5%概率双倍矿石（10级共50%）
func mining_double_chance() -> float:
	return 0.05 * skills.get("mining", 0)

## 农业技能：每级5%概率额外收获一次（10级共50%）
func farming_bonus_chance() -> float:
	return 0.05 * skills.get("farming", 0)

## 采集技能：每级5%概率双倍采集（10级共50%）
func foraging_double_chance() -> float:
	return 0.05 * skills.get("foraging", 0)

## 战斗技能：每级2%暴击率加成（10级共20%）
func combat_crit_bonus() -> float:
	return 0.02 * skills.get("combat", 0)

## 出货箱待售物品（当晚结算卖出）
var shipping_pending: Array = [] ## Array[Item]

## ---------- 开发者功能 ----------
var god_mode: bool = false ## 无敌模式（F2切换）
var item_panel: Control = null ## 物品生成器面板（F3）
var help_panel: Control = null ## 帮助指南面板（H）
var _item_cache: Array = [] ## 扫描到的全部物品

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("god_mode"):
		god_mode = !god_mode
		show_message("无敌模式：" + ("开启！" if god_mode else "关闭"))
	elif event.is_action_pressed("dev_items"):
		_toggle_item_panel()
	elif event.is_action_pressed("help_panel"):
		_toggle_help_panel()

## 扫描 Bag/items 下所有物品资源
func _scan_all_items() -> Array:
	if not _item_cache.is_empty():
		return _item_cache
	var items: Array = []
	_scan_item_dir("res://Bag/items", items)
	_item_cache = items
	return items

func _scan_item_dir(path: String, items: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir() and f != "." and f != "..":
			_scan_item_dir(path + "/" + f, items)
		elif f.ends_with(".tres"):
			var res = load(path + "/" + f)
			if res is Item and res.name != "":
				items.append(res)
		f = dir.get_next()
	dir.list_dir_end()

## 物品生成器面板（F3）：列出全部物品，点击获得
func _toggle_item_panel() -> void:
	var canvas := get_node_or_null(root_scene["main_canvas_layer"]) as CanvasLayer
	if canvas == null: return
	if item_panel == null:
		item_panel = Control.new()
		item_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.4)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_panel.add_child(dim)
		var box := Panel.new()
		box.position = Vector2(280, 60)
		box.size = Vector2(720, 600)
		item_panel.add_child(box)
		var title := Label.new()
		title.text = "物品生成器（F3关闭）— 点击获取"
		title.position = Vector2(16, 10)
		box.add_child(title)
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(16, 44)
		scroll.size = Vector2(688, 540)
		box.add_child(scroll)
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		for item in _scan_all_items():
			var btn := Button.new()
			btn.text = "%s  （%d金）" % [item.name, item.price]
			btn.custom_minimum_size = Vector2(0, 34)
			btn.pressed.connect(_give_item.bind(item))
			vbox.add_child(btn)
		canvas.add_child(item_panel)
	item_panel.visible = !item_panel.visible

func _give_item(item: Item) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player == null: return
	var ins: Item = item.duplicate()
	ins.quantity = 1
	player.bag_system.add_item(ins)
	show_message("获得 %s ×1" % item.name)

## 帮助指南面板（H）：键位与玩法说明
func _toggle_help_panel() -> void:
	var canvas := get_node_or_null(root_scene["main_canvas_layer"]) as CanvasLayer
	if canvas == null: return
	if help_panel == null:
		help_panel = Control.new()
		help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		help_panel.add_child(dim)
		var box := Panel.new()
		box.position = Vector2(200, 40)
		box.size = Vector2(880, 640)
		help_panel.add_child(box)
		var title := Label.new()
		title.text = "游戏指南（H关闭）"
		title.position = Vector2(16, 10)
		box.add_child(title)
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(16, 44)
		scroll.size = Vector2(848, 580)
		box.add_child(scroll)
		var label := RichTextLabel.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.fit_content = true
		label.bbcode_enabled = true
		label.text = _help_text()
		scroll.add_child(label)
		canvas.add_child(help_panel)
	help_panel.visible = !help_panel.visible

func _help_text() -> String:
	return "[b]【基础操作】[/b]
移动：WASD　　背包：E　　丢弃：Q　　交互/睡觉：F
合成面板：C　　图鉴：G　　旅行传送：M　　帮助：H
左键：攻击/使用工具/放置　　右键：食用/召唤/送礼/喂食
[b]【开发者功能】[/b]
F2：无敌模式开关　　F3：物品生成器（获取任意物品）
屏幕右上角：存档/加载/时间按钮
[b]【合成与材料】[/b]
按C打开合成面板（80+配方，可滚动）。材料：木头/石头砍树敲石；
矿石在矿洞与采石场（M键传送）；金属锭由矿石×5合成；
骨头/蛛网/凝胶打怪掉落（骷髅/蜘蛛/史莱姆）。
[b]【Boss战】[/b]
合成召唤物 → 夜晚（19点后）手持右键使用 → 顶部出现Boss血条。
克苏鲁之眼（可疑眼球=凝胶×10）；史莱姆王（王冠=凝胶×30）；
血肉墙（向导娃娃=骨头×15）；双子魔眼（机械魔眼=铁锭6+金锭4+骨头15）；
骷髅王（巫毒娃娃=骨头25+蛛网10+金锭5）；月亮领主（天界符=金锭10+四色宝石×8）；
猪鲨（虾松露=鲤鱼3+章鱼2+金锭10+骨头15）……共20个Boss，合成面板全部可见。
等夜晚：现实1秒=游戏1分钟；或去温泉泡澡、准备战斗物资。
[b]【快速成长】[/b]
农作物成熟后挥武器收获 → 出货箱（小屋旁）晚上自动卖钱；
钓鱼得宝箱；采石场安全挖矿练采矿技能；花卉送村民好感翻倍可求婚（10心+花束）。"

## 在 PopUp 上显示一条短暂提示文字
func show_message(text:String) -> void:
	var pop_up = get_node_or_null(root_scene["pop_up"])
	if pop_up == null: return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(430, 400)
	label.z_index = 100
	pop_up.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", 330.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tween.tween_callback(label.queue_free)
