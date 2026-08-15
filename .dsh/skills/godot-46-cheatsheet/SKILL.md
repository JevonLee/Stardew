---
name: godot-46-cheatsheet
description: Godot 4.6 / GDScript 4 关键 API 速查与常见坑：TileMapLayer、uid 引用、信号、Group、CanvasModulate、GL Compatibility 渲染限制、常用节点 API。写本项目代码前先查阅。
whenToUse: 编写或修改 GDScript/场景，需要确认 Godot 4.6 API 用法或避免已知坑时
---

# Godot 4.6 / GDScript 4 速查

## 版本要点（本项目 = 4.6，GL Compatibility）

- `TileMap` 在 4.3+ 已废弃，改用 **`TileMapLayer`**（每个图层一个节点，不再有 `layers` 字典）；`set_cell(coords, source_id, atlas_coords)` → `set_cell(coords, source_id, atlas_coords, alternative_tile)`
- 资源引用：.tscn/.tres 内用 `uid://...`；重命名/移动文件后必须重新导入，否则报 `res://` 找不到
- GL Compatibility：无 HDR 光、无 2D 光照贴图；`CanvasModulate`（全局色调）、`Light2D`（点光，兼容模式支持）、`CanvasGroup` 可用；`hdr_2d=true` 已开
- 像素风：`textures/canvas_textures/default_texture_filter=0`（最近邻过滤）已设置，新贴图默认保持

## GDScript 4 语法要点

- `@export var` 导出；`@export_group` 分组；`@onready var` 延迟获取
- 信号：`signal 名称(参数)`；发射 `名称.emit(...)`；连接 `pressed.connect(_on_pressed)`（可带 Callable 参数）
- 类型标注尽量写全：`var x: int`、`func f(a: Vector2) -> void`
- 枚举/常量：`enum State { IDLE, MOVE }`
- 字典/数组字面量：`{}`、`[]`；`for k in dict:` 遍历键；`dict.get(k, default)`
- 字符串：`"..."` 内插值用 `"值=%s" % v` 或 `"{v}".format({...})`
- 空安全：`node?.method()` 不存在；用 `if is_instance_valid(x)` 或 `x == null` 判断
- `await` 可用于信号/`create_timer`：`await get_tree().create_timer(0.5).timeout`
- 物理帧回调 `_physics_process(delta)`；普通帧 `_process(delta)`
- 避免在 `_ready` 中依赖其他节点未初始化的状态；autoload 在场景节点之前就绪

## 常用节点 API

| 需求 | API |
|---|---|
| 移动 | `CharacterBody2D` + `velocity` + `move_and_slide()`；`Input.get_vector("move_left","move_right","move_up","move_down")` |
| 检测 | `Area2D` + `body_entered/body_exited`；`get_overlapping_bodies()` |
| 动画 | `AnimatedSprite2D`：`play("name")`、`animation_finished`、`frame_changed`、`sprite_frames` |
| 碰撞形状 | `CollisionShape2D`（shape 用 `RectangleShape2D`/`CircleShape2D`）|
| 定时 | `get_tree().create_timer(秒).timeout`（注意：暂停时默认不跑，可用 `process_mode` 调整）|
| 暂停 | `get_tree().paused = true`；节点 `process_mode = PROCESS_MODE_WHEN_PAUSED` |
| 场景切换 | `get_tree().change_scene_to_file("res://...tscn")`；`change_scene_to_packed(packed)` |
| 实例化 | `var inst = scene.instantiate()`; `add_child(inst)` |
| 相机 | `Camera2D`：`position_smoothing_enabled`、`limit_left/right/top/bottom`、`zoom` |
| 屏幕坐标 | `get_viewport().get_mouse_position()`；`get_global_mouse_position()` |
| 世界坐标 | `node.get_global_mouse_position()`（CanvasItem 方法）|
| UI | `Control`、`Panel`、`Label`、`TextureRect`、`GridContainer`、`Button`；`mouse_filter` 控制穿透 |
| 拖拽 | `Control._get_drag_data/_can_drop_data/_drop_data` 或手动 `mouse_item` 方案（本项目用自定义）|
| 保存 | `FileAccess.open(path, FileAccess.WRITE)` / `READ`；`JSON.stringify/parse`；`user://` 用户目录 |
| 随机 | `randf()`、`randi_range(a,b)`、`randf_range(a,b)`；`RandomNumberGenerator` 可播种 |
| 瓦片 | `TileMapLayer.set_cell(coords, source_id, atlas_coords)`；`get_cell_source_id(coords)`；`local_to_map(world_pos)`、`map_to_local(coords)` |
| 组 | `add_to_group("名")`、`get_tree().get_nodes_in_group("名")`、`is_in_group("名")` |
| 输入 | `Input.is_action_just_pressed("名")`、`Input.is_action_pressed`、`Input.is_action_just_released` |
| 节点查找 | `get_node("路径")`、`$路径`、`find_child("名", true, false)` |

## 常见坑（本项目尤其注意）

1. **TileMapLayer**：老教程的 `tilemap.set_cell(0, ...)` 在 4.6 直接报错——必须用 TileMapLayer 单层 API
2. **uid 失效**：删除/移动资源后残留 `uid://` 引用 → 报错或加载失败；重新导入并修正引用
3. **GL Compatibility 下 Shader**：部分 2D 特效（如 SDF 雾）不可用；用 CanvasModulate/ColorRect 渐变更稳妥
4. **物理层掩码**：`collision_layer`/`collision_mask` 用位运算 `1 << 层号`（如第 5 层 = 1<<4 = 16）
5. **AnimatedSprite2D 素材**：星露谷人物帧 16x32/16x16 之类小图，注意 `hframes/vframes` 与 `region` 设置
6. **gl_compatibility 中 Camera2D 平滑**：`position_smoothing_enabled` 在低帧率下会抖动，必要时关掉或用 lerp 自实现
7. **导出时**：export_presets.cfg 已存在；Windows 导出建议保留
8. **场景切换时 autoload 持久**：全局状态放 autoload（Global/TimeSystem/SaveManager），场景内数据用组/信号同步
9. **字符串键枚举**：物品 id 用字符串常量集中管理，避免散落魔法字符串
10. **`--headless` 冒烟测试**：UI 动画/Shader 在 headless 下可能无渲染，但脚本逻辑错误（空引用、非法调用）会打印 SCRIPT ERROR，测试日志以红色 ERROR 为准
