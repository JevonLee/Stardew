---
name: project-conventions
description: 本项目（Godot 4.6 星露谷复刻 + 泰拉瑞亚战斗）的架构地图与开发约定：目录职责、autoload 单例、输入映射、物理层、全局组、命名规范、headless 验证流程。开发任何功能前先阅读本 skill。
whenToUse: 在本项目中新增或修改功能、新建脚本或场景、需要了解现有系统架构或验证方式时
---

# Stardew 项目开发约定（deepseek 分支）

## 项目概况

- Godot **4.6**，GL Compatibility 渲染器（注意：无高级 2D 光照效果，SDF/CanvasModulate 可用）
- 窗口 1280x720 固定尺寸，`canvas_items` 拉伸，`expand` 纵横比
- 引擎可执行文件：`D:\GoDot\Godot_v4.6.3-stable_win64.exe`
- 项目路径：`D:\GoDot\Program\4\Stardew`
- 素材：`Art/` 内含星露谷（StardewValley/、tile_sheets/、character/、maps/、portraits/、buildings/、terrain/）与泰拉瑞亚（Terraria/）两套素材

## 目录职责

| 目录 | 职责 |
|---|---|
| `Global/` | 全局单例与跨场景工具：global.gd、scene_manager、audio_manager、mouse_cursor、mouse_item、save_manager |
| `Player/` | 玩家本体与状态机（`States/` 子目录：idle/move/swing/axe/hoe/water/draft/state/state_machine）|
| `Bag/` | 背包系统：inventory_system、item、slot、tool_bar、bag_ui、box、box_ui、ui_manager；`projectiles/` 为武器投射物（彩虹猫、暗影焰刀、烈焰激光）|
| `Map/` | 地图场景：Farm、Town、MyHouse、Store（含 commodity/store_panel 商店）及 change_scene_area |
| `NPC/` | 村民：`dialogue/`（dialogue、dialogue_ui）、emily、pig |
| `Placeables/` | 可放置物：`Crops/`（crops_component、甜瓜）、place_component、placeable、placeable_footprint |
| `Terrain/` | 地形可破坏物：Grass/、Rocks/、Trees/ |
| `Weapons/` | 武器系统与剑气（jian_qi）|
| `FallObjects/` | 掉落物与战利品表：fall_object_component、loot_table |
| `TimeSystem/` | 时间/昼夜循环：time_system、time_color、time_system_ui |
| `SaveSystem/` | 存档：save_data、save_component |
| `UI/` | 界面：game_start_menu、tool_tip、get_item_tip、save_tool_tip |
| `AudioSystem/` | 音频资源与播放 |
| `Component/` | 通用可复用组件：click_area、hit、hurt、tilemap_component |
| `Shader/` | 着色器资源 |

## Autoload 单例（加载顺序见 project.godot）

1. `Global`（Global/global.gd）— 全局状态/工具
2. `SceneManager`（Global/scene_manager.tscn）— 场景切换
3. `AudioManager`（Global/audio_manager.gd）
4. `MouseCursor`（Global/mouse_cursor.tscn）— 游戏内鼠标光标
5. `MouseItem`（Global/mouse_item.gd）— 鼠标拖动物品
6. `TimeSystem`（TimeSystem/time_system.gd）— 游戏时间
7. `SaveManager`（Global/save_manager.gd）— 存档读写

## 输入映射

| 动作 | 键 |
|---|---|
| move_up/down/left/right | W/A/S/D |
| open_bag | E |
| drop | Q |
| Esc | Esc |
| mouse_left / mouse_right | 鼠标左右键 |
| scroll_up / scroll_down | 滚轮 |
| test | `（反引号，调试用）|

## 物理层（2D）

1=Player，2=Objects，3=Tools，4=Placeable，5=Terrain，6=Wall，7=ChangeSeneArea

## 全局组

`Boxes`、`Player`、`TileMap`、`SpawnPosition`（各场景出生点）、`ToolTip`、`SaveComponents`

## 命名与代码风格

- 文件/目录一律 `snake_case`（.gd/.tscn/.tres）
- 类名 PascalCase；变量/函数 snake_case；常量 UPPER_SNAKE
- 存档对象：实现/挂接 SaveSystem 协议并加入 `SaveComponents` 组，由 SaveManager 统一序列化
- 交互物体：使用 Component/click_area_component 提供鼠标交互与 ToolTip 组提示
- 新系统优先做成独立目录 + 场景/脚本，再挂接 autoload 或主场景，避免把逻辑堆进 Player

## Headless 验证流程（每完成一批功能必须执行）

```powershell
# 1) 导入资源并检查解析/脚本错误
& 'D:\GoDot\Godot_v4.6.3-stable_win64.exe' --headless --path 'D:\GoDot\Program\4\Stardew' --import *> import_check.log

# 2) 冒烟测试：运行主场景若干帧（捕捉 _ready/_process 运行时错误）
& 'D:\GoDot\Godot_v4.6.3-stable_win64.exe' --headless --path 'D:\GoDot\Program\4\Stardew' --quit-after 10 *> smoke_test.log

# 2b) 深度冒烟测试（全功能回归，61+项断言，约20秒）
& 'D:\GoDot\Godot_v4.6.3-stable_win64.exe' --headless --path 'D:\GoDot\Program\4\Stardew' 'res://tools_smoke.tscn' --quit-after 1500

# 3) 单脚本语法检查
& 'D:\GoDot\Godot_v4.6.3-stable_win64.exe' --headless --check-only --script 'res://路径/脚本.gd'
```

- 红色 ERROR/SCRIPT ERROR 必须修复；资源缺失警告按需处理
- 修改 .tscn 后再次 --import 确保无 uid/路径错误
