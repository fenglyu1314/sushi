## Context

见 proposal.md - Why。当前 `day_cycle.gd` 用三个 `const` 承载时间参数：

```
const DAY_DURATION_SEC: float = 90.0
const TICKS_PER_DAY: int = 20
const TICK_INTERVAL: float = DAY_DURATION_SEC / TICKS_PER_DAY
```

`DayCycle` 是 Autoload 单例，是这些参数的唯一消费者；营业推进在 `_process(delta)` 中累加真实时间。外部通过类常量方式引用：`game_session.gd`（`DC.TICKS_PER_DAY`）、`simulation_panel.gd`（`DC.DAY_DURATION_SEC`）、`main.gd`（`DayCycle.TICKS_PER_DAY`）。项目已有成熟的数据资源约定（`extends Resource` + `class_name` + `@export`，见 `location.gd`），但内容资源经 `ContentDB` 扫目录加载，而配置是「单例」而非集合。

## Goals / Non-Goals

**Goals:**
- 时间参数（一天时长 / tick 密度 / 倍速）沉淀为单一全局配置资源，编辑器可调、无需改代码。
- `DayCycle` 自加载配置，缺失/非法时安全兜底到默认值。
- 引入 `time_scale` 缩放营业时钟，为暂停/倍速留出统一入口。

**Non-Goals:**
- 不改动 `DayCycle` 内部既有 `day_*` 命名、事件名、存档字段（术语表已以「天」为准，配置字段同用 `day_*`，措辞天然一致，无需再做 day→round 重命名 change）。
- 不把时长下放到 `Location`（按地点差异化留后续）。
- 不新增暂停/倍速的 UI 控件（本次只打通数据与逻辑通路，`time_scale` 可先在 `.tres` 里改）。

## Decisions

### 决策 1：配置形态 = 单一 `GameConfig` 资源，固定路径加载
- 新增 `game/scripts/data/game_config.gd`：`extends Resource`、`class_name GameConfig`，`@export` 三个字段并附带 `@export_range` 约束与默认值；提供只读取值方法（对非法值就地回退默认）。
- 资源实例固定路径 `res://data/config/game_config.tres`（新增 `config/` 子目录），由用户在编辑器内创建（§3.1）。
- **为何不走 `ContentDB`**：`ContentDB` 语义是「扫目录聚合成集合」，而配置是单例、且 `DayCycle`（Autoload）在会话建立前就需要它。让 `DayCycle` 自 `load` 固定路径最内聚，避免注入时序耦合（对应用户选定的方案 A）。
- **备选**：由 `GameSession` `@export` 引用注入（拖拽指定）——放弃，因为破坏「丢文件即生效」且引入注入时序问题。

### 决策 2：`const` → 运行时值，`TICK_INTERVAL` 改为按当前 tick 计算
- `DayCycle` 持有 `var _config: GameConfig`，在 `_ready()`（或首次进入模拟前）加载。
- 暴露只读取值：`get_day_duration_sec()`、`get_ticks_per_day()`、`get_time_scale()`（或等价属性），供外部与内部统一读取。
- tick 边界判定从「固定 `TICK_INTERVAL` 常量」改为按 `day_duration_sec / ticks_per_day` 实时推导，保证改配置即时生效。
- **外部引用改造**：`game_session.gd` 的 `DC.TICKS_PER_DAY` → 读运行时值；`simulation_panel.gd` 的 `DC.DAY_DURATION_SEC` → 读运行时值；`main.gd` 的 `DayCycle.TICKS_PER_DAY` → 读运行时值。为降低散落风险，优先通过 `DayCycle` 的取值方法统一出口。

### 决策 3：`time_scale` 在 `_process` 入口缩放 delta
- 在 `DayCycle._process(delta)` 的模拟分支，用 `scaled = delta * time_scale` 参与营业累计与 `advance_crafting(scaled)`，使营业倒计时与制作进度天然同步缩放、同起同停（复用现有单一时钟设计）。
- `time_scale = 0` 即 `scaled = 0`，营业与制作双双静止；决策/结算分支本就 return，不受影响。

### 决策 4：规格纠偏
- 现 `openspec/specs/day-cycle/spec.md` 的「模拟阶段固定步长 tick 推进」描述的是旧 `Timer` 模型，与代码不符。本次 delta 以 MODIFIED 将其纠正为「真实时间时钟推进 + 配置化时长」，archive 时并入主 spec。

## Risks / Trade-offs

- [`const` 改运行时值遗漏某处引用导致取到旧值/报错] → 全局搜索 `TICKS_PER_DAY` / `DAY_DURATION_SEC` / `TICK_INTERVAL` 三个符号，逐处替换并自检；改造后运行空跑一天验证。
- [配置文件缺失或字段乱填导致运行异常] → `GameConfig` 取值方法内做正数/正整数/非负校验并回退默认；`DayCycle` load 失败时用默认实例。
- [`time_scale` 引入后与既有手感参数交互，调值困惑] → 默认 `1.0` 保持现状；文档注释写清 `day_duration_sec` 是「常速下的一天时长」，实际时长 = 时长 / time_scale。
- [项目其余文档 / 代码注释仍有个别「回合」残留（如 `shelf-buffer` spec、`location.gd`、`run_state.gd` 注释）] → 术语表已把「回合」列为弃用叫法，这些属遗留措辞、不影响本变更逻辑；可在后续维护中顺带清理，本次不扩大范围。
