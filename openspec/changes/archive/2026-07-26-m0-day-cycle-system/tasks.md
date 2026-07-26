## 1. 事件总线

- [x] 1.1 创建 `game/scripts/core/event_bus.gd`：`extends Node`，声明 `day_started(day_index)` / `phase_changed(phase)` / `tick_advanced(tick_index)` / `day_ended(day_index)` 四个信号，不含业务逻辑

## 2. 时间/tick 系统

- [x] 2.1 创建 `game/scripts/core/day_cycle.gd`：定义 `enum Phase { DECISION, SIMULATION, SETTLEMENT }`、状态变量 `current_day/current_phase/current_tick`、占位常量 `TICKS_PER_DAY/TICK_INTERVAL`
- [x] 2.2 实现 `_ready`（建 Timer）、`start_new_day`、`set_phase`、`begin_simulation`、`_on_tick`、`_settle`，按 spec 发射对应信号并启停 Timer

## 3. 存档系统

- [x] 3.1 创建 `game/scripts/core/save_manager.gd`：实现 `save_game` / `load_game` / `has_save` / `delete_save`，以 JSON 读写 `user://savegame.json`，存读 `DayCycle` 的 day/phase/tick

## 4. 验证场景

- [x] 4.1 创建 `game/scripts/main.gd`：连接 `EventBus` 信号，`_ready` 调用 `DayCycle.start_new_day()`，按键驱动循环（空格→模拟、回车→下一天、S 存档、L 读档）
- [x] 4.2 在 Godot 编辑器创建 `game/scenes/main.tscn`（根节点 `Node`），附加 `main.gd`，设为主场景

## 5. 集成与验证

- [x] 5.1 在 Godot 编辑器注册 Autoload，顺序：`EventBus` → `DayCycle` → `SaveManager`
- [x] 5.2 F5 运行，验证空的一天循环（决策→模拟→结算→下一天）与存读档功能
