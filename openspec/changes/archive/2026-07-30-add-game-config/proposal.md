## Why

一天营业的真实时长、售卖采样密度、时间倍速目前以 `const` 硬编码在 `day_cycle.gd`（`DAY_DURATION_SEC` / `TICKS_PER_DAY`），调节手感每次都要改代码，违背项目「数据驱动、加内容不改代码」的地基约定。需要把这些时间参数抽成专门的可配置数据资源，便于反复调节节奏而无需改动逻辑。

## What Changes

- 新增全局配置资源 `GameConfig`（`extends Resource`，`class_name GameConfig`），承载时间相关可调参数：
  - `day_duration_sec`：一天营业的真实秒数（手感核心参数）
  - `ticks_per_day`：售卖采样密度（内部平滑度参数）
  - `time_scale`：时间倍速系数（预留倍速/暂停能力，`0` = 暂停，`1` = 常速）
- `DayCycle`（Autoload）启动时从固定路径 `res://data/config/game_config.tres` 加载 `GameConfig`；文件缺失或字段非法时回退到内置默认值（当前 90 秒 / 20 ticks / 1.0 倍速），保证不崩溃。
- `DayCycle` 营业阶段推进按 `time_scale` 缩放真实时间（`time_scale = 0` 即暂停营业时钟与制作时钟）。
- 将 `DAY_DURATION_SEC` / `TICKS_PER_DAY` / `TICK_INTERVAL` 三个 `const` 改为读取配置的运行时值；`DC.TICKS_PER_DAY`、`DC.DAY_DURATION_SEC` 的外部引用（`game_session.gd`、`simulation_panel.gd`、`main.gd`）改为读运行时值。
- 更新已过期的 `day-cycle` 规格（现仍描述旧的 `Timer` + tick 上限驱动模型），使其与「真实时间时钟 + 配置化时长」的现有实现一致。
- 命名采用术语表「天」措辞（`day_*`），与 `DayCycle` 内部既有 `day_*` 命名天然一致；术语表已确立以「天」为准（弃用「回合」），原计划的 day→round 重命名 change 取消。

## Capabilities

### New Capabilities
- `game-config`: 全局可配置数据资源，定义时间参数（一天时长、售卖采样密度、时间倍速）的字段、默认值与加载/兜底规则。

### Modified Capabilities
- `day-cycle`: 一天循环的时长与 tick 密度来源从硬编码常量改为读取 `GameConfig`；营业阶段时钟按 `time_scale` 缩放（支持暂停/倍速）；同步纠正规格中过期的 `Timer` 驱动描述为真实时间时钟驱动。

## Impact

- 新增脚本：`game/scripts/data/game_config.gd`。
- 新增数据资源（由用户在编辑器内创建）：`game/data/config/game_config.tres`。
- 修改脚本：`game/scripts/core/day_cycle.gd`（const → 配置注入 + time_scale 缩放）、`game/scripts/core/game_session.gd`、`game/scripts/ui/simulation_panel.gd`、`game/scripts/main.gd`（引用改为运行时值）。
- 修改规格：`openspec/specs/day-cycle/spec.md`。
- 存档：本次不改存档字段（时间参数属配置而非运行态），无存档兼容风险。
- 不在本次范围：时长下放到 `Location` 的按地点差异化（后续）；项目其余文档 / 代码注释里「回合」残留措辞的清理（术语表已弃用「回合」，属遗留、可后续顺带处理）。
