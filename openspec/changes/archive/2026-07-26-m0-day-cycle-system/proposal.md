## Why

M0 是项目骨架里程碑（见 `docs/03-开发路线图.md`）。后续 M1-M5 所有玩法都在"一天为一局 + 内部 tick 推进"的时间模型上叠加新约束层，因此必须先建立这个地基并验证其可跑通。事件总线是架构约定的系统间解耦中枢（`docs/02-技术架构.md` §4），存档是经营模拟的必备能力。M0 的验证目标是：能运行一个空的"一天"循环（决策→模拟→结算→下一天）。

## What Changes

- 新增**事件总线** Autoload（`EventBus`）：声明日周期信号（`day_started` / `phase_changed` / `tick_advanced` / `day_ended`），作为系统间解耦通信中枢。M0 只放日循环必需信号，后续按需扩展。
- 新增**时间/tick 系统** Autoload（`DayCycle`）：实现"决策→模拟→结算"三阶段状态机；模拟阶段用固定步长 tick 推进（不依赖帧率）；提供 `start_new_day` / `begin_simulation` / `set_phase` 等接口。
- 新增**存档** Autoload（`SaveManager`）：M0 阶段序列化日周期状态（day/phase/tick），验证存读机制；后续扩展现金/库存/布局。
- 新增**M0 验证主场景** `main.tscn` + `main.gd`：通过按键驱动空的一天循环并验证存读档（决策按空格→模拟→结算按回车→下一天；S 存档 / L 读档）。
- 在 `project.godot` 注册 3 个 Autoload（顺序：`EventBus` → `DayCycle` → `SaveManager`）。

## Capabilities

### New Capabilities

- `event-bus`: 全局事件总线 Autoload，声明信号供系统间解耦通信。
- `day-cycle`: 一天循环时间系统，决策/模拟/结算三阶段状态机 + 固定步长 tick 推进。
- `save-system`: 基础存档系统，M0 阶段序列化日周期状态。

### Modified Capabilities

无（`openspec/specs/` 当前为空，均为新建）。

## Impact

- 新增脚本：`game/scripts/core/{event_bus, day_cycle, save_manager}.gd`、`game/scripts/main.gd`
- 新增场景：`game/scenes/main.tscn`（在 Godot 编辑器内创建，根节点挂 `main.gd`）
- 配置变更：`project.godot` 注册 3 个 Autoload + 设主场景（编辑器内操作，非直接编辑文件）
- 后续影响：M1+ 的采购/生产/售卖等系统将连接 `EventBus` 信号、遵循 `DayCycle` 阶段、通过 `SaveManager` 存档
